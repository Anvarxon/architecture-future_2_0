# Каталог доменных событий

## Общие правила

**Именование:** `<Контекст>.<Агрегат><ГлаголВПрошедшемВремени>` — событие описывает
свершившийся факт, а не намерение. `LoanApplicationSubmitted`, а не `SubmitLoanApplication`.

**Топики:** `future20.<домен>.<агрегат>.v<major>` — например,
`future20.lending.credit-agreement.v1`. Ключ партиционирования — идентификатор агрегата:
это гарантирует порядок событий одного агрегата.

**Формат:** Avro со схемой в Schema Registry, режим совместимости `BACKWARD`
(новые подписчики читают старые сообщения; добавление поля с default разрешено,
удаление обязательного поля — нет).

**Гарантии доставки:** at-least-once на транспорте + идемпотентность обработчиков по
`event_id`. Exactly-once достигается не транспортом, а идемпотентностью бизнес-эффекта.

**DLQ:** сообщение, не прошедшее валидацию схемы или обработку после N повторов,
уходит в `<топик>.dlq` с причиной и алертом владельцу домена-издателя. Потери сообщений
не происходит ни при каком сценарии обработки.

### Конверт события (обязателен для всех событий)

```json
{
  "event_id":      "01J8...",        // UUIDv7, ключ идемпотентности
  "event_type":    "lending.CreditAgreementCreated",
  "event_version": 1,                 // major-версия схемы
  "occurred_at":   "2026-03-14T09:21:03.412Z",  // событийное время домена-источника
  "produced_at":   "2026-03-14T09:21:03.508Z",  // время публикации
  "producer":      "lending-service",
  "aggregate_id":  "agr_7f3c...",
  "correlation_id":"...",             // сквозной идентификатор бизнес-операции
  "causation_id":  "...",             // событие/команда-причина
  "tenant":        "ru-central",      // регион/юрлицо — для геораспределения
  "data_class":    "internal",        // public | internal | pii | financial | phi
  "payload":       { }
}
```

`correlation_id` и `causation_id` обязательны: без них расследование сквозного инцидента
в событийной системе превращается в археологию.

**Класс данных (`data_class`)** определяет маршрутизацию: события класса `phi`
не имеют коннектора в аналитический контур — ограничение действует на уровне платформы.

---

## 1. Party & Identity

| Событие | Семантика | Минимальный контракт | Подписчики | SLA |
|---|---|---|---|---|
| `PartyIdentified` | зарегистрировано физическое/юридическое лицо | `party_id`, `party_type`, `created_at`, `identity_hash` | Patient Care, Patient Access, Lending, Accounts, Billing, Data Platform | ≤ 5 с |
| `PartyAttributesUpdated` | изменены реквизиты | `party_id`, `changed_fields[]`, `version` | те же | ≤ 5 с |
| `PartyMerged` | две записи признаны одним лицом | `surviving_party_id`, `merged_party_id`, `reason` | те же | ≤ 5 с |
| `PartyBlocked` | лицо заблокировано (комплаенс) | `party_id`, `reason_code`, `blocked_until` | Lending, Accounts, Patient Access | ≤ 1 с |

`data_class`: `pii`. В аналитический контур попадает только псевдонимизированный `party_ref`.

> `PartyMerged` — событие, которое обязаны обработать все домены: оно требует
> перенаправления локальных ссылок. Именно его отсутствие в текущей архитектуре
> порождает дубли клиентов в отчётности.

## 2. Consent

| Событие | Семантика | Минимальный контракт | Подписчики | SLA |
|---|---|---|---|---|
| `ConsentGranted` | получено согласие на обработку | `consent_id`, `party_id`, `purpose`, `scope[]`, `valid_until` | Patient Care, AI Diagnostics, Data Platform | ≤ 1 с |
| `ConsentRevoked` | согласие отозвано | `consent_id`, `party_id`, `purpose`, `revoked_at` | те же | **≤ 1 с, приоритетный топик** |
| `ConsentExpired` | истёк срок действия | `consent_id`, `party_id`, `purpose` | те же | ≤ 60 с |

`data_class`: `pii`. Отзыв согласия обрабатывается вне общей очереди: задержка здесь —
регуляторный риск, а не неудобство.

## 3. Patient Access

| Событие | Семантика | Минимальный контракт | Подписчики | SLA |
|---|---|---|---|---|
| `AppointmentScheduled` | **зарегистрирован новый пациент на приём** | `appointment_id`, `party_ref`, `provider_id`, `clinic_id`, `service_code`, `slot_start`, `slot_end` | Patient Care, Workforce, Data Platform | ≤ 5 с |
| `AppointmentConfirmed` | пациент подтвердил визит | `appointment_id`, `confirmed_at`, `channel` | Patient Care, Data Platform | ≤ 5 с |
| `AppointmentCancelled` | запись отменена | `appointment_id`, `cancelled_by`, `reason_code` | Patient Care, Workforce, Data Platform | ≤ 5 с |
| `NoShowRegistered` | пациент не явился | `appointment_id`, `registered_at` | Data Platform, Medical Billing | ≤ 60 с |
| `SchedulePublished` | опубликовано расписание на период | `provider_id`, `period_start`, `period_end`, `slot_count` | Data Platform | ≤ 60 с |

`data_class`: `internal`. Персональные данные пациента в события не входят — только `party_ref`.

## 4. Patient Care 🔒

| Событие | Семантика | Минимальный контракт (аналитический контур) | Подписчики | SLA |
|---|---|---|---|---|
| `EncounterStarted` | приём начат | `encounter_id`, `appointment_id`, `party_ref`, `provider_id`, `clinic_id`, `started_at` | Medical Billing, Patient Access, Data Platform | ≤ 5 с |
| `EncounterCompleted` | приём завершён | `encounter_id`, `duration_min`, `service_codes[]`, `completed_at` | Medical Billing, Data Platform | ≤ 5 с |
| `EncounterCancelled` | приём отменён | `encounter_id`, `reason_code` | Medical Billing, Data Platform | ≤ 5 с |
| `ClinicalOrderPlaced` | назначено исследование/процедура | `order_id`, `encounter_id`, `order_type`, `modality`, `placed_at` | AI Diagnostics, Inventory, Data Platform | ≤ 1 с |
| `TreatmentPlanApproved` | утверждён план лечения | `plan_id`, `party_ref`, `total_amount`, `currency`, `duration_days` | Lending, Medical Billing, Data Platform | ≤ 5 с |

**Ключевое ограничение.** Существует **две** проекции этих событий:

* внутренняя (`data_class: phi`, топик доступен только медицинскому контуру) — содержит
  клиническое содержание;
* внешняя (`data_class: internal`, поля из таблицы выше) — операционные атрибуты без
  диагнозов, назначений и текстов.

Разделение выполняется в домене-издателе, а не в потребителе. Добавление клинического
поля во внешнюю схему блокируется проверкой в CI (сканер полей + обязательное ревью
владельца домена и офицера ИБ).

## 5. AI Diagnostics 🔒

| Событие | Семантика | Минимальный контракт (внешняя проекция) | Подписчики | SLA |
|---|---|---|---|---|
| `AIStudyRequested` | запрошен анализ | `study_id`, `order_id`, `modality`, `model_id`, `requested_at` | Data Platform | ≤ 1 с |
| `AIStudyCompleted` | **пройдено исследование ИИ** | `study_id`, `order_id`, `model_version_id`, `confidence`, `processing_ms`, `requires_physician_review` | Patient Care (полная версия), Data Platform (без выводов) | ≤ 2 с |
| `AIStudyRejected` | анализ не выполнен (нет согласия/данных) | `study_id`, `reason_code` | Patient Care, Data Platform | ≤ 2 с |
| `AIStudyFailed` | техническая ошибка инференса | `study_id`, `error_code`, `model_version_id` | Patient Care, Data Platform, наблюдаемость | ≤ 2 с |
| `ModelVersionPublished` | опубликована версия модели | `model_version_id`, `model_id`, `metrics{}`, `published_at` | Data Platform, комплаенс | ≤ 60 с |
| `ModelDriftDetected` | обнаружен дрейф модели | `model_version_id`, `metric`, `observed`, `threshold` | AI Diagnostics, Data Platform, комплаенс | ≤ 60 с |

Клиническое содержание заключения (`findings`) присутствует только во внутренней
проекции `AIStudyCompleted` для Patient Care. В аналитику уходят метрики работы моделей —
именно они нужны для монетизации ИИ-функций, заявленной в трёхлетних целях.

## 6. Medical Billing

| Событие | Семантика | Минимальный контракт | Подписчики | SLA |
|---|---|---|---|---|
| `ServiceInvoiceIssued` | выставлен счёт за услугу | `invoice_id`, `encounter_id`, `party_ref`, `amount`, `currency`, `service_codes[]`, `payer_type` | Accounts & Payments, Corporate Finance, Data Platform | ≤ 5 с |
| `ServiceInvoiceSettled` | счёт оплачен | `invoice_id`, `settled_amount`, `payment_id`, `funding_source` | Corporate Finance, Data Platform | ≤ 5 с |
| `ServiceInvoiceVoided` | счёт аннулирован | `invoice_id`, `reason_code`, `reversal_document_id` | Corporate Finance, Data Platform | ≤ 5 с |
| `InsuranceClaimSubmitted` | обращение направлено в страховую | `claim_id`, `invoice_id`, `insurer_id`, `amount` | Corporate Finance, Data Platform | ≤ 60 с |
| `InsuranceClaimAccepted` / `Rejected` | ответ страховой | `claim_id`, `decision`, `approved_amount`, `reason_code` | Medical Billing, Corporate Finance, Data Platform | ≤ 60 с |

`data_class`: `financial`. Коды услуг передаются как коды тарифа, без клинической расшифровки.

## 7. Lending

| Событие | Семантика | Минимальный контракт | Подписчики | SLA |
|---|---|---|---|---|
| `LoanApplicationSubmitted` | подана заявка | `application_id`, `party_ref`, `product_code`, `amount`, `term_months`, `channel` | Accounts, Corporate Finance, Data Platform | ≤ 5 с |
| `LoanApplicationScored` | заявка оценена | `application_id`, `score`, `model_version_id`, `decision_factors[]` | Data Platform, комплаенс | ≤ 5 с |
| `LoanApplicationApproved` | заявка одобрена | `application_id`, `approved_amount`, `rate`, `valid_until` | Accounts, Data Platform | ≤ 5 с |
| `LoanApplicationRejected` | заявка отклонена | `application_id`, `reason_code` | Data Platform | ≤ 5 с |
| `CreditAgreementCreated` | **создан кредитный договор** | `agreement_id`, `application_id`, `party_ref`, `principal`, `rate`, `term_months`, `signed_at` | Accounts, Medical Billing, Corporate Finance, Data Platform | ≤ 2 с |
| `CreditAgreementAmended` | изменены условия | `agreement_id`, `amendment_id`, `changed_terms{}` | те же | ≤ 5 с |
| `CreditAgreementClosed` | договор закрыт | `agreement_id`, `closed_at`, `close_reason` | те же | ≤ 5 с |
| `RepaymentScheduleActivated` | активирован график | `schedule_id`, `agreement_id`, `installments[]` | Accounts, Data Platform | ≤ 5 с |
| `RepaymentReceived` | получен платёж по кредиту | `agreement_id`, `payment_id`, `amount`, `period` | Accounts, Corporate Finance, Data Platform | ≤ 5 с |
| `RepaymentOverdue` | платёж просрочен | `agreement_id`, `period`, `days_overdue`, `outstanding_amount` | Accounts, Corporate Finance, Data Platform, комплаенс | ≤ 60 с |

`data_class`: `financial`. `decision_factors[]` обязателен: банк должен уметь объяснить
решение клиенту и регулятору.

### Пример полного контракта: `CreditAgreementCreated`

```json
{
  "event_id": "01J8ZK3Q2M7X4V0T5R8N1P6Y3D",
  "event_type": "lending.CreditAgreementCreated",
  "event_version": 1,
  "occurred_at": "2026-03-14T09:21:03.412Z",
  "produced_at": "2026-03-14T09:21:03.508Z",
  "producer": "lending-service",
  "aggregate_id": "agr_7f3c9a12",
  "correlation_id": "req_5a1e88b0",
  "causation_id": "01J8ZK3PWQ0000000000000000",
  "tenant": "ru-central",
  "data_class": "financial",
  "payload": {
    "agreement_id": "agr_7f3c9a12",
    "application_id": "app_2b91cc07",
    "party_ref": "prt_9d41e5f8",
    "product_code": "MED_INSTALLMENT_12",
    "principal": 480000.00,
    "currency": "RUB",
    "rate": 12.5,
    "term_months": 12,
    "signed_at": "2026-03-14T09:21:02Z",
    "purpose_ref": "plan_31ba77"
  }
}
```

`purpose_ref` — ссылка на план лечения; сам план остаётся в медицинском домене.
Финансовый домен знает, что кредит связан с медицинской услугой, но не знает, с какой.

## 8. Accounts & Payments

| Событие | Семантика | Минимальный контракт | Подписчики | SLA |
|---|---|---|---|---|
| `AccountOpened` | открыт счёт | `account_id`, `party_ref`, `currency`, `account_type` | Lending, Corporate Finance, Data Platform | ≤ 5 с |
| `PaymentInitiated` | платёж инициирован | `payment_id`, `from_account`, `to_account`, `amount`, `idempotency_key` | Data Platform | ≤ 1 с |
| `PaymentCaptured` | платёж проведён | `payment_id`, `amount`, `captured_at`, `ledger_entry_ids[]` | Medical Billing, Lending, Corporate Finance, Data Platform | ≤ 1 с |
| `PaymentFailed` | платёж не прошёл | `payment_id`, `error_code`, `retryable` | инициатор, Data Platform | ≤ 1 с |
| `PaymentReversed` | платёж сторнирован | `payment_id`, `reversal_id`, `reason_code` | те же | ≤ 1 с |
| `FundsDisbursed` | средства выданы по кредиту | `agreement_id`, `account_id`, `amount`, `disbursed_at` | Lending, Corporate Finance, Data Platform | ≤ 1 с |

`data_class`: `financial`. Топики финансовых событий имеют повышенный retention
(требования к хранению и восстановлению).

## 9. Workforce

| Событие | Семантика | Минимальный контракт | Подписчики |
|---|---|---|---|
| `EmployeeHired` | принят сотрудник | `employee_id`, `party_ref`, `role`, `unit_id`, `hired_at` | Patient Access, Data Platform |
| `EmployeeQualificationUpdated` | изменена квалификация | `employee_id`, `qualification_code`, `valid_until` | Patient Access, Data Platform |
| `ShiftPlanned` | запланирована смена | `shift_id`, `employee_id`, `starts_at`, `ends_at`, `unit_id` | Patient Access, Data Platform |
| `EmployeeTerminated` | сотрудник уволен | `employee_id`, `terminated_at` | Patient Access, Data Platform, ИБ |

`data_class`: `pii`.

## 10. Inventory & Equipment

| Событие | Семантика | Минимальный контракт | Подписчики |
|---|---|---|---|
| `StockReceived` | поступление на склад | `sku_id`, `location_id`, `quantity`, `batch_id`, `expires_at` | Data Platform, Pharmacy |
| `StockConsumed` | списание | `sku_id`, `location_id`, `quantity`, `encounter_ref` | Medical Billing, Data Platform |
| `StockLevelLow` | остаток ниже порога | `sku_id`, `location_id`, `current`, `threshold` | Pharmacy, Data Platform |
| `EquipmentMaintenanceDue` | требуется обслуживание | `equipment_id`, `due_at`, `severity` | Patient Access, Data Platform |
| `EquipmentDecommissioned` | оборудование выведено | `equipment_id`, `reason_code` | Patient Access, Data Platform |

## 11. Corporate Finance

| Событие | Семантика | Минимальный контракт | Подписчики |
|---|---|---|---|
| `FinancialPeriodClosed` | закрыт учётный период | `period`, `closed_at`, `control_totals{}` | Data Platform, все домены |
| `LedgerEntryPosted` | проведена запись в главной книге | `entry_id`, `account_code`, `amount`, `direction`, `period` | Data Platform |

`FinancialPeriodClosed` — сигнал для витрин: показатели за закрытый период
считаются окончательными и не пересчитываются.

## 12. Data Platform

| Событие | Семантика | Минимальный контракт | Подписчики |
|---|---|---|---|
| `DataProductPublished` | опубликована версия дата-продукта | `product_id`, `version`, `owner`, `sla{}`, `data_class`, `schema_ref` | портал, домены-потребители |
| `DataProductDeprecated` | версия объявлена устаревшей | `product_id`, `version`, `sunset_at`, `replacement` | те же |
| `DataQualityViolated` | нарушено качество данных | `product_id`, `check`, `observed`, `expected`, `severity` | владелец продукта, портал |
| `AccessRequested` / `AccessGranted` / `AccessRevoked` | движение доступа к продукту | `grant_id`, `product_id`, `principal`, `scope`, `valid_until` | портал, аудит |

## 13. Планируемые домены

| Событие | Контекст | Семантика |
|---|---|---|
| `PharmacyOrderPlaced`, `PharmacyOrderFulfilled` | Pharmacy & Supply | заказ препаратов размещён/исполнен |
| `DrugCatalogUpdated` | Pharmacy & Supply | обновлён каталог препаратов |
| `DeviceReadingReceived` | Device Telemetry | получены показания оборудования |
| `DeviceHealthDegraded` | Device Telemetry | состояние оборудования ухудшилось (предиктивное обслуживание) |

Подключение этих доменов **не требует изменений** в существующих: они публикуют события
в свои топики и регистрируют дата-продукты в каталоге. Это и есть проверка того, что
архитектура выдерживает рост числа направлений.

---

## Мосты совместимости на время миграции

| Мост | Направление | Срок жизни |
|---|---|---|
| CDC из DWH → события (через ACL) | легаси → новые домены | этапы 1–2 |
| События → обратная запись в DWH | новые домены → легаси-отчётность | этап 2, до подтверждения паритета |
| Camel-маршруты → ACL → события | внешние интеграции | этапы 1–2, отключаются по мере переноса |

Каждый мост имеет **дату вывода** в реестре и владельца. Мост без даты вывода —
это не мост, а новая постоянная зависимость.
