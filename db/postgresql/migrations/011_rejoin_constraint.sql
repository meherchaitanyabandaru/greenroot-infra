-- Fix: replace the plain unique on nursery_users with a partial unique so that
-- a manager who left (is_active = false) can be re-invited to the same nursery
-- with the same role without hitting a duplicate-key violation.
--
-- Before: UNIQUE (nursery_id, user_id, nursery_role_id) — blocks any re-join
-- After:  UNIQUE (nursery_id, user_id, nursery_role_id) WHERE is_active = true
--          — only one active record per (nursery, user, role) at a time

ALTER TABLE public.nursery_users DROP CONSTRAINT IF EXISTS nursery_users_uq;

CREATE UNIQUE INDEX IF NOT EXISTS uq_nursery_users_active
    ON public.nursery_users(nursery_id, user_id, nursery_role_id)
    WHERE is_active = true;
