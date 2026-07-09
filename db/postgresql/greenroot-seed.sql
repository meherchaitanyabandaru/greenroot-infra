-- =============================================================================
-- GreenRoot — Dev Seed  (v2)
-- Wipes all transactional data, keeps schema + reference tables.
--
-- USAGE
--   psql 'postgres:///greenroot?host=/tmp' -v ON_ERROR_STOP=1 \
--        -c "SET session_replication_role = replica;" \
--        -f greenroot-seed.sql \
--        -c "SET session_replication_role = DEFAULT;"
--
-- DEV LOGIN CREDENTIALS  (OTP: 123456 for all)
-- ─────────────────────────────────────────────
--   Mobile        Role                Name
--   9000000000    Admin + Super Admin  Mehar Bandaru
--   9100000000    Nursery Owner        Priya Reddy       (Green Valley Nursery)
--   9110000000    Nursery Owner        Suresh Patel      (Lotus Gardens)
--   9120000000    Nursery Owner        Kavitha Nair      (Nature's Nest)
--   9200000000    Manager              Arjun Kumar       (Green Valley)
--   9210000000    Manager              Lakshmi Devi      (Lotus Gardens)
--   9300000000    Buyer                Ramesh Gupta
--   9310000000    Buyer                Ananya Singh
--   9400000000    Driver               Venkat Rao        (pre-approved)
--   9410000000    Driver               Balaji Krishnan   (pre-approved)
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 1: CLEAN SLATE
-- ─────────────────────────────────────────────────────────────────────────────
SET session_replication_role = replica;

TRUNCATE TABLE
  public.notifications,
  public.subscription_promos,
  public.user_subscriptions,
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
  public.market_ad_reports,
  public.market_ad_saves,
  public.market_ad_views,
  public.market_ads,
  public.market_enquiries,
  public.market_enquiry_messages,
  public.user_sessions,
  public.otp_requests,
  public.user_activities,
  public.user_addresses,
  public.user_notification_devices,
  public.user_roles,
  public.users,
  public.plant_category_mapping,
  public.plant_care_guides,
  public.plant_images,
  public.plant_names,
  public.plants,
  public.public_code_sequences
RESTART IDENTITY;

SET session_replication_role = DEFAULT;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 2: REFERENCE DATA
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
  ('Indoor Plants',    true),
  ('Succulents',       true),
  ('Climbers',         true)
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
-- SECTION 3: PLANTS  (15 common Indian nursery plants)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO public.plants (scientific_name, common_name, plant_type, light_requirement, water_requirement, english_description, is_active) VALUES
  ('Mangifera indica',         'Mango',           'TREE',   'FULL_SUN',    'HIGH',     'King of fruits. Popular tropical tree, grafted varieties fruit in 2–3 years.',          true),
  ('Azadirachta indica',       'Neem',            'TREE',   'FULL_SUN',    'LOW',      'Hardy medicinal tree. Leaves, bark, and oil used in traditional medicine.',             true),
  ('Hibiscus rosa-sinensis',   'Hibiscus',        'SHRUB',  'FULL_SUN',    'MODERATE', 'Ornamental shrub with large vibrant flowers, blooms year-round in warm climates.',      true),
  ('Cocos nucifera',           'Coconut',         'TREE',   'FULL_SUN',    'HIGH',     'Coastal palm producing coconuts; all parts commercially valuable.',                     true),
  ('Moringa oleifera',         'Drumstick',       'TREE',   'FULL_SUN',    'LOW',      'Fast-growing nutritious tree; pods, leaves, and flowers are edible.',                  true),
  ('Ocimum tenuiflorum',       'Tulsi',           'HERB',   'FULL_SUN',    'MODERATE', 'Sacred basil plant with strong medicinal properties. Easy to grow in pots.',           true),
  ('Aloe vera',                'Aloe Vera',       'SHRUB',  'FULL_SUN',    'LOW',      'Succulent known for skin-healing gel. Very low maintenance, ideal for beginners.',      true),
  ('Psidium guajava',          'Guava',           'TREE',   'FULL_SUN',    'MODERATE', 'Fast-fruiting tropical tree. Rich in Vitamin C, popular in home gardens.',             true),
  ('Rosa indica',              'Rose',            'SHRUB',  'FULL_SUN',    'MODERATE', 'Classic flowering shrub available in hundreds of varieties and colors.',                true),
  ('Catharanthus roseus',      'Periwinkle',      'HERB',   'FULL_SUN',    'MODERATE', 'Hardy ground-cover with pink/white flowers. Drought tolerant once established.',        true),
  ('Ficus benjamina',          'Weeping Fig',     'TREE',   'PARTIAL_SUN', 'MODERATE', 'Popular indoor ornamental tree with glossy leaves. Ideal for large indoor spaces.',    true),
  ('Epipremnum aureum',        'Money Plant',     'CLIMBER','LOW_LIGHT',   'LOW',      'Extremely easy to grow climber. Thrives in water or soil, purifies indoor air.',       true),
  ('Sansevieria trifasciata',  'Snake Plant',     'SHRUB',  'LOW_LIGHT',   'LOW',      'Near-indestructible indoor plant. Releases oxygen at night, great for bedrooms.',      true),
  ('Plumeria rubra',           'Frangipani',      'TREE',   'FULL_SUN',    'LOW',      'Tropical tree with fragrant waxy flowers. Often used in garlands and temples.',        true),
  ('Duranta erecta',           'Golden Dewdrop',  'SHRUB',  'FULL_SUN',    'MODERATE', 'Fast-growing ornamental shrub with purple flowers and golden berries.',                 true)
ON CONFLICT (scientific_name) DO NOTHING;

INSERT INTO public.plant_category_mapping (plant_id, category_id, created_at)
SELECT p.plant_id, c.category_id, CURRENT_TIMESTAMP
FROM (VALUES
  ('Mangifera indica',        'Fruit Trees'),
  ('Azadirachta indica',      'Medicinal Plants'),
  ('Azadirachta indica',      'Shade Trees'),
  ('Hibiscus rosa-sinensis',  'Ornamental'),
  ('Hibiscus rosa-sinensis',  'Flowering Shrubs'),
  ('Cocos nucifera',          'Fruit Trees'),
  ('Moringa oleifera',        'Medicinal Plants'),
  ('Ocimum tenuiflorum',      'Herbs'),
  ('Ocimum tenuiflorum',      'Medicinal Plants'),
  ('Aloe vera',               'Medicinal Plants'),
  ('Aloe vera',               'Succulents'),
  ('Psidium guajava',         'Fruit Trees'),
  ('Rosa indica',             'Flowering Shrubs'),
  ('Rosa indica',             'Ornamental'),
  ('Catharanthus roseus',     'Flowering Shrubs'),
  ('Ficus benjamina',         'Indoor Plants'),
  ('Epipremnum aureum',       'Indoor Plants'),
  ('Epipremnum aureum',       'Climbers'),
  ('Sansevieria trifasciata', 'Indoor Plants'),
  ('Plumeria rubra',          'Flowering Shrubs'),
  ('Duranta erecta',          'Ornamental'),
  ('Duranta erecta',          'Flowering Shrubs')
) AS m(sci, cat)
JOIN public.plants           p ON p.scientific_name = m.sci
JOIN public.plant_categories c ON c.category_name   = m.cat
ON CONFLICT DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 4: USERS  (10 meaningful dev users)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO public.users (first_name, last_name, mobile, status, mobile_verified) VALUES
  ('Mehar',    'Bandaru',   '9000000000', 'ACTIVE', true),  -- Admin
  ('Priya',    'Reddy',     '9100000000', 'ACTIVE', true),  -- Owner 1
  ('Suresh',   'Patel',     '9110000000', 'ACTIVE', true),  -- Owner 2
  ('Kavitha',  'Nair',      '9120000000', 'ACTIVE', true),  -- Owner 3
  ('Arjun',    'Kumar',     '9200000000', 'ACTIVE', true),  -- Manager 1
  ('Lakshmi',  'Devi',      '9210000000', 'ACTIVE', true),  -- Manager 2
  ('Ramesh',   'Gupta',     '9300000000', 'ACTIVE', true),  -- Buyer 1
  ('Ananya',   'Singh',     '9310000000', 'ACTIVE', true),  -- Buyer 2
  ('Venkat',   'Rao',       '9400000000', 'ACTIVE', true),  -- Driver 1
  ('Balaji',   'Krishnan',  '9410000000', 'ACTIVE', true)   -- Driver 2
ON CONFLICT (mobile) DO NOTHING;

INSERT INTO public.user_roles (user_id, role_id, assigned_at)
SELECT u.user_id, r.role_id, CURRENT_TIMESTAMP
FROM (VALUES
  ('9000000000', 'ADMIN'),
  ('9000000000', 'SUPER_ADMIN'),
  ('9100000000', 'NURSERY_OWNER'),
  ('9110000000', 'NURSERY_OWNER'),
  ('9120000000', 'NURSERY_OWNER'),
  ('9200000000', 'MANAGER'),
  ('9210000000', 'MANAGER'),
  ('9300000000', 'BUYER'),
  ('9310000000', 'BUYER'),
  ('9400000000', 'DRIVER'),
  ('9410000000', 'DRIVER')
) AS m(mobile, role_code)
JOIN public.users u ON u.mobile    = m.mobile
JOIN public.roles r ON r.role_code = m.role_code
ON CONFLICT DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 5: NURSERIES  (3 nurseries, all ACTIVE)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO public.nurseries (nursery_name, owner_user_id, mobile, email, description, status)
SELECT 'Green Valley Nursery', u.user_id, '9100000000', 'priya@greenvalley.in',
       'Specialises in fruit trees and shade trees. Located in Bangalore outskirts.', 'ACTIVE'
FROM public.users u WHERE u.mobile = '9100000000'
ON CONFLICT DO NOTHING;

INSERT INTO public.nurseries (nursery_name, owner_user_id, mobile, email, description, status)
SELECT 'Lotus Gardens', u.user_id, '9110000000', 'suresh@lotusgardens.in',
       'Premium ornamental and flowering plant nursery. Hyderabad based.', 'ACTIVE'
FROM public.users u WHERE u.mobile = '9110000000'
ON CONFLICT DO NOTHING;

INSERT INTO public.nurseries (nursery_name, owner_user_id, mobile, email, description, status)
SELECT 'Nature''s Nest', u.user_id, '9120000000', 'kavitha@naturesnest.in',
       'Indoor plants and succulents specialist. Ships across South India.', 'ACTIVE'
FROM public.users u WHERE u.mobile = '9120000000'
ON CONFLICT DO NOTHING;

-- Owner memberships
INSERT INTO public.nursery_users (nursery_id, user_id, nursery_role_id, role, status)
SELECT n.nursery_id, u.user_id, 1, 'OWNER', 'ACTIVE'
FROM public.nurseries n
JOIN public.users     u ON u.mobile = n.mobile
ON CONFLICT DO NOTHING;

-- Arjun Kumar → Manager at Green Valley Nursery
INSERT INTO public.nursery_users (nursery_id, user_id, nursery_role_id, role, status)
SELECT n.nursery_id, u.user_id, 3, 'MANAGER', 'ACTIVE'
FROM public.nurseries n
JOIN public.users     u ON u.mobile = '9200000000'
WHERE n.mobile = '9100000000'
ON CONFLICT DO NOTHING;

-- Lakshmi Devi → Manager at Lotus Gardens
INSERT INTO public.nursery_users (nursery_id, user_id, nursery_role_id, role, status)
SELECT n.nursery_id, u.user_id, 3, 'MANAGER', 'ACTIVE'
FROM public.nurseries n
JOIN public.users     u ON u.mobile = '9210000000'
WHERE n.mobile = '9110000000'
ON CONFLICT DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 6: DRIVERS  (2 pre-approved)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO public.drivers (user_id, license_number, vehicle_type, vehicle_number, profile_status, approval_status, status)
SELECT u.user_id, 'KA-2024-DL-7821', 'TRUCK', 'KA-01-AA-0001', 'COMPLETE', 'APPROVED', 'ACTIVE'
FROM public.users u WHERE u.mobile = '9400000000'
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.drivers (user_id, license_number, vehicle_type, vehicle_number, profile_status, approval_status, status)
SELECT u.user_id, 'TN-2023-DL-4456', 'MINI_TRUCK', 'TN-07-CB-5522', 'COMPLETE', 'APPROVED', 'ACTIVE'
FROM public.users u WHERE u.mobile = '9410000000'
ON CONFLICT (user_id) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 7: VEHICLES
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO public.vehicles (vehicle_number, vehicle_type, capacity_kg, owner_name, mobile, status) VALUES
  ('KA-01-AA-0001', 'TRUCK',      2000.00, 'Venkat Rao',      '9400000000', 'ACTIVE'),
  ('TN-07-CB-5522', 'MINI_TRUCK',  800.00, 'Balaji Krishnan', '9410000000', 'ACTIVE')
ON CONFLICT (vehicle_number) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 8: SOURCING NETWORK + FEATURED PLANTS
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO public.sourcing_network_members (nursery_id, is_active, road_accessible, lorry_accessible, service_radius_km, joined_by_user_id)
SELECT n.nursery_id, true, true, true,
       CASE n.mobile WHEN '9100000000' THEN 75 WHEN '9110000000' THEN 50 ELSE 40 END,
       u.user_id
FROM public.nurseries n
JOIN public.users     u ON u.mobile = n.mobile
ON CONFLICT (nursery_id) DO NOTHING;

-- Green Valley: fruit + shade trees
INSERT INTO public.nursery_featured_plants (nursery_id, plant_id, display_order, approximate_quantity, approximate_size, quality_notes)
SELECT n.nursery_id, p.plant_id,
       ROW_NUMBER() OVER (PARTITION BY n.nursery_id ORDER BY p.plant_id),
       (ARRAY[120, 80, 50, 200])[MOD(p.plant_id::int, 4) + 1],
       'MEDIUM', 'Well-maintained. Available for bulk dispatch.'
FROM public.nurseries n
CROSS JOIN public.plants p
WHERE n.mobile = '9100000000'
  AND p.scientific_name IN ('Mangifera indica', 'Azadirachta indica', 'Cocos nucifera', 'Moringa oleifera', 'Psidium guajava')
ON CONFLICT (nursery_id, plant_id) DO NOTHING;

-- Lotus Gardens: ornamental + flowering
INSERT INTO public.nursery_featured_plants (nursery_id, plant_id, display_order, approximate_quantity, approximate_size, quality_notes)
SELECT n.nursery_id, p.plant_id,
       ROW_NUMBER() OVER (PARTITION BY n.nursery_id ORDER BY p.plant_id),
       (ARRAY[300, 150, 200])[MOD(p.plant_id::int, 3) + 1],
       'SMALL', 'Premium blooming stock, freshly potted.'
FROM public.nurseries n
CROSS JOIN public.plants p
WHERE n.mobile = '9110000000'
  AND p.scientific_name IN ('Hibiscus rosa-sinensis', 'Rosa indica', 'Catharanthus roseus', 'Duranta erecta', 'Plumeria rubra')
ON CONFLICT (nursery_id, plant_id) DO NOTHING;

-- Nature's Nest: indoor + succulents
INSERT INTO public.nursery_featured_plants (nursery_id, plant_id, display_order, approximate_quantity, approximate_size, quality_notes)
SELECT n.nursery_id, p.plant_id,
       ROW_NUMBER() OVER (PARTITION BY n.nursery_id ORDER BY p.plant_id),
       (ARRAY[500, 400, 250, 180])[MOD(p.plant_id::int, 4) + 1],
       'SMALL', 'Healthy indoor stock. Suitable for gifting or bulk orders.'
FROM public.nurseries n
CROSS JOIN public.plants p
WHERE n.mobile = '9120000000'
  AND p.scientific_name IN ('Ficus benjamina', 'Epipremnum aureum', 'Sansevieria trifasciata', 'Aloe vera', 'Ocimum tenuiflorum')
ON CONFLICT (nursery_id, plant_id) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 9: SUBSCRIPTION PLANS  (updated pricing + anchor MRP)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO public.subscription_plans
  (plan_code, plan_name, description, monthly_price, yearly_price, max_managers, is_active, features)
VALUES
  ('TRIAL',
   '🌱 Community (Free)',
   '6-month free trial — full platform access, 1 manager, unlimited orders & quotations.',
   0.00, 0.00, 1, true,
   '{"support":"community","analytics":"basic","max_managers":1,"billing_cycles":["TRIAL"],"unlimited_orders":true,"unlimited_quotations":true,"market_posts_per_day":3}'::jsonb),

  ('GROWTH',
   '🚀 Growth',
   'For growing nurseries — unlimited orders, quotations, and up to 5 managers.',
   2499.00, 3999.00, 5, true,
   '{"support":"email","analytics":"full","max_managers":5,"billing_cycles":["SIX_MONTH","YEARLY"],"unlimited_orders":true,"unlimited_quotations":true,"market_posts_per_day":5,"mrp_six_month":4999,"mrp_yearly":19999}'::jsonb),

  ('ENTERPRISE',
   '🏢 Enterprise',
   'For large operations — unlimited managers, advanced analytics, and priority support.',
   7499.00, 11999.00, NULL, true,
   '{"support":"priority","analytics":"advanced","max_managers":null,"billing_cycles":["SIX_MONTH","YEARLY"],"unlimited_orders":true,"unlimited_quotations":true,"market_posts_per_day":null,"mrp_six_month":14999,"mrp_yearly":59999}'::jsonb)

ON CONFLICT (plan_code) DO UPDATE
  SET plan_name     = EXCLUDED.plan_name,
      description   = EXCLUDED.description,
      monthly_price = EXCLUDED.monthly_price,
      yearly_price  = EXCLUDED.yearly_price,
      max_managers  = EXCLUDED.max_managers,
      is_active     = EXCLUDED.is_active,
      features      = EXCLUDED.features,
      updated_at    = CURRENT_TIMESTAMP;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 10: SYNC PUBLIC CODE SEQUENCES
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
  (SELECT COUNT(*) FROM public.users)         AS users,
  (SELECT COUNT(*) FROM public.nurseries)     AS nurseries,
  (SELECT COUNT(*) FROM public.plants)        AS plants,
  (SELECT COUNT(*) FROM public.vehicles)      AS vehicles,
  (SELECT COUNT(*) FROM public.drivers)       AS drivers,
  (SELECT COUNT(*) FROM public.subscription_plans WHERE plan_code IN ('TRIAL','GROWTH','ENTERPRISE')) AS plans;
