output "network_id" {
  description = "ID сети окружения."
  value       = yandex_vpc_network.this.id
}

output "subnet_ids" {
  description = "Карта: зона доступности -> ID подсети."
  value       = { for zone, subnet in yandex_vpc_subnet.this : zone => subnet.id }
}

output "security_group_id" {
  description = "ID группы безопасности ВМ."
  value       = yandex_vpc_security_group.vm.id
}

output "nat_gateway_id" {
  description = "ID NAT-шлюза (null, если шлюз отключён)."
  value       = var.enable_nat_gateway ? yandex_vpc_gateway.nat[0].id : null
}

output "instance_ids" {
  description = "Карта: зона доступности -> {имя ВМ -> ID}."
  value       = { for zone, m in module.vm : zone => m.instance_ids }
}

output "internal_ips" {
  description = "Карта: зона доступности -> {имя ВМ -> внутренний IP}."
  value       = { for zone, m in module.vm : zone => m.internal_ips }
}

output "secondary_disk_ids" {
  description = "Карта: зона доступности -> {имя ВМ -> ID диска с данными}."
  value       = { for zone, m in module.vm : zone => m.secondary_disk_ids }
}

output "all_instance_names" {
  description = "Плоский список имён всех ВМ прод-окружения."
  value       = flatten([for zone, m in module.vm : m.instance_names])
}

output "summary" {
  description = "Сводка по конфигурации каждой зоны."
  value       = { for zone, m in module.vm : zone => m.summary }
}
