locals {
  labels = merge(
    {
      environment = var.environment
      owner       = "platform-team"
      criticality = "high"
    },
    var.labels
  )

  ssh_public_key = coalesce(
    var.ssh_public_key,
    try(trimspace(file(pathexpand(var.ssh_public_key_path))), null)
  )

  # Короткий суффикс зоны для имён ВМ: ru-central1-a -> a
  zone_suffix = { for z in var.zones : z => substr(z, -1, 1) }
}

##############################################################################
# Один и тот же модуль вызывается по разу на зону доступности.
# Это и есть проверка переиспользуемости: меняются только входные параметры.
##############################################################################

module "vm" {
  source   = "../../../Task1Advanced/modules/vm"
  for_each = toset(var.zones)

  # Идентификация
  name        = "${var.vm_name}-${local.zone_suffix[each.value]}"
  environment = var.environment
  labels      = merge(local.labels, { zone = each.value })

  # Размещение и мощность
  zone           = each.value
  instance_count = var.instances_per_zone
  platform_id    = var.platform_id
  cores          = var.cores
  memory         = var.memory
  core_fraction  = var.core_fraction
  preemptible    = false

  # Диски: данные переживают пересоздание ВМ (auto_delete = false).
  boot_disk_image_id         = var.boot_disk_image_id
  boot_disk_size             = var.boot_disk_size
  boot_disk_type             = var.boot_disk_type
  secondary_disk_enabled     = var.secondary_disk_enabled
  secondary_disk_size        = var.secondary_disk_size
  secondary_disk_type        = var.secondary_disk_type
  secondary_disk_auto_delete = var.secondary_disk_auto_delete

  # Сеть: приватные ВМ, выход в интернет через NAT-шлюз.
  subnet_id          = yandex_vpc_subnet.this[each.value].id
  security_group_ids = [yandex_vpc_security_group.vm.id]
  nat                = var.nat

  # Отказоустойчивость внутри зоны
  placement_group_id = var.enable_placement_group ? yandex_compute_placement_group.this[each.value].id : null

  # Доступ
  ssh_user           = var.ssh_user
  ssh_public_key     = local.ssh_public_key
  service_account_id = var.service_account_id

  # Эксплуатация
  serial_port_enabled       = var.serial_port_enabled
  allow_recreate            = var.allow_recreate
  allow_stopping_for_update = var.allow_stopping_for_update
}
