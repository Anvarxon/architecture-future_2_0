##############################################################################
# Идентификаторы и имена
##############################################################################

output "instance_ids" {
  description = "Карта: имя ВМ -> ID виртуальной машины."
  value       = { for name, vm in yandex_compute_instance.this : name => vm.id }
}

output "instance_names" {
  description = "Список имён созданных виртуальных машин."
  value       = sort(keys(yandex_compute_instance.this))
}

output "instance_id" {
  description = "ID первой (или единственной) ВМ — удобно, когда модуль создаёт один экземпляр."
  value       = yandex_compute_instance.this[sort(keys(yandex_compute_instance.this))[0]].id
}

output "fqdns" {
  description = "Карта: имя ВМ -> внутренний FQDN."
  value       = { for name, vm in yandex_compute_instance.this : name => vm.fqdn }
}

##############################################################################
# Сеть
##############################################################################

output "internal_ips" {
  description = "Карта: имя ВМ -> внутренний IPv4-адрес."
  value       = { for name, vm in yandex_compute_instance.this : name => vm.network_interface[0].ip_address }
}

output "external_ips" {
  description = "Карта: имя ВМ -> публичный IPv4-адрес (пустая строка, если NAT выключен)."
  value       = { for name, vm in yandex_compute_instance.this : name => vm.network_interface[0].nat_ip_address }
}

output "subnet_id" {
  description = "ID подсети, в которой размещены ВМ."
  value       = var.subnet_id
}

##############################################################################
# Диски
##############################################################################

output "boot_disk_ids" {
  description = "Карта: имя ВМ -> ID загрузочного диска."
  value       = { for name, vm in yandex_compute_instance.this : name => vm.boot_disk[0].disk_id }
}

output "secondary_disk_ids" {
  description = "Карта: имя ВМ -> ID подключаемого диска. Пустая карта, если дополнительный диск отключён."
  value       = { for name, disk in yandex_compute_disk.secondary : name => disk.id }
}

##############################################################################
# Сводка и эксплуатация
##############################################################################

output "zone" {
  description = "Зона доступности, в которой развёрнуты ресурсы."
  value       = var.zone
}

output "ssh_commands" {
  description = "Готовые команды подключения по SSH (по публичному IP, если он есть, иначе по внутреннему)."
  value = {
    for name, vm in yandex_compute_instance.this :
    name => format(
      "ssh %s@%s",
      var.ssh_user,
      vm.network_interface[0].nat_ip_address != "" ? vm.network_interface[0].nat_ip_address : vm.network_interface[0].ip_address
    )
  }
}

output "summary" {
  description = "Сводная информация о конфигурации, развёрнутой модулем."
  value = {
    environment    = var.environment
    zone           = var.zone
    instance_count = var.instance_count
    cores          = var.cores
    memory_gb      = var.memory
    core_fraction  = var.core_fraction
    preemptible    = var.preemptible
    boot_disk_gb   = var.boot_disk_size
    data_disk_gb   = var.secondary_disk_enabled ? var.secondary_disk_size : 0
  }
}
