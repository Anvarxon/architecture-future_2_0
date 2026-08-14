terraform {
  required_version = ">= 1.6.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.110.0"
    }
  }
}

# Внутри модуля намеренно НЕ объявляется блок `provider`.
# Конфигурация провайдера (токен, cloud_id, folder_id, zone) задаётся
# на уровне окружения (envs/<env>/providers.tf) и наследуется модулем.
# Это позволяет переиспользовать модуль в разных облаках/каталогах и
# вызывать его несколько раз в одном окружении (см. envs/prod).
