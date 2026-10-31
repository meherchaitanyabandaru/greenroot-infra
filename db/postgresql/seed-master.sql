-- =============================================================================
-- GreenRoot master/reference seed
-- =============================================================================
-- Loads only platform/reference data required by the application.
-- Customer-facing users use the BUYER role; CUSTOMER is not an RBAC role.
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- Platform roles
INSERT INTO public.roles (role_id, role_code, role_name, description, is_active) VALUES
  (1, 'ADMIN',              'Admin',              'Platform administrator',           true),
  (2, 'BUYER',              'Buyer',              'Plant buyer / customer',           true),
  (3, 'NURSERY_OWNER',      'Nursery Owner',      'Nursery owner',                    true),
  (4, 'DRIVER',             'Driver',             'Delivery driver',                  true),
  (5, 'MANAGER',            'Manager',            'Nursery manager',                  true),
  (6, 'SUPER_ADMIN',        'Super Admin',        'Platform super administrator',     true);

SELECT setval('public.roles_role_id_seq', (SELECT max(role_id) FROM public.roles), true);

-- Plant sizes
INSERT INTO public.plant_sizes (size_id, size_code, display_name, display_order, is_active) VALUES
  (1, 'SEED',        'Seed',        1, true),
  (2, 'SAPLING',     'Sapling',     2, true),
  (3, 'SMALL',       'Small',       3, true),
  (4, 'MEDIUM',      'Medium',      4, true),
  (5, 'LARGE',       'Large',       5, true),
  (6, 'EXTRA_LARGE', 'Extra Large', 6, true);

SELECT setval('public.plant_sizes_size_id_seq', (SELECT max(size_id) FROM public.plant_sizes), true);

-- Plant categories: none. Admin → Categories lists the World Flora Online
-- families in public.botanical_names instead.

-- Platform config
INSERT INTO public.platform_config (config_key, config_value, data_type, description) VALUES
  ('otp_expiry_minutes',      '5',    'integer', 'OTP validity window in minutes'),
  ('otp_max_attempts',        '5',    'integer', 'Wrong OTP attempts before the code is blocked'),
  ('otp_resend_cooldown_sec', '30',   'integer', 'Seconds a user must wait before requesting another OTP'),
  ('min_order_amount',        '100',  'numeric', 'Minimum order total in INR'),
  ('platform_fee_pct',        '0',    'numeric', 'Platform fee percentage applied to orders'),
  ('driver_approval_days',    '3',    'integer', 'Days before a pending driver approval auto-expires'),
  ('nursery_approval_days',   '7',    'integer', 'Days before a pending nursery application auto-expires'),
  ('assistant_enabled',         'true', 'boolean', 'Mango AI on for owners, managers and customers (the API''s AI_ENABLED must also be on)'),
  ('assistant_daily_questions', '5',    'integer', 'Mango AI questions each user may ask per day (India time)')
ON CONFLICT (config_key) DO NOTHING;

-- Subscription plans
INSERT INTO public.subscription_plans
  (plan_code, plan_name, description, monthly_price, yearly_price, max_managers, is_active, features)
VALUES
  ('FREE',
   'Free',
   'Free starter plan for public buying and basic GreenRoot access.',
   0.00, 0.00, 0, true,
   '{"support":"community","analytics":"none","max_managers":0,"billing_cycles":["FREE"],"unlimited_orders":false,"unlimited_quotations":false,"market_posts_per_day":0}'::jsonb),
  ('TRIAL',
   'Community Trial',
   '1-month free trial for new approved nurseries.',
   0.00, 0.00, 1, true,
   '{"support":"community","analytics":"basic","max_managers":1,"billing_cycles":["TRIAL"],"unlimited_orders":true,"unlimited_quotations":true,"local_market_ads":true,"market_posts_per_day":3}'::jsonb),
  -- Paid plans are priced monthly; the API prices quarterly / half-yearly /
  -- yearly from monthly_price (5 / 10 / 15 % off). yearly_price is kept in step.
  -- Shown as Silver / Gold / Platinum; the codes stay BASIC / GROWTH / ENTERPRISE.
  ('GROWTH',
   'Gold',
   'For growing nurseries with a team of managers.',
   499.00, 5089.80, 5, true,
   '{"tier":"GOLD","support":"email","analytics":"full","max_managers":5,"billing_cycles":["MONTHLY","QUARTERLY","SIX_MONTH","YEARLY"],"unlimited_orders":true,"unlimited_quotations":true,"local_market_ads":true,"market_posts_per_day":5}'::jsonb),
  ('ENTERPRISE',
   'Platinum',
   'For large nursery operations, with priority support.',
   999.00, 10189.80, 10, true,
   '{"tier":"PLATINUM","support":"priority","analytics":"advanced","max_managers":10,"billing_cycles":["MONTHLY","QUARTERLY","SIX_MONTH","YEARLY"],"unlimited_orders":true,"unlimited_quotations":true,"local_market_ads":true,"market_posts_per_day":null}'::jsonb),
  -- Added last so the ids above stay as they were.
  ('BASIC',
   'Silver',
   'For small nurseries run by the owner and one manager.',
   299.00, 3049.80, 1, true,
   '{"tier":"SILVER","support":"community","analytics":"basic","max_managers":1,"billing_cycles":["MONTHLY","QUARTERLY","SIX_MONTH","YEARLY"],"unlimited_orders":true,"unlimited_quotations":true,"local_market_ads":true,"market_posts_per_day":3}'::jsonb);

-- Plant catalogue
-- wfo_id: World Flora Online record for the exact scientific_name (public.botanical_names)
INSERT INTO public.plants (scientific_name, common_name, plant_type, light_requirement, water_requirement, english_description, is_active, wfo_id) VALUES
  ('Mangifera indica',         'Mango',           'TREE',    'FULL_SUN',    'HIGH',     'Popular tropical fruit tree.', true, 'wfo-0000371248'),
  ('Azadirachta indica',       'Neem',            'TREE',    'FULL_SUN',    'LOW',      'Hardy medicinal shade tree.', true, 'wfo-0000557668'),
  ('Hibiscus rosa-sinensis',   'Hibiscus',        'SHRUB',   'FULL_SUN',    'MODERATE', 'Flowering ornamental shrub.', true, 'wfo-0000723007'),
  ('Cocos nucifera',           'Coconut',         'TREE',    'FULL_SUN',    'HIGH',     'Coastal palm producing coconuts.', true, 'wfo-0000903570'),
  ('Moringa oleifera',         'Drumstick',       'TREE',    'FULL_SUN',    'LOW',      'Fast-growing edible tree.', true, 'wfo-0001085051'),
  ('Ocimum tenuiflorum',       'Tulsi',           'HERB',    'FULL_SUN',    'MODERATE', 'Sacred basil and medicinal herb.', true, 'wfo-0000253537'),
  ('Aloe vera',                'Aloe Vera',       'SHRUB',   'FULL_SUN',    'LOW',      'Low-maintenance succulent.', true, 'wfo-0000758976'),
  ('Psidium guajava',          'Guava',           'TREE',    'FULL_SUN',    'MODERATE', 'Fast-fruiting tropical tree.', true, 'wfo-0000284421'),
  ('Rosa indica',              'Rose',            'SHRUB',   'FULL_SUN',    'MODERATE', 'Classic flowering shrub.', true, 'wfo-0001014404'),
  ('Catharanthus roseus',      'Periwinkle',      'HERB',    'FULL_SUN',    'MODERATE', 'Hardy flowering ground-cover.', true, 'wfo-0000819442'),
  ('Ficus benjamina',          'Weeping Fig',     'TREE',    'PARTIAL_SUN', 'MODERATE', 'Popular indoor ornamental tree.', true, 'wfo-0000687511'),
  ('Epipremnum aureum',        'Money Plant',     'CLIMBER', 'LOW_LIGHT',   'LOW',      'Easy indoor climber.', true, 'wfo-0000952367'),
  ('Sansevieria trifasciata',  'Snake Plant',     'SHRUB',   'LOW_LIGHT',   'LOW',      'Hardy indoor plant.', true, 'wfo-0000734376'),
  ('Plumeria rubra',           'Frangipani',      'TREE',    'FULL_SUN',    'LOW',      'Tropical fragrant flowering tree.', true, 'wfo-0000279184'),
  ('Duranta erecta',           'Golden Dewdrop',  'SHRUB',   'FULL_SUN',    'MODERATE', 'Fast-growing ornamental shrub.', true, 'wfo-0000946828');



SELECT setval('public.plants_plant_id_seq', (SELECT max(plant_id) FROM public.plants), true);
SELECT setval('public.plant_categories_category_id_seq', (SELECT max(category_id) FROM public.plant_categories), true);
SELECT setval('public.subscription_plans_plan_id_seq', (SELECT max(plan_id) FROM public.subscription_plans), true);

-- SMS / TRAI DLT registry. Everything starts DRAFT with no DLT IDs: fill pe_id,
-- dlt_header_id and dlt_template_id from the DLT portal (Admin > SMS / DLT) and
-- mark them APPROVED before switching SMS_PROVIDER off mock.
-- Template bodies must match the DLT-registered text character for character.
INSERT INTO public.sms_dlt_entities (entity_name, dlt_operator, status) VALUES
  ('GreenRoot', 'JIO', 'NOT_REGISTERED');

INSERT INTO public.sms_headers (header_id, header, header_type, status) VALUES
  (1, 'GRROOT', 'SERVICE', 'DRAFT');

SELECT setval('public.sms_headers_header_id_seq', (SELECT max(header_id) FROM public.sms_headers), true);

INSERT INTO public.sms_templates (template_code, template_name, category, header_id, body, variables) VALUES
  ('AUTH_LOGIN_OTP', 'Login OTP', 'SERVICE_IMPLICIT', 1,
   '{#numeric#} is your OTP to log in to GreenRoot. It is valid for {#numeric#} minutes. Do not share this OTP with anyone. - GreenRoot',
   '["otp", "valid_minutes"]'),
  ('AUTH_REGISTER_OTP', 'Registration OTP', 'SERVICE_IMPLICIT', 1,
   '{#numeric#} is your OTP to create your GreenRoot account. It is valid for {#numeric#} minutes. Do not share this OTP with anyone. - GreenRoot',
   '["otp", "valid_minutes"]'),
  ('ACCOUNT_WELCOME', 'Account created', 'SERVICE_IMPLICIT', 1,
   'Welcome to GreenRoot. Your account for the mobile number ending {#numeric#} has been created successfully. - GreenRoot',
   '["mobile_last4"]'),
  ('PAYMENT_RECEIVED_ORDER', 'Order payment received', 'SERVICE_IMPLICIT', 1,
   'Payment of Rs.{#numeric#}.{#numeric#} received for GreenRoot order ORD-{#numeric#}-{#numeric#}. Payment ref PAY-{#numeric#}-{#numeric#}. - GreenRoot',
   '["amount_rupees", "amount_paise", "order_date", "order_seq", "payment_date", "payment_seq"]'),
  ('PAYMENT_RECEIVED_SUBSCRIPTION', 'Subscription payment received', 'SERVICE_IMPLICIT', 1,
   'Payment of Rs.{#numeric#}.{#numeric#} received for your GreenRoot subscription. Payment ref PAY-{#numeric#}-{#numeric#}. - GreenRoot',
   '["amount_rupees", "amount_paise", "payment_date", "payment_seq"]'),
  ('PAYMENT_FAILED', 'Payment failed', 'SERVICE_IMPLICIT', 1,
   'Your payment of Rs.{#numeric#}.{#numeric#} on GreenRoot (ref PAY-{#numeric#}-{#numeric#}) was not successful. Please try again. - GreenRoot',
   '["amount_rupees", "amount_paise", "payment_date", "payment_seq"]');

-- Email channel. Set the From address in Admin > Email and mark the domain
-- verified (SPF/DKIM/DMARC) before switching EMAIL_PROVIDER off mock.
-- body_html is content only; the API wraps it in the shared layout.
INSERT INTO public.email_senders (from_name) VALUES ('GreenRoot');

INSERT INTO public.email_templates (template_code, template_name, subject, body_html, body_text) VALUES
  ('EMAIL_VERIFY_OTP', 'Email verification code', 'Verify your email for GreenRoot',
   $html$<p>Use this code to verify your email address on GreenRoot:</p>
<p style="font-size:30px;font-weight:bold;letter-spacing:6px;margin:16px 0;">{{otp}}</p>
<p>The code is valid for {{valid_minutes}} minutes. Never share it with anyone, including GreenRoot staff.</p>$html$,
   $text$Use this code to verify your email address on GreenRoot: {{otp}}

The code is valid for {{valid_minutes}} minutes. Never share it with anyone, including GreenRoot staff.$text$),

  ('PAYMENT_RECEIVED_ORDER', 'Order payment received', 'Payment received for order {{order_code}}',
   $html$<p>We have received your payment.</p>
<table role="presentation" cellpadding="6" cellspacing="0" style="border-collapse:collapse;margin:12px 0;">
<tr><td style="color:#6b7c72;">Amount</td><td style="font-weight:bold;">&#8377;{{amount}}</td></tr>
<tr><td style="color:#6b7c72;">Order</td><td>{{order_code}}</td></tr>
<tr><td style="color:#6b7c72;">Payment reference</td><td>{{payment_code}}</td></tr>
</table>
<p>You can see the order and its payments in the GreenRoot app.</p>$html$,
   $text$We have received your payment.

Amount: Rs.{{amount}}
Order: {{order_code}}
Payment reference: {{payment_code}}

You can see the order and its payments in the GreenRoot app.$text$),

  ('PAYMENT_RECEIVED_SUBSCRIPTION', 'Subscription payment received', 'Payment received for your GreenRoot subscription',
   $html$<p>We have received your subscription payment.</p>
<table role="presentation" cellpadding="6" cellspacing="0" style="border-collapse:collapse;margin:12px 0;">
<tr><td style="color:#6b7c72;">Amount</td><td style="font-weight:bold;">&#8377;{{amount}}</td></tr>
<tr><td style="color:#6b7c72;">Payment reference</td><td>{{payment_code}}</td></tr>
</table>
<p>Your plan details are in the GreenRoot app under Subscription.</p>$html$,
   $text$We have received your subscription payment.

Amount: Rs.{{amount}}
Payment reference: {{payment_code}}

Your plan details are in the GreenRoot app under Subscription.$text$),

  ('PAYMENT_FAILED', 'Payment failed', 'Your GreenRoot payment {{payment_code}} was not successful',
   $html$<p>Your payment of <strong>&#8377;{{amount}}</strong> (reference {{payment_code}}) was not successful.</p>
<p>Please try again from the GreenRoot app.</p>$html$,
   $text$Your payment of Rs.{{amount}} (reference {{payment_code}}) was not successful.

Please try again from the GreenRoot app.$text$);

-- Image upload rules per category (same as the API's built-in defaults; 2026-10-30).
-- Safe defaults (same as imagepolicy.Defaults), version 1.
INSERT INTO public.image_policies (category, max_side, min_side, quality, max_bytes, allowed_formats) VALUES
    ('SELFIE',           800,  200, 85, 1048576, '["JPEG", "PNG"]'),
    ('MARKET_AD',        1600, 400, 82, 2097152, '["JPEG"]'),
    ('NURSERY_BRANDING', 800,  200, 90, 1048576, '["JPEG", "PNG"]'),
    ('DELIVERY_PROOF',   2048, 480, 85, 3145728, '["JPEG"]'),
    ('LOADING_PROOF',    2048, 480, 85, 3145728, '["JPEG"]'),
    ('DRIVER_LICENCE',   2048, 600, 90, 4194304, '["JPEG", "PNG"]'),
    ('ATTACHMENT',       4096, 200, 90, 8388608, '["JPEG", "PNG"]')
ON CONFLICT (category) DO NOTHING;
INSERT INTO public.image_policy_versions (image_policy_id, category, version, policy, change_note)
SELECT image_policy_id, category, version,
       jsonb_build_object('category', category, 'max_side', max_side, 'min_side', min_side, 'quality', quality,
                          'max_bytes', max_bytes, 'allowed_formats', allowed_formats,
                          'is_compression_enabled', is_compression_enabled, 'version', version),
       'safe default'
FROM public.image_policies
ON CONFLICT DO NOTHING;

-- Unusual-activity checks and their thresholds (2026-10-30).
INSERT INTO public.risk_rules (signal_code, threshold, risk_level, description) VALUES
    ('HIGH_AMOUNT', 500000, 'MEDIUM', 'An order total above this amount (₹)'),
    ('PRICE_OUTLIER', 5, 'LOW', 'A unit price this many times above or below the usual price of the plant (needs 5+ earlier prices); pricing alone is never fraud'),
    ('DUPLICATE_ORDER', 10, 'MEDIUM', 'The same buyer, nursery and amount again within this many minutes'),
    ('REPEATED_CANCELLATIONS', 3, 'MEDIUM', 'This many cancelled orders by one buyer or nursery in 7 days'),
    ('QUANTITY_SHORTFALL', 50, 'LOW', 'Loaded less than this % of the ordered quantity'),
    ('DELIVERY_DISPUTE', 1, 'MEDIUM', 'The buyer reported a problem with a delivery'),
    ('PAYMENT_MISMATCH', 5, 'MEDIUM', 'Successful payments exceed the order total by more than this %'),
    ('DRIVER_DISPUTES', 3, 'HIGH', 'This many delivery problems reported on one driver''s trips in 30 days')
ON CONFLICT (signal_code) DO NOTHING;

-- Delivered without the customer's code (migration 20261025_02).
INSERT INTO public.sms_templates (template_code, template_name, category, header_id, body, variables)
SELECT 'DELIVERY_UNCONFIRMED', 'Delivered without customer code', 'SERVICE_IMPLICIT', h.header_id,
       'GreenRoot delivery DSP-{#numeric#}-{#numeric#} was marked done by the nursery without your code. Not received? Report it in the app within 48 hours. - GreenRoot',
       '["dispatch_date", "dispatch_seq"]'
FROM (SELECT min(header_id) AS header_id FROM public.sms_headers) h
ON CONFLICT (template_code) DO NOTHING;

INSERT INTO public.email_templates (template_code, template_name, subject, body_html, body_text) VALUES
  ('DELIVERY_UNCONFIRMED', 'Delivered without customer code', 'Your GreenRoot delivery {{dispatch_code}} was marked delivered',
   $html$<p>The nursery marked delivery <strong>{{dispatch_code}}</strong> as done without your delivery code.</p>
<p>Reason given: {{reason}}</p>
<p>If you did not receive your plants, open the order in the GreenRoot app and report a problem within 48 hours.</p>$html$,
   $text$The nursery marked delivery {{dispatch_code}} as done without your delivery code.

Reason given: {{reason}}

If you did not receive your plants, open the order in the GreenRoot app and report a problem within 48 hours.$text$)
ON CONFLICT (template_code) DO NOTHING;

-- Order-lifecycle messages (migration 20261028_01; fresh installs get them here,
-- since schema.sql records that migration as applied).
INSERT INTO public.sms_templates (template_code, template_name, category, header_id, body, variables)
SELECT t.code, t.name, 'SERVICE_IMPLICIT', h.header_id, t.body, t.vars::jsonb
FROM (SELECT min(header_id) AS header_id FROM public.sms_headers) h,
(VALUES
  ('QUOTATION_RECEIVED', 'Quotation for a customer not on the app',
   'You have a GreenRoot quotation QUO-{#numeric#}-{#numeric#} for Rs.{#numeric#}.{#numeric#}. Sign in to the GreenRoot app with this number to view and accept it. - GreenRoot',
   '["quotation_date", "quotation_seq", "amount_rupees", "amount_paise"]'),
  ('ORDER_PLACED', 'Order placed for a customer not on the app',
   'Your GreenRoot order ORD-{#numeric#}-{#numeric#} for Rs.{#numeric#}.{#numeric#} has been placed. Sign in to the GreenRoot app with this number to track it. - GreenRoot',
   '["order_date", "order_seq", "amount_rupees", "amount_paise"]'),
  ('DELIVERY_ON_THE_WAY', 'On the way, with the delivery code',
   'Your GreenRoot delivery DSP-{#numeric#}-{#numeric#} is on the way. Give code {#numeric#} to the driver only after you check your plants. - GreenRoot',
   '["dispatch_date", "dispatch_seq", "delivery_code"]'),
  ('ORDER_PARTIAL', 'Order loaded with fewer plants',
   'GreenRoot order ORD-{#numeric#}-{#numeric#} was loaded with fewer plants than ordered. New total Rs.{#numeric#}.{#numeric#}. - GreenRoot',
   '["order_date", "order_seq", "amount_rupees", "amount_paise"]'),
  ('NURSERY_APPROVED', 'Nursery approved',
   'Your nursery is approved on GreenRoot. Sign in to start taking orders. - GreenRoot',
   '[]'),
  ('TRIAL_ENDING', 'Free trial ending',
   'Your GreenRoot free trial ends in {#numeric#} days. Choose a plan in the app to keep taking orders. - GreenRoot',
   '["days_left"]'),
  ('DELIVERY_ISSUE', 'Customer reported a delivery problem',
   'A customer reported a problem with GreenRoot delivery DSP-{#numeric#}-{#numeric#}. Open the app to respond. - GreenRoot',
   '["dispatch_date", "dispatch_seq"]')
) AS t(code, name, body, vars)
ON CONFLICT (template_code) DO NOTHING;

INSERT INTO public.email_templates (template_code, template_name, subject, body_html, body_text) VALUES
  ('TRIAL_ENDING', 'Free trial ending', 'Your GreenRoot free trial ends in {{days_left}} days',
   $html$<p>Your GreenRoot free trial ends in <strong>{{days_left}} days</strong>.</p>
<p>Open the app and choose a plan to keep taking orders and quotations without a break.</p>$html$,
   $text$Your GreenRoot free trial ends in {{days_left}} days.

Open the app and choose a plan to keep taking orders and quotations without a break.$text$)
ON CONFLICT (template_code) DO NOTHING;

COMMIT;

-- Data retention rules (2026-10-31). Every new rule starts switched OFF.
-- The first three keep the cleanups that already ran (same periods, ON).
-- requires_legal_review: cannot be switched on until legal review clears it.
INSERT INTO public.retention_rules (rule_code, category, description, action, period_days, min_period_days, is_enabled, is_dry_run_only, requires_legal_review, legal_review_note) VALUES
('NOTIFICATIONS_READ', 'Notifications', 'In-app notifications read more than N days ago. Unread ones are never deleted.', 'DELETE', 90, 7, true, false, false, NULL),
('MANGO_USAGE', 'Mango AI usage', 'Mango cost and usage rows (no conversation content) older than N days.', 'DELETE', 90, 30, true, false, false, NULL),
('MANGO_PROPOSALS', 'Mango AI proposals', 'Mango confirm-before-change proposals older than N days (they expire after 10 minutes).', 'DELETE', 7, 1, true, false, false, NULL),
('CRASH_REPORTS', 'App crash reports', 'Crash reports received more than N days ago.', 'DELETE', 90, 7, false, false, false, NULL),
('SMS_LOG_MASK', 'SMS delivery log', 'SMS log rows older than N days: mobile reduced to its last 4 digits, message text removed. Delivery status is kept.', 'MASK', 180, 30, false, false, false, NULL),
('EMAIL_LOG_MASK', 'Email delivery log', 'Email log rows older than N days: address reduced to its domain, body removed. Subject and status are kept.', 'MASK', 180, 30, false, false, false, NULL),
('MARKET_CHAT', 'Market chat messages', 'Messages of market enquiries closed or cancelled more than N days ago. Kept while the ad has a pending report.', 'DELETE', 365, 30, false, false, false, NULL),
('OTP_REQUEST_LOG', 'OTP request log', 'OTP request rows (mobile, IP) older than N days.', 'DELETE', 30, 1, false, false, true, 'Legal review: CERT-In Directions (Apr 2022) may require ICT logs, including IP addresses, for 180 days.'),
('SESSIONS', 'Login sessions', 'Session rows (IP, user agent, device) with no activity for N days.', 'DELETE', 30, 1, false, false, true, 'Legal review: CERT-In Directions (Apr 2022) may require logs with IP/device fields for 180 days.'),
('GPS_TRAILS', 'GPS trails', 'Trip GPS points N days after the trip ended (and driver location points older than N days). Held while the trip has a delivery issue or the order an open risk signal.', 'DELETE', 90, 30, false, false, true, 'Legal review: GPS trails may be evidence in delivery and payment disputes (limitation periods).'),
('ORPHAN_FILES', 'Uploaded files', 'Stored files older than N days that no database row points to. Report only: this rule never deletes.', 'REPORT', 30, 7, false, true, false, NULL)
ON CONFLICT (rule_code) DO NOTHING;
