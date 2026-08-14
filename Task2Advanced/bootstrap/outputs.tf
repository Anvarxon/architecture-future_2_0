output "bucket_name" {
  description = "Имя бакета с состоянием Terraform (подставляется в backend-*.hcl)."
  value       = yandex_storage_bucket.tfstate.bucket
}

output "kms_key_id" {
  description = "ID KMS-ключа, которым шифруется содержимое бакета."
  value       = yandex_kms_symmetric_key.tfstate.id
}

output "ci_service_account_ids" {
  description = "Карта: окружение -> ID сервисного аккаунта CI/CD."
  value       = { for env, sa in yandex_iam_service_account.ci : env => sa.id }
}

output "ci_access_keys" {
  description = <<-EOT
    Карта: окружение -> статические ключи доступа к S3 API.
    Значения помечены как sensitive: их нужно один раз выгрузить
    (`terraform output -json ci_access_keys`) и положить в защищённые переменные CI/CD
    (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY), после чего в открытом виде нигде не хранить.
  EOT
  sensitive   = true

  value = {
    for env, key in yandex_iam_service_account_static_access_key.ci :
    env => {
      access_key = key.access_key
      secret_key = key.secret_key
    }
  }
}

output "backend_config_hint" {
  description = "Готовая подсказка по заполнению backend-*.hcl."
  value = {
    bucket      = yandex_storage_bucket.tfstate.bucket
    region      = "ru-central1"
    endpoint    = "https://storage.yandexcloud.net"
    key_pattern = "task2advanced/<env>/terraform.tfstate"
  }
}
