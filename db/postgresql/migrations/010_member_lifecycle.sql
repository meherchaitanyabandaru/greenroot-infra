-- Migration 010: Member lifecycle — performance indexes + driver disconnect tracking
-- Supports: manager removal, driver disconnection, account deletion.

-- Fast lookup: find active sessions for a user (used when invalidating on removal/deletion)
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_active
    ON public.user_sessions(user_id)
    WHERE session_status = 'ACTIVE';

-- Fast lookup: active nursery memberships for a user (used for removal + account delete)
CREATE INDEX IF NOT EXISTS idx_nursery_users_user_active
    ON public.nursery_users(user_id)
    WHERE is_active = true;

-- Allow a mobile number to re-register after account deletion while preserving
-- the deleted historical user row for business records.
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_mobile_key;

CREATE UNIQUE INDEX IF NOT EXISTS uq_users_mobile_active
    ON public.users(mobile)
    WHERE deleted_at IS NULL;

-- Track when and by whom a driver was disconnected from a nursery
ALTER TABLE public.nursery_drivers
    ADD COLUMN IF NOT EXISTS disconnected_at  TIMESTAMP,
    ADD COLUMN IF NOT EXISTS disconnected_by  BIGINT REFERENCES public.users(user_id) ON DELETE SET NULL;

COMMENT ON COLUMN public.nursery_drivers.disconnected_at IS
    'Timestamp when the driver was disconnected from the nursery. NULL if still connected.';
COMMENT ON COLUMN public.nursery_drivers.disconnected_by IS
    'user_id of the owner who disconnected the driver, or the driver themselves.';
