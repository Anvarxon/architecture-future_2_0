# Task 2 Advanced — удалённое состояние (S3) и CI/CD для Terraform

Автоматизация развёртывания инфраструктуры: состояние хранится в S3-совместимом
объектном хранилище, применение идёт через пайплайн с ручным подтверждением.

> **Проверено на живом облаке.** Результаты фактических запусков против Yandex Cloud —
> в [docs/plan-evidence.md](docs/plan-evidence.md): dev развёрнут, для stage и prod
> построены планы, состояние подтверждённо хранится в бакете.

## Структура

```
Task2Advanced/
├── bootstrap/                     # разовая подготовка backend'а (бакет, KMS, сервисные аккаунты)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   └── terraform.tfvars.example
├── envs/
│   ├── dev/
│   │   ├── backend.tf             # terraform { backend "s3" {} } — частичная конфигурация
│   │   ├── backend-dev.hcl        # неконфиденциальные параметры backend'а
│   │   ├── backend-minio.hcl.example
│   │   ├── main.tf                # вызов модуля из Task1Advanced/modules/vm
│   │   ├── network.tf, providers.tf, variables.tf, outputs.tf, versions.tf
│   │   └── dev.tfvars
│   ├── stage/  (backend-stage.hcl, stage.tfvars)
│   └── prod/   (backend-prod.hcl,  prod.tfvars)
└── ci/
    └── gitlab-ci.terraform.yml    # переиспользуемый компонент GitLab CI

.gitlab-ci.yml                     # корневой конвейер GitLab (include компонента)
.github/workflows/terraform.yml    # альтернативная реализация на GitHub Actions
.github/workflows/terraform-apply.yml
```

Окружения **не дублируют** модуль: `main.tf` каждого окружения ссылается на
`../../../Task1Advanced/modules/vm`. Один модуль — два задания, ноль копипасты.

## 1. Удалённое состояние

### Почему так

| Решение | Причина |
|---|---|
| S3-совместимое хранилище (Yandex Object Storage / MinIO / AWS S3) | состояние доступно всей команде и CI, не лежит на ноутбуке инженера |
| Отдельный ключ (`key`) на окружение | `dev` физически не может перезаписать состояние `prod` |
| `use_lockfile = true` | блокировка состояния: одновременные `apply` из CI и с локальной машины невозможны |
| Версионирование бакета | повреждённое или частично записанное состояние можно откатить |
| Шифрование KMS + запрет анонимного доступа | в state попадают чувствительные значения (IP, ID, иногда пароли) |
| Частичная конфигурация backend'а | в Git нет ни одного ключа доступа: только имя бакета и путь |

### Конфигурация

`envs/<env>/backend.tf` содержит пустой блок — все параметры передаются при `init`:

```hcl
terraform {
  backend "s3" {}
}
```

`envs/dev/backend-dev.hcl`:

```hcl
bucket = "future20-tfstate-uz01"
key    = "task2advanced/dev/terraform.tfstate"
region = "ru-central1"

endpoints = { s3 = "https://storage.yandexcloud.net" }

skip_region_validation      = true
skip_credentials_validation = true
skip_requesting_account_id  = true
skip_metadata_api_check     = true
skip_s3_checksum            = true
use_path_style              = true
use_lockfile                = true
```

Ключи доступа передаются **только** переменными окружения:

```bash
export AWS_ACCESS_KEY_ID="<static access key сервисного аккаунта>"
export AWS_SECRET_ACCESS_KEY="<secret key>"
```

> `use_lockfile` требует Terraform >= 1.11 (или OpenTofu >= 1.11). На более старых
> версиях блокировка настраивается через `dynamodb_table` + Yandex Document API (YDB).

### Разовая подготовка (bootstrap)

`bootstrap/` создаёт бакет состояния, KMS-ключ и сервисные аккаунты CI —
по одному на окружение. Его собственное состояние локальное: он создаёт то
хранилище, в котором будут храниться все остальные состояния.

```bash
cd Task2Advanced/bootstrap
cp terraform.tfvars.example terraform.tfvars   # подставить свои cloud_id / folder_id
export YC_TOKEN=$(yc iam create-token)

terraform init
terraform apply

# Ключи доступа для CI — выгружаются один раз и переносятся в защищённые переменные CI/CD.
terraform output -json ci_access_keys
```

После этого `bootstrap.tfstate` убирается в защищённое хранилище (или сам импортируется
в созданный бакет отдельным `terraform init -migrate-state`).

### Локальный запуск окружения

```bash
cd Task2Advanced/envs/dev

export YC_SERVICE_ACCOUNT_KEY_FILE=/secure/path/sa-key.json
export AWS_ACCESS_KEY_ID=...        # ключ доступа к бакету состояния
export AWS_SECRET_ACCESS_KEY=...

terraform init -backend-config=backend-dev.hcl
terraform plan  -var-file=dev.tfvars -out=dev.tfplan
terraform apply dev.tfplan
```

Проверка, что состояние действительно удалённое:

```bash
ls terraform.tfstate           # файла нет
terraform state list           # список ресурсов приходит из бакета
```

Отладка без облака — тот же код поверх локального MinIO
(`envs/dev/backend-minio.hcl.example`, инструкция внутри файла).

## 2. Пайплайн

Основная реализация — GitLab CI (`ci/gitlab-ci.terraform.yml`, подключается из корневого
`.gitlab-ci.yml`). Эквивалент на GitHub Actions — в `.github/workflows/`.

### Стадии

| Стадия | Job | Что делает | Когда |
|---|---|---|---|
| `validate` | `fmt` | `terraform fmt -check -recursive -diff` | MR и основная ветка |
| `validate` | `validate` (matrix dev/stage/prod) | `init -backend=false` + `validate` — синтаксис без доступа к секретам | MR и основная ветка |
| `security` | `tfsec` | статический анализ IaC, отчёт в формате JUnit | MR и основная ветка |
| `plan` | `plan:dev` | `terraform plan -out=dev.tfplan`, план в артефакте и в виджете MR | MR и основная ветка |
| `plan` | `plan:stage`, `plan:prod` | то же для stage и prod | только основная ветка |
| `apply` | `apply:dev` | `terraform apply <env>.tfplan` | автоматически после мержа |
| `apply` | `apply:stage` | то же | **вручную** (`when: manual`) |
| `apply` | `apply:prod` | то же | **вручную** + approval у Environment, только после `apply:stage` |
| `destroy` | `destroy:dev/stage` | `terraform destroy` | вручную; для prod job отсутствует намеренно |

### Ключевые решения пайплайна

**Apply применяет проверенный план, а не пересчитывает его.**
`plan` сохраняет бинарный `<env>.tfplan` артефактом, `apply` запускает именно его.
Между проверкой и применением ничего не может измениться незаметно: если состояние
успело поменяться, `apply` упадёт — это желаемое поведение.

**Состояние никогда не локальное.** Каждый job начинается с
`terraform init -backend-config=backend-$ENVIRONMENT.hcl`. Локальный `terraform.tfstate`
не создаётся, а `.gitignore` дополнительно исключает его из репозитория.

**Изоляция окружений:**

* отдельный сервисный аккаунт Yandex Cloud на каждое окружение (создаётся в `bootstrap`);
* отдельный каталог (folder) облака на каждое окружение — разные квоты и права;
* отдельный префикс в бакете состояния;
* отдельный набор секретов: в GitLab — переменные со scope окружения, в GitHub — секреты
  уровня Environment. Job окружения `dev` физически не видит учётные данные `prod`.

**Секреты.** В репозитории нет ни одного секрета. В CI используются:

| Переменная | Тип | Назначение |
|---|---|---|
| `YC_SA_KEY_FILE` (GitLab, тип File) / `YC_SA_KEY_JSON` (GitHub, secret) | masked; protected для stage и prod | ключ сервисного аккаунта Yandex Cloud |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (`TFSTATE_*` в GitHub) | masked; protected для stage и prod | доступ к бакету состояния |
| `TF_SSH_PUBLIC_KEY` / `vars.SSH_PUBLIC_KEY` | обычная переменная | публичный SSH-ключ (не секрет, но не хардкодится) |
| `TF_VAR_cloud_id` / `vars.YC_CLOUD_ID` | обычная переменная | ID облака |
| `TF_VAR_folder_id` / `vars.YC_FOLDER_ID` | обычная переменная | ID каталога окружения |

Идентификаторов облака нет и в `.tfvars`: они различаются между инсталляциями и не
являются частью профиля окружения. Заглушки в файле были бы хуже их отсутствия —
с ними `apply` уходит в несуществующий каталог с невнятной ошибкой, а без них
Terraform прямо называет недостающую переменную.

Переменные окружения **dev намеренно не помечены как protected**: именно поэтому план для
dev виден прямо в merge request — это главная ценность ревью инфраструктурных изменений.
Компрометация dev-учётных данных не даёт доступа ни к stage, ни к prod: разные сервисные
аккаунты, разные каталоги облака, разные префиксы в бакете состояния. Переменные stage и
prod защищены, поэтому пайплайн непроверенной ветки до них не дотянется — и по этой же
причине план для stage и prod строится только на основной ветке.

Файл ключа сервисного аккаунта в GitHub Actions создаётся с `umask 077` и удаляется
шагом с `if: always()` — он не остаётся на раннере даже при падении job.

**Ограничение доступа к ветке.** Все `apply`-job'ы выполняются только для основной ветки
(`$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH` / `github.ref == 'refs/heads/main'`).
Переменные помечены как protected, поэтому даже принудительный запуск пайплайна из
произвольной ветки не получит доступа к учётным данным prod.

**Порядок раскатки.** `apply:prod` объявляет зависимость от `apply:stage`: попасть в прод
минуя stage нельзя. Это защита не от техники, а от процесса.

**Артефакты планов живут 3 дня** — план может содержать чувствительные значения,
поэтому долго его хранить не нужно.

### Поведение, пока секреты не настроены

Код требует реального бакета состояния и сервисного аккаунта. Если секреты в репозитории
ещё не заведены, `terraform init` падает с `No valid credential sources found` — S3-backend
не находит ключей доступа. Чтобы это не выглядело как поломка конфигурации, в GitHub Actions
добавлена явная проверка: шаг `Проверить наличие учётных данных` определяет, заданы ли
секреты, и если нет — шаги `init`/`plan`/`apply` пропускаются с пояснением в аннотации job'а.

При этом всё, что не требует облака, продолжает работать в полную силу: `terraform fmt`,
`terraform validate` для трёх окружений и статический анализ tfsec. То есть пайплайн
проверяет корректность кода даже без облачного аккаунта, а после добавления секретов
те же job'ы начинают строить и применять реальные планы — менять ничего не нужно.

> Контекст `secrets` в GitHub Actions недоступен в условиях `if` на уровне job и step,
> поэтому проверка сделана через `env` в отдельном шаге с `id: creds` — это стандартный
> обходной путь. В GitLab CI то же самое делается проще, правилом на уровне job:
> ```yaml
> rules:
>   - if: $AWS_ACCESS_KEY_ID == ""
>     when: never
> ```

### Настройка перед первым запуском

GitLab:

1. Settings → CI/CD → Variables: добавить `YC_SA_KEY_FILE` (File), `AWS_ACCESS_KEY_ID`,
   `AWS_SECRET_ACCESS_KEY`, `TF_SSH_PUBLIC_KEY`. Для каждой указать Environment scope
   (`dev`, `stage`, `prod`) и включить Protected + Masked.
2. Settings → CI/CD → Protected branches: основная ветка защищена, push запрещён.
3. Deployments → Environments: для `prod` включить Approval rules.

GitHub — шаги 1 и 2 автоматизированы скриптом:

```bash
bash Task2Advanced/scripts/setup-github-secrets.sh
```

Скрипт создаёт шесть окружений (`dev`, `stage`, `prod` и `*-plan`), читает значения
напрямую из состояния bootstrap и передаёт их в `gh` через stdin — секреты не
печатаются на экран, не попадают в историю оболочки и не сохраняются во временные файлы.

Что остаётся сделать руками в Settings → Environments:

* для `stage` и `prod` включить **Required reviewers** — это и есть кнопка approval:
  job не стартует, пока подтверждение не получено;
* для `prod` ограничить **Deployment branches** веткой `main`.

Скрипт намеренно не трогает эти два пункта: список ревьюеров — организационное
решение, а не конфигурация.

Два вида ключей у сервисного аккаунта не взаимозаменяемы:

| Ключ | Куда идёт | Зачем |
|---|---|---|
| Статический (`access_key` / `secret_key`) | `TFSTATE_ACCESS_KEY` / `TFSTATE_SECRET_KEY` | доступ к S3 API бакета состояния |
| Авторизованный (JSON) | `YC_SA_KEY_JSON` | аутентификация провайдера Yandex Cloud при создании ВМ, сетей, дисков |

## Что осталось за рамками задания

* **Drift detection** — ночной `plan` по расписанию с уведомлением о расхождениях.
* **OIDC вместо статических ключей.** Идеальная цель — federated identity: CI получает
  короткоживущий токен, долгоживущие ключи не хранятся вообще. В Yandex Cloud это
  делается через Workload Identity Federation; в текущем решении используются
  статические ключи сервисных аккаунтов с обязательной ротацией.
* **Политика бакета с ограничением по префиксу.** Сейчас сервисный аккаунт CI получает
  роль `storage.editor` на каталог, то есть технически видит бакет состояния целиком.
  Разделение по префиксам `task2advanced/<env>/` остаётся организационным. Жёсткий
  вариант — политика бакета с условием на префикс ключа, тогда учётные данные `dev`
  не смогут прочитать состояние `prod` даже при ошибке в конфигурации.
* **Policy as code** (OPA/Conftest) — правила уровня «в prod запрещены прерываемые ВМ»
  сейчас реализованы блоками `validation` в Terraform, но их логичнее вынести в политики.
