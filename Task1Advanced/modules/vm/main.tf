##############################################################################
# Локальные значения
##############################################################################

locals {
  # Единый набор меток для всех ресурсов модуля.
  labels = merge(
    {
      environment = var.environment
      managed_by  = "terraform"
      module      = "vm"
    },
    var.labels
  )

  # Имена ВМ: при одном экземпляре — без индекса, при нескольких — с индексом.
  instance_names = var.instance_count == 1 ? [var.name] : [
    for i in range(var.instance_count) : format("%s-%d", var.name, i + 1)
  ]

  # Образ загрузочного диска: явный ID имеет приоритет над семейством.
  boot_image_id = coalesce(var.boot_disk_image_id, data.yandex_compute_image.boot.id)

  # Метаданные ВМ: SSH-ключ обязателен, остальное — опционально.
  metadata = merge(
    {
      "ssh-keys"           = "${var.ssh_user}:${var.ssh_public_key}"
      "serial-port-enable" = var.serial_port_enabled ? "1" : "0"
    },
    var.user_data == null ? {} : { "user-data" = var.user_data }
  )
}

##############################################################################
# Образ загрузочного диска
##############################################################################

data "yandex_compute_image" "boot" {
  family = var.boot_disk_image_family
}

##############################################################################
# Подключаемый (дополнительный) диск
# Создаётся отдельным ресурсом, чтобы данные не зависели от жизненного цикла ВМ.
##############################################################################

resource "yandex_compute_disk" "secondary" {
  for_each = var.secondary_disk_enabled ? toset(local.instance_names) : toset([])

  name = "${each.value}-data"
  zone = var.zone
  size = var.secondary_disk_size
  type = var.secondary_disk_type

  labels = merge(local.labels, { role = "data" })

  lifecycle {
    # Уменьшение размера диска невозможно без пересоздания — защищаемся явно.
    prevent_destroy = false
  }
}

##############################################################################
# Виртуальные машины
##############################################################################

resource "yandex_compute_instance" "this" {
  for_each = toset(local.instance_names)

  name        = each.value
  hostname    = each.value
  zone        = var.zone
  platform_id = var.platform_id

  allow_stopping_for_update = var.allow_stopping_for_update
  allow_recreate            = var.allow_recreate
  service_account_id        = var.service_account_id

  resources {
    cores         = var.cores
    memory        = var.memory
    core_fraction = var.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = local.boot_image_id
      size     = var.boot_disk_size
      type     = var.boot_disk_type
      name     = "${each.value}-boot"
    }
  }

  # Подключение дополнительного диска (создаётся выше) к соответствующей ВМ.
  dynamic "secondary_disk" {
    for_each = var.secondary_disk_enabled ? [yandex_compute_disk.secondary[each.value].id] : []

    content {
      disk_id     = secondary_disk.value
      auto_delete = var.secondary_disk_auto_delete
      device_name = "data"
    }
  }

  network_interface {
    subnet_id          = var.subnet_id
    nat                = var.nat
    security_group_ids = var.security_group_ids
    ip_address         = var.instance_count == 1 ? var.ipv4_address : null
  }

  scheduling_policy {
    preemptible = var.preemptible
  }

  dynamic "placement_policy" {
    for_each = var.placement_group_id == null ? [] : [var.placement_group_id]

    content {
      placement_group_id = placement_policy.value
    }
  }

  metadata = local.metadata
  labels   = local.labels
}
