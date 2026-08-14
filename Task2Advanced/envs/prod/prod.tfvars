##############################################################################
# PROD: две зоны доступности, гарантированные ресурсы, приватная сеть,
# защита от удаления, диск с данными переживает пересоздание ВМ.
# Запуск: terraform apply -var-file=prod.tfvars
##############################################################################

# Идентификаторы облака НЕ хранятся в этом файле: они различаются между
# инсталляциями и не являются частью профиля окружения. Передаются переменными
# окружения TF_VAR_cloud_id и TF_VAR_folder_id (в CI — из переменных репозитория),
# либо флагами -var при локальном запуске:
#   terraform plan -var-file=prod.tfvars -var cloud_id=<id> -var folder_id=<id>


environment = "prod"
vm_name     = "app-prod"

# Геораспределённое размещение
zones = ["ru-central1-a", "ru-central1-b"]

subnet_cidrs = {
  "ru-central1-a" = "10.30.1.0/24"
  "ru-central1-b" = "10.30.2.0/24"
}

# Сеть: без публичных IP, выход наружу через NAT-шлюз, SSH — только через бастион.
nat                = false
enable_nat_gateway = true
ssh_allowed_cidrs  = ["10.30.0.0/16"]

# Мощность: 2 ВМ в каждой зоне (итого 4), гарантированные vCPU.
instances_per_zone = 2
platform_id        = "standard-v3"
cores              = 8
memory             = 32
core_fraction      = 100

# Диски: SSD, том с данными не удаляется вместе с ВМ.
boot_disk_size             = 50
boot_disk_type             = "network-ssd"
secondary_disk_enabled     = true
secondary_disk_size        = 500
secondary_disk_type        = "network-ssd"
secondary_disk_auto_delete = false

# Отказоустойчивость и защита
enable_placement_group    = true
allow_recreate            = false
serial_port_enabled       = false
allow_stopping_for_update = false

ssh_user            = "ubuntu"
ssh_public_key_path = "~/.ssh/id_ed25519.pub"

labels = {
  tier       = "prod"
  backups    = "hourly"
  compliance = "pci-dss"
}
