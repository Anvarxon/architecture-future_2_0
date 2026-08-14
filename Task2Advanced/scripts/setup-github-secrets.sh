#!/usr/bin/env bash
#
# Переносит учётные данные из выводов bootstrap в GitHub Environments.
#
# Что делает:
#   1. создаёт окружения dev / stage / prod и dev-plan / stage-plan / prod-plan;
#   2. кладёт в каждое три секрета: YC_SA_KEY_JSON, TFSTATE_ACCESS_KEY, TFSTATE_SECRET_KEY;
#   3. кладёт три переменные: YC_CLOUD_ID, YC_FOLDER_ID, SSH_PUBLIC_KEY.
#
# Значения читаются напрямую из состояния Terraform и передаются в gh через stdin —
# они не печатаются на экран, не попадают в историю оболочки и не сохраняются
# во временные файлы.
#
# Требуется: gh (авторизованный, `gh auth status`), terraform, python3.
#
# Запуск из корня репозитория:
#   bash Task2Advanced/scripts/setup-github-secrets.sh
#
# Ручное подтверждение apply для stage и prod настраивается отдельно, в UI:
#   Settings → Environments → <env> → Required reviewers.
# Скрипт этого не делает намеренно: список ревьюеров — организационное решение.

set -euo pipefail

BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bootstrap" && pwd)"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519.pub}"
ENVIRONMENTS=(dev stage prod)

command -v gh >/dev/null || { echo "Нужен gh: brew install gh"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Сначала выполните: gh auth login"; exit 1; }
[ -f "$SSH_KEY_PATH" ] || { echo "Не найден публичный SSH-ключ: $SSH_KEY_PATH"; exit 1; }

REPO="${REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
echo "Репозиторий: $REPO"

# Плагины провайдера могли быть не установлены (свежий клон репозитория или
# очищенный кэш .terraform) — тогда terraform output вернёт текст ошибки вместо
# JSON. init идемпотентен и при наличии кэша отрабатывает мгновенно.
terraform -chdir="$BOOTSTRAP_DIR" init -input=false >/dev/null

# Вспомогательная функция: достаёт значение из JSON-вывода Terraform.
tf_output() {
  local name="$1" out
  if ! out="$(terraform -chdir="$BOOTSTRAP_DIR" output -json "$name" 2>&1)"; then
    echo "Не удалось прочитать вывод '$name' из состояния bootstrap:" >&2
    echo "$out" >&2
    echo "Убедитесь, что bootstrap применён: terraform -chdir=$BOOTSTRAP_DIR apply" >&2
    exit 1
  fi
  printf '%s' "$out"
}

# $1 — путь внутри JSON, например ['dev']['access_key']
extract() {
  python3 -c "import json,sys; d=json.load(sys.stdin); print(d$1)"
}

CLOUD_ID="$(tf_output cloud_id | python3 -c 'import json,sys; print(json.load(sys.stdin))')"
FOLDER_IDS="$(tf_output environment_folder_ids)"
ACCESS_KEYS="$(tf_output ci_access_keys)"
AUTH_KEYS="$(tf_output ci_authorized_keys)"
SSH_PUBLIC_KEY="$(cat "$SSH_KEY_PATH")"

for env in "${ENVIRONMENTS[@]}"; do
  echo
  echo "── Окружение: $env"

  # Окружение должно существовать до записи секретов.
  for suffix in "" "-plan"; do
    gh api -X PUT "repos/$REPO/environments/${env}${suffix}" --silent
    echo "   окружение ${env}${suffix} готово"
  done

  folder_id="$(printf '%s' "$FOLDER_IDS" | extract "['$env']")"
  access_key="$(printf '%s' "$ACCESS_KEYS" | extract "['$env']['access_key']")"
  secret_key="$(printf '%s' "$ACCESS_KEYS" | extract "['$env']['secret_key']")"
  auth_key="$(printf '%s' "$AUTH_KEYS" | extract "['$env']")"

  # Секреты и переменные дублируются в окружение планирования: job плана
  # использует <env>-plan, чтобы не упираться в required reviewers.
  for suffix in "" "-plan"; do
    target="${env}${suffix}"

    printf '%s' "$auth_key"   | gh secret set YC_SA_KEY_JSON     --env "$target" --repo "$REPO"
    printf '%s' "$access_key" | gh secret set TFSTATE_ACCESS_KEY --env "$target" --repo "$REPO"
    printf '%s' "$secret_key" | gh secret set TFSTATE_SECRET_KEY --env "$target" --repo "$REPO"

    gh variable set YC_CLOUD_ID    --env "$target" --repo "$REPO" --body "$CLOUD_ID"
    gh variable set YC_FOLDER_ID   --env "$target" --repo "$REPO" --body "$folder_id"
    gh variable set SSH_PUBLIC_KEY --env "$target" --repo "$REPO" --body "$SSH_PUBLIC_KEY"

    echo "   секреты и переменные записаны в $target"
  done
done

echo
echo "Готово. Осталось вручную, в Settings → Environments:"
echo "  * для stage и prod включить Required reviewers — это кнопка approval в пайплайне;"
echo "  * для prod ограничить Deployment branches веткой main."
