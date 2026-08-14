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

output "cloud_id" {
  description = "ID облака — попадает в переменную репозитория YC_CLOUD_ID."
  value       = var.cloud_id
}

output "environment_folder_ids" {
  description = "Карта: окружение -> ID каталога. Попадает в переменную YC_FOLDER_ID соответствующего окружения."
  value       = { for env, cfg in var.environments : env => cfg.folder_id }
}

output "ci_authorized_keys" {
  description = <<-EOT
    Карта: окружение -> авторизованный ключ сервисного аккаунта в формате JSON.
    Это содержимое секрета YC_SA_KEY_JSON (GitHub) / YC_SA_KEY_FILE (GitLab).
    Значение sensitive: выгружается один раз командой
    `terraform output -json ci_authorized_keys` и сразу переносится в секреты CI.
  EOT
  sensitive   = true

  value = {
    for env, key in yandex_iam_service_account_key.ci :
    env => jsonencode({
      id                 = key.id
      service_account_id = key.service_account_id
      created_at         = key.created_at
      key_algorithm      = key.key_algorithm
      public_key         = key.public_key
      private_key        = key.private_key
    })
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
