output "network_id" {
  description = "ID сети окружения."
  value       = yandex_vpc_network.this.id
}

output "subnet_id" {
  description = "ID подсети окружения."
  value       = yandex_vpc_subnet.this.id
}

output "security_group_id" {
  description = "ID группы безопасности ВМ."
  value       = yandex_vpc_security_group.vm.id
}

output "instance_ids" {
  description = "ID созданных ВМ."
  value       = module.vm.instance_ids
}

output "internal_ips" {
  description = "Внутренние IP-адреса ВМ."
  value       = module.vm.internal_ips
}

output "external_ips" {
  description = "Публичные IP-адреса ВМ."
  value       = module.vm.external_ips
}

output "secondary_disk_ids" {
  description = "ID подключаемых дисков."
  value       = module.vm.secondary_disk_ids
}

output "ssh_commands" {
  description = "Команды подключения по SSH."
  value       = module.vm.ssh_commands
}

output "summary" {
  description = "Сводка по конфигурации окружения."
  value       = module.vm.summary
}
