terraform {
  required_version = ">= 1.6.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.110.0"
    }
  }

  # У bootstrap состояние локальное и это осознанно: он создаёт сам бакет,
  # в котором будет храниться состояние всех остальных конфигураций.
  # Файл bootstrap.tfstate после применения кладётся в защищённое хранилище
  # (или импортируется в созданный бакет отдельной командой).
}

provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}
