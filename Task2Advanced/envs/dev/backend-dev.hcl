# Неконфиденциальные параметры backend'а для окружения dev.
# Ключи доступа передаются переменными окружения AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY.

bucket = "future20-tfstate-uz01"
key    = "task2advanced/dev/terraform.tfstate"
region = "ru-central1"

endpoints = {
  s3 = "https://storage.yandexcloud.net"
}

# Object Storage не реализует часть специфичных для AWS API — отключаем лишние проверки.
skip_region_validation      = true
skip_credentials_validation = true
skip_requesting_account_id  = true
skip_metadata_api_check     = true
skip_s3_checksum            = true
use_path_style              = true

# Блокировка состояния через объект-лок в том же бакете (Terraform >= 1.11 / OpenTofu >= 1.11).
# Защищает от одновременного apply из CI и с ноутбука инженера.
use_lockfile = true
