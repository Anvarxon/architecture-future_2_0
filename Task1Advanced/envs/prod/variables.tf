##############################################################################
# Параметры облака
##############################################################################

variable "cloud_id" {
  description = "ID облака Yandex Cloud."
  type        = string
}

variable "folder_id" {
  description = "ID каталога прод-окружения (отдельный каталог = изоляция прав и квот)."
  type        = string
}

variable "environment" {
  description = "Имя окружения."
  type        = string
  default     = "prod"
}

variable "zones" {
  description = "Зоны доступности, в которых разворачивается прод (геораспределённое размещение)."
  type        = list(string)
  default     = ["ru-central1-a", "ru-central1-b"]

  validation {
    condition     = length(var.zones) >= 2
    error_message = "Для прод-окружения требуется минимум две зоны доступности."
  }
}

##############################################################################
# Сеть
##############################################################################

variable "subnet_cidrs" {
  description = "CIDR подсетей: ключ — зона доступности, значение — блок адресов."
  type        = map(string)
  default = {
    "ru-central1-a" = "10.30.1.0/24"
    "ru-central1-b" = "10.30.2.0/24"
  }
}

variable "ssh_allowed_cidrs" {
  description = "CIDR, которым разрешён SSH (только бастион / корпоративная сеть)."
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "nat" {
  description = "Выдавать ли ВМ публичные IP. В prod по умолчанию false — исходящий трафик идёт через NAT-шлюз."
  type        = bool
  default     = false
}

variable "enable_nat_gateway" {
  description = "Создавать ли NAT-шлюз и таблицу маршрутизации для исходящего трафика приватных ВМ."
  type        = bool
  default     = true
}

##############################################################################
# Конфигурация ВМ (передаётся в модуль vm — по одному вызову на зону)
##############################################################################

variable "vm_name" {
  description = "Базовое имя ВМ."
  type        = string
  default     = "app-prod"
}

variable "instances_per_zone" {
  description = "Количество ВМ в каждой зоне доступности."
  type        = number
  default     = 2
}

variable "cores" {
  description = "Количество vCPU."
  type        = number
  default     = 8
}

variable "memory" {
  description = "Объём RAM, ГБ."
  type        = number
  default     = 32
}

variable "core_fraction" {
  description = "Гарантированная доля vCPU, %. В prod — только 100."
  type        = number
  default     = 100

  validation {
    condition     = var.core_fraction == 100
    error_message = "В prod допустима только гарантированная производительность (core_fraction = 100)."
  }
}

variable "platform_id" {
  description = "Платформа вычислительных ресурсов."
  type        = string
  default     = "standard-v3"
}

variable "boot_disk_image_id" {
  description = "Явный ID образа. В prod образ фиксируется, чтобы plan не менялся при выходе нового образа в семействе."
  type        = string
  default     = null
}

variable "boot_disk_size" {
  description = "Размер загрузочного диска, ГБ."
  type        = number
  default     = 50
}

variable "boot_disk_type" {
  description = "Тип загрузочного диска."
  type        = string
  default     = "network-ssd"
}

variable "secondary_disk_enabled" {
  description = "Подключать ли дополнительный диск."
  type        = bool
  default     = true
}

variable "secondary_disk_size" {
  description = "Размер подключаемого диска, ГБ."
  type        = number
  default     = 500
}

variable "secondary_disk_type" {
  description = "Тип подключаемого диска."
  type        = string
  default     = "network-ssd"
}

variable "secondary_disk_auto_delete" {
  description = "Удалять диск с данными вместе с ВМ. В prod — false."
  type        = bool
  default     = false
}

variable "enable_placement_group" {
  description = "Разносить ВМ зоны по разным физическим хостам (анти-аффинити)."
  type        = bool
  default     = true
}

##############################################################################
# Эксплуатация и доступ
##############################################################################

variable "allow_recreate" {
  description = "Разрешать Terraform пересоздавать ВМ при изменениях, требующих replace. В prod — false."
  type        = bool
  default     = false
}

variable "serial_port_enabled" {
  description = "Доступ к серийной консоли. В prod — false."
  type        = bool
  default     = false
}

variable "allow_stopping_for_update" {
  description = "Разрешать Terraform останавливать ВМ для изменения ресурсов."
  type        = bool
  default     = false
}

variable "ssh_user" {
  description = "Пользователь ОС для SSH."
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key_path" {
  description = "Путь к файлу публичного SSH-ключа."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_public_key" {
  description = "Публичный SSH-ключ строкой (приоритетнее ssh_public_key_path; используется в CI/CD)."
  type        = string
  default     = null
}

variable "service_account_id" {
  description = "ID сервисного аккаунта, привязываемого к ВМ."
  type        = string
  default     = null
}

variable "labels" {
  description = "Дополнительные метки для всех ресурсов окружения."
  type        = map(string)
  default     = {}
}
