-- =============================================================================
-- GreenRoot local dev admin seed
-- =============================================================================
-- Dev admin login:
--   Mobile: 9000000000
--   OTP:    123456
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- Single platform admin
INSERT INTO public.users
  (user_id, user_code, first_name, last_name, mobile, email, mobile_verified, email_verified, status)
VALUES
  (1, 'USR-000001', 'GreenRoot', 'Admin', '9000000000', 'admin@greenroot.local', true, true, 'ACTIVE');

INSERT INTO public.user_roles (user_id, role_id)
SELECT 1, role_id
FROM public.roles
WHERE role_code IN ('ADMIN', 'SUPER_ADMIN');

SELECT setval('public.users_user_id_seq', 1, true);
SELECT setval('public.plants_plant_id_seq', (SELECT max(plant_id) FROM public.plants), true);
SELECT setval('public.plant_categories_category_id_seq', (SELECT max(category_id) FROM public.plant_categories), true);
SELECT setval('public.languages_language_id_seq', (SELECT max(language_id) FROM public.languages), true);
SELECT setval('public.subscription_plans_plan_id_seq', (SELECT max(plan_id) FROM public.subscription_plans), true);

-- Public code sequence sync
DELETE FROM public.public_code_sequences;

INSERT INTO public.public_code_sequences (code_key, date_key, last_value) VALUES
  ('users',                 '', 1),
  ('nurseries',             '', 0),
  ('nursery_inventory',     '', 0),
  ('nursery_applications',  '', 0),
  ('drivers',               '', 0),
  ('vehicles',              '', 0),
  ('attachments',           '', 0),
  ('notifications',         '', 0),
  ('user_subscriptions',    '', 0),
  ('orders',                to_char(CURRENT_DATE, 'YYYYMMDD'), 0),
  ('quotations',            to_char(CURRENT_DATE, 'YYYYMMDD'), 0),
  ('dispatches',            to_char(CURRENT_DATE, 'YYYYMMDD'), 0),
  ('plants',                '', COALESCE((SELECT max(regexp_replace(plant_code, '[^0-9]', '', 'g')::integer) FROM public.plants), 0));


COMMIT;

SELECT
  (SELECT count(*) FROM public.users) AS users,
  (SELECT count(*) FROM public.roles) AS roles,
  (SELECT count(*) FROM public.plants) AS plants,
  (SELECT count(*) FROM public.subscription_plans) AS subscription_plans,
  (SELECT count(*) FROM public.nurseries) AS nurseries,
  (SELECT count(*) FROM public.orders) AS orders,
  (SELECT count(*) FROM public.quotations) AS quotations;
