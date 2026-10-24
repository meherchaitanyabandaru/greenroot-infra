#!/usr/bin/env bash
# Make a mobile number a platform admin (creates the user if needed).
# Production has no seeded admin; run this once after the first deploy.
#
#   sudo /opt/greenroot/bin/create-admin.sh 98XXXXXXXX "First" "Last"
#
# The admin then signs in to admin.<domain> with an OTP sent to that number.
source "$(dirname "$0")/common.sh"

mobile=${1:?usage: create-admin.sh <10-digit mobile> <first name> <last name>}
first=${2:?first name}
last=${3:?last name}
[[ "$mobile" =~ ^[6-9][0-9]{9}$ ]] || { echo "mobile must be a 10-digit Indian number" >&2; exit 2; }

psql_container "$(setting DATABASE_URL)" -q -v mobile="$mobile" -v first="$first" -v last="$last" <<'SQL'
BEGIN;
INSERT INTO public.users (first_name, last_name, mobile, is_mobile_verified, status)
VALUES (:'first', :'last', :'mobile', true, 'ACTIVE')
ON CONFLICT (mobile) DO NOTHING;
INSERT INTO public.user_roles (user_id, role_id)
SELECT u.user_id, r.role_id FROM public.users u, public.roles r
WHERE u.mobile = :'mobile' AND r.role_code IN ('ADMIN', 'SUPER_ADMIN')
ON CONFLICT DO NOTHING;
SELECT 'admin ready: user ' || user_id FROM public.users WHERE mobile = :'mobile';
COMMIT;
SQL
