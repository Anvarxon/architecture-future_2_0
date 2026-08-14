locals {
  labels = merge(
    {
      environment = var.environment
      owner       = "platform-team"
      cost_center = "rnd"
    },
    var.labels
  )

  # Публичный ключ берём из строки (сценарий CI) либо из файла (локальная работа).
  ssh_public_key = coalesce(
    var.ssh_public_key,
    try(trimspace(file(pathexpand(var.ssh_public_key_path))), null)
  )
}

module "vm" {
  source = "../../../Task1Advanced/modules/vm"

  # Идентификация
  name        = var.vm_name
  environment = var.environment
  labels      = local.labels

  # Размещение и мощность
  zone           = var.zone
  instance_count = var.instance_count
  cores          = var.cores
  memory         = var.memory
  core_fraction  = var.core_fraction
  preemptible    = var.preemptible

  # Диски
  boot_disk_size             = var.boot_disk_size
  boot_disk_type             = var.boot_disk_type
  secondary_disk_enabled     = var.secondary_disk_enabled
  secondary_disk_size        = var.secondary_disk_size
  secondary_disk_type        = var.secondary_disk_type
  secondary_disk_auto_delete = var.secondary_disk_auto_delete

  # Сеть
  subnet_id          = yandex_vpc_subnet.this.id
  security_group_ids = [yandex_vpc_security_group.vm.id]
  nat                = var.nat

  # Доступ
  ssh_user       = var.ssh_user
  ssh_public_key = local.ssh_public_key

  # Эксплуатация: значения задаются в <env>.tfvars, код окружений остаётся идентичным.
  serial_port_enabled = var.serial_port_enabled
  allow_recreate      = var.allow_recreate
}
