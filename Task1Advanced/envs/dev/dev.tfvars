##############################################################################
# DEV: минимальная стоимость, максимальная скорость итераций.
# Запуск: terraform apply -var-file=dev.tfvars
##############################################################################

cloud_id  = "b1gxxxxxxxxxxxxxxxxx"
folder_id = "b1gyyyyyyyyyyyyyyyyy"
zone      = "ru-central1-a"

environment = "dev"
vm_name     = "app-dev"

# Сеть: dev открыт наружу для удобства разработчиков.
vpc_cidr          = ["10.10.0.0/24"]
ssh_allowed_cidrs = ["0.0.0.0/0"]
nat               = true

# Мощность: 2 vCPU c гарантированной долей 20 % + прерываемая ВМ ≈ самый дешёвый вариант.
instance_count = 1
cores          = 2
memory         = 2
core_fraction  = 20
preemptible    = true

# Диски: HDD, небольшие объёмы.
boot_disk_size         = 20
boot_disk_type         = "network-hdd"
secondary_disk_enabled = true
secondary_disk_size    = 20
secondary_disk_type    = "network-hdd"

ssh_user            = "ubuntu"
ssh_public_key_path = "~/.ssh/id_ed25519.pub"

labels = {
  tier    = "dev"
  backups = "none"
}
