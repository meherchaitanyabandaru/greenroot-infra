-- GreenRoot sample seed data
-- Run after all migrations. Safe to re-run (ON CONFLICT DO NOTHING / DO UPDATE).
-- Inserts: platform roles, admin user, nurseries, manager users, vehicles, plant sizes, plant categories, sample plants.

-- ─── Platform roles (ADMIN / BUYER / NURSERY_OWNER / DRIVER) ──────────────────
INSERT INTO public.roles (role_id, role_code, role_name, description, is_active)
VALUES
  (1, 'ADMIN',         'Admin',         'Platform administrator', true),
  (2, 'BUYER',         'Buyer',         'Plant buyer',            true),
  (3, 'NURSERY_OWNER', 'Nursery Owner', 'Nursery owner',          true),
  (4, 'DRIVER',        'Driver',        'Delivery driver',        true)
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

-- ─── 5 Manager users ──────────────────────────────────────────────────────────
INSERT INTO public.users (first_name, last_name, mobile, email, status)
VALUES
  ('Arjun',   'Sharma', '9876500001', 'arjun.sharma@greenroot.example',   'ACTIVE'),
  ('Priya',   'Patel',  '9876500002', 'priya.patel@greenroot.example',    'ACTIVE'),
  ('Rahul',   'Mehta',  '9876500003', 'rahul.mehta@greenroot.example',    'ACTIVE'),
  ('Sneha',   'Reddy',  '9876500004', 'sneha.reddy@greenroot.example',    'ACTIVE'),
  ('Karthik', 'Nair',   '9876500005', 'karthik.nair@greenroot.example',   'ACTIVE')
ON CONFLICT (mobile) DO NOTHING;

-- ─── Link managers to nurseries (nursery_role_id 3 = MANAGER) ─────────────────
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
