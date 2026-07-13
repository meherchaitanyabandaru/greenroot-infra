-- Migration 014: market_ads pickup location columns
-- Adds per-ad pickup location (separate from the nursery's permanent address).
-- The Go repository already writes these columns; this migration makes the DB
-- match the existing code.

-- Shared trigger function is defined in migration 013 (sync_latlong_to_geography).
-- This migration uses a table-specific function because the column names are
-- pickup_latitude / pickup_longitude / pickup_location rather than the standard
-- latitude / longitude / location.

CREATE OR REPLACE FUNCTION public.sync_market_pickup_to_geography()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.pickup_latitude IS NOT NULL AND NEW.pickup_longitude IS NOT NULL THEN
        NEW.pickup_location := ST_SetSRID(
            ST_MakePoint(NEW.pickup_longitude::double precision, NEW.pickup_latitude::double precision),
            4326
        )::geography;
    ELSE
        NEW.pickup_location := NULL;
    END IF;
    RETURN NEW;
END;
$$;

ALTER TABLE public.market_ads
    ADD COLUMN IF NOT EXISTS pickup_address          text,
    ADD COLUMN IF NOT EXISTS pickup_landmark         character varying(255),
    ADD COLUMN IF NOT EXISTS pickup_latitude         numeric(10,7),
    ADD COLUMN IF NOT EXISTS pickup_longitude        numeric(10,7),
    ADD COLUMN IF NOT EXISTS pickup_gps_accuracy_meters numeric(8,2),
    ADD COLUMN IF NOT EXISTS pickup_location_source  character varying(50),
    ADD COLUMN IF NOT EXISTS pickup_confirmed_by     bigint REFERENCES public.users(user_id),
    ADD COLUMN IF NOT EXISTS pickup_confirmed_at     timestamp without time zone,
    ADD COLUMN IF NOT EXISTS pickup_location         geography(Point, 4326);

-- Back-fill any rows with coordinates already present (e.g., from a manual insert)
UPDATE public.market_ads
    SET pickup_location = ST_SetSRID(
        ST_MakePoint(pickup_longitude::double precision, pickup_latitude::double precision),
        4326
    )::geography
    WHERE pickup_latitude IS NOT NULL AND pickup_longitude IS NOT NULL AND pickup_location IS NULL;

CREATE INDEX IF NOT EXISTS idx_market_ads_pickup_location
    ON public.market_ads USING GIST (pickup_location)
    WHERE pickup_location IS NOT NULL;

DROP TRIGGER IF EXISTS trg_market_ads_sync_pickup_location ON public.market_ads;
CREATE TRIGGER trg_market_ads_sync_pickup_location
    BEFORE INSERT OR UPDATE OF pickup_latitude, pickup_longitude
    ON public.market_ads
    FOR EACH ROW EXECUTE FUNCTION public.sync_market_pickup_to_geography();
