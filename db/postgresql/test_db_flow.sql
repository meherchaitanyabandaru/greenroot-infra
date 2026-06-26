-- =============================================================================
-- GreenRoot V1 — End-to-End Flow Test
-- =============================================================================
-- Run AFTER greenroot_schema.sql on a test / dev database.
-- Tests the complete business journey: user registration → nursery → quotation
-- → order → loading → dispatch → delivery, plus plant requests and payments.
--
-- Each step prints PASS or FAIL with a description.
-- Run:  psql "$DATABASE_URL" -f test_db_flow.sql
-- =============================================================================

DO $$
DECLARE
    -- user IDs
    v_admin_id          BIGINT;
    v_super_admin_id    BIGINT;
    v_owner_id          BIGINT;
    v_manager1_id       BIGINT;
    v_manager2_id       BIGINT;
    v_driver_id         BIGINT;
    v_buyer_id          BIGINT;
    v_buyer2_nursery_id BIGINT;

    -- entity IDs
    v_nursery_id        BIGINT;
    v_nursery2_id       BIGINT;
    v_driver_profile_id BIGINT;
    v_vehicle_id        BIGINT;
    v_plant_id          BIGINT;
    v_plant2_id         BIGINT;
    v_inventory_id      BIGINT;
    v_quotation_id      BIGINT;
    v_quotation_code    VARCHAR;
    v_order_id          BIGINT;
    v_order_code        VARCHAR;
    v_order_item_id     BIGINT;
    v_dispatch_id       BIGINT;
    v_dispatch_code     VARCHAR;
    v_payment_id        BIGINT;
    v_request_id        BIGINT;
    v_invite_id         BIGINT;
    v_invite_uuid       UUID;
    v_nd_id             BIGINT;   -- nursery_driver connection

    -- temp counts
    v_count             INTEGER;

BEGIN
    RAISE NOTICE '══════════════════════════════════════════════════════';
    RAISE NOTICE 'GreenRoot V1 — End-to-End Flow Test';
    RAISE NOTICE '══════════════════════════════════════════════════════';

    -- ──────────────────────────────────────────────────────────────────────
    -- STEP 1: Create test users across all roles
    -- ──────────────────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '── STEP 1: Users ───────────────────────────────────';

    INSERT INTO public.users (first_name, last_name, mobile, mobile_verified, status)
    VALUES ('GreenRoot', 'SuperAdmin', '9000000000', true, 'ACTIVE')
    ON CONFLICT (mobile) DO UPDATE SET first_name = EXCLUDED.first_name
    RETURNING user_id INTO v_super_admin_id;

    INSERT INTO public.users (first_name, last_name, mobile, mobile_verified, status)
    VALUES ('Priya', 'Owner', '9001100001', true, 'ACTIVE')
    ON CONFLICT (mobile) DO UPDATE SET first_name = EXCLUDED.first_name
    RETURNING user_id INTO v_owner_id;

    INSERT INTO public.users (first_name, last_name, mobile, mobile_verified, status)
    VALUES ('Suresh', 'Manager', '9001100002', true, 'ACTIVE')
    ON CONFLICT (mobile) DO UPDATE SET first_name = EXCLUDED.first_name
    RETURNING user_id INTO v_manager1_id;

    INSERT INTO public.users (first_name, last_name, mobile, mobile_verified, status)
    VALUES ('Kavya', 'Manager2', '9001100003', true, 'ACTIVE')
    ON CONFLICT (mobile) DO UPDATE SET first_name = EXCLUDED.first_name
    RETURNING user_id INTO v_manager2_id;

    INSERT INTO public.users (first_name, last_name, mobile, mobile_verified, status)
    VALUES ('Raju', 'Driver', '9001100004', true, 'ACTIVE')
    ON CONFLICT (mobile) DO UPDATE SET first_name = EXCLUDED.first_name
    RETURNING user_id INTO v_driver_id;

    INSERT INTO public.users (first_name, last_name, mobile, mobile_verified, status)
    VALUES ('Arjun', 'Buyer', '9001100005', true, 'ACTIVE')
    ON CONFLICT (mobile) DO UPDATE SET first_name = EXCLUDED.first_name
    RETURNING user_id INTO v_buyer_id;

    INSERT INTO public.users (first_name, last_name, mobile, mobile_verified, status)
    VALUES ('Buyer', 'Nursery', '9001100006', true, 'ACTIVE')
    ON CONFLICT (mobile) DO UPDATE SET first_name = EXCLUDED.first_name
    RETURNING user_id INTO v_buyer2_nursery_id;

    -- Assign roles
    INSERT INTO public.user_roles (user_id, role_id)
    SELECT v_super_admin_id, role_id FROM public.roles WHERE role_code = 'SUPER_ADMIN'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.user_roles (user_id, role_id)
    SELECT v_owner_id, role_id FROM public.roles WHERE role_code = 'NURSERY_OWNER'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.user_roles (user_id, role_id)
    SELECT v_manager1_id, role_id FROM public.roles WHERE role_code = 'MANAGER'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.user_roles (user_id, role_id)
    SELECT v_manager2_id, role_id FROM public.roles WHERE role_code = 'MANAGER'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.user_roles (user_id, role_id)
    SELECT v_driver_id, role_id FROM public.roles WHERE role_code = 'DRIVER'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.user_roles (user_id, role_id)
    SELECT v_buyer_id, role_id FROM public.roles WHERE role_code = 'BUYER'
    ON CONFLICT DO NOTHING;

    SELECT count(*) INTO v_count
    FROM public.users
    WHERE mobile IN ('9001100001','9001100002','9001100003','9001100004','9001100005','9001100006');

    IF v_count = 6 THEN
        RAISE NOTICE 'PASS  6 test users created (owner, 2 managers, driver, buyer, buyer-nursery)';
    ELSE
        RAISE NOTICE 'FAIL  Expected 6 users, got %', v_count;
    END IF;

    -- ──────────────────────────────────────────────────────────────────────
    -- STEP 2: Create nurseries
    -- ──────────────────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '── STEP 2: Nurseries ───────────────────────────────';

    INSERT INTO public.nurseries (nursery_name, owner_user_id, mobile, gst_number, status)
    VALUES ('Priya Green Nursery', v_owner_id, '9001100001', 'GST29ABCDE1234F1Z5', 'ACTIVE')
    ON CONFLICT (owner_user_id) DO UPDATE SET nursery_name = EXCLUDED.nursery_name
    RETURNING nursery_id INTO v_nursery_id;

    INSERT INTO public.nursery_addresses (nursery_id, address_type, address_line1, city, state, postal_code, latitude, longitude, is_primary)
    VALUES (v_nursery_id, 'FARM', 'Survey No. 45, Banjara Hills', 'Hyderabad', 'Telangana', '500034', 17.4126, 78.4483, true);

    INSERT INTO public.nurseries (nursery_name, owner_user_id, mobile, status)
    VALUES ('Buyer Nursery Farm', v_buyer2_nursery_id, '9001100006', 'ACTIVE')
    ON CONFLICT (owner_user_id) DO UPDATE SET nursery_name = EXCLUDED.nursery_name
    RETURNING nursery_id INTO v_nursery2_id;

    SELECT count(*) INTO v_count FROM public.nurseries WHERE nursery_id IN (v_nursery_id, v_nursery2_id);
    IF v_count = 2 THEN
        RAISE NOTICE 'PASS  2 nurseries created (NUR codes auto-assigned)';
    ELSE
        RAISE NOTICE 'FAIL  Expected 2 nurseries, got %', v_count;
    END IF;

    -- ──────────────────────────────────────────────────────────────────────
    -- STEP 3: Assign managers to nursery
    -- ──────────────────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '── STEP 3: Managers ────────────────────────────────';

    INSERT INTO public.nursery_users (nursery_id, user_id, role, status, invited_by_user_id)
    VALUES
      (v_nursery_id, v_manager1_id, 'MANAGER', 'ACTIVE', v_owner_id),
      (v_nursery_id, v_manager2_id, 'MANAGER', 'ACTIVE', v_owner_id)
    ON CONFLICT (nursery_id, user_id, nursery_role_id) DO NOTHING;

    SELECT count(*) INTO v_count
    FROM public.nursery_users
    WHERE nursery_id = v_nursery_id AND role = 'MANAGER' AND status = 'ACTIVE';

    IF v_count = 2 THEN
        RAISE NOTICE 'PASS  2 managers linked to nursery';
    ELSE
        RAISE NOTICE 'FAIL  Expected 2 managers, got %', v_count;
    END IF;

    -- ──────────────────────────────────────────────────────────────────────
    -- STEP 4: Register driver and connect to nursery
    -- ──────────────────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '── STEP 4: Driver ──────────────────────────────────';

    INSERT INTO public.drivers (user_id, license_number, license_expiry_date, profile_status, approval_status, approved_by_user_id, approved_at)
    VALUES (v_driver_id, 'TS09 2025 0123456', '2028-12-31', 'COMPLETE', 'APPROVED', v_super_admin_id, CURRENT_TIMESTAMP)
    ON CONFLICT (user_id) DO UPDATE SET approval_status = 'APPROVED'
    RETURNING driver_id INTO v_driver_profile_id;

    INSERT INTO public.nursery_drivers (nursery_id, driver_user_id, invited_by_user_id, approved_by_user_id, connection_status, connected_at)
    VALUES (v_nursery_id, v_driver_id, v_manager1_id, v_owner_id, 'APPROVED', CURRENT_TIMESTAMP)
    ON CONFLICT (nursery_id, driver_user_id) DO UPDATE SET connection_status = 'APPROVED'
    RETURNING id INTO v_nd_id;

    IF (SELECT approval_status FROM public.drivers WHERE driver_id = v_driver_profile_id) = 'APPROVED' THEN
        RAISE NOTICE 'PASS  Driver approved and connected to nursery (nursery_driver id=%)', v_nd_id;
    ELSE
        RAISE NOTICE 'FAIL  Driver not approved correctly';
    END IF;

    -- ──────────────────────────────────────────────────────────────────────
    -- STEP 5: Register vehicle
    -- ──────────────────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '── STEP 5: Vehicle ─────────────────────────────────';

    INSERT INTO public.vehicles (vehicle_number, vehicle_type, capacity_kg, owner_name, mobile, status)
    VALUES ('TS09 EA 5678', 'TEMPO', 2000.00, 'Raju Transports', '9001100004', 'ACTIVE')
    ON CONFLICT (vehicle_number) DO UPDATE SET status = 'ACTIVE'
    RETURNING vehicle_id INTO v_vehicle_id;

    RAISE NOTICE 'PASS  Vehicle registered (id=%)', v_vehicle_id;

    -- ──────────────────────────────────────────────────────────────────────
    -- STEP 6: Add plants and inventory
    -- ──────────────────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '── STEP 6: Plants & Inventory ──────────────────────';

    INSERT INTO public.plants (scientific_name, common_name, plant_type, light_requirement, water_requirement, is_active)
    VALUES ('Ficus benghalensis', 'Banyan', 'TREE', 'FULL_SUN', 'MODERATE', true)
    ON CONFLICT (scientific_name) DO UPDATE SET is_active = true
    RETURNING plant_id INTO v_plant_id;

    INSERT INTO public.plants (scientific_name, common_name, plant_type, light_requirement, water_requirement, is_active)
    VALUES ('Delonix regia', 'Gulmohar', 'TREE', 'FULL_SUN', 'LOW', true)
    ON CONFLICT (scientific_name) DO UPDATE SET is_active = true
    RETURNING plant_id INTO v_plant2_id;

    INSERT INTO public.nursery_inventory (nursery_id, plant_id, size_id, available_quantity, inventory_status, last_updated_by)
    VALUES (v_nursery_id, v_plant_id, 4, 150, 'AVAILABLE', v_manager1_id)
    ON CONFLICT (nursery_id, plant_id, size_id) DO UPDATE SET available_quantity = 150
    RETURNING inventory_id INTO v_inventory_id;

    INSERT INTO public.nursery_inventory (nursery_id, plant_id, size_id, available_quantity, inventory_status, last_updated_by)
    VALUES (v_nursery_id, v_plant2_id, 3, 80, 'AVAILABLE', v_manager1_id)
    ON CONFLICT (nursery_id, plant_id, size_id) DO UPDATE SET available_quantity = 80;

    SELECT count(*) INTO v_count FROM public.nursery_inventory WHERE nursery_id = v_nursery_id;
    RAISE NOTICE 'PASS  % inventory lines added for nursery', v_count;

    -- ──────────────────────────────────────────────────────────────────────
    -- STEP 7: Create quotation and add line items
    -- ──────────────────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '── STEP 7: Quotation ───────────────────────────────';

    INSERT INTO public.quotations (
        quotation_code, created_by_user_id, created_by_name,
        nursery_id, nursery_name, nursery_phone,
        customer_name, customer_mobile,
        assigned_manager_user_id, total_amount, status
    )
    VALUES (
        public.next_public_code('quotations', 'QUO', 4, true),
        v_manager1_id, 'Suresh Manager',
        v_nursery_id, 'Priya Green Nursery', '9001100001',
        'Arjun Buyer', '9001100005',
        v_manager1_id, 0, 'DRAFT'
    )
    RETURNING quotation_id, quotation_code INTO v_quotation_id, v_quotation_code;

    INSERT INTO public.quotation_items (quotation_id, plant_id, scientific_name, common_name, plant_name_snapshot, size, quantity, unit_price, total_price)
    VALUES
      (v_quotation_id, v_plant_id,  'Ficus benghalensis', 'Banyan',   'Banyan',   'MEDIUM', 20, 850.00, 17000.00),
      (v_quotation_id, v_plant2_id, 'Delonix regia',      'Gulmohar', 'Gulmohar', 'SMALL',  15, 450.00, 6750.00);

    UPDATE public.quotations
    SET total_amount = (SELECT COALESCE(SUM(total_price), 0) FROM public.quotation_items WHERE quotation_id = v_quotation_id)
    WHERE quotation_id = v_quotation_id;

    SELECT total_amount INTO v_count FROM public.quotations WHERE quotation_id = v_quotation_id;
    IF v_count = 23750 THEN
        RAISE NOTICE 'PASS  Quotation % created, total = ₹23,750', v_quotation_code;
    ELSE
        RAISE NOTICE 'FAIL  Quotation total mismatch: expected 23750, got %', v_count;
    END IF;

    -- ──────────────────────────────────────────────────────────────────────
    -- STEP 8: Convert quotation to order
    -- ──────────────────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '── STEP 8: Convert Quotation → Order ───────────────';

    -- Mark quotation SENT first, then CONVERTED
    UPDATE public.quotations SET status = 'SENT' WHERE quotation_id = v_quotation_id;

    INSERT INTO public.orders (
        order_number, order_code,
        nursery_id, seller_nursery_id,
        quotation_id, customer_user_id, customer_name, customer_mobile,
        assigned_manager_user_id, created_by_user_id,
        total_amount, order_status, order_date
    )
    VALUES (
        'ORD-TEST-001',
        public.next_public_code('orders', 'ORD', 4, true),
        v_nursery_id, v_nursery_id,
        v_quotation_id, v_buyer_id, 'Arjun Buyer', '9001100005',
        v_manager1_id, v_manager1_id,
        23750.00, 'CONFIRMED', CURRENT_TIMESTAMP
    )
    RETURNING order_id, order_code INTO v_order_id, v_order_code;

    -- Copy quotation items to order items
    INSERT INTO public.order_items (order_id, plant_id, plant_name_snapshot, size, quantity, unit_price, total_price)
    SELECT v_order_id, qi.plant_id, qi.plant_name_snapshot, qi.size, qi.quantity, qi.unit_price, qi.total_price
    FROM public.quotation_items qi
    WHERE qi.quotation_id = v_quotation_id;

    -- Mark quotation as converted
    UPDATE public.quotations
    SET status = 'CONVERTED',
        converted_order_id = v_order_id,
        converted_by_user_id = v_manager1_id,
        converted_at = CURRENT_TIMESTAMP
    WHERE quotation_id = v_quotation_id;

    SELECT count(*) INTO v_count FROM public.order_items WHERE order_id = v_order_id;
    IF v_count = 2 THEN
        RAISE NOTICE 'PASS  Order % created from quotation %, 2 items copied', v_order_code, v_quotation_code;
    ELSE
        RAISE NOTICE 'FAIL  Expected 2 order items, got %', v_count;
    END IF;

    IF (SELECT status FROM public.quotations WHERE quotation_id = v_quotation_id) = 'CONVERTED' THEN
        RAISE NOTICE 'PASS  Quotation marked CONVERTED with back-link to order';
    ELSE
        RAISE NOTICE 'FAIL  Quotation not marked CONVERTED';
    END IF;

    -- ──────────────────────────────────────────────────────────────────────
    -- STEP 9: Loading workflow
    -- ──────────────────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '── STEP 9: Loading ─────────────────────────────────';

    UPDATE public.orders
    SET order_status = 'LOADING',
        loading_started_at = CURRENT_TIMESTAMP
    WHERE order_id = v_order_id;

    -- Deduct from inventory
    UPDATE public.nursery_inventory
    SET available_quantity = available_quantity - 20,
        last_updated_by = v_manager1_id,
        last_updated_at = CURRENT_TIMESTAMP
    WHERE nursery_id = v_nursery_id AND plant_id = v_plant_id AND size_id = 4;

    UPDATE public.nursery_inventory
    SET available_quantity = available_quantity - 15,
        last_updated_by = v_manager1_id,
        last_updated_at = CURRENT_TIMESTAMP
    WHERE nursery_id = v_nursery_id AND plant_id = v_plant2_id AND size_id = 3;

    UPDATE public.orders
    SET order_status = 'LOADING_COMPLETE',
        loading_completed_at = CURRENT_TIMESTAMP,
        loading_completed_by_user_id = v_manager1_id
    WHERE order_id = v_order_id;

    IF (SELECT order_status FROM public.orders WHERE order_id = v_order_id) = 'LOADING_COMPLETE' THEN
        RAISE NOTICE 'PASS  Loading completed; inventory deducted';
    ELSE
        RAISE NOTICE 'FAIL  Loading status not updated correctly';
    END IF;

    SELECT available_quantity INTO v_count
    FROM public.nursery_inventory
    WHERE nursery_id = v_nursery_id AND plant_id = v_plant_id AND size_id = 4;

    IF v_count = 130 THEN
        RAISE NOTICE 'PASS  Banyan MEDIUM inventory: 150 → 130 after deducting 20';
    ELSE
        RAISE NOTICE 'FAIL  Banyan inventory expected 130, got %', v_count;
    END IF;

    -- ──────────────────────────────────────────────────────────────────────
    -- STEP 10: Create dispatch and assign driver + vehicle
    -- ──────────────────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '── STEP 10: Dispatch ───────────────────────────────';

    INSERT INTO public.dispatches (
        order_id, nursery_id, dispatch_status,
        dispatched_by, assigned_manager_user_id,
        vehicle_id, driver_id, driver_user_id,
        customer_user_id, customer_name_snapshot, customer_mobile_snapshot,
        destination_address, dispatch_date
    )
    VALUES (
        v_order_id, v_nursery_id, 'CREATED',
        v_manager1_id, v_manager1_id,
        v_vehicle_id, v_driver_profile_id, v_driver_id,
        v_buyer_id, 'Arjun Buyer', '9001100005',
        'Plot 12, Green Valley, Jubilee Hills, Hyderabad 500033',
        CURRENT_TIMESTAMP
    )
    RETURNING dispatch_id, dispatch_code INTO v_dispatch_id, v_dispatch_code;

    -- Add dispatch items (all order items in one trip)
    INSERT INTO public.dispatch_items (dispatch_id, order_item_id, quantity)
    SELECT v_dispatch_id, order_item_id, quantity
    FROM public.order_items
    WHERE order_id = v_order_id;

    -- Update order status to DISPATCHED
    UPDATE public.orders SET order_status = 'DISPATCHED', updated_at = CURRENT_TIMESTAMP
    WHERE order_id = v_order_id;

    RAISE NOTICE 'PASS  Dispatch % created for order %', v_dispatch_code, v_order_code;

    -- ──────────────────────────────────────────────────────────────────────
    -- STEP 11: Create trip tracking link
    -- ──────────────────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '── STEP 11: Trip Tracking ──────────────────────────';

    INSERT INTO public.trip_tracking_links (dispatch_id, customer_user_id, customer_mobile, expires_at, status)
    VALUES (v_dispatch_id, v_buyer_id, '9001100005', CURRENT_TIMESTAMP + INTERVAL '24 hours', 'ACTIVE');

    RAISE NOTICE 'PASS  Tracking link created (expires in 24 hours)';

    -- ──────────────────────────────────────────────────────────────────────
    -- STEP 12: Trip events — started → delivered
    -- ──────────────────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '── STEP 12: Trip Events ────────────────────────────';

    -- Driver starts trip
    UPDATE public.dispatches
    SET dispatch_status = 'IN_TRANSIT',
        trip_started_at = CURRENT_TIMESTAMP,
        trip_started_by_user_id = v_driver_id
    WHERE dispatch_id = v_dispatch_id;

    INSERT INTO public.trip_events (dispatch_id, event_type, latitude, longitude, remarks, created_by_user_id)
    VALUES
      (v_dispatch_id, 'TRIP_STARTED',   17.4126, 78.4483, 'Left nursery gate', v_driver_id),
      (v_dispatch_id, 'EN_ROUTE',       17.4200, 78.4600, 'On NH44',            v_driver_id),
      (v_dispatch_id, 'ARRIVED',        17.4320, 78.4200, 'Reached customer location', v_driver_id),
      (v_dispatch_id, 'DELIVERED',      17.4320, 78.4200, 'All plants unloaded', v_driver_id);

    -- Driver also posts GPS breadcrumbs
    INSERT INTO public.vehicle_tracking (vehicle_id, driver_id, dispatch_id, latitude, longitude)
    VALUES
      (v_vehicle_id, v_driver_profile_id, v_dispatch_id, 17.4126, 78.4483),
      (v_vehicle_id, v_driver_profile_id, v_dispatch_id, 17.4200, 78.4600),
      (v_vehicle_id, v_driver_profile_id, v_dispatch_id, 17.4320, 78.4200);

    -- Complete dispatch
    UPDATE public.dispatches
    SET dispatch_status = 'DELIVERED', completed_at = CURRENT_TIMESTAMP
    WHERE dispatch_id = v_dispatch_id;

    UPDATE public.orders
    SET order_status = 'DELIVERED', updated_at = CURRENT_TIMESTAMP
    WHERE order_id = v_order_id;

    SELECT count(*) INTO v_count FROM public.trip_events WHERE dispatch_id = v_dispatch_id;
    IF v_count = 4 THEN
        RAISE NOTICE 'PASS  4 trip events logged; dispatch and order marked DELIVERED';
    ELSE
        RAISE NOTICE 'FAIL  Expected 4 trip events, got %', v_count;
    END IF;

    -- ──────────────────────────────────────────────────────────────────────
    -- STEP 13: Record payment
    -- ──────────────────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '── STEP 13: Payment ────────────────────────────────';

    INSERT INTO public.payments (
        order_id, payment_for, payer_user_id,
        amount, payment_method, payment_status, payment_date,
        provider, provider_payment_id, notes
    )
    VALUES (
        v_order_id, 'ORDER', v_buyer_id,
        23750.00, 'RAZORPAY', 'COMPLETED', CURRENT_TIMESTAMP,
        'razorpay', 'pay_test_' || substr(md5(random()::TEXT), 1, 14),
        'Full payment received online'
    )
    RETURNING payment_id INTO v_payment_id;

    IF (SELECT payment_status FROM public.payments WHERE payment_id = v_payment_id) = 'COMPLETED' THEN
        RAISE NOTICE 'PASS  Payment of ₹23,750 recorded (RAZORPAY)';
    ELSE
        RAISE NOTICE 'FAIL  Payment status incorrect';
    END IF;

    -- ──────────────────────────────────────────────────────────────────────
    -- STEP 14: Invite flow — manager invite with UUID token
    -- ──────────────────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '── STEP 14: Invite Flow ────────────────────────────';

    INSERT INTO public.invites (invite_type, invited_by_user_id, nursery_id, role, target_mobile, target_name, status, expires_at)
    VALUES ('MANAGER', v_owner_id, v_nursery_id, 'MANAGER', '9001199999', 'New Manager Test', 'PENDING', CURRENT_TIMESTAMP + INTERVAL '7 days')
    RETURNING id, invite_uuid INTO v_invite_id, v_invite_uuid;

    IF v_invite_uuid IS NOT NULL THEN
        RAISE NOTICE 'PASS  Manager invite created (uuid=%)', v_invite_uuid;
    ELSE
        RAISE NOTICE 'FAIL  Invite UUID not generated';
    END IF;

    -- ──────────────────────────────────────────────────────────────────────
    -- STEP 15: Plant request flow
    -- ──────────────────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '── STEP 15: Plant Request (Inter-Nursery) ──────────';

    INSERT INTO public.plant_requests (
        requesting_nursery_id, requested_by_user_id, plant_id, size_id,
        quantity_required, required_by_date, radius_km, notes, status
    )
    VALUES (v_nursery2_id, v_buyer2_nursery_id, v_plant_id, 5, 50, CURRENT_DATE + 14, 100, 'Urgently need large Banyan trees', 'OPEN')
    RETURNING request_id INTO v_request_id;

    -- Priya's nursery responds to the request
    INSERT INTO public.plant_request_responses (request_id, supplier_nursery_id, responded_by_user_id, available_quantity, remarks, status)
    VALUES (v_request_id, v_nursery_id, v_manager1_id, 40, 'Can supply 40 LARGE Banyan trees by end of week', 'AVAILABLE');

    SELECT count(*) INTO v_count FROM public.plant_request_responses WHERE request_id = v_request_id;
    IF v_count = 1 THEN
        RAISE NOTICE 'PASS  Plant request created and 1 supplier responded';
    ELSE
        RAISE NOTICE 'FAIL  Expected 1 response, got %', v_count;
    END IF;

    -- ──────────────────────────────────────────────────────────────────────
    -- STEP 16: Notification test
    -- ──────────────────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '── STEP 16: Notification ───────────────────────────';

    INSERT INTO public.notifications (user_id, notification_type, title, message, channel, notification_status)
    VALUES (v_buyer_id, 'ORDER_UPDATE', 'Order Delivered!',
            'Your order ' || v_order_code || ' has been delivered. Thank you!',
            'PUSH', 'SENT');

    INSERT INTO public.notifications (user_id, notification_type, title, message, channel, notification_status)
    VALUES (v_manager1_id, 'ORDER_UPDATE', 'New order received',
            'Order ' || v_order_code || ' confirmed. Please prepare loading.',
            'PUSH', 'SENT');

    SELECT count(*) INTO v_count FROM public.notifications WHERE user_id IN (v_buyer_id, v_manager1_id);
    IF v_count >= 2 THEN
        RAISE NOTICE 'PASS  % notifications sent', v_count;
    ELSE
        RAISE NOTICE 'FAIL  Notifications not created correctly';
    END IF;

    -- ──────────────────────────────────────────────────────────────────────
    -- STEP 17: Public code validation
    -- ──────────────────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '── STEP 17: Public Codes ───────────────────────────';

    RAISE NOTICE 'PASS  Nursery code  = %', (SELECT nursery_code FROM public.nurseries WHERE nursery_id = v_nursery_id);
    RAISE NOTICE 'PASS  Quotation     = %', v_quotation_code;
    RAISE NOTICE 'PASS  Order code    = %', v_order_code;
    RAISE NOTICE 'PASS  Dispatch code = %', v_dispatch_code;
    RAISE NOTICE 'PASS  Driver code   = %', (SELECT driver_code FROM public.drivers WHERE driver_id = v_driver_profile_id);
    RAISE NOTICE 'PASS  Vehicle code  = %', (SELECT vehicle_code FROM public.vehicles WHERE vehicle_id = v_vehicle_id);

    -- ──────────────────────────────────────────────────────────────────────
    -- STEP 18: Final data summary
    -- ──────────────────────────────────────────────────────────────────────
    RAISE NOTICE '';
    RAISE NOTICE '── STEP 18: Data Summary ───────────────────────────';

    RAISE NOTICE 'Users              : %', (SELECT count(*) FROM public.users);
    RAISE NOTICE 'Nurseries          : %', (SELECT count(*) FROM public.nurseries);
    RAISE NOTICE 'Plants             : %', (SELECT count(*) FROM public.plants);
    RAISE NOTICE 'Inventory lines    : %', (SELECT count(*) FROM public.nursery_inventory);
    RAISE NOTICE 'Quotations         : %', (SELECT count(*) FROM public.quotations);
    RAISE NOTICE 'Orders             : %', (SELECT count(*) FROM public.orders);
    RAISE NOTICE 'Dispatches         : %', (SELECT count(*) FROM public.dispatches);
    RAISE NOTICE 'Trip events        : %', (SELECT count(*) FROM public.trip_events);
    RAISE NOTICE 'Vehicle trackings  : %', (SELECT count(*) FROM public.vehicle_tracking);
    RAISE NOTICE 'Payments           : %', (SELECT count(*) FROM public.payments);
    RAISE NOTICE 'Plant requests     : %', (SELECT count(*) FROM public.plant_requests);
    RAISE NOTICE 'Invites            : %', (SELECT count(*) FROM public.invites);
    RAISE NOTICE 'Notifications      : %', (SELECT count(*) FROM public.notifications);

    RAISE NOTICE '';
    RAISE NOTICE '══════════════════════════════════════════════════════';
    RAISE NOTICE 'All tests completed. Check for any FAIL lines above.';
    RAISE NOTICE '══════════════════════════════════════════════════════';

END;
$$;
