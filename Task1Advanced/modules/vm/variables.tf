##############################################################################
# Идентификация и именование
##############################################################################

variable "name" {
  description = "Базовое имя ВМ. При instance_count > 1 к имени добавляется порядковый индекс (web-1, web-2, ...)."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{1,61})[a-z0-9]$", var.name))
    error_message = "Имя должно соответствовать требованиям Yandex Cloud: 3-63 символа, [a-z0-9-], начинается с буквы."
  }
}

variable "environment" {
  description = "Окружение (dev / stage / prod). Используется в метках и в имени ресурсов."
  type        = string

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Допустимые значения environment: dev, stage, prod."
  }
}

variable "labels" {
  description = "Дополнительные метки, которые будут добавлены ко всем создаваемым ресурсам."
  type        = map(string)
  default     = {}
}

##############################################################################
# Размещение
##############################################################################

variable "zone" {
  description = "Зона доступности, в которой создаются ВМ и диски (например, ru-central1-a)."
  type        = string
}

variable "instance_count" {
  description = "Количество одинаковых ВМ, создаваемых модулем."
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 20
    error_message = "instance_count должен быть в диапазоне 1..20."
  }
}

variable "platform_id" {
  description = "Платформа вычислительных ресурсов (standard-v1 / standard-v2 / standard-v3)."
  type        = string
  default     = "standard-v3"
}

##############################################################################
# Вычислительные ресурсы: ядра и RAM
##############################################################################

variable "cores" {
  description = "Количество vCPU на одну ВМ."
  type        = number

  validation {
    condition     = var.cores >= 2 && var.cores <= 96
    error_message = "cores должен быть в диапазоне 2..96."
  }
}

variable "memory" {
  description = "Объём RAM на одну ВМ, ГБ."
  type        = number

  validation {
    condition     = var.memory >= 1 && var.memory <= 640
    error_message = "memory должен быть в диапазоне 1..640 ГБ."
  }
}

variable "core_fraction" {
  description = "Гарантированная доля vCPU в процентах (5, 20, 50, 100). Для dev-окружений экономично использовать 20."
  type        = number
  default     = 100

  validation {
    condition     = contains([5, 20, 50, 100], var.core_fraction)
    error_message = "core_fraction может принимать значения 5, 20, 50 или 100."
  }
}

variable "preemptible" {
  description = "Прерываемая (preemptible) ВМ. Существенно дешевле, допустимо для dev/stage, запрещено для prod."
  type        = bool
  default     = false
}

##############################################################################
# Загрузочный диск
##############################################################################

variable "boot_disk_image_family" {
  description = "Семейство образа для загрузочного диска (например, ubuntu-2204-lts). Игнорируется, если задан boot_disk_image_id."
  type        = string
  default     = "ubuntu-2204-lts"
}

variable "boot_disk_image_id" {
  description = "Явный ID образа загрузочного диска. Имеет приоритет над boot_disk_image_family (полезно для prod, где образ должен быть зафиксирован)."
  type        = string
  default     = null
}

variable "boot_disk_size" {
  description = "Размер загрузочного диска, ГБ."
  type        = number
  default     = 20
}

variable "boot_disk_type" {
  description = "Тип загрузочного диска (network-hdd / network-ssd / network-ssd-nonreplicated)."
  type        = string
  default     = "network-ssd"
}

##############################################################################
# Подключаемый (дополнительный) диск
##############################################################################

variable "secondary_disk_enabled" {
  description = "Создавать ли дополнительный диск и подключать ли его к ВМ."
  type        = bool
  default     = false
}

variable "secondary_disk_size" {
  description = "Размер подключаемого диска, ГБ."
  type        = number
  default     = 50
}

variable "secondary_disk_type" {
  description = "Тип подключаемого диска (network-hdd / network-ssd / network-ssd-nonreplicated)."
  type        = string
  default     = "network-hdd"
}

variable "secondary_disk_auto_delete" {
  description = "Удалять ли подключаемый диск вместе с ВМ. Для prod рекомендуется false (данные переживают пересоздание ВМ)."
  type        = bool
  default     = true
}

##############################################################################
# Сеть
##############################################################################

variable "subnet_id" {
  description = "ID подсети, в которой создаётся сетевой интерфейс ВМ."
  type        = string
}

variable "nat" {
  description = "Выдавать ли ВМ публичный IP-адрес (NAT в интернет)."
  type        = bool
  default     = false
}

variable "security_group_ids" {
  description = "Список ID групп безопасности, привязываемых к сетевому интерфейсу."
  type        = list(string)
  default     = []
}

variable "ipv4_address" {
  description = "Фиксированный внутренний IPv4-адрес. Если null — адрес выдаётся автоматически. Допустимо только при instance_count = 1."
  type        = string
  default     = null
}

##############################################################################
# Доступ
##############################################################################

variable "ssh_user" {
  description = "Имя пользователя ОС, для которого прописывается SSH-ключ."
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "Содержимое публичного SSH-ключа (ssh-ed25519 AAAA... / ssh-rsa AAAA...)."
  type        = string

  validation {
    condition     = can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256) ", var.ssh_public_key))
    error_message = "ssh_public_key должен содержать публичный ключ в формате OpenSSH (ssh-rsa / ssh-ed25519 / ecdsa-sha2-nistp256)."
  }
}

variable "service_account_id" {
  description = "ID сервисного аккаунта, привязываемого к ВМ (нужен, например, для доступа к Object Storage или Lockbox)."
  type        = string
  default     = null
}

variable "user_data" {
  description = "cloud-init user-data. Если null — в метаданные передаётся только SSH-ключ."
  type        = string
  default     = null
}

##############################################################################
# Эксплуатация
##############################################################################

variable "serial_port_enabled" {
  description = "Разрешить доступ к серийной консоли. Удобно в dev, небезопасно в prod."
  type        = bool
  default     = false
}

variable "allow_stopping_for_update" {
  description = "Разрешить Terraform останавливать ВМ для применения изменений (смена cores/memory требует остановки)."
  type        = bool
  default     = true
}

variable "allow_recreate" {
  description = "Разрешать Terraform пересоздавать ВМ при изменениях, требующих replace. Для prod рекомендуется false — тогда опасное изменение падает на apply вместо тихого пересоздания."
  type        = bool
  default     = true
}

variable "placement_group_id" {
  description = "ID группы размещения. Позволяет развести ВМ по разным физическим хостам (антиаффинити) — актуально для prod."
  type        = string
  default     = null
}
