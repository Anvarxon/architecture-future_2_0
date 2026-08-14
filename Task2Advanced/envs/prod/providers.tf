# Аутентификация НЕ хранится в коде и не передаётся через .tfvars.
# Провайдер берёт учётные данные из переменных окружения:
#   YC_TOKEN                    — OAuth/IAM-токен (локальная работа), либо
#   YC_SERVICE_ACCOUNT_KEY_FILE — путь к JSON-ключу сервисного аккаунта (CI/CD).
provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zones[0]
}
