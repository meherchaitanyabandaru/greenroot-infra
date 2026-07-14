-- =============================================================================
-- GreenRoot dev data seed
-- Run AFTER: seed-master.sql, seed-dev-admin.sql
-- =============================================================================
-- Adds: 9 users, 2 nurseries, 2 vehicles, 2 drivers, 12 inventory items,
--       6 quotations, 5 orders, 2 dispatches, 8 market ads
--
-- Dev login: mobile + OTP 123456 (same for all users)
--
-- Users seeded:
--   9100000000  Priya Owner       NURSERY_OWNER  (GreenLeaf Nursery)
--   9200000000  Gumastha Manager  MANAGER        (GreenLeaf Nursery)
--   9300000000  Ravi Buyer        BUYER
--   9400000000  Raju Driver       DRIVER
--   9500000000  Deepa Owner       NURSERY_OWNER  (Bloom Gardens)
--   9600000000  Suresh Manager    MANAGER        (Bloom Gardens)
--   9700000000  Meena Buyer       BUYER
--   9800000000  Kiran Driver      DRIVER
--   9900000000  Arjun Buyer       BUYER
-- =============================================================================

\set ON_ERROR_STOP on

-- schema.sql resets search_path to ''; restore it so PostGIS functions
-- and next_public_code() resolve without explicit schema qualification.
SET search_path TO public;

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- USERS  (IDs 2–10)
-- user_code uses DEFAULT next_public_code(), which auto-increments
-- the public_code_sequences entry for 'users' starting from last_value=1
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO public.users
  (user_id, first_name, last_name, mobile, email, mobile_verified, email_verified, status)
VALUES
  (2,  'Priya',    'Owner',   '9100000000', 'priya@greenroot.local',    true, true, 'ACTIVE'),
  (3,  'Gumastha', 'Manager', '9200000000', 'gumastha@greenroot.local', true, true, 'ACTIVE'),
  (4,  'Ravi',     'Buyer',   '9300000000', 'ravi@greenroot.local',     true, true, 'ACTIVE'),
  (5,  'Raju',     'Driver',  '9400000000', 'raju@greenroot.local',     true, true, 'ACTIVE'),
  (6,  'Deepa',    'Owner',   '9500000000', 'deepa@greenroot.local',    true, true, 'ACTIVE'),
  (7,  'Suresh',   'Manager', '9600000000', 'suresh@greenroot.local',   true, true, 'ACTIVE'),
  (8,  'Meena',    'Buyer',   '9700000000', 'meena@greenroot.local',    true, true, 'ACTIVE'),
  (9,  'Kiran',    'Driver',  '9800000000', 'kiran@greenroot.local',    true, true, 'ACTIVE'),
  (10, 'Arjun',    'Buyer',   '9900000000', 'arjun@greenroot.local',    true, true, 'ACTIVE');

SELECT setval('public.users_user_id_seq', 10, true);

-- User platform roles
INSERT INTO public.user_roles (user_id, role_id)
SELECT v.uid, r.role_id
FROM (VALUES
  (2,  'NURSERY_OWNER'),
  (3,  'MANAGER'),
  (4,  'BUYER'),
  (5,  'DRIVER'),
  (6,  'NURSERY_OWNER'),
  (7,  'MANAGER'),
  (8,  'BUYER'),
  (9,  'DRIVER'),
  (10, 'BUYER')
) AS v(uid, rc)
JOIN public.roles r ON r.role_code = v.rc;

-- ─────────────────────────────────────────────────────────────────────────────
-- NURSERIES (IDs 1–2)
-- nursery_code uses DEFAULT next_public_code()
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO public.nurseries
  (nursery_id, nursery_name, owner_user_id, status)
VALUES
  (1, 'GreenLeaf Nursery', 2, 'ACTIVE'),
  (2, 'Bloom Gardens',     6, 'ACTIVE');

SELECT setval('public.nurseries_nursery_id_seq', 2, true);

-- Nursery addresses with PostGIS geography
INSERT INTO public.nursery_addresses
  (nursery_id, address_type, address_line1, city, state, country, postal_code,
   latitude, longitude, location, is_primary)
VALUES
  (1, 'PRIMARY',
   '42, Nursery Road, Jayanagar', 'Bengaluru', 'Karnataka', 'India', '560041',
   12.9324, 77.5834,
   ST_SetSRID(ST_MakePoint(77.5834, 12.9324), 4326)::public.geography,
   true),
  (2, 'PRIMARY',
   '15, Garden Lane, Adyar', 'Chennai', 'Tamil Nadu', 'India', '600020',
   13.0067, 80.2569,
   ST_SetSRID(ST_MakePoint(80.2569, 13.0067), 4326)::public.geography,
   true);

-- ─────────────────────────────────────────────────────────────────────────────
-- VEHICLES (IDs 1–2)
-- vehicle_code uses DEFAULT next_public_code()
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO public.vehicles
  (vehicle_id, vehicle_number, vehicle_type, capacity_kg, owner_name, mobile, status)
VALUES
  (1, 'KA-01-AB-1234', 'Truck',      3000, 'Raju Driver',  '9400000000', 'ACTIVE'),
  (2, 'TN-22-CD-5678', 'Mini Truck', 1500, 'Kiran Driver', '9800000000', 'ACTIVE');

SELECT setval('public.vehicles_vehicle_id_seq', 2, true);

-- ─────────────────────────────────────────────────────────────────────────────
-- DRIVERS (IDs 1–2)
-- driver_code uses DEFAULT next_public_code()
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO public.drivers
  (driver_id, user_id, license_number, license_expiry_date,
   vehicle_number, vehicle_type, emergency_contact,
   profile_status, approval_status, approved_by_user_id, approved_at, status)
VALUES
  (1, 5, 'KA-2019-1234567', '2028-06-30',
   'KA-01-AB-1234', 'Truck', '9400000001',
   'COMPLETE', 'APPROVED', 1, NOW() - INTERVAL '30 days', 'ACTIVE'),
  (2, 9, 'TN-2020-9876543', '2027-12-31',
   'TN-22-CD-5678', 'Mini Truck', '9800000001',
   'COMPLETE', 'APPROVED', 1, NOW() - INTERVAL '15 days', 'ACTIVE');

SELECT setval('public.drivers_driver_id_seq', 2, true);

-- ─────────────────────────────────────────────────────────────────────────────
-- NURSERY USERS  (managers linked to nurseries)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO public.nursery_users
  (nursery_id, user_id, role, status, nursery_role_id, is_active)
VALUES
  (1, 3, 'MANAGER', 'ACTIVE', 3, true),   -- Gumastha manages GreenLeaf
  (2, 7, 'MANAGER', 'ACTIVE', 3, true);   -- Suresh manages Bloom Gardens

-- ─────────────────────────────────────────────────────────────────────────────
-- NURSERY INVENTORY
-- plant_ids (from seed-master): 1=Mango 2=Neem 3=Hibiscus 5=Drumstick
--   6=Tulsi 7=Aloe Vera 8=Guava 9=Rose 11=Weeping Fig 12=Money Plant 13=Snake Plant
-- size_ids: 1=Seed 2=Sapling 3=Small 4=Medium 5=Large
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO public.nursery_inventory
  (nursery_id, plant_id, size_id, available_quantity, inventory_status, last_updated_by)
VALUES
  -- GreenLeaf Nursery (nursery 1)
  (1, 1,  2,  50, 'AVAILABLE', 2),   -- Mango Sapling
  (1, 1,  3,  30, 'AVAILABLE', 2),   -- Mango Small
  (1, 2,  3, 100, 'AVAILABLE', 2),   -- Neem Small
  (1, 3,  3, 200, 'AVAILABLE', 2),   -- Hibiscus Small
  (1, 5,  2,  75, 'AVAILABLE', 2),   -- Drumstick Sapling
  (1, 6,  1, 500, 'AVAILABLE', 2),   -- Tulsi Seed
  (1, 7,  3, 150, 'AVAILABLE', 2),   -- Aloe Vera Small
  (1, 8,  2,  40, 'AVAILABLE', 2),   -- Guava Sapling
  -- Bloom Gardens (nursery 2)
  (2, 12, 3, 300, 'AVAILABLE', 6),   -- Money Plant Small
  (2, 13, 3, 100, 'AVAILABLE', 6),   -- Snake Plant Small
  (2, 11, 4,  50, 'AVAILABLE', 6),   -- Weeping Fig Medium
  (2, 9,  3, 200, 'AVAILABLE', 6);   -- Rose Small

-- ─────────────────────────────────────────────────────────────────────────────
-- QUOTATIONS (IDs 1–6)
-- quotation_code has no DEFAULT, so we call next_public_code() inline
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO public.quotations
  (quotation_id, quotation_code, created_by_user_id, created_by_name,
   nursery_id, nursery_name, customer_user_id, assigned_manager_user_id,
   recipient_name, recipient_mobile, total_amount, status, quotation_type,
   sent_at, customer_responded_at, valid_until)
VALUES
  -- ── GreenLeaf Nursery quotations ──
  (1, next_public_code('quotations','QUO',4,true), 3, 'Gumastha Manager',
   1, 'GreenLeaf Nursery', 4, 3,
   'Ravi Buyer', '9300000000', 5625.00, 'CUSTOMER_DRAFT', 'CUSTOMER',
   NULL, NULL, NOW() + INTERVAL '30 days'),

  (2, next_public_code('quotations','QUO',4,true), 3, 'Gumastha Manager',
   1, 'GreenLeaf Nursery', 4, 3,
   'Ravi Buyer', '9300000000', 9000.00, 'CUSTOMER_SENT', 'CUSTOMER',
   NOW() - INTERVAL '2 days', NULL, NOW() + INTERVAL '28 days'),

  (3, next_public_code('quotations','QUO',4,true), 3, 'Gumastha Manager',
   1, 'GreenLeaf Nursery', 8, 3,
   'Meena Buyer', '9700000000', 3200.00, 'CUSTOMER_ACCEPTED', 'CUSTOMER',
   NOW() - INTERVAL '5 days', NOW() - INTERVAL '3 days', NOW() + INTERVAL '25 days'),

  -- Quotation 4 inserted without converted_order_id (order doesn't exist yet).
  -- It is updated below after order 4 is inserted.
  (4, next_public_code('quotations','QUO',4,true), 3, 'Gumastha Manager',
   1, 'GreenLeaf Nursery', 10, 3,
   'Arjun Buyer', '9900000000', 12000.00, 'CONVERTED', 'CUSTOMER',
   NOW() - INTERVAL '10 days', NOW() - INTERVAL '8 days', NOW() + INTERVAL '20 days'),

  -- ── Bloom Gardens quotations ──
  (5, next_public_code('quotations','QUO',4,true), 7, 'Suresh Manager',
   2, 'Bloom Gardens', 4, 7,
   'Ravi Buyer', '9300000000', 4500.00, 'CUSTOMER_DRAFT', 'CUSTOMER',
   NULL, NULL, NOW() + INTERVAL '30 days'),

  (6, next_public_code('quotations','QUO',4,true), 7, 'Suresh Manager',
   2, 'Bloom Gardens', 8, 7,
   'Meena Buyer', '9700000000', 7200.00, 'CUSTOMER_SENT', 'CUSTOMER',
   NOW() - INTERVAL '1 day', NULL, NOW() + INTERVAL '29 days');

SELECT setval('public.quotations_quotation_id_seq', 6, true);

-- Quotation line items
INSERT INTO public.quotation_items
  (quotation_id, plant_id, scientific_name, common_name, quantity, unit_price, total_price)
VALUES
  -- Q1: 25 Mango saplings + 75 Neem small
  (1, 1, 'Mangifera indica',        'Mango',      25,  150.00,  3750.00),
  (1, 2, 'Azadirachta indica',      'Neem',       75,   25.00,  1875.00),
  -- Q2: 10 Mango small + 110 Tulsi seed
  (2, 1, 'Mangifera indica',        'Mango',      10,  350.00,  3500.00),
  (2, 6, 'Ocimum tenuiflorum',      'Tulsi',     110,   50.00,  5500.00),
  -- Q3: 40 Aloe Vera small
  (3, 7, 'Aloe vera',               'Aloe Vera',  40,   80.00,  3200.00),
  -- Q4: 30 Guava sapling + 20 Drumstick sapling
  (4, 8, 'Psidium guajava',         'Guava',      30,  200.00,  6000.00),
  (4, 5, 'Moringa oleifera',        'Drumstick',  20,  300.00,  6000.00),
  -- Q5: 50 Money Plant small
  (5, 12,'Epipremnum aureum',       'Money Plant',50,   90.00,  4500.00),
  -- Q6: 30 Snake Plant + 18 Weeping Fig
  (6, 13,'Sansevieria trifasciata', 'Snake Plant',30,  120.00,  3600.00),
  (6, 11,'Ficus benjamina',         'Weeping Fig',18,  200.00,  3600.00);

-- ─────────────────────────────────────────────────────────────────────────────
-- ORDERS (IDs 1–5)
-- order_code uses DEFAULT next_public_code()
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO public.orders
  (order_id, order_number, nursery_id, seller_nursery_id,
   buyer_user_id, customer_user_id, customer_name, customer_mobile,
   assigned_manager_user_id, created_by_user_id,
   order_status, total_amount, quotation_id)
VALUES
  -- GreenLeaf Nursery orders
  (1, 'GRN-ORD-001', 1, 1,  4,  4,  'Ravi Buyer',  '9300000000', 3, 4,  'PENDING',   5625.00, NULL),
  (2, 'GRN-ORD-002', 1, 1,  4,  4,  'Ravi Buyer',  '9300000000', 3, 3,  'CONFIRMED', 9000.00, NULL),
  (3, 'GRN-ORD-003', 1, 1,  8,  8,  'Meena Buyer', '9700000000', 3, 3,  'LOADING',   3200.00, NULL),
  -- Order 4 was converted from quotation 4
  (4, 'GRN-ORD-004', 1, 1,  10, 10, 'Arjun Buyer', '9900000000', 3, 3,  'COMPLETED', 12000.00, 4),
  -- Bloom Gardens order
  (5, 'BLM-ORD-001', 2, 2,  8,  8,  'Meena Buyer', '9700000000', 7, 7,  'PENDING',   4500.00, NULL);

SELECT setval('public.orders_order_id_seq', 5, true);

-- Now link quotation 4 → order 4
UPDATE public.quotations
SET converted_order_id  = 4,
    converted_by_user_id = 3,
    converted_at        = NOW() - INTERVAL '7 days'
WHERE quotation_id = 4;

-- Order line items
INSERT INTO public.order_items
  (order_id, plant_id, plant_name_snapshot, size_id, size, quantity, unit_price, total_price)
VALUES
  -- Order 1: Mango saplings + Neem small
  (1, 1, 'Mango',       2, 'Sapling', 25,  150.00,  3750.00),
  (1, 2, 'Neem',        3, 'Small',   75,   25.00,  1875.00),
  -- Order 2: Mango small + Tulsi seed
  (2, 1, 'Mango',       3, 'Small',   10,  350.00,  3500.00),
  (2, 6, 'Tulsi',       1, 'Seed',   110,   50.00,  5500.00),
  -- Order 3: Aloe Vera small
  (3, 7, 'Aloe Vera',   3, 'Small',   40,   80.00,  3200.00),
  -- Order 4: Guava sapling + Drumstick sapling
  (4, 8, 'Guava',       2, 'Sapling', 30,  200.00,  6000.00),
  (4, 5, 'Drumstick',   2, 'Sapling', 20,  300.00,  6000.00),
  -- Order 5: Money Plant small
  (5, 12,'Money Plant', 3, 'Small',   50,   90.00,  4500.00);

-- ─────────────────────────────────────────────────────────────────────────────
-- DISPATCHES (IDs 1–2)
-- dispatch_code uses DEFAULT next_public_code()
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO public.dispatches
  (dispatch_id, order_id, nursery_id, dispatch_status,
   dispatched_by, assigned_manager_user_id,
   vehicle_id, driver_id, driver_user_id,
   owner_user_id_snapshot, customer_user_id,
   customer_name_snapshot, customer_mobile_snapshot,
   destination_address, dispatch_date, delivery_date,
   trip_started_at, completed_at, notes)
VALUES
  -- Dispatch 1: order 2 (CONFIRMED), driver assigned, pending acceptance
  (1, 2, 1, 'PENDING',
   3, 3,
   1, 1, 5,
   2, 4,
   'Ravi Buyer', '9300000000',
   '15, Gandhi Nagar, Koramangala, Bengaluru, Karnataka 560034',
   NOW(), NOW() + INTERVAL '2 days',
   NULL, NULL,
   'Handle with care — grafted saplings'),

  -- Dispatch 2: order 4 (COMPLETED), fully delivered
  (2, 4, 1, 'DELIVERED',
   3, 3,
   2, 2, 9,
   2, 10,
   'Arjun Buyer', '9900000000',
   '22, MG Road, Chennai, Tamil Nadu 600034',
   NOW() - INTERVAL '6 days', NOW() - INTERVAL '3 days',
   NOW() - INTERVAL '5 days', NOW() - INTERVAL '3 days',
   'Delivered successfully');

SELECT setval('public.dispatches_dispatch_id_seq', 2, true);

-- ─────────────────────────────────────────────────────────────────────────────
-- MARKET ADS (IDs 1–8)
-- ad_code uses DEFAULT next_public_code() via market_listings_listing_id_seq
-- ─────────────────────────────────────────────────────────────────────────────

-- next_public_code() auto-inserts the sequence row on first call,
-- but we ensure it exists cleanly here.
INSERT INTO public.public_code_sequences (code_key, date_key, last_value)
VALUES ('market_listings', '', 0)
ON CONFLICT (code_key, date_key) DO NOTHING;

INSERT INTO public.market_ads
  (ad_id, nursery_id, created_by_user_id, plant_id, plant_name, category_name,
   title, description,
   quantity, size_description, price_per_unit, price_unit,
   pickup_address, pickup_landmark,
   pickup_latitude, pickup_longitude, pickup_location,
   status, published_at, expires_at)
VALUES
  -- ── GreenLeaf Nursery ads ─────────────────────────────────────────────────
  (1, 1, 2, 1, 'Mango', 'Fruit Trees',
   'Fresh Mango Saplings – Ready to Plant',
   'Healthy 1-year-old grafted mango saplings. Alphonso and Kesar varieties available. Minimum order 5 plants.',
   100, 'Sapling (~1 ft)', 150.00, 'per plant',
   '42, Nursery Road, Jayanagar, Bengaluru', 'Near Jayanagar 4th Block Metro',
   12.9324, 77.5834, ST_SetSRID(ST_MakePoint(77.5834, 12.9324), 4326)::public.geography,
   'PUBLISHED', NOW() - INTERVAL '7 days', NOW() + INTERVAL '23 days'),

  (2, 1, 2, 2, 'Neem', 'Medicinal Plants',
   'Neem Plants – Medicinal & Shade',
   'Fast-growing neem trees perfect for farms, roads, and organic gardens. Bulk discounts available.',
   200, 'Small (~2 ft)', 25.00, 'per plant',
   '42, Nursery Road, Jayanagar, Bengaluru', 'Near Jayanagar 4th Block Metro',
   12.9324, 77.5834, ST_SetSRID(ST_MakePoint(77.5834, 12.9324), 4326)::public.geography,
   'PUBLISHED', NOW() - INTERVAL '5 days', NOW() + INTERVAL '25 days'),

  (3, 1, 3, 7, 'Aloe Vera', 'Medicinal Plants',
   'Aloe Vera – Low Maintenance Succulent',
   'Thick-leaf aloe vera in terracotta pots. Ideal for home gardens and Ayurvedic use.',
   150, 'Small (6-inch pot)', 80.00, 'per plant',
   '42, Nursery Road, Jayanagar, Bengaluru', 'Near Jayanagar 4th Block Metro',
   12.9324, 77.5834, ST_SetSRID(ST_MakePoint(77.5834, 12.9324), 4326)::public.geography,
   'PUBLISHED', NOW() - INTERVAL '3 days', NOW() + INTERVAL '27 days'),

  (4, 1, 3, 3, 'Hibiscus', 'Flowering Shrubs',
   'Vibrant Hibiscus Shrubs – Multiple Colors',
   'Double-petal hibiscus available in red, yellow, and pink. Great for pots and garden borders.',
   200, 'Small (~1 ft)', 50.00, 'per plant',
   '42, Nursery Road, Jayanagar, Bengaluru', 'Near Jayanagar 4th Block Metro',
   12.9324, 77.5834, ST_SetSRID(ST_MakePoint(77.5834, 12.9324), 4326)::public.geography,
   'PUBLISHED', NOW() - INTERVAL '2 days', NOW() + INTERVAL '28 days'),

  -- ── Bloom Gardens ads ─────────────────────────────────────────────────────
  (5, 2, 6, 12, 'Money Plant', 'Indoor Plants',
   'Money Plant – Lucky Indoor Climber',
   'Easy-to-grow money plant cuttings in small pots. Perfect for home, office, and gifting.',
   300, 'Small (4-inch pot)', 90.00, 'per plant',
   '15, Garden Lane, Adyar, Chennai', 'Near Adyar Flyover',
   13.0067, 80.2569, ST_SetSRID(ST_MakePoint(80.2569, 13.0067), 4326)::public.geography,
   'PUBLISHED', NOW() - INTERVAL '6 days', NOW() + INTERVAL '24 days'),

  (6, 2, 6, 13, 'Snake Plant', 'Indoor Plants',
   'Snake Plant – Air Purifying Indoor Plant',
   'Sansevieria trifasciata – extremely hardy, thrives in low light, minimal watering needed.',
   100, 'Small (6-inch pot)', 120.00, 'per plant',
   '15, Garden Lane, Adyar, Chennai', 'Near Adyar Flyover',
   13.0067, 80.2569, ST_SetSRID(ST_MakePoint(80.2569, 13.0067), 4326)::public.geography,
   'PUBLISHED', NOW() - INTERVAL '4 days', NOW() + INTERVAL '26 days'),

  (7, 2, 6, 9, 'Rose', 'Flowering Shrubs',
   'Classic Rose Bushes – All Colors',
   'Grafted rose plants in red, white, pink, and yellow. Vigorous growth, fragrant blooms.',
   200, 'Small (~1 ft)', 150.00, 'per plant',
   '15, Garden Lane, Adyar, Chennai', 'Near Adyar Flyover',
   13.0067, 80.2569, ST_SetSRID(ST_MakePoint(80.2569, 13.0067), 4326)::public.geography,
   'PUBLISHED', NOW() - INTERVAL '2 days', NOW() + INTERVAL '28 days'),

  (8, 2, 7, 11, 'Weeping Fig', 'Indoor Plants',
   'Weeping Fig Bonsai – Premium Indoor Tree',
   '3-year-old Ficus benjamina trained as bonsai. Limited stock – collectors only.',
   15, 'Medium (~2 ft)', 800.00, 'per plant',
   '15, Garden Lane, Adyar, Chennai', 'Near Adyar Flyover',
   13.0067, 80.2569, ST_SetSRID(ST_MakePoint(80.2569, 13.0067), 4326)::public.geography,
   'DRAFT', NULL, NULL);

SELECT setval('public.market_listings_listing_id_seq', 8, true);

COMMIT;

-- Verification
SELECT
  (SELECT count(*) FROM public.users)             AS total_users,
  (SELECT count(*) FROM public.nurseries)         AS nurseries,
  (SELECT count(*) FROM public.drivers)           AS drivers,
  (SELECT count(*) FROM public.vehicles)          AS vehicles,
  (SELECT count(*) FROM public.nursery_users)     AS nursery_users,
  (SELECT count(*) FROM public.nursery_inventory) AS inventory_items,
  (SELECT count(*) FROM public.quotations)        AS quotations,
  (SELECT count(*) FROM public.orders)            AS orders,
  (SELECT count(*) FROM public.dispatches)        AS dispatches,
  (SELECT count(*) FROM public.market_ads)        AS market_ads;
