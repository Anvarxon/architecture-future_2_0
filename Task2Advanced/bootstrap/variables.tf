variable "cloud_id" {
  description = "ID облака Yandex Cloud."
  type        = string
}

variable "folder_id" {
  description = "ID каталога, в котором создаются бакет состояния, KMS-ключ и сервисные аккаунты."
  type        = string
}

variable "zone" {
  description = "Зона по умолчанию для провайдера."
  type        = string
  default     = "ru-central1-a"
}

variable "bucket_name" {
  description = "Имя бакета для хранения состояния Terraform (должно быть глобально уникальным)."
  type        = string
}

variable "state_retention_days" {
  description = "Сколько дней хранить неактуальные версии файла состояния."
  type        = number
  default     = 90
}

variable "environments" {
  description = <<-EOT
    Окружения, для которых создаются сервисные аккаунты CI/CD.
    Ключ — имя окружения, значение — каталог и роль в нём.
    Роль намеренно задаётся отдельно: prod может получать более узкую роль,
    чем dev, либо наоборот — набор ролей вместо editor.
  EOT

  type = map(object({
    folder_id = string
    role      = string
  }))

  default = {
    dev = {
      folder_id = "REPLACE_WITH_DEV_FOLDER_ID"
      role      = "editor"
    }
    stage = {
      folder_id = "REPLACE_WITH_STAGE_FOLDER_ID"
      role      = "editor"
    }
    prod = {
      folder_id = "REPLACE_WITH_PROD_FOLDER_ID"
      role      = "editor"
    }
  }
}
