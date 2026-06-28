-- =============================================================================
-- GreenRoot — Dev Seed
-- Single canonical seed file. Safe to re-run on an existing DB.
--
-- USAGE
--   Full reset (wipes all data, keeps schema):
--     psql 'postgres:///greenroot?host=/tmp' -v ON_ERROR_STOP=1 \
--          -c "SET session_replication_role = replica;" \
--          -f greenroot-seed.sql \
--          -c "SET session_replication_role = DEFAULT;"
--
--   Or use the helper script:
--     cd greenroot-api && make db-reset
--
-- DEV LOGIN CREDENTIALS  (OTP: 123456 for all)
-- ─────────────────────────────────────────────
--   Role            Mobile        Name
--   Admin           9000000000    GreenRoot Admin
--   Nursery Owner   9100000000    Priya Owner
--   Manager         9200000000    Gumastha Manager
--   Buyer           9300000000    Ravi Buyer
--   Driver          9400000000    Raju Driver
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 1: CLEAN SLATE
-- Disable FK checks → truncate all transactional + identity tables → re-enable.
-- Reference tables (roles, plant_sizes, etc.) are preserved via ON CONFLICT.
-- ─────────────────────────────────────────────────────────────────────────────
SET session_replication_role = replica;

TRUNCATE TABLE
  public.notifications,
  public.platform_config,
  public.audit_logs,
  public.attachments,
  public.payments,
  public.trip_events,
  public.trip_tracking_links,
  public.vehicle_tracking,
  public.dispatch_items,
  public.dispatch_assignments,
  public.dispatches,
  public.order_items,
  public.orders,
  public.quotation_items,
  public.quotations,
  public.invites,
  public.plant_request_responses,
  public.plant_requests,
  public.sourcing_post_photos,
  public.sourcing_post_responses,
  public.sourcing_posts,
  public.sourcing_network_members,
  public.nursery_featured_plants,
  public.nursery_inventory,
  public.nursery_drivers,
  public.nursery_applications,
  public.nursery_addresses,
  public.nursery_users,
  public.nurseries,
  public.driver_locations,
  public.vehicle_locations,
  public.drivers,
  public.vehicles,
  public.user_sessions,
  public.otp_requests,
  public.user_activities,
  public.user_addresses,
  public.user_subscriptions,
  public.user_notification_devices,
  public.user_roles,
  public.users,
  public.public_code_sequences
RESTART IDENTITY;

SET session_replication_role = DEFAULT;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 2: REFERENCE DATA (idempotent — safe to re-run)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO public.roles (role_id, role_code, role_name, description, is_active) VALUES
  (1, 'ADMIN',              'Admin',              'Platform administrator',          true),
  (2, 'BUYER',              'Buyer',              'Plant buyer / customer',          true),
  (3, 'NURSERY_OWNER',      'Nursery Owner',      'Nursery owner',                   true),
  (4, 'DRIVER',             'Driver',             'Delivery driver',                 true),
  (5, 'MANAGER',            'Manager',            'Nursery manager (gumastha)',       true),
  (6, 'SUPER_ADMIN',        'Super Admin',        'Super administrator',             true),
  (7, 'TRANSPORT_PROVIDER', 'Transport Provider', 'Fleet / transport company owner', true)
ON CONFLICT (role_id) DO NOTHING;

INSERT INTO public.nursery_roles (nursery_role_id, role_code, role_name, description) VALUES
  (1, 'OWNER',      'Owner',      'Primary owner of nursery'),
  (2, 'PARTNER',    'Partner',    'Business partner'),
  (3, 'MANAGER',    'Manager',    'Nursery manager'),
  (4, 'OPERATOR',   'Operator',   'Day to day operations'),
  (5, 'ACCOUNTANT', 'Accountant', 'Accounts and finance'),
  (6, 'DISPATCHER', 'Dispatcher', 'Dispatch operations')
ON CONFLICT (nursery_role_id) DO NOTHING;

INSERT INTO public.plant_sizes (size_id, size_code, display_name, display_order, is_active) VALUES
  (1, 'SEED',        'Seed',        1, true),
  (2, 'SAPLING',     'Sapling',     2, true),
  (3, 'SMALL',       'Small',       3, true),
  (4, 'MEDIUM',      'Medium',      4, true),
  (5, 'LARGE',       'Large',       5, true),
  (6, 'EXTRA_LARGE', 'Extra Large', 6, true)
ON CONFLICT (size_id) DO NOTHING;

INSERT INTO public.plant_categories (category_name, is_active) VALUES
  ('Fruit Trees',      true),
  ('Medicinal Plants', true),
  ('Shade Trees',      true),
  ('Herbs',            true),
  ('Ornamental',       true),
  ('Flowering Shrubs', true),
  ('Indoor Plants',    true)
ON CONFLICT (category_name) DO NOTHING;

INSERT INTO public.languages (language_id, language_code, language_name, is_active, created_at, updated_at)
VALUES (1, 'en', 'English', true, NOW(), NOW())
ON CONFLICT DO NOTHING;

INSERT INTO public.platform_config (config_key, config_value, data_type, description) VALUES
  ('otp_expiry_minutes',      '5',    'integer', 'OTP validity window in minutes'),
  ('otp_max_attempts',        '5',    'integer', 'Wrong OTP attempts before code is blocked'),
  ('otp_resend_cooldown_sec', '30',   'integer', 'Seconds to wait before requesting another OTP'),
  ('min_order_amount',        '100',  'numeric', 'Minimum order total in INR'),
  ('platform_fee_pct',        '0',    'numeric', 'Platform fee percentage applied to orders'),
  ('driver_approval_days',    '3',    'integer', 'Days before pending driver approval auto-expires'),
  ('nursery_approval_days',   '7',    'integer', 'Days before pending nursery application auto-expires')
ON CONFLICT (config_key) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 3: SAMPLE PLANTS
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO public.plants (scientific_name, common_name, plant_type, light_requirement, water_requirement, english_description, is_active) VALUES
  ('Mangifera indica',       'Mango',     'TREE',  'FULL_SUN', 'HIGH',     'Popular tropical fruit tree grown across India.',          true),
  ('Azadirachta indica',     'Neem',      'TREE',  'FULL_SUN', 'LOW',      'Hardy medicinal tree known for antibacterial properties.', true),
  ('Hibiscus rosa-sinensis', 'Hibiscus',  'SHRUB', 'FULL_SUN', 'MODERATE', 'Ornamental flowering shrub with large colorful blooms.',   true),
  ('Cocos nucifera',         'Coconut',   'TREE',  'FULL_SUN', 'HIGH',     'Coastal palm tree producing coconuts.',                   true),
  ('Moringa oleifera',       'Drumstick', 'TREE',  'FULL_SUN', 'LOW',      'Fast-growing nutritious tree; all parts are edible.',      true)
ON CONFLICT (scientific_name) DO NOTHING;

INSERT INTO public.plant_category_mapping (plant_id, category_id, created_at)
SELECT p.plant_id, c.category_id, CURRENT_TIMESTAMP
FROM (VALUES
  ('Mangifera indica',       'Fruit Trees'),
  ('Azadirachta indica',     'Medicinal Plants'),
  ('Azadirachta indica',     'Shade Trees'),
  ('Hibiscus rosa-sinensis', 'Ornamental'),
  ('Hibiscus rosa-sinensis', 'Flowering Shrubs'),
  ('Cocos nucifera',         'Fruit Trees'),
  ('Moringa oleifera',       'Medicinal Plants')
) AS m(sci, cat)
JOIN public.plants           p ON p.scientific_name = m.sci
JOIN public.plant_categories c ON c.category_name   = m.cat
ON CONFLICT DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 4: DEV TEST USERS
-- 5 users — one per role. OTP: 123456 for all.
--
--   Mobile        Role            Name
--   9000000000    Admin           GreenRoot Admin
--   9100000000    Nursery Owner   Priya Owner
--   9200000000    Manager         Gumastha Manager
--   9300000000    Buyer           Ravi Buyer
--   9400000000    Driver          Raju Driver
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO public.users (first_name, last_name, mobile, status, mobile_verified) VALUES
  ('GreenRoot', 'Admin',   '9000000000', 'ACTIVE', true),
  ('Priya',     'Owner',   '9100000000', 'ACTIVE', true),
  ('Gumastha',  'Manager', '9200000000', 'ACTIVE', true),
  ('Ravi',      'Buyer',   '9300000000', 'ACTIVE', true),
  ('Raju',      'Driver',  '9400000000', 'ACTIVE', true)
ON CONFLICT (mobile) DO NOTHING;

INSERT INTO public.user_roles (user_id, role_id, assigned_at)
SELECT u.user_id, r.role_id, CURRENT_TIMESTAMP
FROM (VALUES
  ('9000000000', 'ADMIN'),
  ('9000000000', 'SUPER_ADMIN'),
  ('9100000000', 'NURSERY_OWNER'),
  ('9200000000', 'MANAGER'),
  ('9300000000', 'BUYER'),
  ('9400000000', 'DRIVER')
) AS m(mobile, role_code)
JOIN public.users u ON u.mobile     = m.mobile
JOIN public.roles r ON r.role_code  = m.role_code
ON CONFLICT DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 5: NURSERY
-- One nursery for the Owner. Skips PENDING_APPROVAL (dev convenience).
-- Manager is linked as an active member.
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO public.nurseries (nursery_name, owner_user_id, mobile, email, description, status)
SELECT 'GreenRoot Dev Nursery', u.user_id, '9100000000', 'owner@greenroot.dev',
       'Default dev nursery for testing', 'ACTIVE'
FROM public.users u WHERE u.mobile = '9100000000'
ON CONFLICT DO NOTHING;

-- Owner membership (nursery_role_id 1 = OWNER)
INSERT INTO public.nursery_users (nursery_id, user_id, nursery_role_id, role, status)
SELECT n.nursery_id, u.user_id, 1, 'OWNER', 'ACTIVE'
FROM public.nurseries n
JOIN public.users     u ON u.mobile = '9100000000'
WHERE n.mobile = '9100000000'
ON CONFLICT DO NOTHING;

-- Manager membership (nursery_role_id 3 = MANAGER)
INSERT INTO public.nursery_users (nursery_id, user_id, nursery_role_id, role, status)
SELECT n.nursery_id, u.user_id, 3, 'MANAGER', 'ACTIVE'
FROM public.nurseries n
JOIN public.users     u ON u.mobile = '9200000000'
WHERE n.mobile = '9100000000'
ON CONFLICT DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 6: DRIVER PROFILE (pre-approved for immediate dispatch testing)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO public.drivers (user_id, license_number, vehicle_type, vehicle_number, profile_status, approval_status, status)
SELECT u.user_id, 'DL-KA-2024-001', 'TRUCK', 'KA-01-AA-0001', 'COMPLETE', 'APPROVED', 'ACTIVE'
FROM public.users u WHERE u.mobile = '9400000000'
ON CONFLICT (user_id) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 7: SAMPLE VEHICLES
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO public.vehicles (vehicle_number, vehicle_type, capacity_kg, owner_name, mobile, status) VALUES
  ('KA-01-AA-1001', 'TRUCK',     2000.00, 'Dev Transport Co',  '9100000000', 'ACTIVE'),
  ('KA-01-BB-2002', 'MINI_TRUCK', 800.00, 'Dev Logistics',     '9200000000', 'ACTIVE')
ON CONFLICT (vehicle_number) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 8: NURSERY FEATURED PLANTS (sourcing network preview)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO public.sourcing_network_members (nursery_id, is_active, road_accessible, lorry_accessible, service_radius_km, joined_by_user_id)
SELECT n.nursery_id, true, true, true, 50, u.user_id
FROM public.nurseries n
JOIN public.users     u ON u.mobile = '9100000000'
WHERE n.mobile = '9100000000'
ON CONFLICT (nursery_id) DO NOTHING;

INSERT INTO public.nursery_featured_plants (nursery_id, plant_id, display_order, approximate_quantity, approximate_size, quality_notes)
SELECT n.nursery_id, p.plant_id,
       ROW_NUMBER() OVER (ORDER BY p.plant_id),
       CASE ROW_NUMBER() OVER (ORDER BY p.plant_id) WHEN 1 THEN 100 WHEN 2 THEN 60 ELSE 40 END,
       'MEDIUM',
       'Good quality, available for dispatch'
FROM public.nurseries n
CROSS JOIN public.plants p
WHERE n.mobile = '9100000000'
  AND p.scientific_name IN ('Mangifera indica', 'Azadirachta indica', 'Cocos nucifera')
ON CONFLICT (nursery_id, plant_id) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 9: SYNC PUBLIC CODE SEQUENCES
-- Ensures next_public_code() generates correct codes after seed data.
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO public.public_code_sequences (code_key, date_key, last_value)
SELECT 'users', '', COALESCE(MAX(REGEXP_REPLACE(user_code, '[^0-9]', '', 'g')::INTEGER), 0)
FROM public.users
ON CONFLICT (code_key, date_key) DO UPDATE
  SET last_value = GREATEST(public_code_sequences.last_value, EXCLUDED.last_value),
      updated_at = CURRENT_TIMESTAMP;

INSERT INTO public.public_code_sequences (code_key, date_key, last_value)
SELECT 'nurseries', '', COALESCE(MAX(REGEXP_REPLACE(nursery_code, '[^0-9]', '', 'g')::INTEGER), 0)
FROM public.nurseries
ON CONFLICT (code_key, date_key) DO UPDATE
  SET last_value = GREATEST(public_code_sequences.last_value, EXCLUDED.last_value),
      updated_at = CURRENT_TIMESTAMP;

INSERT INTO public.public_code_sequences (code_key, date_key, last_value)
SELECT 'vehicles', '', COALESCE(MAX(REGEXP_REPLACE(vehicle_code, '[^0-9]', '', 'g')::INTEGER), 0)
FROM public.vehicles
ON CONFLICT (code_key, date_key) DO UPDATE
  SET last_value = GREATEST(public_code_sequences.last_value, EXCLUDED.last_value),
      updated_at = CURRENT_TIMESTAMP;

INSERT INTO public.public_code_sequences (code_key, date_key, last_value)
SELECT 'plants', '', COALESCE(MAX(REGEXP_REPLACE(plant_code, '[^0-9]', '', 'g')::INTEGER), 0)
FROM public.plants
ON CONFLICT (code_key, date_key) DO UPDATE
  SET last_value = GREATEST(public_code_sequences.last_value, EXCLUDED.last_value),
      updated_at = CURRENT_TIMESTAMP;

INSERT INTO public.public_code_sequences (code_key, date_key, last_value)
SELECT 'drivers', '', COALESCE(MAX(REGEXP_REPLACE(driver_code, '[^0-9]', '', 'g')::INTEGER), 0)
FROM public.drivers
ON CONFLICT (code_key, date_key) DO UPDATE
  SET last_value = GREATEST(public_code_sequences.last_value, EXCLUDED.last_value),
      updated_at = CURRENT_TIMESTAMP;

-- Done
SELECT
  (SELECT COUNT(*) FROM public.users)     AS users,
  (SELECT COUNT(*) FROM public.nurseries) AS nurseries,
  (SELECT COUNT(*) FROM public.plants)    AS plants,
  (SELECT COUNT(*) FROM public.vehicles)  AS vehicles,
  (SELECT COUNT(*) FROM public.drivers)   AS drivers;
