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

-- Nursery-scoped roles
INSERT INTO public.nursery_roles (nursery_role_id, role_code, role_name, description, is_active) VALUES
  (1, 'OWNER',      'Owner',      'Primary owner of nursery', true),
  (2, 'PARTNER',    'Partner',    'Business partner',         true),
  (3, 'MANAGER',    'Manager',    'Nursery manager',          true),
  (4, 'OPERATOR',   'Operator',   'Day-to-day operations',    true),
  (5, 'ACCOUNTANT', 'Accountant', 'Accounts and finance',     true),
  (6, 'DISPATCHER', 'Dispatcher', 'Dispatch operations',      true);

SELECT setval('public.nursery_roles_nursery_role_id_seq', (SELECT max(nursery_role_id) FROM public.nursery_roles), true);

-- Plant sizes
INSERT INTO public.plant_sizes (size_id, size_code, display_name, display_order, is_active) VALUES
  (1, 'SEED',        'Seed',        1, true),
  (2, 'SAPLING',     'Sapling',     2, true),
  (3, 'SMALL',       'Small',       3, true),
  (4, 'MEDIUM',      'Medium',      4, true),
  (5, 'LARGE',       'Large',       5, true),
  (6, 'EXTRA_LARGE', 'Extra Large', 6, true);

SELECT setval('public.plant_sizes_size_id_seq', (SELECT max(size_id) FROM public.plant_sizes), true);

-- Plant categories
INSERT INTO public.plant_categories (category_name, is_active) VALUES
  ('Fruit Trees',      true),
  ('Medicinal Plants', true),
  ('Shade Trees',      true),
  ('Herbs',            true),
  ('Ornamental',       true),
  ('Flowering Shrubs', true),
  ('Indoor Plants',    true),
  ('Succulents',       true),
  ('Climbers',         true);

-- Languages
INSERT INTO public.languages (language_code, language_name, is_active) VALUES
  ('en', 'English', true),
  ('hi', 'Hindi',   true),
  ('te', 'Telugu',  true),
  ('ta', 'Tamil',   true),
  ('kn', 'Kannada', true),
  ('mr', 'Marathi', true);

-- Platform config
INSERT INTO public.platform_config (config_key, config_value, data_type, description) VALUES
  ('otp_expiry_minutes',      '5',    'integer', 'OTP validity window in minutes'),
  ('otp_max_attempts',        '5',    'integer', 'Wrong OTP attempts before the code is blocked'),
  ('otp_resend_cooldown_sec', '30',   'integer', 'Seconds a user must wait before requesting another OTP'),
  ('min_order_amount',        '100',  'numeric', 'Minimum order total in INR'),
  ('platform_fee_pct',        '0',    'numeric', 'Platform fee percentage applied to orders'),
  ('driver_approval_days',    '3',    'integer', 'Days before a pending driver approval auto-expires'),
  ('nursery_approval_days',   '7',    'integer', 'Days before a pending nursery application auto-expires');

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
   '6-month free trial for new approved nurseries.',
   0.00, 0.00, 1, true,
   '{"support":"community","analytics":"basic","max_managers":1,"billing_cycles":["TRIAL"],"unlimited_orders":true,"unlimited_quotations":true,"market_posts_per_day":3}'::jsonb),
  ('GROWTH',
   'Growth',
   'For growing nurseries with more managers and market activity.',
   2499.00, 3999.00, 5, true,
   '{"support":"email","analytics":"full","max_managers":5,"billing_cycles":["SIX_MONTH","YEARLY"],"unlimited_orders":true,"unlimited_quotations":true,"market_posts_per_day":5,"mrp_six_month":4999,"mrp_yearly":19999}'::jsonb),
  ('ENTERPRISE',
   'Enterprise',
   'For large nursery operations with priority support.',
   7499.00, 11999.00, NULL, true,
   '{"support":"priority","analytics":"advanced","max_managers":null,"billing_cycles":["SIX_MONTH","YEARLY"],"unlimited_orders":true,"unlimited_quotations":true,"market_posts_per_day":null,"mrp_six_month":14999,"mrp_yearly":59999}'::jsonb);

-- Plant catalogue
INSERT INTO public.plants (scientific_name, common_name, plant_type, light_requirement, water_requirement, english_description, is_active) VALUES
  ('Mangifera indica',         'Mango',           'TREE',    'FULL_SUN',    'HIGH',     'Popular tropical fruit tree.', true),
  ('Azadirachta indica',       'Neem',            'TREE',    'FULL_SUN',    'LOW',      'Hardy medicinal shade tree.', true),
  ('Hibiscus rosa-sinensis',   'Hibiscus',        'SHRUB',   'FULL_SUN',    'MODERATE', 'Flowering ornamental shrub.', true),
  ('Cocos nucifera',           'Coconut',         'TREE',    'FULL_SUN',    'HIGH',     'Coastal palm producing coconuts.', true),
  ('Moringa oleifera',         'Drumstick',       'TREE',    'FULL_SUN',    'LOW',      'Fast-growing edible tree.', true),
  ('Ocimum tenuiflorum',       'Tulsi',           'HERB',    'FULL_SUN',    'MODERATE', 'Sacred basil and medicinal herb.', true),
  ('Aloe vera',                'Aloe Vera',       'SHRUB',   'FULL_SUN',    'LOW',      'Low-maintenance succulent.', true),
  ('Psidium guajava',          'Guava',           'TREE',    'FULL_SUN',    'MODERATE', 'Fast-fruiting tropical tree.', true),
  ('Rosa indica',              'Rose',            'SHRUB',   'FULL_SUN',    'MODERATE', 'Classic flowering shrub.', true),
  ('Catharanthus roseus',      'Periwinkle',      'HERB',    'FULL_SUN',    'MODERATE', 'Hardy flowering ground-cover.', true),
  ('Ficus benjamina',          'Weeping Fig',     'TREE',    'PARTIAL_SUN', 'MODERATE', 'Popular indoor ornamental tree.', true),
  ('Epipremnum aureum',        'Money Plant',     'CLIMBER', 'LOW_LIGHT',   'LOW',      'Easy indoor climber.', true),
  ('Sansevieria trifasciata',  'Snake Plant',     'SHRUB',   'LOW_LIGHT',   'LOW',      'Hardy indoor plant.', true),
  ('Plumeria rubra',           'Frangipani',      'TREE',    'FULL_SUN',    'LOW',      'Tropical fragrant flowering tree.', true),
  ('Duranta erecta',           'Golden Dewdrop',  'SHRUB',   'FULL_SUN',    'MODERATE', 'Fast-growing ornamental shrub.', true);

INSERT INTO public.plant_category_mappings (plant_id, category_id, created_at)
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
) AS m(scientific_name, category_name)
JOIN public.plants p ON p.scientific_name = m.scientific_name
JOIN public.plant_categories c ON c.category_name = m.category_name;


SELECT setval('public.plants_plant_id_seq', (SELECT max(plant_id) FROM public.plants), true);
SELECT setval('public.plant_categories_category_id_seq', (SELECT max(category_id) FROM public.plant_categories), true);
SELECT setval('public.languages_language_id_seq', (SELECT max(language_id) FROM public.languages), true);
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

COMMIT;
