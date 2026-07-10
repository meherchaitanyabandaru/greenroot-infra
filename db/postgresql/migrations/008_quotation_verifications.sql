-- Migration 008: quotation_verifications
-- Cryptographically secure tokens for QR-based public verification.
-- Each quotation has at most one ACTIVE token (enforced by partial unique index).
-- Object key format for QR URL: {webBaseUrl}/verify/{token}

CREATE TABLE IF NOT EXISTS public.quotation_verifications (
    verification_id BIGSERIAL PRIMARY KEY,
    quotation_id    BIGINT        NOT NULL REFERENCES public.quotations(quotation_id) ON DELETE CASCADE,
    token           CHAR(64)      NOT NULL UNIQUE,   -- crypto/rand 32 bytes, hex-encoded
    status          VARCHAR(20)   NOT NULL DEFAULT 'ACTIVE', -- ACTIVE | REVOKED
    created_at      TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revoked_at      TIMESTAMP WITHOUT TIME ZONE,
    revoked_by      BIGINT
);

-- At most one ACTIVE token per quotation.
CREATE UNIQUE INDEX IF NOT EXISTS idx_quotation_verifications_active
    ON public.quotation_verifications (quotation_id)
    WHERE status = 'ACTIVE';

CREATE INDEX IF NOT EXISTS idx_quotation_verifications_token
    ON public.quotation_verifications (token);

CREATE INDEX IF NOT EXISTS idx_quotation_verifications_quotation
    ON public.quotation_verifications (quotation_id);
