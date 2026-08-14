##############################################################################
# Параметры облака
##############################################################################

variable "cloud_id" {
  description = "ID облака Yandex Cloud."
  type        = string
}

variable "folder_id" {
  description = "ID каталога, в котором создаются ресурсы окружения."
  type        = string
}

variable "zone" {
  description = "Зона доступности окружения."
  type        = string
  default     = "ru-central1-a"
}

variable "environment" {
  description = "Имя окружения."
  type        = string
  default     = "dev"
}

##############################################################################
# Сеть
##############################################################################

variable "vpc_cidr" {
  description = "CIDR подсети окружения."
  type        = list(string)
  default     = ["10.10.0.0/24"]
}

variable "ssh_allowed_cidrs" {
  description = "Список CIDR, которым разрешён SSH-доступ к ВМ."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

##############################################################################
# Конфигурация ВМ (передаётся в модуль vm)
##############################################################################

variable "vm_name" {
  description = "Базовое имя ВМ."
  type        = string
  default     = "app-dev"
}

variable "instance_count" {
  description = "Количество ВМ."
  type        = number
  default     = 1
}

variable "cores" {
  description = "Количество vCPU."
  type        = number
  default     = 2
}

variable "memory" {
  description = "Объём RAM, ГБ."
  type        = number
  default     = 2
}

variable "core_fraction" {
  description = "Гарантированная доля vCPU, %."
  type        = number
  default     = 20
}

variable "preemptible" {
  description = "Использовать прерываемые ВМ."
  type        = bool
  default     = true
}

variable "boot_disk_size" {
  description = "Размер загрузочного диска, ГБ."
  type        = number
  default     = 20
}

variable "boot_disk_type" {
  description = "Тип загрузочного диска."
  type        = string
  default     = "network-hdd"
}

variable "secondary_disk_enabled" {
  description = "Подключать ли дополнительный диск."
  type        = bool
  default     = true
}

variable "secondary_disk_size" {
  description = "Размер подключаемого диска, ГБ."
  type        = number
  default     = 20
}

variable "secondary_disk_type" {
  description = "Тип подключаемого диска."
  type        = string
  default     = "network-hdd"
}

variable "nat" {
  description = "Выдавать ли публичный IP."
  type        = bool
  default     = true
}

##############################################################################
# Эксплуатация
##############################################################################

variable "serial_port_enabled" {
  description = "Разрешить доступ к серийной консоли."
  type        = bool
  default     = true
}

variable "allow_recreate" {
  description = "Разрешать Terraform пересоздавать ВМ при изменениях, требующих replace."
  type        = bool
  default     = true
}

variable "secondary_disk_auto_delete" {
  description = "Удалять подключаемый диск вместе с ВМ."
  type        = bool
  default     = true
}

##############################################################################
# Доступ
##############################################################################

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
  description = "Публичный SSH-ключ строкой. Если задан, имеет приоритет над ssh_public_key_path (используется в CI, где нет пользовательского ~/.ssh)."
  type        = string
  default     = null
}

variable "labels" {
  description = "Дополнительные метки для всех ресурсов окружения."
  type        = map(string)
  default     = {}
}
