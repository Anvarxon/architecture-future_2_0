##############################################################################
# STAGE: конфигурация, приближенная к prod, но в одной зоне и без защиты от удаления.
# Запуск: terraform apply -var-file=stage.tfvars
##############################################################################

# Идентификаторы облака НЕ хранятся в этом файле: они различаются между
# инсталляциями и не являются частью профиля окружения. Передаются переменными
# окружения TF_VAR_cloud_id и TF_VAR_folder_id (в CI — из переменных репозитория),
# либо флагами -var при локальном запуске:
#   terraform plan -var-file=stage.tfvars -var cloud_id=<id> -var folder_id=<id>

zone = "ru-central1-b"

environment = "stage"
vm_name     = "app-stage"

# Сеть: доступ по SSH только из корпоративной сети / VPN.
vpc_cidr          = ["10.20.0.0/24"]
ssh_allowed_cidrs = ["10.0.0.0/8", "192.168.0.0/16"]
nat               = true

# Мощность: полноценные vCPU, две ВМ для проверки поведения под нагрузкой.
instance_count = 2
cores          = 4
memory         = 8
core_fraction  = 100
preemptible    = false

# Диски: SSD, объёмы близки к прод-профилю.
boot_disk_size             = 40
boot_disk_type             = "network-ssd"
secondary_disk_enabled     = true
secondary_disk_size        = 100
secondary_disk_type        = "network-ssd"
secondary_disk_auto_delete = true

# Эксплуатация: серийная консоль закрыта, удаление окружения разрешено.
serial_port_enabled = false
allow_recreate      = true

ssh_user            = "ubuntu"
ssh_public_key_path = "~/.ssh/id_ed25519.pub"

labels = {
  tier    = "stage"
  backups = "daily"
}
