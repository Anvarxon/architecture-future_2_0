# Доказательства работоспособности

Результаты фактического запуска Terraform против Yandex Cloud. Это не пересказ, а вывод
команд: каждый план обращается к реальному API облака и падает на любой ошибке конфигурации.

| Параметр | Значение |
|---|---|
| Дата проверки | 15 августа 2026 |
| Terraform | v1.15.8 |
| Провайдер | yandex-cloud/yandex 0.221.0 |
| Облако | `b1g0…63b` (идентификаторы сокращены) |
| Backend | Yandex Object Storage, бакет `future20-tfstate-uz01` |

## Сводка

| Окружение | Команда | Результат | Ресурсов |
|---|---|---|---|
| dev | `apply`, затем повторный `plan` | развёрнуто, `No changes` | 6 |
| stage | `plan` | `Plan: 7 to add, 0 to change, 0 to destroy` | 7 |
| prod | `plan` | `Plan: 16 to add, 0 to change, 0 to destroy` | 16 |

Развёрнуто только dev. Причина не техническая, а экономическая: прод-профиль из задания —
4 ВМ по 8 vCPU и 32 ГБ RAM плюс 2 ТБ SSD, это порядка 2400 ₽ в сутки и превышение квот
пробного аккаунта. Конфигурация в коде описывает реальный боевой профиль, а не то, что
помещается в грант, поэтому её работоспособность подтверждается планом.

## dev — развёрнуто

Состояние читается из бакета, локального файла нет:

```console
$ ls terraform.tfstate
ls: terraform.tfstate: No such file or directory

$ terraform state list
yandex_vpc_network.this
yandex_vpc_security_group.vm
yandex_vpc_subnet.this
module.vm.data.yandex_compute_image.boot
module.vm.yandex_compute_disk.secondary["app-dev"]
module.vm.yandex_compute_instance.this["app-dev"]

$ terraform state pull   # разбор JSON
версия формата 4 | serial 2 | ресурсов 6
```

Повторный план после применения — конфигурация совпадает с реальностью:

```console
$ terraform plan -var-file=dev.tfvars
No changes. Your infrastructure matches the configuration.
```

Выходные значения модуля (публичный адрес сокращён):

```
external_ips       = { "app-dev" = "62.84.112.xxx" }
internal_ips       = { "app-dev" = "10.10.0.14" }
secondary_disk_ids = { "app-dev" = "fhmec07qfa5kplqrq8mp" }
summary = {
  boot_disk_gb   = 20
  core_fraction  = 20
  cores          = 2
  data_disk_gb   = 20
  environment    = "dev"
  instance_count = 1
  memory_gb      = 2
  preemptible    = true
  zone           = "ru-central1-a"
}
```

## stage — план

```console
$ terraform plan -var-file=stage.tfvars
  # yandex_vpc_network.this will be created
  # yandex_vpc_security_group.vm will be created
  # yandex_vpc_subnet.this will be created
  # module.vm.yandex_compute_disk.secondary["app-stage-1"] will be created
  # module.vm.yandex_compute_disk.secondary["app-stage-2"] will be created
  # module.vm.yandex_compute_instance.this["app-stage-1"] will be created
  # module.vm.yandex_compute_instance.this["app-stage-2"] will be created

Plan: 7 to add, 0 to change, 0 to destroy.
```

Две ВМ вместо одной — это `instance_count = 2` из `stage.tfvars`. Имена получают индексы,
диск с данными создаётся для каждой ВМ отдельным ресурсом.

## prod — план

```console
$ terraform plan -var-file=prod.tfvars
  # yandex_compute_placement_group.this["ru-central1-a"] will be created
  # yandex_compute_placement_group.this["ru-central1-b"] will be created
  # yandex_vpc_gateway.nat[0] will be created
  # yandex_vpc_network.this will be created
  # yandex_vpc_route_table.egress[0] will be created
  # yandex_vpc_security_group.vm will be created
  # yandex_vpc_subnet.this["ru-central1-a"] will be created
  # yandex_vpc_subnet.this["ru-central1-b"] will be created
  # module.vm["ru-central1-a"].yandex_compute_disk.secondary["app-prod-a-1"] will be created
  # module.vm["ru-central1-a"].yandex_compute_disk.secondary["app-prod-a-2"] will be created
  # module.vm["ru-central1-a"].yandex_compute_instance.this["app-prod-a-1"] will be created
  # module.vm["ru-central1-a"].yandex_compute_instance.this["app-prod-a-2"] will be created
  # module.vm["ru-central1-b"].yandex_compute_disk.secondary["app-prod-b-1"] will be created
  # module.vm["ru-central1-b"].yandex_compute_disk.secondary["app-prod-b-2"] will be created
  # module.vm["ru-central1-b"].yandex_compute_instance.this["app-prod-b-1"] will be created
  # module.vm["ru-central1-b"].yandex_compute_instance.this["app-prod-b-2"] will be created

Plan: 16 to add, 0 to change, 0 to destroy.
```

Здесь виден ключевой для задания момент: **один и тот же модуль вызывается дважды**, по
разу на зону доступности — `module.vm["ru-central1-a"]` и `module.vm["ru-central1-b"]`, —
и внутри каждого разворачивается по две ВМ. Плюс инфраструктура, которой нет в других
окружениях: NAT-шлюз с таблицей маршрутизации (прод-ВМ не имеют публичных адресов) и
группы размещения, разносящие ВМ по разным физическим хостам.

## Что подтверждают эти запуски

1. **Модуль переиспользуем.** Один и тот же код `Task1Advanced/modules/vm` разворачивается
   в три разных профиля: одна прерываемая ВМ, две обычные, четыре в двух зонах.
2. **Различия окружений вынесены в `.tfvars`.** Код dev и stage идентичен, отличаются
   только файлы переменных.
3. **Состояние удалённое.** Локального `terraform.tfstate` нет ни в одном окружении,
   блокировка через `use_lockfile` захватывается и снимается при каждой операции.
4. **Backend изолирован по окружениям.** Отдельный сервисный аккаунт, отдельный каталог
   облака и отдельный префикс в бакете состояния для каждого окружения.

## Как воспроизвести

```bash
export YC_TOKEN=$(yc iam create-token)
export AWS_ACCESS_KEY_ID=...        # статический ключ сервисного аккаунта окружения
export AWS_SECRET_ACCESS_KEY=...
export TF_VAR_cloud_id=<cloud-id>
export TF_VAR_folder_id=<folder-id окружения>

cd Task2Advanced/envs/dev
terraform init -backend-config=backend-dev.hcl
terraform plan -var-file=dev.tfvars
```

Ключи доступа выпускаются конфигурацией `Task2Advanced/bootstrap` — см. [README](../README.md).
