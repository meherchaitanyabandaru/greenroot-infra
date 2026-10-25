#!/usr/bin/env bash
# Change one API setting in Secrets Manager. The value is read from stdin so it
# never appears in shell history or the process list.
#
#   sudo /opt/greenroot/bin/set-secret.sh RAZORPAY_KEY_ID          # paste, Enter, Ctrl-D
#   sudo /opt/greenroot/bin/set-secret.sh FCM_SERVICE_ACCOUNT_JSON < service-account.json
#   sudo /opt/greenroot/bin/set-secret.sh APP_ENV <<<production
#
# Then restart the API so it reads the new value:  sudo /opt/greenroot/bin/restart.sh
source "$(dirname "$0")/common.sh"

key=${1:?usage: set-secret.sh KEY  (value on stdin)}
[[ "$key" =~ ^[A-Z][A-Z0-9_]*$ ]] || { echo "KEY must look like an environment variable" >&2; exit 2; }
[[ -t 0 ]] && echo "Enter the value for $key, then Ctrl-D:" >&2
value=$(cat)
value=${value%$'\n'} # drop the final newline from paste / heredoc

current=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --query SecretString --output text)
updated=$(jq -c --arg k "$key" --arg v "$value" '.[$k] = $v' <<<"$current")
aws secretsmanager put-secret-value --secret-id "$SECRET_ID" --secret-string "$updated" >/dev/null
log "$key updated (${#value} characters). Restart the API to apply it."
