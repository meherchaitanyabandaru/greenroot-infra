-- Migration 009: Nursery branding fields
-- Adds logo_url, brand_icon_key, and brand_color to nurseries.
-- logo_url and brand_icon_key are mutually exclusive (enforced in application layer).
-- brand_color stores a 7-character hex value e.g. #2E7D32.
-- Website and description remain optional and are NOT affected by this migration.

ALTER TABLE public.nurseries
    ADD COLUMN logo_url       TEXT,
    ADD COLUMN brand_icon_key VARCHAR(40),
    ADD COLUMN brand_color    VARCHAR(7);

COMMENT ON COLUMN public.nurseries.logo_url IS
    'MinIO public URL of uploaded nursery logo. NULL when using a preset icon.';
COMMENT ON COLUMN public.nurseries.brand_icon_key IS
    'Preset icon identifier (leaf, tree, flower, seedling, pot, cactus, palm, bonsai, herb, lotus). NULL when using an uploaded logo.';
COMMENT ON COLUMN public.nurseries.brand_color IS
    'Hex brand color e.g. #2E7D32. Must be one of the 10 curated palette values enforced in the application layer.';
