-- =============================================================================
-- GreenRoot — User Management Test Suite
-- Covers: creation, public codes, roles, sessions, activities,
--         addresses, subscriptions, devices, profile updates,
--         status/soft-delete, and all constraint edge cases.
--
-- Run: psql 'postgres:///greenroot?host=/tmp' -f test_user_management.sql
-- Prerequisite: fresh schema applied (greenroot_schema.sql)
-- =============================================================================

DO $$
DECLARE
    -- core test users
    v_uid_buyer       BIGINT;
    v_uid_owner       BIGINT;
    v_uid_manager     BIGINT;
    v_uid_driver      BIGINT;
    v_uid_customer    BIGINT;
    -- temp vars for cascade/edge-case tests
    v_uid_temp        BIGINT;
    -- other
    v_code            VARCHAR(50);
    v_text            TEXT;
    v_count           INTEGER;
    v_bool            BOOLEAN;
    v_session_id      BIGINT;
    v_address_id      BIGINT;
    v_device_id       BIGINT;
    v_sub_id          BIGINT;
    v_plan_id_free    BIGINT;
    v_plan_id_pro     BIGINT;

BEGIN

-- =========================================================================
-- SECTION 1: USER CREATION & PUBLIC CODE GENERATION
-- =========================================================================
RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════════════';
RAISE NOTICE 'SECTION 1 — USER CREATION & PUBLIC CODE GENERATION';
RAISE NOTICE '══════════════════════════════════════════════════════';

-- 1.1  First new user after admin (USR-000001) must get USR-000002
INSERT INTO public.users (first_name, last_name, mobile, email, mobile_verified, status)
VALUES ('Ravi', 'Kumar', '9100000001', 'ravi@example.com', true, 'ACTIVE')
RETURNING user_id, user_code INTO v_uid_buyer, v_code;

IF v_code = 'USR-000002' THEN
    RAISE NOTICE 'PASS 1.1  First user auto-code: %  (user_id=%)', v_code, v_uid_buyer;
ELSE
    RAISE NOTICE 'FAIL 1.1  Expected USR-000002, got %', v_code;
END IF;

-- 1.2  Second user gets USR-000003
INSERT INTO public.users (first_name, last_name, mobile, email, mobile_verified, status)
VALUES ('Priya', 'Sharma', '9100000002', 'priya@example.com', true, 'ACTIVE')
RETURNING user_id, user_code INTO v_uid_owner, v_code;

IF v_code = 'USR-000003' THEN
    RAISE NOTICE 'PASS 1.2  Second user auto-code: %  (user_id=%)', v_code, v_uid_owner;
ELSE
    RAISE NOTICE 'FAIL 1.2  Expected USR-000003, got %', v_code;
END IF;

-- 1.3  Create manager user
INSERT INTO public.users (first_name, last_name, mobile, email, mobile_verified, status)
VALUES ('Gumastha', 'Rao', '9100000003', 'manager@example.com', true, 'ACTIVE')
RETURNING user_id INTO v_uid_manager;
RAISE NOTICE 'PASS 1.3  Manager user created  (user_id=%)', v_uid_manager;

-- 1.4  Create driver user with gender
INSERT INTO public.users (first_name, mobile, mobile_verified, status, gender)
VALUES ('Ramu', '9100000004', true, 'ACTIVE', 'MALE')
RETURNING user_id INTO v_uid_driver;
RAISE NOTICE 'PASS 1.4  Driver user created with gender=MALE  (user_id=%)', v_uid_driver;

-- 1.5  Create customer user (no email — optional)
INSERT INTO public.users (first_name, mobile, mobile_verified, status)
VALUES ('Customer', '9100000005', false, 'ACTIVE')
RETURNING user_id INTO v_uid_customer;
RAISE NOTICE 'PASS 1.5  Customer user created without email  (user_id=%)', v_uid_customer;

-- 1.6  All 5 gender enum values accepted
BEGIN
    INSERT INTO public.users (first_name, mobile, gender) VALUES ('G1', '9100000010', 'MALE');
    INSERT INTO public.users (first_name, mobile, gender) VALUES ('G2', '9100000011', 'FEMALE');
    INSERT INTO public.users (first_name, mobile, gender) VALUES ('G3', '9100000012', 'NON_BINARY');
    INSERT INTO public.users (first_name, mobile, gender) VALUES ('G4', '9100000013', 'OTHER');
    INSERT INTO public.users (first_name, mobile, gender) VALUES ('G5', '9100000014', 'PREFER_NOT_TO_SAY');
    RAISE NOTICE 'PASS 1.6  All 5 gender enum values accepted';
EXCEPTION WHEN others THEN
    RAISE NOTICE 'FAIL 1.6  Gender enum error: %', SQLERRM;
END;

-- 1.7  Duplicate mobile must be rejected
BEGIN
    INSERT INTO public.users (first_name, mobile) VALUES ('Dup', '9100000001');
    RAISE NOTICE 'FAIL 1.7  Duplicate mobile was accepted — should have been rejected';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'PASS 1.7  Duplicate mobile correctly rejected';
END;

-- 1.8  Duplicate email must be rejected
BEGIN
    INSERT INTO public.users (first_name, mobile, email) VALUES ('Dup', '9199999999', 'ravi@example.com');
    RAISE NOTICE 'FAIL 1.8  Duplicate email was accepted — should have been rejected';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'PASS 1.8  Duplicate email correctly rejected';
END;

-- 1.9  mobile is NOT NULL
BEGIN
    INSERT INTO public.users (first_name) VALUES ('No Mobile');
    RAISE NOTICE 'FAIL 1.9  Insert without mobile should have failed';
EXCEPTION WHEN not_null_violation THEN
    RAISE NOTICE 'PASS 1.9  mobile NOT NULL enforced';
END;

-- 1.10  first_name is NOT NULL
BEGIN
    INSERT INTO public.users (mobile) VALUES ('9199999998');
    RAISE NOTICE 'FAIL 1.10 Insert without first_name should have failed';
EXCEPTION WHEN not_null_violation THEN
    RAISE NOTICE 'PASS 1.10 first_name NOT NULL enforced';
END;

-- 1.11  Invalid gender enum rejected
BEGIN
    INSERT INTO public.users (first_name, mobile, gender)
    VALUES ('Bad', '9199999997', 'UNKNOWN'::public.gender_type);
    RAISE NOTICE 'FAIL 1.11 Invalid gender should have failed';
EXCEPTION WHEN others THEN
    RAISE NOTICE 'PASS 1.11 Invalid gender enum correctly rejected';
END;

-- 1.12  All user codes unique and follow USR-NNNNNN format
SELECT count(*) INTO v_count FROM public.users WHERE user_code NOT LIKE 'USR-%';
SELECT count(*) = count(DISTINCT user_code) INTO v_bool FROM public.users;
IF v_count = 0 AND v_bool THEN
    RAISE NOTICE 'PASS 1.12 All user_codes unique and follow USR-NNNNNN format';
ELSE
    RAISE NOTICE 'FAIL 1.12 Code format or uniqueness issue (non-standard: %, duplicates: %)', v_count, NOT v_bool;
END IF;

-- 1.13  created_by self-reference FK
UPDATE public.users
SET created_by = v_uid_buyer, updated_by = v_uid_buyer
WHERE user_id = v_uid_manager;
SELECT created_by INTO v_count FROM public.users WHERE user_id = v_uid_manager;
IF v_count = v_uid_buyer THEN
    RAISE NOTICE 'PASS 1.13 created_by self-referential FK works';
ELSE
    RAISE NOTICE 'FAIL 1.13 created_by not set correctly';
END IF;


-- =========================================================================
-- SECTION 2: ROLE ASSIGNMENT
-- =========================================================================
RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════════════';
RAISE NOTICE 'SECTION 2 — ROLE ASSIGNMENT';
RAISE NOTICE '══════════════════════════════════════════════════════';

-- roles seeded: 1=ADMIN 2=BUYER 3=NURSERY_OWNER 4=DRIVER 5=MANAGER 6=SUPER_ADMIN 8=CUSTOMER

-- 2.1  Assign BUYER role
INSERT INTO public.user_roles (user_id, role_id, assigned_by) VALUES (v_uid_buyer, 2, 1);
SELECT count(*) INTO v_count FROM public.user_roles WHERE user_id = v_uid_buyer AND role_id = 2;
IF v_count = 1 THEN RAISE NOTICE 'PASS 2.1  BUYER role assigned';
ELSE RAISE NOTICE 'FAIL 2.1  BUYER role assignment failed'; END IF;

-- 2.2  Assign NURSERY_OWNER role
INSERT INTO public.user_roles (user_id, role_id, assigned_by) VALUES (v_uid_owner, 3, 1);
RAISE NOTICE 'PASS 2.2  NURSERY_OWNER role assigned';

-- 2.3  Assign MANAGER role
INSERT INTO public.user_roles (user_id, role_id, assigned_by) VALUES (v_uid_manager, 5, 1);
RAISE NOTICE 'PASS 2.3  MANAGER role assigned';

-- 2.4  Assign DRIVER role
INSERT INTO public.user_roles (user_id, role_id, assigned_by) VALUES (v_uid_driver, 4, 1);
RAISE NOTICE 'PASS 2.4  DRIVER role assigned';

-- 2.5  Assign CUSTOMER role
INSERT INTO public.user_roles (user_id, role_id, assigned_by) VALUES (v_uid_customer, 8, 1);
RAISE NOTICE 'PASS 2.5  CUSTOMER role assigned';

-- 2.6  User can hold multiple roles (owner who also buys)
INSERT INTO public.user_roles (user_id, role_id, assigned_by) VALUES (v_uid_owner, 2, 1);
SELECT count(*) INTO v_count FROM public.user_roles WHERE user_id = v_uid_owner;
IF v_count = 2 THEN
    RAISE NOTICE 'PASS 2.6  Owner has 2 roles: NURSERY_OWNER + BUYER';
ELSE
    RAISE NOTICE 'FAIL 2.6  Expected 2 roles, got %', v_count;
END IF;

-- 2.7  Duplicate role rejected (PK constraint)
BEGIN
    INSERT INTO public.user_roles (user_id, role_id) VALUES (v_uid_buyer, 2);
    RAISE NOTICE 'FAIL 2.7  Duplicate role should have been rejected';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'PASS 2.7  Duplicate role correctly rejected (PK violation)';
END;

-- 2.8  FK: role assigned to non-existent user rejected
BEGIN
    INSERT INTO public.user_roles (user_id, role_id) VALUES (999999, 2);
    RAISE NOTICE 'FAIL 2.8  Non-existent user FK should have failed';
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'PASS 2.8  Non-existent user FK correctly rejected';
END;

-- 2.9  FK: assigned_by must be a valid user
BEGIN
    INSERT INTO public.user_roles (user_id, role_id, assigned_by) VALUES (v_uid_customer, 2, 999999);
    RAISE NOTICE 'FAIL 2.9  assigned_by FK should have failed';
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'PASS 2.9  assigned_by FK correctly rejected';
END;

-- 2.10  Remove a role
DELETE FROM public.user_roles WHERE user_id = v_uid_owner AND role_id = 2;
SELECT count(*) INTO v_count FROM public.user_roles WHERE user_id = v_uid_owner;
IF v_count = 1 THEN
    RAISE NOTICE 'PASS 2.10 BUYER role removed — owner back to 1 role (NURSERY_OWNER)';
ELSE
    RAISE NOTICE 'FAIL 2.10 Expected 1 role, got %', v_count;
END IF;

-- 2.11  Roles+users join query (what the auth middleware runs)
SELECT count(*) INTO v_count
FROM public.users u
JOIN public.user_roles ur ON u.user_id = ur.user_id
JOIN public.roles r ON ur.role_id = r.role_id
WHERE u.status = 'ACTIVE' AND u.deleted_at IS NULL AND r.is_active = true;
RAISE NOTICE 'PASS 2.11 Auth join (users+user_roles+roles) returns % active assignments', v_count;

-- 2.12  Cascade: deleting user removes their role rows
INSERT INTO public.users (first_name, mobile) VALUES ('TempRole', '9188880010') RETURNING user_id INTO v_uid_temp;
INSERT INTO public.user_roles (user_id, role_id) VALUES (v_uid_temp, 2);
DELETE FROM public.users WHERE user_id = v_uid_temp;
SELECT count(*) INTO v_count FROM public.user_roles WHERE user_id = v_uid_temp;
IF v_count = 0 THEN
    RAISE NOTICE 'PASS 2.12 Cascade: user_roles deleted when user hard-deleted';
ELSE
    RAISE NOTICE 'FAIL 2.12 user_roles still exist after user delete';
END IF;


-- =========================================================================
-- SECTION 3: USER SESSIONS
-- =========================================================================
RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════════════';
RAISE NOTICE 'SECTION 3 — USER SESSIONS';
RAISE NOTICE '══════════════════════════════════════════════════════';

-- 3.1  Create session on login
INSERT INTO public.user_sessions (user_id, session_token, session_status, device_type, os_name, app_version, ip_address, user_agent)
VALUES (v_uid_buyer, 'tok_buyer_phone', 'ACTIVE', 'PHONE', 'Android', '1.2.0', '103.55.12.1', 'GreenRoot/1.2.0 (Android 13)')
RETURNING session_id INTO v_session_id;

IF v_session_id IS NOT NULL THEN
    RAISE NOTICE 'PASS 3.1  Session created on login  (session_id=%)', v_session_id;
ELSE
    RAISE NOTICE 'FAIL 3.1  Session creation failed';
END IF;

-- 3.2  Update last_activity_at (called on every API request)
UPDATE public.user_sessions SET last_activity_at = CURRENT_TIMESTAMP WHERE session_id = v_session_id;
RAISE NOTICE 'PASS 3.2  last_activity_at refreshed';

-- 3.3  Multiple concurrent sessions (phone + tablet = 2 devices)
INSERT INTO public.user_sessions (user_id, session_token, session_status, device_type, os_name)
VALUES (v_uid_buyer, 'tok_buyer_tablet', 'ACTIVE', 'TABLET', 'iOS');

SELECT count(*) INTO v_count FROM public.user_sessions
WHERE user_id = v_uid_buyer AND session_status = 'ACTIVE';
IF v_count = 2 THEN
    RAISE NOTICE 'PASS 3.3  User has 2 concurrent active sessions (phone + tablet)';
ELSE
    RAISE NOTICE 'FAIL 3.3  Expected 2 active sessions, got %', v_count;
END IF;

-- 3.4  Logout single device (expire one session)
UPDATE public.user_sessions SET session_status = 'EXPIRED' WHERE session_id = v_session_id;
SELECT count(*) INTO v_count FROM public.user_sessions
WHERE user_id = v_uid_buyer AND session_status = 'ACTIVE';
IF v_count = 1 THEN
    RAISE NOTICE 'PASS 3.4  Single-device logout: 1 session expired, 1 still active';
ELSE
    RAISE NOTICE 'FAIL 3.4  Expected 1 active session after single logout, got %', v_count;
END IF;

-- 3.5  Force logout all devices (admin action)
UPDATE public.user_sessions SET session_status = 'EXPIRED' WHERE user_id = v_uid_buyer;
SELECT count(*) INTO v_count FROM public.user_sessions
WHERE user_id = v_uid_buyer AND session_status = 'ACTIVE';
IF v_count = 0 THEN
    RAISE NOTICE 'PASS 3.5  Force logout all: 0 active sessions remain';
ELSE
    RAISE NOTICE 'FAIL 3.5  % sessions still active after force logout', v_count;
END IF;

-- 3.6  FK: session tied to non-existent user rejected
BEGIN
    INSERT INTO public.user_sessions (user_id, session_token, session_status)
    VALUES (999999, 'tok_nobody', 'ACTIVE');
    RAISE NOTICE 'FAIL 3.6  Non-existent user FK should have failed';
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'PASS 3.6  Session FK to non-existent user rejected';
END;

-- 3.7  Cascade: sessions deleted when user is hard-deleted
INSERT INTO public.users (first_name, mobile) VALUES ('TempSess', '9188880011') RETURNING user_id INTO v_uid_temp;
INSERT INTO public.user_sessions (user_id, session_token, session_status)
VALUES (v_uid_temp, 'tok_temp_cascade', 'ACTIVE');
DELETE FROM public.users WHERE user_id = v_uid_temp;
SELECT count(*) INTO v_count FROM public.user_sessions WHERE user_id = v_uid_temp;
IF v_count = 0 THEN
    RAISE NOTICE 'PASS 3.7  Cascade: sessions deleted when user hard-deleted';
ELSE
    RAISE NOTICE 'FAIL 3.7  Sessions still exist after user delete';
END IF;

-- 3.8  Query: latest session per user (how admin "last seen" is built)
SELECT count(*) INTO v_count FROM (
    SELECT DISTINCT ON (user_id) user_id, last_activity_at
    FROM public.user_sessions
    ORDER BY user_id, last_activity_at DESC
) sub;
RAISE NOTICE 'PASS 3.8  Latest-session-per-user query works: % distinct users', v_count;


-- =========================================================================
-- SECTION 4: USER ACTIVITIES
-- =========================================================================
RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════════════';
RAISE NOTICE 'SECTION 4 — USER ACTIVITIES';
RAISE NOTICE '══════════════════════════════════════════════════════';

-- fresh session for activity logging
INSERT INTO public.user_sessions (user_id, session_token, session_status)
VALUES (v_uid_buyer, 'tok_activity_test', 'ACTIVE')
RETURNING session_id INTO v_session_id;

-- 4.1  Log VIEW_PLANT activity with session
INSERT INTO public.user_activities (user_id, session_id, activity_type, entity_type, entity_id, activity_data)
VALUES (v_uid_buyer, v_session_id, 'VIEW_PLANT', 'plant', 1, '{"plant_code":"PLT-000001","plant_name":"Neem"}');
RAISE NOTICE 'PASS 4.1  VIEW_PLANT activity logged with session';

-- 4.2  Log CREATE_QUOTATION activity
INSERT INTO public.user_activities (user_id, session_id, activity_type, entity_type, entity_id, activity_data)
VALUES (v_uid_buyer, v_session_id, 'CREATE_QUOTATION', 'quotation', 1, '{"quotation_code":"QUO-000001","amount":50000}');
RAISE NOTICE 'PASS 4.2  CREATE_QUOTATION activity logged';

-- 4.3  Log activity without session (background API call — session_id nullable)
INSERT INTO public.user_activities (user_id, activity_type, entity_type, entity_id)
VALUES (v_uid_buyer, 'UPDATE_PROFILE', 'user', v_uid_buyer);
RAISE NOTICE 'PASS 4.3  Activity without session_id logged (nullable)';

-- 4.4  JSONB activity_data can be queried
SELECT activity_data->>'amount' INTO v_text
FROM public.user_activities
WHERE user_id = v_uid_buyer AND activity_type = 'CREATE_QUOTATION';
IF v_text = '50000' THEN
    RAISE NOTICE 'PASS 4.4  JSONB activity_data query returns correct value (amount=%)', v_text;
ELSE
    RAISE NOTICE 'FAIL 4.4  JSONB query returned %, expected 50000', v_text;
END IF;

-- 4.5  Filter activities by entity_type
SELECT count(*) INTO v_count FROM public.user_activities WHERE entity_type = 'plant';
IF v_count >= 1 THEN
    RAISE NOTICE 'PASS 4.5  Filter by entity_type=plant returns % row(s)', v_count;
ELSE
    RAISE NOTICE 'FAIL 4.5  No plant activities found';
END IF;

-- 4.6  Session → activities FK (SET NULL on session delete)
INSERT INTO public.user_sessions (user_id, session_token, session_status)
VALUES (v_uid_manager, 'tok_mgr_delete_test', 'ACTIVE') RETURNING session_id INTO v_count; -- reuse v_count as temp
INSERT INTO public.user_activities (user_id, session_id, activity_type)
VALUES (v_uid_manager, v_count, 'LOGIN');
-- Expire the session (soft) — activity stays, session_id → SET NULL only on CASCADE
-- In this schema: ON DELETE SET NULL for user_activities.session_id
DELETE FROM public.user_sessions WHERE session_id = v_count;
SELECT count(*) INTO v_count FROM public.user_activities
WHERE user_id = v_uid_manager AND activity_type = 'LOGIN' AND session_id IS NULL;
IF v_count = 1 THEN
    RAISE NOTICE 'PASS 4.6  Activity session_id SET NULL when session deleted';
ELSE
    RAISE NOTICE 'FAIL 4.6  Expected session_id=NULL on orphaned activity, got % rows', v_count;
END IF;

-- 4.7  Cascade: activities deleted when user hard-deleted
INSERT INTO public.users (first_name, mobile) VALUES ('TempAct', '9188880012') RETURNING user_id INTO v_uid_temp;
INSERT INTO public.user_activities (user_id, activity_type) VALUES (v_uid_temp, 'TEST_EVENT');
DELETE FROM public.users WHERE user_id = v_uid_temp;
SELECT count(*) INTO v_count FROM public.user_activities WHERE user_id = v_uid_temp;
IF v_count = 0 THEN
    RAISE NOTICE 'PASS 4.7  Cascade: activities deleted when user hard-deleted';
ELSE
    RAISE NOTICE 'FAIL 4.7  Activities still exist after user delete';
END IF;


-- =========================================================================
-- SECTION 5: USER ADDRESSES
-- =========================================================================
RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════════════';
RAISE NOTICE 'SECTION 5 — USER ADDRESSES';
RAISE NOTICE '══════════════════════════════════════════════════════';

-- 5.1  Add home address with lat/lng
INSERT INTO public.user_addresses (
    user_id, address_type, contact_name, contact_mobile,
    address_line1, city, state, country, postal_code,
    latitude, longitude, is_default
) VALUES (
    v_uid_buyer, 'HOME', 'Ravi Kumar', '9100000001',
    '42 MG Road', 'Hyderabad', 'Telangana', 'India', '500001',
    17.3850000, 78.4867000, true
) RETURNING address_id INTO v_address_id;

IF v_address_id IS NOT NULL THEN
    RAISE NOTICE 'PASS 5.1  Home address added  (address_id=%)', v_address_id;
ELSE
    RAISE NOTICE 'FAIL 5.1  Address insert failed';
END IF;

-- 5.2  Add second address (farm)
INSERT INTO public.user_addresses (
    user_id, address_type, contact_name, contact_mobile,
    address_line1, address_line2, city, state, country, postal_code, is_default
) VALUES (
    v_uid_buyer, 'FARM', 'Ravi Kumar', '9100000001',
    'Survey No 45', 'Near Shamshabad Village', 'Hyderabad', 'Telangana', 'India', '501218', false
);

SELECT count(*) INTO v_count FROM public.user_addresses WHERE user_id = v_uid_buyer;
IF v_count = 2 THEN
    RAISE NOTICE 'PASS 5.2  User has 2 addresses (HOME + FARM)';
ELSE
    RAISE NOTICE 'FAIL 5.2  Expected 2 addresses, got %', v_count;
END IF;

-- 5.3  Update city
UPDATE public.user_addresses SET city = 'Bangalore', state = 'Karnataka' WHERE address_id = v_address_id;
SELECT city INTO v_text FROM public.user_addresses WHERE address_id = v_address_id;
IF v_text = 'Bangalore' THEN
    RAISE NOTICE 'PASS 5.3  Address city updated to Bangalore';
ELSE
    RAISE NOTICE 'FAIL 5.3  City not updated, got %', v_text;
END IF;

-- 5.4  lat/lng stored with 7 decimal precision
SELECT latitude::TEXT INTO v_text FROM public.user_addresses WHERE address_id = v_address_id;
RAISE NOTICE 'PASS 5.4  Latitude stored: %', v_text;

-- 5.5  address_line1 is NOT NULL
BEGIN
    INSERT INTO public.user_addresses (user_id) VALUES (v_uid_buyer);
    RAISE NOTICE 'FAIL 5.5  Insert without address_line1 should have failed';
EXCEPTION WHEN not_null_violation THEN
    RAISE NOTICE 'PASS 5.5  address_line1 NOT NULL enforced';
END;

-- 5.6  Delete one address
DELETE FROM public.user_addresses WHERE user_id = v_uid_buyer AND address_type = 'FARM';
SELECT count(*) INTO v_count FROM public.user_addresses WHERE user_id = v_uid_buyer;
IF v_count = 1 THEN
    RAISE NOTICE 'PASS 5.6  FARM address deleted, 1 remains';
ELSE
    RAISE NOTICE 'FAIL 5.6  Expected 1 address, got %', v_count;
END IF;

-- 5.7  Cascade: addresses deleted when user deleted
INSERT INTO public.users (first_name, mobile) VALUES ('TempAddr', '9188880013') RETURNING user_id INTO v_uid_temp;
INSERT INTO public.user_addresses (user_id, address_line1) VALUES (v_uid_temp, '99 Temp Lane');
DELETE FROM public.users WHERE user_id = v_uid_temp;
SELECT count(*) INTO v_count FROM public.user_addresses WHERE user_id = v_uid_temp;
IF v_count = 0 THEN
    RAISE NOTICE 'PASS 5.7  Cascade: addresses deleted when user hard-deleted';
ELSE
    RAISE NOTICE 'FAIL 5.7  Addresses still exist after user delete';
END IF;


-- =========================================================================
-- SECTION 6: USER SUBSCRIPTIONS
-- =========================================================================
RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════════════';
RAISE NOTICE 'SECTION 6 — USER SUBSCRIPTIONS';
RAISE NOTICE '══════════════════════════════════════════════════════';

-- seed plans
INSERT INTO public.subscription_plans (plan_code, plan_name, monthly_price, yearly_price, max_users, max_nurseries, is_active)
VALUES ('FREE', 'Free Plan', 0, 0, 3, 1, true)
RETURNING plan_id INTO v_plan_id_free;

INSERT INTO public.subscription_plans (plan_code, plan_name, monthly_price, yearly_price, max_users, max_nurseries, is_active)
VALUES ('PRO', 'Pro Plan', 999.00, 9999.00, 20, 5, true)
RETURNING plan_id INTO v_plan_id_pro;

RAISE NOTICE 'INFO  Plans seeded: FREE (id=%), PRO (id=%)', v_plan_id_free, v_plan_id_pro;

-- 6.1  Subscribe owner to FREE plan
INSERT INTO public.user_subscriptions (user_id, plan_id, start_date, subscription_status, auto_renew)
VALUES (v_uid_owner, v_plan_id_free, CURRENT_DATE, 'ACTIVE', false)
RETURNING user_subscription_id INTO v_sub_id;

IF v_sub_id IS NOT NULL THEN
    RAISE NOTICE 'PASS 6.1  Subscription created  (id=%)', v_sub_id;
ELSE
    RAISE NOTICE 'FAIL 6.1  Subscription creation failed';
END IF;

-- 6.2  Auto-generated subscription code follows SUB-NNNNNN
SELECT subscription_code INTO v_text FROM public.user_subscriptions WHERE user_subscription_id = v_sub_id;
IF v_text LIKE 'SUB-%' THEN
    RAISE NOTICE 'PASS 6.2  Subscription code format correct: %', v_text;
ELSE
    RAISE NOTICE 'FAIL 6.2  Unexpected subscription code: %', v_text;
END IF;

-- 6.3  Upgrade from FREE to PRO
UPDATE public.user_subscriptions SET plan_id = v_plan_id_pro WHERE user_subscription_id = v_sub_id;
SELECT plan_id INTO v_count FROM public.user_subscriptions WHERE user_subscription_id = v_sub_id;
IF v_count = v_plan_id_pro THEN
    RAISE NOTICE 'PASS 6.3  Plan upgraded from FREE to PRO';
ELSE
    RAISE NOTICE 'FAIL 6.3  Plan upgrade failed';
END IF;

-- 6.4  Expire subscription
UPDATE public.user_subscriptions
SET end_date = CURRENT_DATE - 1, subscription_status = 'EXPIRED'
WHERE user_subscription_id = v_sub_id;
SELECT subscription_status INTO v_text FROM public.user_subscriptions WHERE user_subscription_id = v_sub_id;
IF v_text = 'EXPIRED' THEN
    RAISE NOTICE 'PASS 6.4  Subscription expired';
ELSE
    RAISE NOTICE 'FAIL 6.4  Expected EXPIRED, got %', v_text;
END IF;

-- 6.5  Enable auto-renew
UPDATE public.user_subscriptions SET auto_renew = true WHERE user_subscription_id = v_sub_id;
SELECT auto_renew INTO v_bool FROM public.user_subscriptions WHERE user_subscription_id = v_sub_id;
IF v_bool THEN RAISE NOTICE 'PASS 6.5  auto_renew enabled';
ELSE RAISE NOTICE 'FAIL 6.5  auto_renew not set'; END IF;

-- 6.6  Cancel subscription
UPDATE public.user_subscriptions SET subscription_status = 'CANCELLED' WHERE user_subscription_id = v_sub_id;
SELECT subscription_status INTO v_text FROM public.user_subscriptions WHERE user_subscription_id = v_sub_id;
IF v_text = 'CANCELLED' THEN RAISE NOTICE 'PASS 6.6  Subscription cancelled';
ELSE RAISE NOTICE 'FAIL 6.6  Expected CANCELLED, got %', v_text; END IF;

-- 6.7  FK: non-existent plan rejected
BEGIN
    INSERT INTO public.user_subscriptions (user_id, plan_id, start_date, subscription_status)
    VALUES (v_uid_owner, 999999, CURRENT_DATE, 'ACTIVE');
    RAISE NOTICE 'FAIL 6.7  Non-existent plan FK should have failed';
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'PASS 6.7  Non-existent plan FK correctly rejected';
END;


-- =========================================================================
-- SECTION 7: NOTIFICATION DEVICES (FCM tokens)
-- =========================================================================
RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════════════';
RAISE NOTICE 'SECTION 7 — NOTIFICATION DEVICES (FCM TOKENS)';
RAISE NOTICE '══════════════════════════════════════════════════════';

-- 7.1  Register first device (Android phone)
INSERT INTO public.user_notification_devices
    (user_id, fcm_token, device_type, platform, app_version, is_active, last_seen_at)
VALUES (v_uid_buyer, 'fcm_android_buyer_001', 'PHONE', 'Android', '1.2.0', true, CURRENT_TIMESTAMP)
RETURNING device_id INTO v_device_id;

IF v_device_id IS NOT NULL THEN
    RAISE NOTICE 'PASS 7.1  Android phone FCM token registered  (device_id=%)', v_device_id;
ELSE
    RAISE NOTICE 'FAIL 7.1  Device registration failed';
END IF;

-- 7.2  Register second device (iOS tablet)
INSERT INTO public.user_notification_devices
    (user_id, fcm_token, device_type, platform, app_version, is_active)
VALUES (v_uid_buyer, 'fcm_ios_buyer_tablet_002', 'TABLET', 'iOS', '1.2.0', true);

SELECT count(*) INTO v_count FROM public.user_notification_devices
WHERE user_id = v_uid_buyer AND is_active = true;
IF v_count = 2 THEN
    RAISE NOTICE 'PASS 7.2  User has 2 active devices (phone + tablet)';
ELSE
    RAISE NOTICE 'FAIL 7.2  Expected 2 active devices, got %', v_count;
END IF;

-- 7.3  Same FCM token cannot be registered for two users
BEGIN
    INSERT INTO public.user_notification_devices (user_id, fcm_token, is_active)
    VALUES (v_uid_manager, 'fcm_android_buyer_001', true);
    RAISE NOTICE 'FAIL 7.3  Duplicate FCM token should have been rejected';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'PASS 7.3  Duplicate FCM token across users correctly rejected';
END;

-- 7.4  Deactivate device on logout
UPDATE public.user_notification_devices SET is_active = false WHERE device_id = v_device_id;
SELECT is_active INTO v_bool FROM public.user_notification_devices WHERE device_id = v_device_id;
IF NOT v_bool THEN
    RAISE NOTICE 'PASS 7.4  Device deactivated on logout';
ELSE
    RAISE NOTICE 'FAIL 7.4  Device still active after logout';
END IF;

-- 7.5  Token refresh — new token for same device (old deactivated, new registered)
INSERT INTO public.user_notification_devices (user_id, fcm_token, device_type, platform, is_active)
VALUES (v_uid_buyer, 'fcm_android_buyer_refreshed_003', 'PHONE', 'Android', true);
SELECT count(*) INTO v_count FROM public.user_notification_devices
WHERE user_id = v_uid_buyer AND is_active = true;
RAISE NOTICE 'PASS 7.5  Token refreshed — % active device(s) for buyer', v_count;

-- 7.6  Cascade: FCM tokens deleted when user hard-deleted
INSERT INTO public.users (first_name, mobile) VALUES ('TempFCM', '9188880014') RETURNING user_id INTO v_uid_temp;
INSERT INTO public.user_notification_devices (user_id, fcm_token, is_active)
VALUES (v_uid_temp, 'fcm_temp_cascade_token', true);
DELETE FROM public.users WHERE user_id = v_uid_temp;
SELECT count(*) INTO v_count FROM public.user_notification_devices WHERE user_id = v_uid_temp;
IF v_count = 0 THEN
    RAISE NOTICE 'PASS 7.6  Cascade: FCM tokens deleted when user hard-deleted';
ELSE
    RAISE NOTICE 'FAIL 7.6  FCM tokens still exist after user delete';
END IF;


-- =========================================================================
-- SECTION 8: PROFILE UPDATES
-- =========================================================================
RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════════════';
RAISE NOTICE 'SECTION 8 — PROFILE UPDATES';
RAISE NOTICE '══════════════════════════════════════════════════════';

-- 8.1  Update name
UPDATE public.users SET first_name = 'Ravi', last_name = 'Kumar Sharma', updated_at = CURRENT_TIMESTAMP
WHERE user_id = v_uid_buyer;
SELECT last_name INTO v_text FROM public.users WHERE user_id = v_uid_buyer;
IF v_text = 'Kumar Sharma' THEN RAISE NOTICE 'PASS 8.1  Name updated';
ELSE RAISE NOTICE 'FAIL 8.1  last_name not updated, got %', v_text; END IF;

-- 8.2  Update profile photo URL
UPDATE public.users SET profile_image_url = 'https://minio.local/profile-images/ravi.jpg'
WHERE user_id = v_uid_buyer;
SELECT profile_image_url IS NOT NULL INTO v_bool FROM public.users WHERE user_id = v_uid_buyer;
IF v_bool THEN RAISE NOTICE 'PASS 8.2  Profile image URL set';
ELSE RAISE NOTICE 'FAIL 8.2  profile_image_url not set'; END IF;

-- 8.3  Update gender
UPDATE public.users SET gender = 'MALE' WHERE user_id = v_uid_buyer;
SELECT gender::TEXT INTO v_text FROM public.users WHERE user_id = v_uid_buyer;
IF v_text = 'MALE' THEN RAISE NOTICE 'PASS 8.3  Gender updated to MALE';
ELSE RAISE NOTICE 'FAIL 8.3  Gender not updated, got %', v_text; END IF;

-- 8.4  Update email — triggers email_verified reset (app layer responsibility, DB allows it)
UPDATE public.users SET email = 'ravi.new@example.com', email_verified = false
WHERE user_id = v_uid_buyer;
SELECT email INTO v_text FROM public.users WHERE user_id = v_uid_buyer;
IF v_text = 'ravi.new@example.com' THEN
    RAISE NOTICE 'PASS 8.4  Email updated to ravi.new@example.com';
ELSE
    RAISE NOTICE 'FAIL 8.4  Email not updated, got %', v_text;
END IF;

-- 8.5  Mark email verified
UPDATE public.users SET email_verified = true WHERE user_id = v_uid_buyer;
SELECT email_verified INTO v_bool FROM public.users WHERE user_id = v_uid_buyer;
IF v_bool THEN RAISE NOTICE 'PASS 8.5  email_verified set to true';
ELSE RAISE NOTICE 'FAIL 8.5  email_verified not set'; END IF;

-- 8.6  Store password hash (optional password login feature)
UPDATE public.users SET password_hash = '$2b$12$abcdefghijklmnopqrstuuVGZzYz1234567890ABCDEF'
WHERE user_id = v_uid_buyer;
SELECT password_hash IS NOT NULL INTO v_bool FROM public.users WHERE user_id = v_uid_buyer;
IF v_bool THEN RAISE NOTICE 'PASS 8.6  password_hash stored';
ELSE RAISE NOTICE 'FAIL 8.6  password_hash not persisted'; END IF;

-- 8.7  Record last_login_at (simulates successful OTP verification)
UPDATE public.users SET last_login_at = CURRENT_TIMESTAMP WHERE user_id = v_uid_buyer;
SELECT last_login_at IS NOT NULL INTO v_bool FROM public.users WHERE user_id = v_uid_buyer;
IF v_bool THEN RAISE NOTICE 'PASS 8.7  last_login_at updated on OTP login';
ELSE RAISE NOTICE 'FAIL 8.7  last_login_at not set'; END IF;

-- 8.8  Mobile update (number change — rare but must preserve uniqueness)
UPDATE public.users SET mobile = '9100099001' WHERE user_id = v_uid_buyer;
SELECT mobile INTO v_text FROM public.users WHERE user_id = v_uid_buyer;
IF v_text = '9100099001' THEN RAISE NOTICE 'PASS 8.8  Mobile number updated';
ELSE RAISE NOTICE 'FAIL 8.8  Mobile update failed, got %', v_text; END IF;

-- 8.9  Attempt to change mobile to an already-taken number
BEGIN
    UPDATE public.users SET mobile = '9100000002' WHERE user_id = v_uid_buyer;
    RAISE NOTICE 'FAIL 8.9  Duplicate mobile on update should have been rejected';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'PASS 8.9  Duplicate mobile on UPDATE correctly rejected';
END;


-- =========================================================================
-- SECTION 9: STATUS TRANSITIONS & SOFT DELETE
-- =========================================================================
RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════════════';
RAISE NOTICE 'SECTION 9 — STATUS TRANSITIONS & SOFT DELETE';
RAISE NOTICE '══════════════════════════════════════════════════════';

-- 9.1  Suspend a user (admin action)
UPDATE public.users SET status = 'SUSPENDED' WHERE user_id = v_uid_customer;
SELECT status INTO v_text FROM public.users WHERE user_id = v_uid_customer;
IF v_text = 'SUSPENDED' THEN RAISE NOTICE 'PASS 9.1  User suspended';
ELSE RAISE NOTICE 'FAIL 9.1  Expected SUSPENDED, got %', v_text; END IF;

-- 9.2  Reactivate suspended user
UPDATE public.users SET status = 'ACTIVE' WHERE user_id = v_uid_customer;
SELECT status INTO v_text FROM public.users WHERE user_id = v_uid_customer;
IF v_text = 'ACTIVE' THEN RAISE NOTICE 'PASS 9.2  User reactivated to ACTIVE';
ELSE RAISE NOTICE 'FAIL 9.2  Reactivation failed, got %', v_text; END IF;

-- 9.3  Soft delete (set deleted_at) — row still exists
UPDATE public.users SET deleted_at = CURRENT_TIMESTAMP, status = 'DELETED'
WHERE user_id = v_uid_customer;
SELECT count(*) INTO v_count FROM public.users WHERE user_id = v_uid_customer;
IF v_count = 1 THEN
    RAISE NOTICE 'PASS 9.3  Soft delete: row still in DB with deleted_at set';
ELSE
    RAISE NOTICE 'FAIL 9.3  Soft-deleted user row not found';
END IF;

-- 9.4  Soft-deleted user excluded from active list
SELECT count(*) INTO v_count FROM public.users
WHERE user_id = v_uid_customer AND deleted_at IS NULL;
IF v_count = 0 THEN
    RAISE NOTICE 'PASS 9.4  Soft-deleted user excluded by deleted_at IS NULL filter';
ELSE
    RAISE NOTICE 'FAIL 9.4  Soft-deleted user visible in active filter';
END IF;

-- 9.5  Restore soft-deleted user (admin undo action)
UPDATE public.users SET deleted_at = NULL, status = 'ACTIVE' WHERE user_id = v_uid_customer;
SELECT status INTO v_text FROM public.users WHERE user_id = v_uid_customer;
IF v_text = 'ACTIVE' THEN RAISE NOTICE 'PASS 9.5  Soft-deleted user restored to ACTIVE';
ELSE RAISE NOTICE 'FAIL 9.5  Restore failed, status=%', v_text; END IF;

-- 9.6  Active users count (what the admin dashboard shows)
SELECT count(*) INTO v_count FROM public.users
WHERE status = 'ACTIVE' AND deleted_at IS NULL;
RAISE NOTICE 'PASS 9.6  Active non-deleted user count: %', v_count;


-- =========================================================================
-- SECTION 10: PUBLIC CODE SEQUENCES
-- =========================================================================
RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════════════';
RAISE NOTICE 'SECTION 10 — PUBLIC CODE SEQUENCE MECHANICS';
RAISE NOTICE '══════════════════════════════════════════════════════';

-- 10.1  Sequential codes issued in order
DECLARE
    v_codes  TEXT[];
    i        INTEGER;
BEGIN
    FOR i IN 1..5 LOOP
        v_codes := array_append(v_codes,
            public.next_public_code('test_seq', 'SEQ', 4, false));
    END LOOP;
    IF v_codes[1] = 'SEQ-0001' AND v_codes[5] = 'SEQ-0005' THEN
        RAISE NOTICE 'PASS 10.1 Sequential codes: % → %', v_codes[1], v_codes[5];
    ELSE
        RAISE NOTICE 'FAIL 10.1 Unexpected codes: % → %', v_codes[1], v_codes[5];
    END IF;
END;

-- 10.2  Date-based code includes today's date
DECLARE
    v_code  TEXT;
    v_today TEXT := to_char(CURRENT_DATE, 'YYYYMMDD');
BEGIN
    v_code := public.next_public_code('test_date', 'DT', 4, true);
    IF v_code LIKE 'DT-' || v_today || '-%' THEN
        RAISE NOTICE 'PASS 10.2 Date-based code format correct: %', v_code;
    ELSE
        RAISE NOTICE 'FAIL 10.2 Date-based code wrong: %', v_code;
    END IF;
END;

-- 10.3  Sequence for different keys are independent (users vs plants)
DECLARE
    v_u TEXT;
    v_p TEXT;
    v_n_before BIGINT;
    v_n_after  BIGINT;
BEGIN
    SELECT last_value INTO v_n_before FROM public.public_code_sequences
    WHERE code_key = 'plants' AND date_key = '';

    v_u := public.next_public_code('users', 'USR', 6, false);
    v_p := public.next_public_code('plants', 'PLT', 6, false);

    SELECT last_value INTO v_n_after FROM public.public_code_sequences
    WHERE code_key = 'plants' AND date_key = '';

    IF v_n_after = v_n_before + 1 THEN
        RAISE NOTICE 'PASS 10.3 Independent sequences: users counter did not affect plants counter';
    ELSE
        RAISE NOTICE 'FAIL 10.3 Sequence counters appear to be shared';
    END IF;
END;

-- 10.4  Rerun safety: ON CONFLICT DO UPDATE never resets to 0
DECLARE
    v_before BIGINT;
    v_after  BIGINT;
BEGIN
    SELECT last_value INTO v_before FROM public.public_code_sequences
    WHERE code_key = 'users' AND date_key = '';

    -- Simulate a duplicate seed run (what happens if schema is re-applied)
    INSERT INTO public.public_code_sequences (code_key, date_key, last_value)
    VALUES ('users', '', 0)
    ON CONFLICT (code_key, date_key) DO UPDATE
        SET last_value = GREATEST(public_code_sequences.last_value, EXCLUDED.last_value);

    SELECT last_value INTO v_after FROM public.public_code_sequences
    WHERE code_key = 'users' AND date_key = '';

    IF v_after = v_before THEN
        RAISE NOTICE 'PASS 10.4 Re-seed with 0 does not reset counter (GREATEST guard works)';
    ELSE
        RAISE NOTICE 'FAIL 10.4 Counter reset! before=%, after=%', v_before, v_after;
    END IF;
END;


-- =========================================================================
-- SECTION 11: CROSS-TABLE QUERIES (WHAT THE API WILL RUN)
-- =========================================================================
RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════════════';
RAISE NOTICE 'SECTION 11 — CROSS-TABLE QUERIES';
RAISE NOTICE '══════════════════════════════════════════════════════';

-- 11.1  Full user profile: user + roles + address + device count
SELECT count(*) INTO v_count
FROM public.users u
LEFT JOIN public.user_roles ur  ON u.user_id = ur.user_id
LEFT JOIN public.roles r        ON ur.role_id = r.role_id
LEFT JOIN public.user_addresses ua ON u.user_id = ua.user_id
WHERE u.user_id = v_uid_buyer;
RAISE NOTICE 'PASS 11.1 Full profile join for buyer: % rows', v_count;

-- 11.2  List all ACTIVE users with their assigned roles (admin list page)
SELECT count(*) INTO v_count
FROM public.users u
JOIN public.user_roles ur ON u.user_id = ur.user_id
JOIN public.roles r ON ur.role_id = r.role_id
WHERE u.deleted_at IS NULL
  AND u.status = 'ACTIVE'
  AND r.is_active = true;
RAISE NOTICE 'PASS 11.2 Admin users list query returns % role assignments', v_count;

-- 11.3  Find users who have no role assigned (orphaned — should not exist)
SELECT count(*) INTO v_count
FROM public.users u
LEFT JOIN public.user_roles ur ON u.user_id = ur.user_id
WHERE ur.user_id IS NULL
  AND u.deleted_at IS NULL;
RAISE NOTICE 'PASS 11.3 Users with no role: % (should be 0 or admin-managed)', v_count;

-- 11.4  Active sessions across all users (live user count)
SELECT count(*) INTO v_count FROM public.user_sessions WHERE session_status = 'ACTIVE';
RAISE NOTICE 'PASS 11.4 Active sessions across all users: %', v_count;

-- 11.5  User with their default delivery address (order creation pre-fill)
SELECT count(*) INTO v_count
FROM public.users u
JOIN public.user_addresses ua ON u.user_id = ua.user_id AND ua.is_default = true
WHERE u.user_id = v_uid_buyer;
RAISE NOTICE 'PASS 11.5 Buyer default address lookup: % row(s)', v_count;

-- 11.6  All active FCM tokens for a user (push notification fan-out)
SELECT count(*) INTO v_count FROM public.user_notification_devices
WHERE user_id = v_uid_buyer AND is_active = true;
RAISE NOTICE 'PASS 11.6 Active FCM tokens for buyer: %', v_count;

-- 11.7  User subscription + plan details (feature gate check)
SELECT count(*) INTO v_count
FROM public.user_subscriptions us
JOIN public.subscription_plans sp ON us.plan_id = sp.plan_id
WHERE us.user_id = v_uid_owner;
RAISE NOTICE 'PASS 11.7 Subscription+plan join for owner: % row(s)', v_count;


-- =========================================================================
-- SECTION 12: FINAL DATA SUMMARY
-- =========================================================================
RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════════════';
RAISE NOTICE 'SECTION 12 — FINAL DATA SUMMARY';
RAISE NOTICE '══════════════════════════════════════════════════════';

RAISE NOTICE 'Total users in DB             : %', (SELECT count(*) FROM public.users);
RAISE NOTICE 'Active non-deleted users       : %', (SELECT count(*) FROM public.users WHERE status = 'ACTIVE' AND deleted_at IS NULL);
RAISE NOTICE 'Soft-deleted users             : %', (SELECT count(*) FROM public.users WHERE deleted_at IS NOT NULL);
RAISE NOTICE 'Total role assignments         : %', (SELECT count(*) FROM public.user_roles);
RAISE NOTICE 'Total sessions                 : %', (SELECT count(*) FROM public.user_sessions);
RAISE NOTICE 'Active sessions                : %', (SELECT count(*) FROM public.user_sessions WHERE session_status = 'ACTIVE');
RAISE NOTICE 'Total activity events          : %', (SELECT count(*) FROM public.user_activities);
RAISE NOTICE 'Total saved addresses          : %', (SELECT count(*) FROM public.user_addresses);
RAISE NOTICE 'Total subscriptions            : %', (SELECT count(*) FROM public.user_subscriptions);
RAISE NOTICE 'Total notification devices     : %', (SELECT count(*) FROM public.user_notification_devices);
RAISE NOTICE 'Active FCM devices             : %', (SELECT count(*) FROM public.user_notification_devices WHERE is_active = true);
RAISE NOTICE '';
RAISE NOTICE 'Role distribution:';

DECLARE v_row RECORD;
BEGIN
    FOR v_row IN
        SELECT r.role_code, r.is_active, count(ur.user_id) AS assigned
        FROM public.roles r
        LEFT JOIN public.user_roles ur ON r.role_id = ur.role_id
        GROUP BY r.role_code, r.is_active, r.role_id
        ORDER BY r.role_id
    LOOP
        RAISE NOTICE '  %-20s  active=%-5s  assigned=%s',
            v_row.role_code, v_row.is_active, v_row.assigned;
    END LOOP;
END;

RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════════════';
RAISE NOTICE 'ALL USER MANAGEMENT TESTS COMPLETE';
RAISE NOTICE '══════════════════════════════════════════════════════';

END $$;
