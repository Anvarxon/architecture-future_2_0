##############################################################################
# Bootstrap: инфраструктура для хранения удалённого состояния Terraform.
#
# Запускается ОДИН РАЗ и вручную (его собственное состояние локальное — иначе
# получается проблема курицы и яйца). Дальше все окружения работают с backend'ом,
# созданным здесь.
#
# Создаётся:
#   * KMS-ключ для шифрования содержимого бакета;
#   * бакет Object Storage с версионированием, шифрованием и запретом публичного доступа;
#   * сервисный аккаунт CI/CD на каждое окружение + статические ключи доступа к S3 API.
##############################################################################

locals {
  labels = {
    managed_by = "terraform"
    purpose    = "tf-state"
  }
}

##############################################################################
# Шифрование состояния
##############################################################################

resource "yandex_kms_symmetric_key" "tfstate" {
  name              = "kms-${var.bucket_name}"
  description       = "Ключ шифрования бакета с состоянием Terraform"
  default_algorithm = "AES_256"
  rotation_period   = "8760h" # 1 год

  labels = local.labels
}

##############################################################################
# Сервисный аккаунт, владеющий бакетом состояния
##############################################################################

resource "yandex_iam_service_account" "tfstate" {
  name        = "sa-tfstate"
  description = "Владелец бакета с состоянием Terraform"
}

resource "yandex_resourcemanager_folder_iam_member" "tfstate_storage_admin" {
  folder_id = var.folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.tfstate.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "tfstate_kms" {
  folder_id = var.folder_id
  role      = "kms.keys.encrypterDecrypter"
  member    = "serviceAccount:${yandex_iam_service_account.tfstate.id}"
}

resource "yandex_iam_service_account_static_access_key" "tfstate" {
  service_account_id = yandex_iam_service_account.tfstate.id
  description        = "Ключ доступа к S3 API для бакета состояния"
}

##############################################################################
# Бакет состояния
##############################################################################

resource "yandex_storage_bucket" "tfstate" {
  access_key = yandex_iam_service_account_static_access_key.tfstate.access_key
  secret_key = yandex_iam_service_account_static_access_key.tfstate.secret_key

  bucket = var.bucket_name

  # Ни при каких условиях бакет не должен быть публичным.
  anonymous_access_flags {
    read        = false
    list        = false
    config_read = false
  }

  # Версионирование — единственный способ откатить повреждённое состояние.
  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = yandex_kms_symmetric_key.tfstate.id
        sse_algorithm     = "aws:kms"
      }
    }
  }

  # Старые версии состояния храним ограниченное время.
  lifecycle_rule {
    id      = "expire-old-state-versions"
    enabled = true

    noncurrent_version_expiration {
      days = var.state_retention_days
    }
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_member.tfstate_storage_admin,
    yandex_resourcemanager_folder_iam_member.tfstate_kms,
  ]
}

##############################################################################
# Сервисные аккаунты CI/CD — по одному на окружение (принцип изоляции прав).
# Каждый SA имеет доступ только к своему каталогу и только к своему префиксу в бакете.
##############################################################################

resource "yandex_iam_service_account" "ci" {
  for_each = var.environments

  name        = "sa-ci-${each.key}"
  description = "Сервисный аккаунт CI/CD для окружения ${each.key}"
}

resource "yandex_resourcemanager_folder_iam_member" "ci_editor" {
  for_each = var.environments

  folder_id = each.value.folder_id
  role      = each.value.role
  member    = "serviceAccount:${yandex_iam_service_account.ci[each.key].id}"
}

# Доступ к бакету состояния.
#
# Нужна именно storage.editor, а не storage.uploader: Terraform читает файл
# состояния, перезаписывает его и удаляет объект блокировки (use_lockfile).
# Роли, дающей только запись, для этого недостаточно.
#
# Роль выдаётся на каталог, то есть на бакет целиком. Разделение по префиксам
# (`task2advanced/<env>/`) на этом уровне — организационное, а не техническое:
# жёсткое ограничение требует политики бакета с условием на префикс ключа.
# Это учтено как шаг усиления в README, раздел «Что осталось за рамками задания».
resource "yandex_resourcemanager_folder_iam_member" "ci_state_access" {
  for_each = var.environments

  folder_id = var.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.ci[each.key].id}"
}

# Содержимое бакета шифруется KMS-ключом, поэтому одних прав на Object Storage
# недостаточно: без kms.keys.encrypterDecrypter запись объекта (включая объект
# блокировки состояния) отклоняется с ошибкой 403 AccessDenied.
resource "yandex_resourcemanager_folder_iam_member" "ci_kms" {
  for_each = var.environments

  folder_id = var.folder_id
  role      = "kms.keys.encrypterDecrypter"
  member    = "serviceAccount:${yandex_iam_service_account.ci[each.key].id}"
}

resource "yandex_iam_service_account_static_access_key" "ci" {
  for_each = var.environments

  service_account_id = yandex_iam_service_account.ci[each.key].id
  description        = "Ключ доступа к S3 API (state) для окружения ${each.key}"
}

# Авторизованный ключ (JSON) — им провайдер Yandex Cloud аутентифицируется в CI.
# Статический ключ выше открывает доступ только к S3 API бакета состояния,
# а для создания ВМ, сетей и дисков нужен именно авторизованный ключ:
# он подставляется в переменную YC_SERVICE_ACCOUNT_KEY_FILE.
resource "yandex_iam_service_account_key" "ci" {
  for_each = var.environments

  service_account_id = yandex_iam_service_account.ci[each.key].id
  description        = "Авторизованный ключ CI/CD для окружения ${each.key}"
  key_algorithm      = "RSA_2048"
}
