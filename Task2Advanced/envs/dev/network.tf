##############################################################################
# Сеть окружения.
# Модуль vm намеренно принимает готовый subnet_id: сеть — ресурс уровня
# окружения, её жизненный цикл длиннее жизненного цикла отдельных ВМ.
##############################################################################

resource "yandex_vpc_network" "this" {
  name   = "net-${var.environment}"
  labels = local.labels
}

resource "yandex_vpc_subnet" "this" {
  name           = "subnet-${var.environment}-${var.zone}"
  zone           = var.zone
  network_id     = yandex_vpc_network.this.id
  v4_cidr_blocks = var.vpc_cidr
  labels         = local.labels
}

resource "yandex_vpc_security_group" "vm" {
  name       = "sg-vm-${var.environment}"
  network_id = yandex_vpc_network.this.id
  labels     = local.labels

  ingress {
    description    = "SSH"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = var.ssh_allowed_cidrs
  }

  ingress {
    description       = "Внутренний трафик между ВМ окружения"
    protocol          = "ANY"
    predefined_target = "self_security_group"
  }

  egress {
    description    = "Исходящий трафик"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
