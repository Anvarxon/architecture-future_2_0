##############################################################################
# Сеть прод-окружения: одна VPC, по подсети на каждую зону доступности.
##############################################################################

resource "yandex_vpc_network" "this" {
  name   = "net-${var.environment}"
  labels = local.labels
}

# Исходящий трафик приватных ВМ (без публичных IP) — через NAT-шлюз.
resource "yandex_vpc_gateway" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  name = "gw-nat-${var.environment}"

  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "egress" {
  count = var.enable_nat_gateway ? 1 : 0

  name       = "rt-egress-${var.environment}"
  network_id = yandex_vpc_network.this.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat[0].id
  }
}

resource "yandex_vpc_subnet" "this" {
  for_each = toset(var.zones)

  name           = "subnet-${var.environment}-${each.value}"
  zone           = each.value
  network_id     = yandex_vpc_network.this.id
  v4_cidr_blocks = [var.subnet_cidrs[each.value]]
  route_table_id = var.enable_nat_gateway ? yandex_vpc_route_table.egress[0].id : null
  labels         = local.labels
}

resource "yandex_vpc_security_group" "vm" {
  name       = "sg-vm-${var.environment}"
  network_id = yandex_vpc_network.this.id
  labels     = local.labels

  ingress {
    description    = "SSH только из доверенных сетей (бастион/VPN)"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = var.ssh_allowed_cidrs
  }

  ingress {
    description       = "Внутренний трафик между ВМ окружения"
    protocol          = "ANY"
    predefined_target = "self_security_group"
  }

  ingress {
    description    = "Проверки состояния от балансировщика"
    protocol       = "TCP"
    port           = 8080
    v4_cidr_blocks = ["198.18.235.0/24", "198.18.248.0/24"]
  }

  egress {
    description    = "Исходящий трафик"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Анти-аффинити: ВМ одной зоны разносятся по разным физическим хостам.
resource "yandex_compute_placement_group" "this" {
  for_each = var.enable_placement_group ? toset(var.zones) : toset([])

  name                      = "pg-${var.environment}-${each.value}"
  placement_strategy_spread = true
}
