terraform {
  required_version = ">= 1.6.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.110.0"
    }
  }

  # В Task1Advanced состояние хранится локально — цель задания в переиспользуемости модуля.
  # Удалённый backend (S3-совместимое хранилище + блокировки) реализован в Task2Advanced.
}
