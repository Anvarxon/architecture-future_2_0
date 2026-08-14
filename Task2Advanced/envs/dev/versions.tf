terraform {
  # >= 1.11 требуется для блокировки состояния через use_lockfile в S3-backend'е.
  # Для более старых версий используйте dynamodb_table (Yandex Document API / YDB).
  required_version = ">= 1.11.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.110.0"
    }
  }
}
