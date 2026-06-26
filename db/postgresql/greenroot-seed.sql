-- GreenRoot sample seed data
-- Run after all migrations. Safe to re-run (ON CONFLICT DO NOTHING / DO UPDATE).
-- Inserts: platform roles, admin user, nurseries, manager users, vehicles, plant sizes, plant categories, sample plants.

-- ─── Platform roles ───────────────────────────────────────────────────────────
INSERT INTO public.roles (role_id, role_code, role_name, description, is_active)
VALUES
  (1, 'ADMIN',              'Admin',              'Platform administrator',          true),
  (2, 'BUYER',              'Buyer',              'Plant buyer / customer',          true),
  (3, 'NURSERY_OWNER',      'Nursery Owner',      'Nursery owner or co-owner',       true),
  (4, 'DRIVER',             'Driver',             'Delivery driver',                 true),
  (5, 'MANAGER',            'Manager',            'Nursery manager (gumastha)',       true),
  (6, 'SUPER_ADMIN',        'Super Admin',        'Super administrator',             true),
  (7, 'TRANSPORT_PROVIDER', 'Transport Provider', 'Fleet / transport company owner', true)
ON CONFLICT (role_id) DO NOTHING;

-- ─── Admin user (login: 9000000777 / OTP 123456) ──────────────────────────────
INSERT INTO public.users (first_name, last_name, mobile, status, mobile_verified)
VALUES ('GreenRoot', 'Admin', '9000000777', 'ACTIVE', true)
ON CONFLICT (mobile) DO NOTHING;

INSERT INTO public.user_roles (user_id, role_id, assigned_at, assigned_by)
SELECT u.user_id, 1, CURRENT_TIMESTAMP, u.user_id
FROM public.users u
WHERE u.mobile = '9000000777'
  AND NOT EXISTS (
    SELECT 1 FROM public.user_roles ur WHERE ur.user_id = u.user_id AND ur.role_id = 1
  );

-- ─── Plant sizes (reference data) ─────────────────────────────────────────────
INSERT INTO public.plant_sizes (size_id, size_code, display_name, display_order, is_active)
VALUES
  (1, 'SEED',        'Seed',        1, true),
  (2, 'SAPLING',     'Sapling',     2, true),
  (3, 'SMALL',       'Small',       3, true),
  (4, 'MEDIUM',      'Medium',      4, true),
  (5, 'LARGE',       'Large',       5, true),
  (6, 'EXTRA_LARGE', 'Extra Large', 6, true)
ON CONFLICT (size_id) DO NOTHING;

-- ─── Plant categories (reference data) ────────────────────────────────────────
INSERT INTO public.plant_categories (category_name, is_active)
VALUES
  ('Fruit Trees',      true),
  ('Medicinal Plants', true),
  ('Shade Trees',      true),
  ('Herbs',            true),
  ('Ornamental',       true),
  ('Flowering Shrubs', true),
  ('Indoor Plants',    true)
ON CONFLICT (category_name) DO NOTHING;

-- ─── Sample plants ─────────────────────────────────────────────────────────────
INSERT INTO public.plants (scientific_name, common_name, plant_type, light_requirement, water_requirement, english_description, is_active)
VALUES
  ('Mangifera indica',       'Mango',      'TREE',  'FULL_SUN',      'HIGH',     'Popular tropical fruit tree grown across India.',        true),
  ('Azadirachta indica',     'Neem',       'TREE',  'FULL_SUN',      'LOW',      'Hardy medicinal tree known for antibacterial properties.', true),
  ('Hibiscus rosa-sinensis', 'Hibiscus',   'SHRUB', 'FULL_SUN',      'MODERATE', 'Ornamental flowering shrub with large colorful blooms.',  true),
  ('Cocos nucifera',         'Coconut',    'TREE',  'FULL_SUN',      'HIGH',     'Coastal palm tree producing coconuts.',                  true),
  ('Moringa oleifera',       'Drumstick',  'TREE',  'FULL_SUN',      'LOW',      'Fast-growing nutritious tree; all parts are edible.',     true)
ON CONFLICT (scientific_name) DO NOTHING;

-- ─── Map sample plants to categories ──────────────────────────────────────────
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
JOIN public.plants           p ON p.scientific_name  = m.sci
JOIN public.plant_categories c ON c.category_name    = m.cat
ON CONFLICT DO NOTHING;

-- ─── Nursery roles (reference data) ───────────────────────────────────────────
INSERT INTO public.nursery_roles (nursery_role_id, role_code, role_name, description)
VALUES
  (1, 'OWNER',      'Owner',      'Primary owner of nursery'),
  (2, 'PARTNER',    'Partner',    'Business partner'),
  (3, 'MANAGER',    'Manager',    'Nursery manager'),
  (4, 'OPERATOR',   'Operator',   'Day to day operations'),
  (5, 'ACCOUNTANT', 'Accountant', 'Accounts and finance'),
  (6, 'DISPATCHER', 'Dispatcher', 'Dispatch operations')
ON CONFLICT (nursery_role_id) DO NOTHING;

-- ─── 5 Nurseries ──────────────────────────────────────────────────────────────
INSERT INTO public.nurseries (nursery_name, mobile, email, description, status)
VALUES
  ('GreenLeaf Gardens', '9800000001', 'greenleaf@example.com',   'Premium indoor and outdoor plants',    'ACTIVE'),
  ('TreeTop Nursery',   '9800000002', 'treetop@example.com',     'Specialising in native trees',         'ACTIVE'),
  ('Bloom Valley',      '9800000003', 'bloomvalley@example.com', 'Flowering plants and seasonal blooms', 'ACTIVE'),
  ('Urban Roots',       '9800000004', 'urbanroots@example.com',  'Urban gardening solutions',            'ACTIVE'),
  ('EcoGreen Farms',    '9800000005', 'ecogreen@example.com',    'Organic and eco-friendly nursery',     'ACTIVE')
ON CONFLICT DO NOTHING;

-- ─── Nursery addresses ────────────────────────────────────────────────────────
INSERT INTO public.nursery_addresses (nursery_id, address_type, address_line1, city, state, country, postal_code, is_primary)
SELECT n.nursery_id, 'BUSINESS', a.line1, a.city, a.state, 'India', a.pin, true
FROM (VALUES
  ('9800000001', '12 Garden Lane',   'Mumbai',    'Maharashtra', '400001'),
  ('9800000002', '45 Forest Road',   'Pune',      'Maharashtra', '411001'),
  ('9800000003', '78 Valley Street', 'Nashik',    'Maharashtra', '422001'),
  ('9800000004', '23 Metro Plaza',   'Bangalore', 'Karnataka',   '560001'),
  ('9800000005', '90 Farm Road',     'Chennai',   'Tamil Nadu',  '600001')
) AS a(mobile, line1, city, state, pin)
JOIN public.nurseries n ON n.mobile = a.mobile
ON CONFLICT DO NOTHING;

-- ─── Dev test users ───────────────────────────────────────────────────────────
-- Easy-to-remember dev login numbers (OTP 123456 for all)
INSERT INTO public.users (first_name, last_name, mobile, status, mobile_verified)
VALUES
  ('Arjun',  'Buyer',   '9111111111', 'ACTIVE', true),
  ('Priya',  'Owner',   '9222222222', 'ACTIVE', true),
  ('Rahul',  'Driver',  '9333333333', 'ACTIVE', true),
  ('Suresh', 'Manager', '9555555555', 'ACTIVE', true)
ON CONFLICT (mobile) DO NOTHING;

INSERT INTO public.user_roles (user_id, role_id, assigned_at)
SELECT u.user_id, r.role_id, CURRENT_TIMESTAMP
FROM (VALUES
  ('9111111111', 'BUYER'),
  ('9222222222', 'NURSERY_OWNER'),
  ('9333333333', 'DRIVER'),
  ('9555555555', 'MANAGER')
) AS m(mobile, role_code)
JOIN public.users u ON u.mobile = m.mobile
JOIN public.roles r ON r.role_code = m.role_code
ON CONFLICT DO NOTHING;

-- ─── Nursery for dev owner (9222222222) ───────────────────────────────────────
INSERT INTO public.nurseries (nursery_name, mobile, email, description, status)
VALUES ('Dev Nursery', '9222222222', 'dev@greenroot.example', 'Default dev nursery', 'ACTIVE')
ON CONFLICT DO NOTHING;

INSERT INTO public.nursery_users (nursery_id, user_id, nursery_role_id)
SELECT n.nursery_id, u.user_id, nr.nursery_role_id
FROM public.nurseries n
JOIN public.users u ON u.mobile = '9222222222'
JOIN public.nursery_roles nr ON nr.role_code = 'OWNER'
WHERE n.mobile = '9222222222'
ON CONFLICT DO NOTHING;

-- Link dev manager to dev nursery
INSERT INTO public.nursery_users (nursery_id, user_id, nursery_role_id)
SELECT n.nursery_id, u.user_id, nr.nursery_role_id
FROM public.nurseries n
JOIN public.users u ON u.mobile = '9555555555'
JOIN public.nursery_roles nr ON nr.role_code = 'MANAGER'
WHERE n.mobile = '9222222222'
ON CONFLICT DO NOTHING;

-- ─── 5 sample nursery staff users ─────────────────────────────────────────────
INSERT INTO public.users (first_name, last_name, mobile, email, status)
VALUES
  ('Arjun',   'Sharma', '9876500001', 'arjun.sharma@greenroot.example',   'ACTIVE'),
  ('Priya',   'Patel',  '9876500002', 'priya.patel@greenroot.example',    'ACTIVE'),
  ('Rahul',   'Mehta',  '9876500003', 'rahul.mehta@greenroot.example',    'ACTIVE'),
  ('Sneha',   'Reddy',  '9876500004', 'sneha.reddy@greenroot.example',    'ACTIVE'),
  ('Karthik', 'Nair',   '9876500005', 'karthik.nair@greenroot.example',   'ACTIVE')
ON CONFLICT (mobile) DO NOTHING;

-- Assign MANAGER platform role to sample staff
INSERT INTO public.user_roles (user_id, role_id, assigned_at)
SELECT u.user_id, r.role_id, CURRENT_TIMESTAMP
FROM public.users u
JOIN public.roles r ON r.role_code = 'MANAGER'
WHERE u.mobile IN ('9876500001','9876500002','9876500003','9876500004','9876500005')
ON CONFLICT DO NOTHING;

-- ─── Link sample staff to nurseries (nursery_role_id 3 = MANAGER) ─────────────
INSERT INTO public.nursery_users (nursery_id, user_id, nursery_role_id)
SELECT n.nursery_id, u.user_id, 3
FROM (VALUES
  ('9800000001', '9876500001'),
  ('9800000002', '9876500002'),
  ('9800000003', '9876500003'),
  ('9800000004', '9876500004'),
  ('9800000005', '9876500005')
) AS m(nursery_mobile, user_mobile)
JOIN public.nurseries n ON n.mobile = m.nursery_mobile
JOIN public.users     u ON u.mobile = m.user_mobile
ON CONFLICT (nursery_id, user_id, nursery_role_id) DO NOTHING;

-- ─── 5 Vehicles ───────────────────────────────────────────────────────────────
INSERT INTO public.vehicles (vehicle_number, vehicle_type, capacity_kg, owner_name, mobile, status)
VALUES
  ('MH01AB1234', 'TRUCK',  2000.00, 'GreenLeaf Transport',  '9700000001', 'ACTIVE'),
  ('MH02CD5678', 'VAN',     800.00, 'TreeTop Logistics',    '9700000002', 'ACTIVE'),
  ('MH03EF9012', 'PICKUP',  600.00, 'Bloom Valley Carrier', '9700000003', 'ACTIVE'),
  ('KA01GH3456', 'TRUCK',  1500.00, 'Urban Roots Fleet',    '9700000004', 'ACTIVE'),
  ('TN02IJ7890', 'VAN',     900.00, 'EcoGreen Logistics',   '9700000005', 'ACTIVE')
ON CONFLICT (vehicle_number) DO NOTHING;

-- ─── Sync public code sequences ───────────────────────────────────────────────
INSERT INTO public.public_code_sequences (code_key, date_key, last_value)
SELECT 'users', '', count(*) FROM public.users
ON CONFLICT (code_key, date_key) DO UPDATE SET last_value = EXCLUDED.last_value, updated_at = CURRENT_TIMESTAMP;

INSERT INTO public.public_code_sequences (code_key, date_key, last_value)
SELECT 'nurseries', '', count(*) FROM public.nurseries
ON CONFLICT (code_key, date_key) DO UPDATE SET last_value = EXCLUDED.last_value, updated_at = CURRENT_TIMESTAMP;

INSERT INTO public.public_code_sequences (code_key, date_key, last_value)
SELECT 'vehicles', '', count(*) FROM public.vehicles
ON CONFLICT (code_key, date_key) DO UPDATE SET last_value = EXCLUDED.last_value, updated_at = CURRENT_TIMESTAMP;

INSERT INTO public.public_code_sequences (code_key, date_key, last_value)
SELECT 'plants', '', count(*) FROM public.plants
ON CONFLICT (code_key, date_key) DO UPDATE SET last_value = EXCLUDED.last_value, updated_at = CURRENT_TIMESTAMP;

-- ─── Sample quotations ─────────────────────────────────────────────────────────
-- One demo quotation by the admin user linked to nursery 1.
-- Idempotent: only inserts if no quotations exist yet.

DO $$
DECLARE
  v_admin_id   BIGINT;
  v_admin_name VARCHAR;
  v_nur_id     BIGINT;
  v_nur_name   VARCHAR;
  v_nur_phone  VARCHAR;
  v_plant1_id  BIGINT;
  v_plant2_id  BIGINT;
  v_p1_sci     VARCHAR; v_p1_com VARCHAR;
  v_p2_sci     VARCHAR; v_p2_com VARCHAR;
  v_qid        BIGINT;
  v_code       VARCHAR;
BEGIN
  IF (SELECT count(*) FROM public.quotations) > 0 THEN RETURN; END IF;

  SELECT user_id, first_name INTO v_admin_id, v_admin_name
    FROM public.users WHERE mobile = '9000000777' LIMIT 1;
  IF v_admin_id IS NULL THEN RETURN; END IF;

  SELECT nursery_id, nursery_name, COALESCE(mobile,'')
    INTO v_nur_id, v_nur_name, v_nur_phone
    FROM public.nurseries WHERE nursery_id = 1 LIMIT 1;

  SELECT plant_id, scientific_name, COALESCE(common_name,'')
    INTO v_plant1_id, v_p1_sci, v_p1_com
    FROM public.plants WHERE scientific_name = 'Mangifera indica' LIMIT 1;

  SELECT plant_id, scientific_name, COALESCE(common_name,'')
    INTO v_plant2_id, v_p2_sci, v_p2_com
    FROM public.plants WHERE scientific_name = 'Azadirachta indica' LIMIT 1;

  v_code := 'QUO-' || to_char(CURRENT_DATE,'YYYYMMDD') || '-0001';

  INSERT INTO public.quotations (
    quotation_code, created_by_user_id, created_by_name,
    nursery_id, nursery_name, nursery_phone,
    recipient_name, recipient_mobile, notes, total_amount, status
  ) VALUES (
    v_code, v_admin_id, v_admin_name,
    v_nur_id, v_nur_name, NULLIF(v_nur_phone,''),
    'Ravi Kumar', '9800000001', 'Sample quotation for mango and neem plants', 0, 'DRAFT'
  ) RETURNING quotation_id INTO v_qid;

  IF v_plant1_id IS NOT NULL THEN
    INSERT INTO public.quotation_items
      (quotation_id, plant_id, scientific_name, common_name, description, quantity, unit_price, total_price)
    VALUES (v_qid, v_plant1_id, v_p1_sci, NULLIF(v_p1_com,''), 'Premium grade', 10, 250.00, 2500.00);
  END IF;

  IF v_plant2_id IS NOT NULL THEN
    INSERT INTO public.quotation_items
      (quotation_id, plant_id, scientific_name, common_name, description, quantity, unit_price, total_price)
    VALUES (v_qid, v_plant2_id, v_p2_sci, NULLIF(v_p2_com,''), 'Standard grade', 5, 180.00, 900.00);
  END IF;

  UPDATE public.quotations
    SET total_amount = (SELECT COALESCE(SUM(total_price),0) FROM public.quotation_items WHERE quotation_id = v_qid)
  WHERE quotation_id = v_qid;
END;
$$;

-- Sync quotations public code sequence
INSERT INTO public.public_code_sequences (code_key, date_key, last_value)
SELECT 'quotations', to_char(CURRENT_DATE,'YYYYMMDD'), count(*)
FROM public.quotations
ON CONFLICT (code_key, date_key) DO UPDATE SET last_value = EXCLUDED.last_value, updated_at = CURRENT_TIMESTAMP;
