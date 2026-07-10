-- Migration 007: quotation_documents
-- Stores PDF metadata only; bytes live in MinIO (quotation-pdfs bucket).
-- Object key format: quotations/{nurseryId}/{quotationId}/quotation-v{N}.pdf

CREATE TABLE IF NOT EXISTS public.quotation_documents (
    doc_id           BIGSERIAL PRIMARY KEY,
    quotation_id     BIGINT        NOT NULL REFERENCES public.quotations(quotation_id) ON DELETE CASCADE,
    version          INT           NOT NULL DEFAULT 1,
    object_key       TEXT          NOT NULL,
    sha256_hash      CHAR(64)      NOT NULL,
    mime_type        VARCHAR(100)  NOT NULL DEFAULT 'application/pdf',
    file_size        BIGINT        NOT NULL,
    generated_by     BIGINT,
    generated_by_name VARCHAR(255),
    is_current       BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Enforce at most one current document per quotation.
CREATE UNIQUE INDEX IF NOT EXISTS idx_quotation_documents_current
    ON public.quotation_documents (quotation_id)
    WHERE is_current = TRUE;

CREATE INDEX IF NOT EXISTS idx_quotation_documents_quotation
    ON public.quotation_documents (quotation_id);
