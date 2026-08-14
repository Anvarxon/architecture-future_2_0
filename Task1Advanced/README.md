# Task 1 Advanced — переиспользуемый модуль Terraform `vm` для dev / stage / prod

Универсальный модуль создания виртуальных машин в Yandex Cloud и три окружения,
которые вызывают один и тот же модуль с разными параметрами через `-var-file`.

## Структура

```
Task1Advanced/
├── modules/
│   └── vm/
│       ├── main.tf        # ВМ + подключаемый диск + сетевой интерфейс + группа размещения
│       ├── variables.tf   # входные параметры (ядра, RAM, диск, subnet_id, SSH-ключ, ...)
│       ├── outputs.tf     # id ВМ, имена, IP, id дисков, ssh-команды, сводка
│       └── versions.tf    # требования к версиям Terraform и провайдера
└── envs/
    ├── dev/               # 1 прерываемая ВМ, 2 vCPU (20 %), 2 ГБ RAM, HDD
    │   ├── main.tf        # вызов модуля
    │   ├── network.tf     # VPC + подсеть + security group окружения
    │   ├── providers.tf   # конфигурация провайдера
    │   ├── variables.tf   # параметры окружения
    │   ├── outputs.tf     # выходы окружения
    │   ├── versions.tf
    │   └── dev.tfvars     # ← значения именно для dev
    ├── stage/             # 2 ВМ, 4 vCPU (100 %), 8 ГБ RAM, SSD
    │   └── stage.tfvars
    └── prod/              # 2 зоны × 2 ВМ, 8 vCPU, 32 ГБ RAM, NAT-шлюз, запрет пересоздания ВМ
        └── prod.tfvars
```

## Что делает модуль `modules/vm`

| Ресурс | Назначение |
|---|---|
| `data.yandex_compute_image.boot` | поиск актуального образа по семейству (можно переопределить явным `boot_disk_image_id`) |
| `yandex_compute_disk.secondary` | подключаемый диск с данными, создаётся отдельным ресурсом (переживает пересоздание ВМ, если `secondary_disk_auto_delete = false`) |
| `yandex_compute_instance.this` | ВМ: ресурсы, загрузочный диск, `secondary_disk`, сетевой интерфейс, SSH-ключ в метаданных, политика прерываемости, группа размещения |

> **О названии.** В задании модуль назван `vm_module` и размещён в папке `modules/vm/`.
> Здесь соблюдён требуемый путь `Task1Advanced/modules/vm/`, а вызывается модуль как
> `module "vm"` — имя блока вызова задаётся окружением и на переиспользуемость не влияет.

Ключевые решения:

* **Внутри модуля нет ни одного захардкоженного значения окружения** — ни имени, ни зоны,
  ни CIDR, ни ID каталога. Всё приходит через переменные.
* **В модуле нет блока `provider`** — только `required_providers`. Провайдер настраивается
  в окружении и наследуется. Благодаря этому модуль можно вызвать несколько раз в одном
  окружении (см. `envs/prod`, где модуль вызывается по разу на каждую зону доступности).
* **Сеть разделена по уровням**: VPC, подсети и security group живут в окружении (их
  жизненный цикл длиннее, чем у ВМ), а модуль получает готовые `subnet_id` и
  `security_group_ids` и отвечает за сетевой интерфейс ВМ. Это следует из самого
  интерфейса модуля: `subnet_id` — его входной параметр, поэтому создавать подсеть
  внутри модуля нельзя без противоречия. Сетевая часть модуля — `network_interface`
  (подсеть, NAT, группы безопасности, фиксированный IP), сетевая часть окружения —
  `envs/<env>/network.tf`.
* **Валидация входов**: `cores`, `memory`, `core_fraction`, `environment`, формат имени и
  формат SSH-ключа проверяются блоками `validation` — ошибка видна на `plan`, а не на `apply`.
* **Множественные экземпляры**: `instance_count` создаёт N одинаковых ВМ через `for_each`
  (не `count`), поэтому удаление одной ВМ из середины списка не пересоздаёт остальные.

### Входные параметры (интерфейс модуля)

Обязательные:

| Параметр | Тип | Описание |
|---|---|---|
| `name` | `string` | базовое имя ВМ |
| `environment` | `string` | `dev` / `stage` / `prod` |
| `zone` | `string` | зона доступности |
| `cores` | `number` | **количество ядер** |
| `memory` | `number` | **объём RAM, ГБ** |
| `subnet_id` | `string` | **ID подсети** |
| `ssh_public_key` | `string` | **публичный SSH-ключ** |

Основные опциональные (полный список — в `modules/vm/variables.tf`):

| Параметр | По умолчанию | Описание |
|---|---|---|
| `instance_count` | `1` | количество ВМ |
| `platform_id` | `standard-v3` | платформа |
| `core_fraction` | `100` | гарантированная доля vCPU (5/20/50/100) |
| `preemptible` | `false` | прерываемая ВМ |
| `boot_disk_image_family` / `boot_disk_image_id` | `ubuntu-2204-lts` / `null` | образ |
| `boot_disk_size` / `boot_disk_type` | `20` / `network-ssd` | загрузочный диск |
| `secondary_disk_enabled` | `false` | **подключаемый диск** |
| `secondary_disk_size` / `secondary_disk_type` | `50` / `network-hdd` | параметры подключаемого диска |
| `secondary_disk_auto_delete` | `true` | удалять диск вместе с ВМ |
| `nat` | `false` | публичный IP |
| `security_group_ids` | `[]` | группы безопасности |
| `ssh_user` | `ubuntu` | пользователь ОС |
| `user_data` | `null` | cloud-init |
| `service_account_id` | `null` | сервисный аккаунт ВМ |
| `placement_group_id` | `null` | анти-аффинити |
| `serial_port_enabled` | `false` | серийная консоль |
| `allow_recreate` | `true` | разрешать пересоздание ВМ (в prod — `false`) |
| `allow_stopping_for_update` | `true` | разрешить остановку ВМ при изменении ресурсов |
| `labels` | `{}` | дополнительные метки |

### Выходы модуля

| Output | Содержимое |
|---|---|
| `instance_ids` | карта `имя ВМ -> ID` |
| `instance_id` | ID первой ВМ (удобно при `instance_count = 1`) |
| `instance_names` | список имён |
| `fqdns` | карта `имя -> внутренний FQDN` |
| `internal_ips` / `external_ips` | карты IP-адресов |
| `boot_disk_ids` / `secondary_disk_ids` | ID дисков |
| `subnet_id`, `zone` | сетевые/зональные атрибуты |
| `ssh_commands` | готовые команды подключения |
| `summary` | сводка конфигурации (окружение, ядра, RAM, диски) |

## Как различаются окружения

| Параметр | dev | stage | prod |
|---|---|---|---|
| Зоны | 1 (`ru-central1-a`) | 1 (`ru-central1-b`) | 2 (`a` + `b`) |
| Количество ВМ | 1 | 2 | 2 × 2 = 4 |
| vCPU / RAM | 2 / 2 ГБ | 4 / 8 ГБ | 8 / 32 ГБ |
| `core_fraction` | 20 % | 100 % | 100 % (валидация запрещает иное) |
| Прерываемые ВМ | да | нет | нет |
| Загрузочный диск | 20 ГБ HDD | 40 ГБ SSD | 50 ГБ SSD |
| Подключаемый диск | 20 ГБ HDD, удаляется с ВМ | 100 ГБ SSD, удаляется с ВМ | 500 ГБ SSD, **не** удаляется с ВМ |
| Публичный IP | да | да | нет (NAT-шлюз) |
| SSH-доступ | отовсюду | корпоративные сети | только бастион `10.30.0.0/16` |
| Серийная консоль | включена | выключена | выключена |
| Пересоздание ВМ (`allow_recreate`) | разрешено | разрешено | запрещено |
| Анти-аффинити | нет | нет | да (placement group) |

Код окружений `dev` и `stage` идентичен — различия целиком вынесены в `*.tfvars`.
`prod` отличается структурно: подсети и вызовы модуля разворачиваются `for_each` по списку зон.

## Как запустить

### Предварительные требования

* Terraform >= 1.6
* Аккаунт Yandex Cloud, установленный и инициализированный [`yc`](https://yandex.cloud/ru/docs/cli/quickstart)
* Пара SSH-ключей (`ssh-keygen -t ed25519`)

Учётные данные **не** передаются через `.tfvars` — только через переменные окружения:

```bash
export YC_TOKEN=$(yc iam create-token)
```

Для CI/CD вместо токена используется ключ сервисного аккаунта:

```bash
export YC_SERVICE_ACCOUNT_KEY_FILE=/secure/path/sa-key.json
```

### dev

```bash
cd Task1Advanced/envs/dev
terraform init
terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

### stage

```bash
cd Task1Advanced/envs/stage
terraform init
terraform apply -var-file=stage.tfvars
```

### prod

```bash
cd Task1Advanced/envs/prod
terraform init
terraform apply -var-file=prod.tfvars
```

Перед прод-раскаткой сохраняем план в файл и применяем именно его — так исключается
расхождение между тем, что проверили, и тем, что применилось:

```bash
terraform plan -var-file=prod.tfvars -out=prod.tfplan
terraform apply prod.tfplan
```

### Проверка результата

```bash
terraform output summary
terraform output ssh_commands
```

### Удаление окружения

```bash
terraform destroy -var-file=dev.tfvars
```

В `prod` установлен `allow_recreate = false`: любое изменение, требующее пересоздания
ВМ, падает на `apply` с явной ошибкой вместо тихого replace. Чтобы удалить или
пересоздать прод-ВМ, нужно осознанно переключить флаг в `prod.tfvars` — это барьер
против случайного уничтожения окружения.

## Замечания по эксплуатации

* Файлы `*.tfvars` в этом задании содержат **плейсхолдеры** `cloud_id` / `folder_id` —
  подставьте свои значения перед запуском.
* Состояние здесь локальное: цель Task 1 — переиспользуемость модуля.
  Удалённый backend (S3-совместимое хранилище) и CI/CD — в [Task2Advanced](../Task2Advanced/README.md),
  который переиспользует **этот же** модуль без копирования кода.
* Изменение `cores` / `memory` требует остановки ВМ. В `dev`/`stage`
  `allow_stopping_for_update = true`, в `prod` — `false`, чтобы Terraform не мог
  перезапустить прод-ВМ незаметно для команды.
