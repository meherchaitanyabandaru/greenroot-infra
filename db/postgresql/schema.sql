--
-- PostgreSQL database dump
--


-- Dumped from database version 17.10 (Homebrew)
-- Dumped by pg_dump version 17.10 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- *not* creating schema, since initdb creates it


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS '';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: gender_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.gender_type AS ENUM (
    'MALE',
    'FEMALE',
    'NON_BINARY',
    'OTHER',
    'PREFER_NOT_TO_SAY'
);


--
-- Name: botanical_search_key(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.botanical_search_key(name text) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$ SELECT lower(replace(replace(name, '× ', ''), '×', '')) $$;


--
-- Name: bump_row_version(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.bump_row_version() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.version := OLD.version + 1;
    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION bump_row_version(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.bump_row_version() IS 'BEFORE UPDATE trigger: increments version on every update (optimistic locking).';


--
-- Name: next_public_code(text, text, integer, boolean, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.next_public_code(p_code_key text, p_prefix text, p_width integer, p_date_based boolean DEFAULT false, p_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_date_key  TEXT := '';
    v_last_value BIGINT;
BEGIN
    IF p_date_based THEN
        v_date_key := to_char(p_at::DATE, 'YYYYMMDD');
    END IF;

    INSERT INTO public.public_code_sequences (code_key, date_key, last_value)
    VALUES (p_code_key, v_date_key, 1)
    ON CONFLICT (code_key, date_key)
    DO UPDATE SET
        last_value = public.public_code_sequences.last_value + 1,
        updated_at = CURRENT_TIMESTAMP
    RETURNING last_value INTO v_last_value;

    IF p_date_based THEN
        RETURN p_prefix || '-' || v_date_key || '-' || lpad(v_last_value::TEXT, p_width, '0');
    END IF;

    RETURN p_prefix || '-' || lpad(v_last_value::TEXT, p_width, '0');
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attachments (
    attachment_id bigint NOT NULL,
    attachment_code character varying(20) DEFAULT public.next_public_code('attachments'::text, 'ATT'::text, 6, false) NOT NULL,
    entity_type character varying(50) NOT NULL,
    entity_id bigint NOT NULL,
    file_name character varying(500),
    file_url text NOT NULL,
    file_type character varying(100),
    file_size bigint,
    uploaded_by_user_id bigint,
    uploaded_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    deleted_at timestamp with time zone
);


--
-- Name: attachments_attachment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.attachments_attachment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: attachments_attachment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.attachments_attachment_id_seq OWNED BY public.attachments.attachment_id;


--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs (
    audit_id bigint NOT NULL,
    table_name character varying(100),
    record_id bigint,
    action_type character varying(50),
    old_data jsonb,
    new_data jsonb,
    changed_by_user_id bigint,
    source_ip character varying(100),
    user_agent text,
    changed_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    request_id character varying(100),
    user_id bigint,
    nursery_id bigint,
    module character varying(50),
    entity_type character varying(100),
    description text,
    device_info jsonb,
    metadata jsonb
);


--
-- Name: audit_logs_audit_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audit_logs_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_logs_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audit_logs_audit_id_seq OWNED BY public.audit_logs.audit_id;


--
-- Name: botanical_names; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.botanical_names (
    botanical_name_id bigint NOT NULL,
    wfo_id text NOT NULL,
    scientific_name text NOT NULL,
    authorship text,
    taxon_rank text NOT NULL,
    family text,
    genus text,
    status text NOT NULL,
    accepted_wfo_id text,
    CONSTRAINT ck_botanical_names_accepted CHECK (((status = 'SYNONYM'::text) OR (accepted_wfo_id IS NULL))),
    CONSTRAINT ck_botanical_names_status CHECK ((status = ANY (ARRAY['ACCEPTED'::text, 'SYNONYM'::text, 'UNCHECKED'::text])))
);


--
-- Name: botanical_names_botanical_name_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.botanical_names_botanical_name_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: botanical_names_botanical_name_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.botanical_names_botanical_name_id_seq OWNED BY public.botanical_names.botanical_name_id;


--
-- Name: client_crash_reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_crash_reports (
    client_crash_report_id bigint NOT NULL,
    user_id bigint,
    platform text NOT NULL,
    app_version text NOT NULL,
    build_number text,
    os_version text,
    device_model text,
    error_type text NOT NULL,
    message text NOT NULL,
    stack_trace text,
    context jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_fatal boolean DEFAULT false NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    received_at timestamp with time zone DEFAULT now() NOT NULL,
    request_id text,
    CONSTRAINT ck_client_crash_reports_platform CHECK ((platform = ANY (ARRAY['android'::text, 'ios'::text, 'web'::text]))),
    CONSTRAINT ck_client_crash_reports_sizes CHECK (((length(app_version) <= 32) AND (length(error_type) <= 200) AND (length(message) <= 2000) AND ((stack_trace IS NULL) OR (length(stack_trace) <= 16000)) AND (pg_column_size(context) <= 8192)))
);


--
-- Name: client_crash_reports_client_crash_report_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_crash_reports_client_crash_report_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_crash_reports_client_crash_report_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_crash_reports_client_crash_report_id_seq OWNED BY public.client_crash_reports.client_crash_report_id;


--
-- Name: dispatch_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dispatch_assignments (
    dispatch_assignment_id bigint NOT NULL,
    dispatch_id bigint NOT NULL,
    vehicle_id bigint NOT NULL,
    driver_id bigint NOT NULL,
    assigned_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    assigned_by_user_id bigint,
    status character varying(20) DEFAULT 'ASSIGNED'::character varying
);


--
-- Name: dispatch_assignments_dispatch_assignment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dispatch_assignments_dispatch_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dispatch_assignments_dispatch_assignment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dispatch_assignments_dispatch_assignment_id_seq OWNED BY public.dispatch_assignments.dispatch_assignment_id;


--
-- Name: dispatch_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dispatch_items (
    dispatch_item_id bigint NOT NULL,
    dispatch_id bigint NOT NULL,
    order_item_id bigint,
    quantity numeric(12,2) DEFAULT 0 NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_dispatch_items_quantity CHECK ((quantity > (0)::numeric))
);


--
-- Name: dispatch_items_dispatch_item_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.dispatch_items ALTER COLUMN dispatch_item_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.dispatch_items_dispatch_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: dispatches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dispatches (
    dispatch_id bigint NOT NULL,
    dispatch_code character varying(30) DEFAULT public.next_public_code('dispatches'::text, 'DSP'::text, 4, true) NOT NULL,
    dispatch_number character varying(50),
    order_id bigint NOT NULL,
    nursery_id bigint,
    status character varying(30) DEFAULT 'PENDING'::character varying,
    dispatched_by_user_id bigint,
    assigned_manager_user_id bigint,
    vehicle_id bigint,
    driver_id bigint,
    driver_user_id bigint,
    snapshot_owner_user_id bigint,
    customer_user_id bigint,
    customer_name_snapshot character varying(255),
    customer_mobile_snapshot character varying(20),
    destination_address text,
    dispatched_at timestamp with time zone,
    delivered_at timestamp with time zone,
    trip_started_at timestamp with time zone,
    trip_started_by_user_id bigint,
    completed_at timestamp with time zone,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    driver_accepted_at timestamp with time zone,
    driver_rejected_at timestamp with time zone,
    driver_reject_reason text,
    deleted_at timestamp with time zone,
    trip_uuid uuid DEFAULT gen_random_uuid() NOT NULL,
    version bigint DEFAULT 1 NOT NULL,
    CONSTRAINT ck_dispatches_status CHECK (((status)::text = ANY (ARRAY[('PENDING'::character varying)::text, ('ACCEPTED'::character varying)::text, ('DISPATCHED'::character varying)::text, ('IN_TRANSIT'::character varying)::text, ('DELIVERED'::character varying)::text, ('CANCELLED'::character varying)::text])))
);


--
-- Name: dispatches_dispatch_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dispatches_dispatch_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dispatches_dispatch_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dispatches_dispatch_id_seq OWNED BY public.dispatches.dispatch_id;


--
-- Name: driver_locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.driver_locations (
    location_id bigint NOT NULL,
    driver_id bigint NOT NULL,
    latitude numeric(10,7) NOT NULL,
    longitude numeric(10,7) NOT NULL,
    location public.geography(Point,4326),
    recorded_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by_user_id bigint
);


--
-- Name: driver_locations_location_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.driver_locations ALTER COLUMN location_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.driver_locations_location_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: drivers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.drivers (
    driver_id bigint NOT NULL,
    driver_code character varying(20) DEFAULT public.next_public_code('drivers'::text, 'DRV'::text, 6, false) NOT NULL,
    user_id bigint,
    license_number character varying(100),
    license_expiry_date date,
    licence_photo_url text,
    vehicle_number character varying(50),
    vehicle_type character varying(50),
    emergency_contact character varying(20),
    profile_status character varying(20) DEFAULT 'INCOMPLETE'::character varying NOT NULL,
    approval_status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    approved_by_user_id bigint,
    approved_at timestamp with time zone,
    status character varying(20) DEFAULT 'ACTIVE'::character varying,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_drivers_status CHECK (((status)::text = ANY (ARRAY[('ACTIVE'::character varying)::text, ('INACTIVE'::character varying)::text, ('SUSPENDED'::character varying)::text, ('DELETED'::character varying)::text])))
);


--
-- Name: drivers_driver_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.drivers_driver_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: drivers_driver_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.drivers_driver_id_seq OWNED BY public.drivers.driver_id;


--
-- Name: email_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_messages (
    email_message_id bigint NOT NULL,
    email_template_id bigint,
    template_code character varying(60) NOT NULL,
    user_id bigint,
    to_email character varying(254) NOT NULL,
    subject text NOT NULL,
    body text NOT NULL,
    provider character varying(30) NOT NULL,
    provider_message_id character varying(200),
    status character varying(20) NOT NULL,
    error_code character varying(60),
    error_message text,
    reference_type character varying(30),
    reference_id bigint,
    sent_at timestamp with time zone,
    delivered_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_email_messages_status CHECK (((status)::text = ANY (ARRAY['SENT'::text, 'DELIVERED'::text, 'BOUNCED'::text, 'FAILED'::text, 'BLOCKED'::text, 'MOCKED'::text])))
);


--
-- Name: email_messages_email_message_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.email_messages_email_message_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_messages_email_message_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.email_messages_email_message_id_seq OWNED BY public.email_messages.email_message_id;


--
-- Name: email_senders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_senders (
    sender_id bigint NOT NULL,
    from_name character varying(100) DEFAULT 'GreenRoot'::character varying NOT NULL,
    from_address character varying(254),
    reply_to character varying(254),
    is_domain_verified boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: email_sender_sender_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.email_sender_sender_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_sender_sender_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.email_sender_sender_id_seq OWNED BY public.email_senders.sender_id;


--
-- Name: email_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_templates (
    email_template_id bigint NOT NULL,
    template_code character varying(60) NOT NULL,
    template_name character varying(255) NOT NULL,
    subject character varying(200) NOT NULL,
    body_html text DEFAULT ''::text NOT NULL,
    body_text text DEFAULT ''::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: email_templates_email_template_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.email_templates_email_template_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_templates_email_template_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.email_templates_email_template_id_seq OWNED BY public.email_templates.email_template_id;


--
-- Name: import_checkpoints; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.import_checkpoints (
    import_checkpoint_id bigint NOT NULL,
    source_name text NOT NULL,
    rows_done bigint DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_import_checkpoints_rows_done CHECK ((rows_done >= 0))
);


--
-- Name: import_checkpoints_import_checkpoint_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.import_checkpoints_import_checkpoint_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: import_checkpoints_import_checkpoint_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.import_checkpoints_import_checkpoint_id_seq OWNED BY public.import_checkpoints.import_checkpoint_id;


--
-- Name: invites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invites (
    invite_id bigint NOT NULL,
    invite_uuid uuid DEFAULT gen_random_uuid() NOT NULL,
    invite_type character varying(50) NOT NULL,
    invited_by_user_id bigint,
    nursery_id bigint,
    role character varying(50),
    target_mobile character varying(20),
    target_email character varying(255),
    target_name character varying(255),
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    expires_at timestamp with time zone,
    accepted_by_user_id bigint,
    accepted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_invites_status CHECK (((status)::text = ANY (ARRAY[('PENDING'::character varying)::text, ('ACCEPTED'::character varying)::text, ('CANCELLED'::character varying)::text]))),
    CONSTRAINT ck_invites_type CHECK (((invite_type)::text = ANY (ARRAY[('MANAGER_INVITE'::character varying)::text, ('DRIVER_INVITE'::character varying)::text, ('CUSTOMER_INVITE'::character varying)::text, ('NURSERY_ONBOARDING_INVITE'::character varying)::text, ('TRIP_SHARE_INVITE'::character varying)::text])))
);


--
-- Name: invites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invites_id_seq OWNED BY public.invites.invite_id;


--
-- Name: languages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.languages (
    language_id smallint NOT NULL,
    language_code character varying(10) NOT NULL,
    language_name character varying(100) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: languages_language_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.languages_language_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: languages_language_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.languages_language_id_seq OWNED BY public.languages.language_id;


--
-- Name: market_ad_reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.market_ad_reports (
    report_id bigint NOT NULL,
    ad_id bigint NOT NULL,
    reported_by_user_id bigint NOT NULL,
    reported_by_nursery_id bigint NOT NULL,
    reason character varying(50) NOT NULL,
    notes text,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    reviewed_by_user_id bigint,
    reviewed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_market_ad_reports_reason CHECK (((reason)::text = ANY (ARRAY[('SPAM'::character varying)::text, ('WRONG_PLANT'::character varying)::text, ('DUPLICATE'::character varying)::text, ('FRAUD'::character varying)::text, ('OTHER'::character varying)::text]))),
    CONSTRAINT ck_market_ad_reports_status CHECK (((status)::text = ANY (ARRAY[('PENDING'::character varying)::text, ('REVIEWED'::character varying)::text, ('DISMISSED'::character varying)::text])))
);


--
-- Name: market_ad_saves; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.market_ad_saves (
    save_id bigint NOT NULL,
    ad_id bigint NOT NULL,
    nursery_id bigint NOT NULL,
    saved_by_user_id bigint NOT NULL,
    saved_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: market_ad_views; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.market_ad_views (
    view_id bigint NOT NULL,
    ad_id bigint NOT NULL,
    nursery_id bigint,
    viewed_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: market_ads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.market_ads (
    ad_id bigint NOT NULL,
    ad_code character varying(30) DEFAULT public.next_public_code('market_listings'::text, 'MKT'::text, 6, false) NOT NULL,
    nursery_id bigint NOT NULL,
    created_by_user_id bigint NOT NULL,
    updated_by_user_id bigint,
    plant_id bigint,
    plant_name character varying(255) NOT NULL,
    category_name character varying(100),
    title character varying(255) NOT NULL,
    description text,
    quantity integer,
    size_description character varying(100),
    price_per_unit numeric(15,2),
    price_unit character varying(50),
    photos jsonb DEFAULT '[]'::jsonb NOT NULL,
    pickup_address text,
    pickup_landmark character varying(255),
    pickup_latitude numeric(10,7),
    pickup_longitude numeric(10,7),
    pickup_gps_accuracy_meters numeric(8,2),
    pickup_location_source character varying(50),
    pickup_confirmed_by_user_id bigint,
    pickup_confirmed_at timestamp with time zone,
    pickup_location public.geography(Point,4326),
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    view_count integer DEFAULT 0 NOT NULL,
    save_count integer DEFAULT 0 NOT NULL,
    enquiry_count integer DEFAULT 0 NOT NULL,
    published_at timestamp with time zone,
    paused_at timestamp with time zone,
    expired_at timestamp with time zone,
    archived_at timestamp with time zone,
    expires_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_market_ads_price CHECK (((price_per_unit IS NULL) OR (price_per_unit >= (0)::numeric))),
    CONSTRAINT ck_market_ads_status CHECK (((status)::text = ANY (ARRAY[('DRAFT'::character varying)::text, ('PUBLISHED'::character varying)::text, ('PAUSED'::character varying)::text, ('EXPIRED'::character varying)::text, ('ARCHIVED'::character varying)::text])))
);


--
-- Name: market_enquiries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.market_enquiries (
    enquiry_id bigint NOT NULL,
    enquiry_code character varying(30) DEFAULT public.next_public_code('market_enquiries'::text, 'ENQ'::text, 6, false) NOT NULL,
    ad_id bigint NOT NULL,
    ad_nursery_id bigint NOT NULL,
    enquiring_nursery_id bigint NOT NULL,
    created_by_user_id bigint NOT NULL,
    message text NOT NULL,
    quantity_needed integer,
    status character varying(25) DEFAULT 'NEW'::character varying NOT NULL,
    quotation_id bigint,
    viewed_at timestamp with time zone,
    replied_at timestamp with time zone,
    closed_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_market_enquiries_status CHECK (((status)::text = ANY (ARRAY[('NEW'::character varying)::text, ('IN_PROGRESS'::character varying)::text, ('QUOTATION_CREATED'::character varying)::text, ('CLOSED'::character varying)::text, ('CANCELLED'::character varying)::text])))
);


--
-- Name: market_enquiries_enquiry_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.market_enquiries_enquiry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: market_enquiries_enquiry_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.market_enquiries_enquiry_id_seq OWNED BY public.market_enquiries.enquiry_id;


--
-- Name: market_enquiry_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.market_enquiry_messages (
    message_id bigint NOT NULL,
    enquiry_id bigint NOT NULL,
    sent_by_user_id bigint NOT NULL,
    sent_by_nursery_id bigint NOT NULL,
    body text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: market_enquiry_messages_message_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.market_enquiry_messages_message_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: market_enquiry_messages_message_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.market_enquiry_messages_message_id_seq OWNED BY public.market_enquiry_messages.message_id;


--
-- Name: market_listing_reports_report_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.market_listing_reports_report_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: market_listing_reports_report_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.market_listing_reports_report_id_seq OWNED BY public.market_ad_reports.report_id;


--
-- Name: market_listing_saves_save_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.market_listing_saves_save_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: market_listing_saves_save_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.market_listing_saves_save_id_seq OWNED BY public.market_ad_saves.save_id;


--
-- Name: market_listing_views_view_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.market_listing_views_view_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: market_listing_views_view_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.market_listing_views_view_id_seq OWNED BY public.market_ad_views.view_id;


--
-- Name: market_listings_listing_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.market_listings_listing_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: market_listings_listing_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.market_listings_listing_id_seq OWNED BY public.market_ads.ad_id;


--
-- Name: notification_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_templates (
    template_id bigint NOT NULL,
    template_code character varying(100) NOT NULL,
    template_name character varying(255),
    channel character varying(30),
    subject character varying(255),
    message_template text,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: notification_templates_template_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notification_templates_template_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notification_templates_template_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notification_templates_template_id_seq OWNED BY public.notification_templates.template_id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    notification_id bigint NOT NULL,
    notification_code character varying(20) DEFAULT public.next_public_code('notifications'::text, 'NTF'::text, 6, false) NOT NULL,
    user_id bigint,
    template_id bigint,
    notification_type character varying(100) DEFAULT 'SYSTEM'::character varying NOT NULL,
    title character varying(255),
    message text,
    channel character varying(30),
    data jsonb,
    status character varying(30) DEFAULT 'PENDING'::character varying,
    sent_at timestamp with time zone,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_notifications_channel CHECK (((channel)::text = ANY (ARRAY[('PUSH'::character varying)::text, ('SMS'::character varying)::text, ('EMAIL'::character varying)::text, ('IN_APP'::character varying)::text])))
);


--
-- Name: notifications_notification_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notifications_notification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notifications_notification_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notifications_notification_id_seq OWNED BY public.notifications.notification_id;


--
-- Name: nurseries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nurseries (
    nursery_id bigint NOT NULL,
    nursery_code character varying(50) DEFAULT public.next_public_code('nurseries'::text, 'NUR'::text, 6, false) NOT NULL,
    nursery_name character varying(255) NOT NULL,
    owner_user_id bigint,
    mobile character varying(20),
    email character varying(255),
    website character varying(255),
    description text,
    logo_url text,
    brand_icon_key character varying(50),
    brand_color character varying(20),
    status character varying(20) DEFAULT 'PENDING_APPROVAL'::character varying,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by_user_id bigint,
    updated_by_user_id bigint,
    approved_by_user_id bigint,
    approved_at timestamp with time zone,
    rejected_by_user_id bigint,
    rejected_at timestamp with time zone,
    rejection_reason text,
    deleted_at timestamp with time zone,
    suspension_reason text,
    suspended_by_user_id bigint,
    suspended_at timestamp with time zone,
    unsuspended_by_user_id bigint,
    unsuspended_at timestamp with time zone,
    CONSTRAINT ck_nurseries_status CHECK (((status)::text = ANY (ARRAY[('ACTIVE'::character varying)::text, ('INACTIVE'::character varying)::text, ('SUSPENDED'::character varying)::text, ('DELETED'::character varying)::text, ('PENDING'::character varying)::text, ('APPROVED'::character varying)::text, ('REJECTED'::character varying)::text])))
);


--
-- Name: nurseries_nursery_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.nurseries_nursery_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nurseries_nursery_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.nurseries_nursery_id_seq OWNED BY public.nurseries.nursery_id;


--
-- Name: nursery_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nursery_addresses (
    nursery_address_id bigint NOT NULL,
    nursery_id bigint NOT NULL,
    address_type character varying(50),
    address_line1 character varying(255),
    address_line2 character varying(255),
    city character varying(100),
    state character varying(100),
    country character varying(100),
    postal_code character varying(20),
    landmark character varying(255),
    latitude numeric(10,7),
    longitude numeric(10,7),
    gps_accuracy_meters numeric(8,2),
    location_source character varying(50),
    location_confirmed_by_user_id bigint,
    location_confirmed_at timestamp with time zone,
    location public.geography(Point,4326),
    is_primary boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: nursery_addresses_nursery_address_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.nursery_addresses_nursery_address_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nursery_addresses_nursery_address_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.nursery_addresses_nursery_address_id_seq OWNED BY public.nursery_addresses.nursery_address_id;


--
-- Name: nursery_applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nursery_applications (
    application_id bigint NOT NULL,
    application_code character varying(20) DEFAULT public.next_public_code('nursery_applications'::text, 'NRA'::text, 6, false) NOT NULL,
    applicant_user_id bigint NOT NULL,
    nursery_name character varying(255) NOT NULL,
    mobile character varying(20),
    email character varying(255),
    address_line1 character varying(255),
    address_line2 character varying(255),
    city character varying(100),
    state character varying(100),
    country character varying(100) DEFAULT 'India'::character varying,
    postal_code character varying(20),
    description text,
    status character varying(30) DEFAULT 'PENDING'::character varying NOT NULL,
    reviewed_by_user_id bigint,
    reviewed_at timestamp with time zone,
    rejection_reason text,
    nursery_id bigint,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: nursery_applications_application_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.nursery_applications_application_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nursery_applications_application_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.nursery_applications_application_id_seq OWNED BY public.nursery_applications.application_id;


--
-- Name: nursery_drivers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nursery_drivers (
    nursery_driver_id bigint NOT NULL,
    nursery_id bigint NOT NULL,
    driver_user_id bigint NOT NULL,
    invited_by_user_id bigint,
    approved_by_user_id bigint,
    status character varying(20) DEFAULT 'REQUESTED'::character varying NOT NULL,
    connected_at timestamp with time zone,
    disconnected_at timestamp with time zone,
    disconnected_by_user_id bigint,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: nursery_drivers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.nursery_drivers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nursery_drivers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.nursery_drivers_id_seq OWNED BY public.nursery_drivers.nursery_driver_id;


--
-- Name: nursery_top_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nursery_top_items (
    top_item_id bigint NOT NULL,
    top_item_code character varying(20) DEFAULT public.next_public_code('nursery_top_items'::text, 'TOP'::text, 6, false) NOT NULL,
    nursery_id bigint NOT NULL,
    plant_id bigint NOT NULL,
    size_id smallint NOT NULL,
    unit_price numeric(15,2),
    display_order smallint DEFAULT 0 NOT NULL,
    updated_by_user_id bigint,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version bigint DEFAULT 1 NOT NULL,
    quality_notes text,
    photos jsonb DEFAULT '[]'::jsonb NOT NULL,
    CONSTRAINT ck_nursery_top_items_display_order CHECK ((display_order >= 0)),
    CONSTRAINT ck_nursery_top_items_photos CHECK (((jsonb_typeof(photos) = 'array'::text) AND (jsonb_array_length(photos) <= 5))),
    CONSTRAINT ck_nursery_top_items_price CHECK (((unit_price IS NULL) OR (unit_price >= (0)::numeric)))
);


--
-- Name: TABLE nursery_top_items; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.nursery_top_items IS 'A nursery''s showcase: up to 20 plants (with size and an optional indicative price) it is known for. Not stock — nothing reduces it.';


--
-- Name: nursery_top_items_top_item_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.nursery_top_items_top_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nursery_top_items_top_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.nursery_top_items_top_item_id_seq OWNED BY public.nursery_top_items.top_item_id;


--
-- Name: nursery_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nursery_users (
    nursery_user_id bigint NOT NULL,
    nursery_id bigint NOT NULL,
    user_id bigint NOT NULL,
    role character varying(50) DEFAULT 'MANAGER'::character varying NOT NULL,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    invited_by_user_id bigint,
    joined_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    is_active boolean DEFAULT true,
    CONSTRAINT ck_nursery_users_role CHECK (((role)::text = 'MANAGER'::text)),
    CONSTRAINT ck_nursery_users_status CHECK (((status)::text = ANY (ARRAY[('ACTIVE'::character varying)::text, ('INACTIVE'::character varying)::text])))
);


--
-- Name: nursery_users_nursery_user_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.nursery_users_nursery_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nursery_users_nursery_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.nursery_users_nursery_user_id_seq OWNED BY public.nursery_users.nursery_user_id;


--
-- Name: order_delivery_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_delivery_snapshots (
    snapshot_id bigint NOT NULL,
    order_id bigint NOT NULL,
    contact_name character varying(100),
    contact_mobile character varying(20),
    alternate_mobile character varying(20),
    address_line1 character varying(255),
    address_line2 character varying(255),
    city character varying(100),
    state character varying(100),
    country character varying(100),
    postal_code character varying(20),
    landmark character varying(255),
    delivery_instructions text,
    latitude numeric(10,7),
    longitude numeric(10,7),
    location public.geography(Point,4326),
    gps_accuracy_meters numeric(8,2),
    location_source character varying(40),
    confirmed_by_user_id bigint,
    confirmed_at timestamp with time zone,
    is_emergency_update boolean DEFAULT false NOT NULL,
    requires_driver_ack boolean DEFAULT false NOT NULL,
    driver_acknowledged_by_user_id bigint,
    driver_acknowledged_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_order_delivery_snapshots_latitude CHECK (((latitude IS NULL) OR ((latitude >= ('-90'::integer)::numeric) AND (latitude <= (90)::numeric)))),
    CONSTRAINT ck_order_delivery_snapshots_location_source CHECK (((location_source IS NULL) OR ((location_source)::text = ANY (ARRAY[('gps_confirmed'::character varying)::text, ('nursery_default'::character varying)::text, ('map_selected'::character varying)::text, ('address_search'::character varying)::text, ('admin_updated'::character varying)::text])))),
    CONSTRAINT ck_order_delivery_snapshots_longitude CHECK (((longitude IS NULL) OR ((longitude >= ('-180'::integer)::numeric) AND (longitude <= (180)::numeric))))
);


--
-- Name: order_delivery_snapshots_snapshot_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.order_delivery_snapshots_snapshot_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: order_delivery_snapshots_snapshot_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.order_delivery_snapshots_snapshot_id_seq OWNED BY public.order_delivery_snapshots.snapshot_id;


--
-- Name: order_documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_documents (
    doc_id bigint NOT NULL,
    order_id bigint NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    object_key text NOT NULL,
    sha256_hash character varying(64) NOT NULL,
    mime_type character varying(100) DEFAULT 'application/pdf'::character varying NOT NULL,
    file_size bigint DEFAULT 0 NOT NULL,
    generated_by_user_id bigint,
    generated_by_name character varying(255),
    is_current boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_order_documents_file_size CHECK ((file_size >= 0)),
    CONSTRAINT ck_order_documents_version CHECK ((version > 0))
);


--
-- Name: order_documents_doc_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.order_documents_doc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: order_documents_doc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.order_documents_doc_id_seq OWNED BY public.order_documents.doc_id;


--
-- Name: order_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_items (
    order_item_id bigint NOT NULL,
    order_id bigint NOT NULL,
    plant_id bigint,
    plant_name_snapshot character varying(255),
    size_id smallint,
    size character varying(100),
    quantity numeric(12,2) NOT NULL,
    unit_price numeric(15,2),
    total_price numeric(15,2),
    remarks text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    loaded_quantity numeric(12,2),
    CONSTRAINT ck_order_items_amounts CHECK (((quantity > (0)::numeric) AND ((unit_price IS NULL) OR (unit_price >= (0)::numeric)) AND ((total_price IS NULL) OR (total_price >= (0)::numeric)) AND ((loaded_quantity IS NULL) OR ((loaded_quantity >= (0)::numeric) AND (loaded_quantity <= quantity)))))
);


--
-- Name: order_items_order_item_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.order_items_order_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: order_items_order_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.order_items_order_item_id_seq OWNED BY public.order_items.order_item_id;


--
-- Name: order_verifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_verifications (
    verification_id bigint NOT NULL,
    order_id bigint NOT NULL,
    token character varying(128) NOT NULL,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    revoked_at timestamp with time zone,
    revoked_by_user_id bigint,
    CONSTRAINT ck_order_verifications_status CHECK (((status)::text = ANY (ARRAY[('ACTIVE'::character varying)::text, ('REVOKED'::character varying)::text])))
);


--
-- Name: order_verifications_verification_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.order_verifications_verification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: order_verifications_verification_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.order_verifications_verification_id_seq OWNED BY public.order_verifications.verification_id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    order_id bigint NOT NULL,
    order_code character varying(30) DEFAULT public.next_public_code('orders'::text, 'ORD'::text, 4, true) NOT NULL,
    order_number character varying(50) NOT NULL,
    seller_nursery_id bigint,
    buyer_nursery_id bigint,
    quotation_id bigint,
    buyer_user_id bigint,
    customer_user_id bigint,
    customer_name character varying(255),
    customer_mobile character varying(20),
    assigned_manager_user_id bigint,
    status character varying(30) DEFAULT 'PENDING'::character varying NOT NULL,
    total_amount numeric(15,2) DEFAULT 0,
    notes text,
    ordered_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    loading_started_at timestamp with time zone,
    loading_completed_at timestamp with time zone,
    loading_completed_by_user_id bigint,
    cancelled_by_user_id bigint,
    cancelled_at timestamp with time zone,
    cancel_reason text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by_user_id bigint,
    updated_by_user_id bigint,
    deleted_at timestamp with time zone,
    version bigint DEFAULT 1 NOT NULL,
    currency character(3) DEFAULT 'INR'::bpchar NOT NULL,
    CONSTRAINT ck_orders_currency CHECK ((currency = 'INR'::bpchar)),
    CONSTRAINT ck_orders_status CHECK (((status)::text = ANY (ARRAY[('PENDING'::character varying)::text, ('CONFIRMED'::character varying)::text, ('LOADING'::character varying)::text, ('LOADED'::character varying)::text, ('PARTIALLY_FULFILLED'::character varying)::text, ('COMPLETED'::character varying)::text, ('CANCELLED'::character varying)::text]))),
    CONSTRAINT ck_orders_total_non_negative CHECK ((total_amount >= (0)::numeric))
);


--
-- Name: orders_order_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.orders_order_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: orders_order_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.orders_order_id_seq OWNED BY public.orders.order_id;


--
-- Name: otp_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.otp_requests (
    otp_id bigint NOT NULL,
    mobile character varying(20) NOT NULL,
    otp_code character varying(10) NOT NULL,
    purpose character varying(50) DEFAULT 'LOGIN'::character varying NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    is_used boolean DEFAULT false NOT NULL,
    used_at timestamp with time zone,
    attempt_count integer DEFAULT 0 NOT NULL,
    ip_address character varying(100),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: otp_requests_otp_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.otp_requests_otp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: otp_requests_otp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.otp_requests_otp_id_seq OWNED BY public.otp_requests.otp_id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payments (
    payment_id bigint NOT NULL,
    payment_code character varying(30) DEFAULT public.next_public_code('payments'::text, 'PAY'::text, 4, true) NOT NULL,
    order_id bigint,
    user_subscription_id bigint,
    payment_for character varying(30) DEFAULT 'ORDER'::character varying NOT NULL,
    payer_user_id bigint,
    amount numeric(15,2) NOT NULL,
    payment_method character varying(50),
    status character varying(30) DEFAULT 'PENDING'::character varying NOT NULL,
    paid_at timestamp with time zone,
    provider character varying(50),
    provider_payment_id character varying(255),
    provider_order_id character varying(255),
    provider_signature text,
    transaction_reference character varying(255),
    raw_response jsonb,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    version bigint DEFAULT 1 NOT NULL,
    currency character(3) DEFAULT 'INR'::bpchar NOT NULL,
    CONSTRAINT ck_payments_amount_positive CHECK ((amount > (0)::numeric)),
    CONSTRAINT ck_payments_currency CHECK ((currency = 'INR'::bpchar)),
    CONSTRAINT ck_payments_method CHECK (((payment_method IS NULL) OR ((payment_method)::text = ANY (ARRAY[('UPI'::character varying)::text, ('CARD'::character varying)::text, ('CASH'::character varying)::text, ('BANK_TRANSFER'::character varying)::text, ('NET_BANKING'::character varying)::text, ('WALLET'::character varying)::text, ('COD'::character varying)::text, ('CHEQUE'::character varying)::text, ('OTHER'::character varying)::text])))),
    CONSTRAINT ck_payments_status CHECK (((status)::text = ANY (ARRAY[('PENDING'::character varying)::text, ('SUCCESS'::character varying)::text, ('FAILED'::character varying)::text, ('REFUNDED'::character varying)::text, ('CANCELLED'::character varying)::text]))),
    CONSTRAINT ck_payments_target CHECK (((((payment_for)::text = 'ORDER'::text) AND (order_id IS NOT NULL) AND (user_subscription_id IS NULL)) OR (((payment_for)::text = 'SUBSCRIPTION'::text) AND (user_subscription_id IS NOT NULL) AND (order_id IS NULL))))
);


--
-- Name: payments_payment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payments_payment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payments_payment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payments_payment_id_seq OWNED BY public.payments.payment_id;


--
-- Name: plant_care_guides; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plant_care_guides (
    care_guide_id bigint NOT NULL,
    plant_id bigint NOT NULL,
    sunlight text,
    watering text,
    soil text,
    temperature text,
    fertilizer text,
    pruning text,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: plant_care_guides_care_guide_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.plant_care_guides_care_guide_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: plant_care_guides_care_guide_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.plant_care_guides_care_guide_id_seq OWNED BY public.plant_care_guides.care_guide_id;


--
-- Name: plant_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plant_categories (
    category_id integer NOT NULL,
    category_name character varying(100) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: plant_categories_category_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.plant_categories_category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: plant_categories_category_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.plant_categories_category_id_seq OWNED BY public.plant_categories.category_id;


--
-- Name: plant_category_mappings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plant_category_mappings (
    plant_id bigint NOT NULL,
    category_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: plant_images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plant_images (
    image_id bigint NOT NULL,
    plant_id bigint NOT NULL,
    image_url text NOT NULL,
    alt_text character varying(255),
    display_order integer DEFAULT 0 NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: plant_images_image_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.plant_images_image_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: plant_images_image_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.plant_images_image_id_seq OWNED BY public.plant_images.image_id;


--
-- Name: plant_names; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plant_names (
    plant_name_id bigint NOT NULL,
    plant_id bigint NOT NULL,
    language_id smallint NOT NULL,
    plant_name character varying(255) NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: plant_names_plant_name_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.plant_names_plant_name_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: plant_names_plant_name_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.plant_names_plant_name_id_seq OWNED BY public.plant_names.plant_name_id;


--
-- Name: plant_request_responses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plant_request_responses (
    response_id bigint NOT NULL,
    request_id bigint NOT NULL,
    supplier_nursery_id bigint NOT NULL,
    responded_by_user_id bigint NOT NULL,
    available_quantity integer NOT NULL,
    remarks text,
    status character varying(30) DEFAULT 'RESPONDED'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_plant_request_responses_status CHECK (((status)::text = ANY (ARRAY[('AVAILABLE'::character varying)::text, ('PARTIAL'::character varying)::text, ('NOT_AVAILABLE'::character varying)::text, ('ACCEPTED'::character varying)::text, ('REJECTED'::character varying)::text])))
);


--
-- Name: plant_request_responses_response_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.plant_request_responses_response_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: plant_request_responses_response_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.plant_request_responses_response_id_seq OWNED BY public.plant_request_responses.response_id;


--
-- Name: plant_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plant_requests (
    request_id bigint NOT NULL,
    request_code character varying(30) DEFAULT public.next_public_code('plant_requests'::text, 'REQ'::text, 4, true) NOT NULL,
    requesting_nursery_id bigint NOT NULL,
    requested_by_user_id bigint NOT NULL,
    plant_id bigint NOT NULL,
    size_id smallint,
    quantity_required integer NOT NULL,
    required_by_date date,
    radius_km integer DEFAULT 50 NOT NULL,
    notes text,
    status character varying(30) DEFAULT 'OPEN'::character varying NOT NULL,
    expires_at timestamp with time zone,
    fulfilled_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_plant_requests_status CHECK (((status)::text = ANY (ARRAY[('DRAFT'::character varying)::text, ('OPEN'::character varying)::text, ('PARTIALLY_ACCEPTED'::character varying)::text, ('ACCEPTED'::character varying)::text, ('REJECTED'::character varying)::text, ('CLOSED'::character varying)::text])))
);


--
-- Name: plant_requests_request_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.plant_requests_request_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: plant_requests_request_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.plant_requests_request_id_seq OWNED BY public.plant_requests.request_id;


--
-- Name: plant_sizes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plant_sizes (
    size_id smallint NOT NULL,
    size_code character varying(50) NOT NULL,
    display_name character varying(100) NOT NULL,
    display_order smallint NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: plant_sizes_size_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.plant_sizes_size_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: plant_sizes_size_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.plant_sizes_size_id_seq OWNED BY public.plant_sizes.size_id;


--
-- Name: plants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plants (
    plant_id bigint NOT NULL,
    plant_code character varying(20) DEFAULT public.next_public_code('plants'::text, 'PLT'::text, 6, false) NOT NULL,
    scientific_name character varying(255) NOT NULL,
    common_name character varying(255),
    plant_type character varying(50),
    light_requirement character varying(50),
    water_requirement character varying(50),
    english_description text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    wfo_id text
);


--
-- Name: plants_plant_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.plants_plant_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: plants_plant_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.plants_plant_id_seq OWNED BY public.plants.plant_id;


--
-- Name: platform_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.platform_config (
    config_id bigint NOT NULL,
    config_key character varying(100) NOT NULL,
    config_value text NOT NULL,
    data_type character varying(20) DEFAULT 'string'::character varying NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    updated_by_user_id bigint,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: platform_config_config_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.platform_config_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: platform_config_config_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.platform_config_config_id_seq OWNED BY public.platform_config.config_id;


--
-- Name: public_code_sequences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.public_code_sequences (
    code_key character varying(40) NOT NULL,
    date_key character varying(8) DEFAULT ''::character varying NOT NULL,
    last_value bigint DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: quotation_documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quotation_documents (
    doc_id bigint NOT NULL,
    quotation_id bigint NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    object_key text NOT NULL,
    sha256_hash character varying(64) NOT NULL,
    mime_type character varying(100) DEFAULT 'application/pdf'::character varying NOT NULL,
    file_size bigint DEFAULT 0 NOT NULL,
    generated_by_user_id bigint,
    generated_by_name character varying(255),
    is_current boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_quotation_documents_file_size CHECK ((file_size >= 0)),
    CONSTRAINT ck_quotation_documents_version CHECK ((version > 0))
);


--
-- Name: quotation_documents_doc_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.quotation_documents_doc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quotation_documents_doc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.quotation_documents_doc_id_seq OWNED BY public.quotation_documents.doc_id;


--
-- Name: quotation_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quotation_items (
    quotation_item_id bigint NOT NULL,
    quotation_id bigint NOT NULL,
    plant_id bigint NOT NULL,
    scientific_name character varying(255) NOT NULL,
    common_name character varying(255),
    description text,
    quantity numeric(12,2) NOT NULL,
    unit_price numeric(15,2),
    total_price numeric(15,2),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_quotation_items_amounts CHECK (((quantity > (0)::numeric) AND ((unit_price IS NULL) OR (unit_price >= (0)::numeric)) AND ((total_price IS NULL) OR (total_price >= (0)::numeric))))
);


--
-- Name: quotation_items_quotation_item_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.quotation_items_quotation_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quotation_items_quotation_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.quotation_items_quotation_item_id_seq OWNED BY public.quotation_items.quotation_item_id;


--
-- Name: quotation_verifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quotation_verifications (
    verification_id bigint NOT NULL,
    quotation_id bigint NOT NULL,
    token character varying(128) NOT NULL,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    revoked_at timestamp with time zone,
    revoked_by_user_id bigint,
    CONSTRAINT ck_quotation_verifications_status CHECK (((status)::text = ANY (ARRAY[('ACTIVE'::character varying)::text, ('REVOKED'::character varying)::text])))
);


--
-- Name: quotation_verifications_verification_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.quotation_verifications_verification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quotation_verifications_verification_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.quotation_verifications_verification_id_seq OWNED BY public.quotation_verifications.verification_id;


--
-- Name: quotations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quotations (
    quotation_id bigint NOT NULL,
    quotation_code character varying(30) NOT NULL,
    created_by_user_id bigint NOT NULL,
    created_by_name character varying(255),
    nursery_id bigint,
    nursery_name character varying(255),
    nursery_phone character varying(20),
    customer_user_id bigint,
    assigned_manager_user_id bigint,
    recipient_name character varying(255),
    recipient_mobile character varying(20),
    buyer_nursery_id bigint,
    notes text,
    rejection_reason text,
    total_amount numeric(15,2) DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'CUSTOMER_DRAFT'::character varying NOT NULL,
    sent_at timestamp with time zone,
    customer_responded_at timestamp with time zone,
    converted_order_id bigint,
    converted_by_user_id bigint,
    converted_at timestamp with time zone,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    quotation_type character varying(20) DEFAULT 'CUSTOMER'::character varying NOT NULL,
    valid_until timestamp with time zone,
    version bigint DEFAULT 1 NOT NULL,
    currency character(3) DEFAULT 'INR'::bpchar NOT NULL,
    CONSTRAINT ck_quotations_currency CHECK ((currency = 'INR'::bpchar)),
    CONSTRAINT ck_quotations_quotation_type CHECK (((quotation_type)::text = ANY (ARRAY[('INTERNAL'::character varying)::text, ('CUSTOMER'::character varying)::text]))),
    CONSTRAINT ck_quotations_status CHECK (((status)::text = ANY (ARRAY[('INTERNAL_DRAFT'::character varying)::text, ('CUSTOMER_DRAFT'::character varying)::text, ('CUSTOMER_SENT'::character varying)::text, ('CUSTOMER_ACCEPTED'::character varying)::text, ('CUSTOMER_REJECTED'::character varying)::text, ('CONVERTED'::character varying)::text, ('EXPIRED'::character varying)::text]))),
    CONSTRAINT ck_quotations_total_non_negative CHECK (((total_amount IS NULL) OR (total_amount >= (0)::numeric)))
);


--
-- Name: quotations_quotation_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.quotations_quotation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quotations_quotation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.quotations_quotation_id_seq OWNED BY public.quotations.quotation_id;


--
-- Name: ratings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ratings (
    rating_id bigint NOT NULL,
    rating_type text NOT NULL,
    rated_by_user_id bigint NOT NULL,
    order_id bigint,
    dispatch_id bigint,
    overall_rating smallint,
    would_recommend boolean,
    driver_behaviour_rating smallint,
    on_time_delivery_rating smallint,
    plant_condition_rating smallint,
    plant_quality_rating smallint,
    communication_rating smallint,
    overall_experience_rating smallint,
    would_buy_again boolean,
    comment text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_ratings_scores CHECK ((((overall_rating IS NULL) OR ((overall_rating >= 1) AND (overall_rating <= 5))) AND ((driver_behaviour_rating IS NULL) OR ((driver_behaviour_rating >= 1) AND (driver_behaviour_rating <= 5))) AND ((on_time_delivery_rating IS NULL) OR ((on_time_delivery_rating >= 1) AND (on_time_delivery_rating <= 5))) AND ((plant_condition_rating IS NULL) OR ((plant_condition_rating >= 1) AND (plant_condition_rating <= 5))) AND ((plant_quality_rating IS NULL) OR ((plant_quality_rating >= 1) AND (plant_quality_rating <= 5))) AND ((communication_rating IS NULL) OR ((communication_rating >= 1) AND (communication_rating <= 5))) AND ((overall_experience_rating IS NULL) OR ((overall_experience_rating >= 1) AND (overall_experience_rating <= 5))))),
    CONSTRAINT ck_ratings_type CHECK ((rating_type = ANY (ARRAY['APP'::text, 'TRIP'::text, 'ORDER'::text])))
);


--
-- Name: ratings_rating_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ratings_rating_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ratings_rating_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ratings_rating_id_seq OWNED BY public.ratings.rating_id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    role_id smallint NOT NULL,
    role_code character varying(50) NOT NULL,
    role_name character varying(100) NOT NULL,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: roles_role_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.roles_role_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roles_role_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.roles_role_id_seq OWNED BY public.roles.role_id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version text NOT NULL,
    applied_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    checksum character varying(64) DEFAULT 'baseline'::character varying NOT NULL
);


--
-- Name: security_audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.security_audit_logs (
    security_audit_log_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    request_id character varying(100),
    user_id bigint,
    nursery_id bigint,
    event_type character varying(100) NOT NULL,
    description text,
    metadata jsonb,
    ip_address character varying(100),
    device_info jsonb
);


--
-- Name: security_audit_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.security_audit_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: security_audit_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.security_audit_logs_id_seq OWNED BY public.security_audit_logs.security_audit_log_id;


--
-- Name: sms_dlt_entities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sms_dlt_entities (
    entity_id bigint NOT NULL,
    pe_id character varying(30),
    entity_name character varying(255) NOT NULL,
    dlt_operator character varying(30) DEFAULT 'JIO'::character varying NOT NULL,
    telemarketer_name character varying(255),
    telemarketer_id character varying(50),
    status character varying(30) DEFAULT 'NOT_REGISTERED'::character varying NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_sms_dlt_entities_dlt_operator CHECK (((dlt_operator)::text = ANY (ARRAY['JIO'::text, 'AIRTEL'::text, 'VI'::text, 'BSNL'::text, 'TATA'::text, 'SMARTPING'::text]))),
    CONSTRAINT ck_sms_dlt_entities_pe_id CHECK (((pe_id IS NULL) OR ((pe_id)::text ~ '^[0-9]{10,30}$'::text))),
    CONSTRAINT ck_sms_dlt_entities_status CHECK (((status)::text = ANY (ARRAY['NOT_REGISTERED'::text, 'SUBMITTED'::text, 'APPROVED'::text, 'REJECTED'::text])))
);


--
-- Name: sms_dlt_entities_entity_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sms_dlt_entities_entity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sms_dlt_entities_entity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sms_dlt_entities_entity_id_seq OWNED BY public.sms_dlt_entities.entity_id;


--
-- Name: sms_headers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sms_headers (
    header_id bigint NOT NULL,
    header character varying(11) NOT NULL,
    header_type character varying(20) NOT NULL,
    dlt_header_id character varying(30),
    status character varying(30) DEFAULT 'DRAFT'::character varying NOT NULL,
    rejection_reason text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_sms_headers_header_type CHECK (((header_type)::text = ANY (ARRAY['TRANSACTIONAL'::text, 'SERVICE'::text, 'PROMOTIONAL'::text, 'GOVERNMENT'::text]))),
    CONSTRAINT ck_sms_headers_status CHECK (((status)::text = ANY (ARRAY['DRAFT'::text, 'SUBMITTED'::text, 'APPROVED'::text, 'REJECTED'::text, 'INACTIVE'::text])))
);


--
-- Name: sms_headers_header_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sms_headers_header_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sms_headers_header_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sms_headers_header_id_seq OWNED BY public.sms_headers.header_id;


--
-- Name: sms_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sms_messages (
    sms_message_id bigint NOT NULL,
    sms_template_id bigint,
    template_code character varying(60) NOT NULL,
    user_id bigint,
    mobile character varying(15) NOT NULL,
    message_body text NOT NULL,
    header character varying(11),
    dlt_entity_id character varying(30),
    dlt_template_id character varying(30),
    category character varying(30) NOT NULL,
    parts smallint DEFAULT 1 NOT NULL,
    provider character varying(30) NOT NULL,
    provider_message_id character varying(100),
    status character varying(20) NOT NULL,
    error_code character varying(60),
    error_message text,
    reference_type character varying(30),
    reference_id bigint,
    sent_at timestamp with time zone,
    delivered_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_sms_messages_status CHECK (((status)::text = ANY (ARRAY['QUEUED'::text, 'SENT'::text, 'DELIVERED'::text, 'FAILED'::text, 'BLOCKED'::text, 'MOCKED'::text])))
);


--
-- Name: sms_messages_sms_message_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sms_messages_sms_message_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sms_messages_sms_message_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sms_messages_sms_message_id_seq OWNED BY public.sms_messages.sms_message_id;


--
-- Name: sms_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sms_preferences (
    user_id bigint NOT NULL,
    is_promotional_opt_in boolean DEFAULT false NOT NULL,
    promotional_consent_at timestamp with time zone,
    promotional_revoked_at timestamp with time zone,
    consent_source character varying(30),
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: sms_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sms_templates (
    sms_template_id bigint NOT NULL,
    template_code character varying(60) NOT NULL,
    template_name character varying(255) NOT NULL,
    category character varying(30) NOT NULL,
    header_id bigint,
    body text NOT NULL,
    variables jsonb DEFAULT '[]'::jsonb NOT NULL,
    is_unicode boolean DEFAULT false NOT NULL,
    dlt_template_id character varying(30),
    status character varying(30) DEFAULT 'DRAFT'::character varying NOT NULL,
    rejection_reason text,
    whitelisted_urls jsonb DEFAULT '[]'::jsonb NOT NULL,
    whitelisted_numbers jsonb DEFAULT '[]'::jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    approved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_sms_templates_category CHECK (((category)::text = ANY (ARRAY['TRANSACTIONAL'::text, 'SERVICE_IMPLICIT'::text, 'SERVICE_EXPLICIT'::text, 'PROMOTIONAL'::text]))),
    CONSTRAINT ck_sms_templates_dlt_template_id CHECK (((dlt_template_id IS NULL) OR ((dlt_template_id)::text ~ '^[0-9]{10,30}$'::text))),
    CONSTRAINT ck_sms_templates_status CHECK (((status)::text = ANY (ARRAY['DRAFT'::text, 'SUBMITTED'::text, 'APPROVED'::text, 'REJECTED'::text, 'INACTIVE'::text])))
);


--
-- Name: sms_templates_sms_template_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sms_templates_sms_template_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sms_templates_sms_template_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sms_templates_sms_template_id_seq OWNED BY public.sms_templates.sms_template_id;


--
-- Name: sourcing_network_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sourcing_network_members (
    member_id bigint NOT NULL,
    nursery_id bigint NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_road_accessible boolean DEFAULT true NOT NULL,
    is_lorry_accessible boolean DEFAULT true NOT NULL,
    is_contact_visible boolean DEFAULT false NOT NULL,
    service_radius_km integer DEFAULT 50 NOT NULL,
    joined_by_user_id bigint,
    joined_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deactivated_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: sourcing_network_members_member_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sourcing_network_members_member_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sourcing_network_members_member_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sourcing_network_members_member_id_seq OWNED BY public.sourcing_network_members.member_id;


--
-- Name: sourcing_post_photos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sourcing_post_photos (
    photo_id bigint NOT NULL,
    post_id bigint NOT NULL,
    photo_url character varying(500) NOT NULL,
    display_order smallint DEFAULT 0 NOT NULL,
    uploaded_by_user_id bigint,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: sourcing_post_photos_photo_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sourcing_post_photos_photo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sourcing_post_photos_photo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sourcing_post_photos_photo_id_seq OWNED BY public.sourcing_post_photos.photo_id;


--
-- Name: sourcing_post_responses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sourcing_post_responses (
    response_id bigint NOT NULL,
    post_id bigint NOT NULL,
    responder_nursery_id bigint NOT NULL,
    responded_by_user_id bigint NOT NULL,
    available_quantity integer,
    notes text,
    contact_info character varying(255),
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    responded_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: sourcing_post_responses_response_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sourcing_post_responses_response_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sourcing_post_responses_response_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sourcing_post_responses_response_id_seq OWNED BY public.sourcing_post_responses.response_id;


--
-- Name: sourcing_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sourcing_posts (
    post_id bigint NOT NULL,
    post_code character varying(30) DEFAULT public.next_public_code('sourcing_posts'::text, 'SRC'::text, 4, true) NOT NULL,
    nursery_id bigint NOT NULL,
    posted_by_user_id bigint NOT NULL,
    post_type character varying(20) NOT NULL,
    plant_id bigint,
    plant_name character varying(255) NOT NULL,
    size_description character varying(100),
    quantity integer,
    urgency character varying(20) DEFAULT 'FLEXIBLE'::character varying NOT NULL,
    needed_by_date date,
    notes text,
    radius_km integer DEFAULT 50 NOT NULL,
    response_count integer DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'OPEN'::character varying NOT NULL,
    expires_at timestamp with time zone,
    closed_at timestamp with time zone,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_sourcing_posts_post_type CHECK (((post_type)::text = ANY (ARRAY[('NEED'::character varying)::text, ('AVAILABLE'::character varying)::text]))),
    CONSTRAINT ck_sourcing_posts_urgency CHECK (((urgency)::text = ANY (ARRAY[('TODAY'::character varying)::text, ('URGENT'::character varying)::text, ('FLEXIBLE'::character varying)::text])))
);


--
-- Name: sourcing_posts_post_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sourcing_posts_post_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sourcing_posts_post_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sourcing_posts_post_id_seq OWNED BY public.sourcing_posts.post_id;


--
-- Name: subscription_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscription_plans (
    plan_id bigint NOT NULL,
    plan_code character varying(50) NOT NULL,
    plan_name character varying(100) NOT NULL,
    description text,
    monthly_price numeric(15,2),
    yearly_price numeric(15,2),
    max_users integer,
    max_nurseries integer,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    max_managers integer,
    features jsonb DEFAULT '{}'::jsonb,
    currency character(3) DEFAULT 'INR'::bpchar NOT NULL,
    CONSTRAINT ck_subscription_plans_currency CHECK ((currency = 'INR'::bpchar)),
    CONSTRAINT ck_subscription_plans_prices CHECK ((((monthly_price IS NULL) OR (monthly_price >= (0)::numeric)) AND ((yearly_price IS NULL) OR (yearly_price >= (0)::numeric))))
);


--
-- Name: subscription_plans_plan_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.subscription_plans_plan_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subscription_plans_plan_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.subscription_plans_plan_id_seq OWNED BY public.subscription_plans.plan_id;


--
-- Name: subscription_promos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscription_promos (
    promo_id bigint NOT NULL,
    promo_code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    discount_type character varying(20) DEFAULT 'PERCENTAGE'::character varying NOT NULL,
    discount_value numeric(15,2) DEFAULT 0 NOT NULL,
    max_discount_cap numeric(15,2),
    applicable_plans jsonb DEFAULT '[]'::jsonb NOT NULL,
    applicable_cycles jsonb DEFAULT '[]'::jsonb NOT NULL,
    valid_from date NOT NULL,
    valid_until date NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    max_uses integer,
    used_count integer DEFAULT 0 NOT NULL,
    created_by_user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone,
    CONSTRAINT ck_subscription_promos_discount CHECK (((discount_value > (0)::numeric) AND (((discount_type)::text <> 'PERCENTAGE'::text) OR (discount_value <= (100)::numeric)) AND ((max_discount_cap IS NULL) OR (max_discount_cap >= (0)::numeric)))),
    CONSTRAINT ck_subscription_promos_discount_type CHECK (((discount_type)::text = ANY (ARRAY[('PERCENTAGE'::character varying)::text, ('FLAT'::character varying)::text])))
);


--
-- Name: subscription_promos_promo_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.subscription_promos_promo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subscription_promos_promo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.subscription_promos_promo_id_seq OWNED BY public.subscription_promos.promo_id;


--
-- Name: trip_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trip_events (
    trip_event_id bigint NOT NULL,
    dispatch_id bigint NOT NULL,
    event_type character varying(50) NOT NULL,
    latitude numeric(10,7),
    longitude numeric(10,7),
    photo_url text,
    remarks text,
    created_by_user_id bigint,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: trip_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.trip_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trip_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.trip_events_id_seq OWNED BY public.trip_events.trip_event_id;


--
-- Name: trip_tracking_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trip_tracking_links (
    trip_tracking_link_id bigint NOT NULL,
    tracking_uuid uuid DEFAULT gen_random_uuid() NOT NULL,
    dispatch_id bigint NOT NULL,
    customer_user_id bigint,
    customer_mobile character varying(20),
    expires_at timestamp with time zone,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: trip_tracking_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.trip_tracking_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trip_tracking_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.trip_tracking_links_id_seq OWNED BY public.trip_tracking_links.trip_tracking_link_id;


--
-- Name: user_activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_activities (
    activity_id bigint NOT NULL,
    user_id bigint NOT NULL,
    session_id bigint,
    activity_type character varying(100) NOT NULL,
    entity_type character varying(100),
    entity_id bigint,
    activity_data jsonb,
    occurred_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: user_activities_activity_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_activities_activity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_activities_activity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_activities_activity_id_seq OWNED BY public.user_activities.activity_id;


--
-- Name: user_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_addresses (
    address_id bigint NOT NULL,
    user_id bigint NOT NULL,
    address_type character varying(50),
    contact_name character varying(100),
    contact_mobile character varying(20),
    address_line1 character varying(255) NOT NULL,
    address_line2 character varying(255),
    city character varying(100),
    state character varying(100),
    country character varying(100),
    postal_code character varying(20),
    landmark character varying(255),
    latitude numeric(10,7),
    longitude numeric(10,7),
    gps_accuracy_meters numeric(8,2),
    location_source character varying(50),
    location_confirmed_by_user_id bigint,
    location_confirmed_at timestamp with time zone,
    location public.geography(Point,4326),
    is_default boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: user_addresses_address_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_addresses_address_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_addresses_address_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_addresses_address_id_seq OWNED BY public.user_addresses.address_id;


--
-- Name: user_notification_devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_notification_devices (
    device_id bigint NOT NULL,
    user_id bigint NOT NULL,
    fcm_token text NOT NULL,
    device_type character varying(50),
    device_id_external character varying(255),
    platform character varying(50),
    app_version character varying(50),
    is_active boolean DEFAULT true NOT NULL,
    last_seen_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: user_notification_devices_device_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.user_notification_devices ALTER COLUMN device_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.user_notification_devices_device_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_roles (
    user_id bigint NOT NULL,
    role_id smallint NOT NULL,
    assigned_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    assigned_by_user_id bigint
);


--
-- Name: user_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_sessions (
    session_id bigint NOT NULL,
    user_id bigint NOT NULL,
    session_token character varying(255),
    logged_in_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_activity_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    status character varying(20) DEFAULT 'ACTIVE'::character varying,
    device_type character varying(50),
    os_name character varying(50),
    app_version character varying(50),
    ip_address character varying(100),
    user_agent text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_user_sessions_status CHECK (((status)::text = ANY (ARRAY[('ACTIVE'::character varying)::text, ('LOGGED_OUT'::character varying)::text])))
);


--
-- Name: user_sessions_session_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_sessions_session_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_sessions_session_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_sessions_session_id_seq OWNED BY public.user_sessions.session_id;


--
-- Name: user_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_subscriptions (
    user_subscription_id bigint NOT NULL,
    subscription_code character varying(20) DEFAULT public.next_public_code('user_subscriptions'::text, 'SUB'::text, 6, false) NOT NULL,
    user_id bigint NOT NULL,
    plan_id bigint NOT NULL,
    start_date date NOT NULL,
    end_date date,
    status character varying(30) DEFAULT 'ACTIVE'::character varying,
    is_auto_renew boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_user_subscriptions_status CHECK (((status)::text = ANY (ARRAY[('TRIAL'::character varying)::text, ('ACTIVE'::character varying)::text, ('PAUSED'::character varying)::text, ('CANCELLED'::character varying)::text, ('EXPIRED'::character varying)::text])))
);


--
-- Name: user_subscriptions_user_subscription_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_subscriptions_user_subscription_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_subscriptions_user_subscription_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_subscriptions_user_subscription_id_seq OWNED BY public.user_subscriptions.user_subscription_id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    user_id bigint NOT NULL,
    user_code character varying(20) DEFAULT public.next_public_code('users'::text, 'USR'::text, 6, false) NOT NULL,
    first_name character varying(100) NOT NULL,
    last_name character varying(100),
    mobile character varying(20) NOT NULL,
    email character varying(255),
    password_hash text,
    profile_image_url text,
    is_mobile_verified boolean DEFAULT false,
    is_email_verified boolean DEFAULT false,
    is_onboarding_completed boolean DEFAULT false NOT NULL,
    initial_activity character varying(30),
    onboarding_completed_at timestamp with time zone,
    gender public.gender_type,
    status character varying(20) DEFAULT 'ACTIVE'::character varying,
    last_login_at timestamp with time zone,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    created_by_user_id bigint,
    updated_by_user_id bigint,
    suspension_reason text,
    suspended_by_user_id bigint,
    suspended_at timestamp with time zone,
    unsuspended_by_user_id bigint,
    unsuspended_at timestamp with time zone,
    CONSTRAINT ck_users_initial_activity CHECK (((initial_activity IS NULL) OR ((initial_activity)::text = ANY (ARRAY[('CUSTOMER'::character varying)::text, ('OWNER'::character varying)::text, ('DRIVER'::character varying)::text, ('MANAGER'::character varying)::text])))),
    CONSTRAINT ck_users_mobile CHECK ((((mobile)::text ~ '^[6-9][0-9]{9}$'::text) OR ((deleted_at IS NOT NULL) AND ((mobile)::text = ('DEL'::text || (user_id)::text))))),
    CONSTRAINT ck_users_status CHECK (((status)::text = ANY (ARRAY[('ACTIVE'::character varying)::text, ('SUSPENDED'::character varying)::text, ('DELETED'::character varying)::text])))
);


--
-- Name: users_user_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_user_id_seq OWNED BY public.users.user_id;


--
-- Name: vehicle_locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vehicle_locations (
    location_id bigint NOT NULL,
    vehicle_id bigint NOT NULL,
    latitude numeric(10,7) NOT NULL,
    longitude numeric(10,7) NOT NULL,
    speed_kmph numeric(8,2),
    heading_degrees numeric(8,2),
    recorded_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: vehicle_locations_location_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.vehicle_locations_location_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: vehicle_locations_location_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.vehicle_locations_location_id_seq OWNED BY public.vehicle_locations.location_id;


--
-- Name: vehicle_tracking; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vehicle_tracking (
    tracking_id bigint NOT NULL,
    vehicle_id bigint,
    driver_id bigint,
    dispatch_id bigint,
    latitude numeric(10,7) NOT NULL,
    longitude numeric(10,7) NOT NULL,
    tracked_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    notes text
);


--
-- Name: vehicle_tracking_tracking_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.vehicle_tracking ALTER COLUMN tracking_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.vehicle_tracking_tracking_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: vehicles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vehicles (
    vehicle_id bigint NOT NULL,
    vehicle_code character varying(20) DEFAULT public.next_public_code('vehicles'::text, 'VEH'::text, 6, false) NOT NULL,
    vehicle_number character varying(50) NOT NULL,
    vehicle_type character varying(50),
    capacity_kg numeric(12,2),
    owner_name character varying(255),
    mobile character varying(20),
    status character varying(20) DEFAULT 'ACTIVE'::character varying,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_vehicles_status CHECK (((status)::text = ANY (ARRAY[('ACTIVE'::character varying)::text, ('INACTIVE'::character varying)::text, ('MAINTENANCE'::character varying)::text, ('RETIRED'::character varying)::text])))
);


--
-- Name: vehicles_vehicle_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.vehicles_vehicle_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: vehicles_vehicle_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.vehicles_vehicle_id_seq OWNED BY public.vehicles.vehicle_id;


--
-- Name: attachments attachment_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachments ALTER COLUMN attachment_id SET DEFAULT nextval('public.attachments_attachment_id_seq'::regclass);


--
-- Name: audit_logs audit_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs ALTER COLUMN audit_id SET DEFAULT nextval('public.audit_logs_audit_id_seq'::regclass);


--
-- Name: botanical_names botanical_name_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.botanical_names ALTER COLUMN botanical_name_id SET DEFAULT nextval('public.botanical_names_botanical_name_id_seq'::regclass);


--
-- Name: client_crash_reports client_crash_report_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_crash_reports ALTER COLUMN client_crash_report_id SET DEFAULT nextval('public.client_crash_reports_client_crash_report_id_seq'::regclass);


--
-- Name: dispatch_assignments dispatch_assignment_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatch_assignments ALTER COLUMN dispatch_assignment_id SET DEFAULT nextval('public.dispatch_assignments_dispatch_assignment_id_seq'::regclass);


--
-- Name: dispatches dispatch_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatches ALTER COLUMN dispatch_id SET DEFAULT nextval('public.dispatches_dispatch_id_seq'::regclass);


--
-- Name: drivers driver_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drivers ALTER COLUMN driver_id SET DEFAULT nextval('public.drivers_driver_id_seq'::regclass);


--
-- Name: email_messages email_message_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_messages ALTER COLUMN email_message_id SET DEFAULT nextval('public.email_messages_email_message_id_seq'::regclass);


--
-- Name: email_senders sender_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_senders ALTER COLUMN sender_id SET DEFAULT nextval('public.email_sender_sender_id_seq'::regclass);


--
-- Name: email_templates email_template_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_templates ALTER COLUMN email_template_id SET DEFAULT nextval('public.email_templates_email_template_id_seq'::regclass);


--
-- Name: import_checkpoints import_checkpoint_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_checkpoints ALTER COLUMN import_checkpoint_id SET DEFAULT nextval('public.import_checkpoints_import_checkpoint_id_seq'::regclass);


--
-- Name: invites invite_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invites ALTER COLUMN invite_id SET DEFAULT nextval('public.invites_id_seq'::regclass);


--
-- Name: languages language_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.languages ALTER COLUMN language_id SET DEFAULT nextval('public.languages_language_id_seq'::regclass);


--
-- Name: market_ad_reports report_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_reports ALTER COLUMN report_id SET DEFAULT nextval('public.market_listing_reports_report_id_seq'::regclass);


--
-- Name: market_ad_saves save_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_saves ALTER COLUMN save_id SET DEFAULT nextval('public.market_listing_saves_save_id_seq'::regclass);


--
-- Name: market_ad_views view_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_views ALTER COLUMN view_id SET DEFAULT nextval('public.market_listing_views_view_id_seq'::regclass);


--
-- Name: market_ads ad_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ads ALTER COLUMN ad_id SET DEFAULT nextval('public.market_listings_listing_id_seq'::regclass);


--
-- Name: market_enquiries enquiry_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_enquiries ALTER COLUMN enquiry_id SET DEFAULT nextval('public.market_enquiries_enquiry_id_seq'::regclass);


--
-- Name: market_enquiry_messages message_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_enquiry_messages ALTER COLUMN message_id SET DEFAULT nextval('public.market_enquiry_messages_message_id_seq'::regclass);


--
-- Name: notification_templates template_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_templates ALTER COLUMN template_id SET DEFAULT nextval('public.notification_templates_template_id_seq'::regclass);


--
-- Name: notifications notification_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications ALTER COLUMN notification_id SET DEFAULT nextval('public.notifications_notification_id_seq'::regclass);


--
-- Name: nurseries nursery_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nurseries ALTER COLUMN nursery_id SET DEFAULT nextval('public.nurseries_nursery_id_seq'::regclass);


--
-- Name: nursery_addresses nursery_address_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_addresses ALTER COLUMN nursery_address_id SET DEFAULT nextval('public.nursery_addresses_nursery_address_id_seq'::regclass);


--
-- Name: nursery_applications application_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_applications ALTER COLUMN application_id SET DEFAULT nextval('public.nursery_applications_application_id_seq'::regclass);


--
-- Name: nursery_drivers nursery_driver_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_drivers ALTER COLUMN nursery_driver_id SET DEFAULT nextval('public.nursery_drivers_id_seq'::regclass);


--
-- Name: nursery_top_items top_item_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_top_items ALTER COLUMN top_item_id SET DEFAULT nextval('public.nursery_top_items_top_item_id_seq'::regclass);


--
-- Name: nursery_users nursery_user_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_users ALTER COLUMN nursery_user_id SET DEFAULT nextval('public.nursery_users_nursery_user_id_seq'::regclass);


--
-- Name: order_delivery_snapshots snapshot_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_delivery_snapshots ALTER COLUMN snapshot_id SET DEFAULT nextval('public.order_delivery_snapshots_snapshot_id_seq'::regclass);


--
-- Name: order_documents doc_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_documents ALTER COLUMN doc_id SET DEFAULT nextval('public.order_documents_doc_id_seq'::regclass);


--
-- Name: order_items order_item_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items ALTER COLUMN order_item_id SET DEFAULT nextval('public.order_items_order_item_id_seq'::regclass);


--
-- Name: order_verifications verification_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_verifications ALTER COLUMN verification_id SET DEFAULT nextval('public.order_verifications_verification_id_seq'::regclass);


--
-- Name: orders order_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders ALTER COLUMN order_id SET DEFAULT nextval('public.orders_order_id_seq'::regclass);


--
-- Name: otp_requests otp_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.otp_requests ALTER COLUMN otp_id SET DEFAULT nextval('public.otp_requests_otp_id_seq'::regclass);


--
-- Name: payments payment_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments ALTER COLUMN payment_id SET DEFAULT nextval('public.payments_payment_id_seq'::regclass);


--
-- Name: plant_care_guides care_guide_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_care_guides ALTER COLUMN care_guide_id SET DEFAULT nextval('public.plant_care_guides_care_guide_id_seq'::regclass);


--
-- Name: plant_categories category_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_categories ALTER COLUMN category_id SET DEFAULT nextval('public.plant_categories_category_id_seq'::regclass);


--
-- Name: plant_images image_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_images ALTER COLUMN image_id SET DEFAULT nextval('public.plant_images_image_id_seq'::regclass);


--
-- Name: plant_names plant_name_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_names ALTER COLUMN plant_name_id SET DEFAULT nextval('public.plant_names_plant_name_id_seq'::regclass);


--
-- Name: plant_request_responses response_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_request_responses ALTER COLUMN response_id SET DEFAULT nextval('public.plant_request_responses_response_id_seq'::regclass);


--
-- Name: plant_requests request_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_requests ALTER COLUMN request_id SET DEFAULT nextval('public.plant_requests_request_id_seq'::regclass);


--
-- Name: plant_sizes size_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_sizes ALTER COLUMN size_id SET DEFAULT nextval('public.plant_sizes_size_id_seq'::regclass);


--
-- Name: plants plant_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plants ALTER COLUMN plant_id SET DEFAULT nextval('public.plants_plant_id_seq'::regclass);


--
-- Name: platform_config config_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_config ALTER COLUMN config_id SET DEFAULT nextval('public.platform_config_config_id_seq'::regclass);


--
-- Name: quotation_documents doc_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotation_documents ALTER COLUMN doc_id SET DEFAULT nextval('public.quotation_documents_doc_id_seq'::regclass);


--
-- Name: quotation_items quotation_item_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotation_items ALTER COLUMN quotation_item_id SET DEFAULT nextval('public.quotation_items_quotation_item_id_seq'::regclass);


--
-- Name: quotation_verifications verification_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotation_verifications ALTER COLUMN verification_id SET DEFAULT nextval('public.quotation_verifications_verification_id_seq'::regclass);


--
-- Name: quotations quotation_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotations ALTER COLUMN quotation_id SET DEFAULT nextval('public.quotations_quotation_id_seq'::regclass);


--
-- Name: ratings rating_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings ALTER COLUMN rating_id SET DEFAULT nextval('public.ratings_rating_id_seq'::regclass);


--
-- Name: roles role_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles ALTER COLUMN role_id SET DEFAULT nextval('public.roles_role_id_seq'::regclass);


--
-- Name: security_audit_logs security_audit_log_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security_audit_logs ALTER COLUMN security_audit_log_id SET DEFAULT nextval('public.security_audit_logs_id_seq'::regclass);


--
-- Name: sms_dlt_entities entity_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sms_dlt_entities ALTER COLUMN entity_id SET DEFAULT nextval('public.sms_dlt_entities_entity_id_seq'::regclass);


--
-- Name: sms_headers header_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sms_headers ALTER COLUMN header_id SET DEFAULT nextval('public.sms_headers_header_id_seq'::regclass);


--
-- Name: sms_messages sms_message_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sms_messages ALTER COLUMN sms_message_id SET DEFAULT nextval('public.sms_messages_sms_message_id_seq'::regclass);


--
-- Name: sms_templates sms_template_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sms_templates ALTER COLUMN sms_template_id SET DEFAULT nextval('public.sms_templates_sms_template_id_seq'::regclass);


--
-- Name: sourcing_network_members member_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_network_members ALTER COLUMN member_id SET DEFAULT nextval('public.sourcing_network_members_member_id_seq'::regclass);


--
-- Name: sourcing_post_photos photo_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_post_photos ALTER COLUMN photo_id SET DEFAULT nextval('public.sourcing_post_photos_photo_id_seq'::regclass);


--
-- Name: sourcing_post_responses response_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_post_responses ALTER COLUMN response_id SET DEFAULT nextval('public.sourcing_post_responses_response_id_seq'::regclass);


--
-- Name: sourcing_posts post_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_posts ALTER COLUMN post_id SET DEFAULT nextval('public.sourcing_posts_post_id_seq'::regclass);


--
-- Name: subscription_plans plan_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_plans ALTER COLUMN plan_id SET DEFAULT nextval('public.subscription_plans_plan_id_seq'::regclass);


--
-- Name: subscription_promos promo_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_promos ALTER COLUMN promo_id SET DEFAULT nextval('public.subscription_promos_promo_id_seq'::regclass);


--
-- Name: trip_events trip_event_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_events ALTER COLUMN trip_event_id SET DEFAULT nextval('public.trip_events_id_seq'::regclass);


--
-- Name: trip_tracking_links trip_tracking_link_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_tracking_links ALTER COLUMN trip_tracking_link_id SET DEFAULT nextval('public.trip_tracking_links_id_seq'::regclass);


--
-- Name: user_activities activity_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_activities ALTER COLUMN activity_id SET DEFAULT nextval('public.user_activities_activity_id_seq'::regclass);


--
-- Name: user_addresses address_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_addresses ALTER COLUMN address_id SET DEFAULT nextval('public.user_addresses_address_id_seq'::regclass);


--
-- Name: user_sessions session_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions ALTER COLUMN session_id SET DEFAULT nextval('public.user_sessions_session_id_seq'::regclass);


--
-- Name: user_subscriptions user_subscription_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subscriptions ALTER COLUMN user_subscription_id SET DEFAULT nextval('public.user_subscriptions_user_subscription_id_seq'::regclass);


--
-- Name: users user_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN user_id SET DEFAULT nextval('public.users_user_id_seq'::regclass);


--
-- Name: vehicle_locations location_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_locations ALTER COLUMN location_id SET DEFAULT nextval('public.vehicle_locations_location_id_seq'::regclass);


--
-- Name: vehicles vehicle_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicles ALTER COLUMN vehicle_id SET DEFAULT nextval('public.vehicles_vehicle_id_seq'::regclass);


--
-- Name: attachments attachments_attachment_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachments
    ADD CONSTRAINT attachments_attachment_code_key UNIQUE (attachment_code);


--
-- Name: attachments attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachments
    ADD CONSTRAINT attachments_pkey PRIMARY KEY (attachment_id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (audit_id);


--
-- Name: botanical_names botanical_names_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.botanical_names
    ADD CONSTRAINT botanical_names_pkey PRIMARY KEY (botanical_name_id);


--
-- Name: botanical_names botanical_names_wfo_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.botanical_names
    ADD CONSTRAINT botanical_names_wfo_id_key UNIQUE (wfo_id);


--
-- Name: client_crash_reports client_crash_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_crash_reports
    ADD CONSTRAINT client_crash_reports_pkey PRIMARY KEY (client_crash_report_id);


--
-- Name: dispatch_assignments dispatch_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatch_assignments
    ADD CONSTRAINT dispatch_assignments_pkey PRIMARY KEY (dispatch_assignment_id);


--
-- Name: dispatch_items dispatch_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatch_items
    ADD CONSTRAINT dispatch_items_pkey PRIMARY KEY (dispatch_item_id);


--
-- Name: dispatches dispatches_dispatch_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_dispatch_code_key UNIQUE (dispatch_code);


--
-- Name: dispatches dispatches_dispatch_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_dispatch_number_key UNIQUE (dispatch_number);


--
-- Name: dispatches dispatches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_pkey PRIMARY KEY (dispatch_id);


--
-- Name: driver_locations driver_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.driver_locations
    ADD CONSTRAINT driver_locations_pkey PRIMARY KEY (location_id);


--
-- Name: drivers drivers_driver_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT drivers_driver_code_key UNIQUE (driver_code);


--
-- Name: drivers drivers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT drivers_pkey PRIMARY KEY (driver_id);


--
-- Name: drivers drivers_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT drivers_user_id_key UNIQUE (user_id);


--
-- Name: email_messages email_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_messages
    ADD CONSTRAINT email_messages_pkey PRIMARY KEY (email_message_id);


--
-- Name: email_senders email_senders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_senders
    ADD CONSTRAINT email_senders_pkey PRIMARY KEY (sender_id);


--
-- Name: email_templates email_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_templates
    ADD CONSTRAINT email_templates_pkey PRIMARY KEY (email_template_id);


--
-- Name: email_templates email_templates_template_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_templates
    ADD CONSTRAINT email_templates_template_code_key UNIQUE (template_code);


--
-- Name: import_checkpoints import_checkpoints_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_checkpoints
    ADD CONSTRAINT import_checkpoints_pkey PRIMARY KEY (import_checkpoint_id);


--
-- Name: import_checkpoints import_checkpoints_source_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_checkpoints
    ADD CONSTRAINT import_checkpoints_source_name_key UNIQUE (source_name);


--
-- Name: invites invites_invite_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invites
    ADD CONSTRAINT invites_invite_uuid_key UNIQUE (invite_uuid);


--
-- Name: invites invites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invites
    ADD CONSTRAINT invites_pkey PRIMARY KEY (invite_id);


--
-- Name: languages languages_language_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.languages
    ADD CONSTRAINT languages_language_code_key UNIQUE (language_code);


--
-- Name: languages languages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.languages
    ADD CONSTRAINT languages_pkey PRIMARY KEY (language_id);


--
-- Name: market_ad_reports market_ad_reports_ad_id_reported_by_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_reports
    ADD CONSTRAINT market_ad_reports_ad_id_reported_by_user_id_key UNIQUE (ad_id, reported_by_user_id);


--
-- Name: market_ad_reports market_ad_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_reports
    ADD CONSTRAINT market_ad_reports_pkey PRIMARY KEY (report_id);


--
-- Name: market_ad_saves market_ad_saves_ad_id_nursery_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_saves
    ADD CONSTRAINT market_ad_saves_ad_id_nursery_id_key UNIQUE (ad_id, nursery_id);


--
-- Name: market_ad_saves market_ad_saves_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_saves
    ADD CONSTRAINT market_ad_saves_pkey PRIMARY KEY (save_id);


--
-- Name: market_ad_views market_ad_views_ad_id_nursery_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_views
    ADD CONSTRAINT market_ad_views_ad_id_nursery_id_key UNIQUE (ad_id, nursery_id);


--
-- Name: market_ad_views market_ad_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_views
    ADD CONSTRAINT market_ad_views_pkey PRIMARY KEY (view_id);


--
-- Name: market_ads market_ads_ad_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ads
    ADD CONSTRAINT market_ads_ad_code_key UNIQUE (ad_code);


--
-- Name: market_ads market_ads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ads
    ADD CONSTRAINT market_ads_pkey PRIMARY KEY (ad_id);


--
-- Name: market_enquiries market_enquiries_ad_id_enquiring_nursery_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_enquiries
    ADD CONSTRAINT market_enquiries_ad_id_enquiring_nursery_id_key UNIQUE (ad_id, enquiring_nursery_id);


--
-- Name: market_enquiries market_enquiries_enquiry_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_enquiries
    ADD CONSTRAINT market_enquiries_enquiry_code_key UNIQUE (enquiry_code);


--
-- Name: market_enquiries market_enquiries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_enquiries
    ADD CONSTRAINT market_enquiries_pkey PRIMARY KEY (enquiry_id);


--
-- Name: market_enquiry_messages market_enquiry_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_enquiry_messages
    ADD CONSTRAINT market_enquiry_messages_pkey PRIMARY KEY (message_id);


--
-- Name: notification_templates notification_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_templates
    ADD CONSTRAINT notification_templates_pkey PRIMARY KEY (template_id);


--
-- Name: notification_templates notification_templates_template_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_templates
    ADD CONSTRAINT notification_templates_template_code_key UNIQUE (template_code);


--
-- Name: notifications notifications_notification_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_notification_code_key UNIQUE (notification_code);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (notification_id);


--
-- Name: nurseries nurseries_nursery_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nurseries
    ADD CONSTRAINT nurseries_nursery_code_key UNIQUE (nursery_code);


--
-- Name: nurseries nurseries_owner_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nurseries
    ADD CONSTRAINT nurseries_owner_user_id_key UNIQUE (owner_user_id);


--
-- Name: nurseries nurseries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nurseries
    ADD CONSTRAINT nurseries_pkey PRIMARY KEY (nursery_id);


--
-- Name: nursery_addresses nursery_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_addresses
    ADD CONSTRAINT nursery_addresses_pkey PRIMARY KEY (nursery_address_id);


--
-- Name: nursery_applications nursery_applications_application_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_applications
    ADD CONSTRAINT nursery_applications_application_code_key UNIQUE (application_code);


--
-- Name: nursery_applications nursery_applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_applications
    ADD CONSTRAINT nursery_applications_pkey PRIMARY KEY (application_id);


--
-- Name: nursery_drivers nursery_drivers_nursery_id_driver_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_drivers
    ADD CONSTRAINT nursery_drivers_nursery_id_driver_user_id_key UNIQUE (nursery_id, driver_user_id);


--
-- Name: nursery_drivers nursery_drivers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_drivers
    ADD CONSTRAINT nursery_drivers_pkey PRIMARY KEY (nursery_driver_id);


--
-- Name: nursery_top_items nursery_top_items_nursery_id_plant_id_size_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_top_items
    ADD CONSTRAINT nursery_top_items_nursery_id_plant_id_size_id_key UNIQUE (nursery_id, plant_id, size_id);


--
-- Name: nursery_top_items nursery_top_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_top_items
    ADD CONSTRAINT nursery_top_items_pkey PRIMARY KEY (top_item_id);


--
-- Name: nursery_top_items nursery_top_items_top_item_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_top_items
    ADD CONSTRAINT nursery_top_items_top_item_code_key UNIQUE (top_item_code);


--
-- Name: nursery_users nursery_users_nursery_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_users
    ADD CONSTRAINT nursery_users_nursery_id_user_id_key UNIQUE (nursery_id, user_id);


--
-- Name: nursery_users nursery_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_users
    ADD CONSTRAINT nursery_users_pkey PRIMARY KEY (nursery_user_id);


--
-- Name: order_delivery_snapshots order_delivery_snapshots_order_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_delivery_snapshots
    ADD CONSTRAINT order_delivery_snapshots_order_id_key UNIQUE (order_id);


--
-- Name: order_delivery_snapshots order_delivery_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_delivery_snapshots
    ADD CONSTRAINT order_delivery_snapshots_pkey PRIMARY KEY (snapshot_id);


--
-- Name: order_documents order_documents_order_id_version_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_documents
    ADD CONSTRAINT order_documents_order_id_version_key UNIQUE (order_id, version);


--
-- Name: order_documents order_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_documents
    ADD CONSTRAINT order_documents_pkey PRIMARY KEY (doc_id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (order_item_id);


--
-- Name: order_verifications order_verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_verifications
    ADD CONSTRAINT order_verifications_pkey PRIMARY KEY (verification_id);


--
-- Name: order_verifications order_verifications_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_verifications
    ADD CONSTRAINT order_verifications_token_key UNIQUE (token);


--
-- Name: orders orders_order_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_order_code_key UNIQUE (order_code);


--
-- Name: orders orders_order_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_order_number_key UNIQUE (order_number);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (order_id);


--
-- Name: otp_requests otp_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.otp_requests
    ADD CONSTRAINT otp_requests_pkey PRIMARY KEY (otp_id);


--
-- Name: payments payments_payment_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_payment_code_key UNIQUE (payment_code);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (payment_id);


--
-- Name: plant_care_guides plant_care_guides_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_care_guides
    ADD CONSTRAINT plant_care_guides_pkey PRIMARY KEY (care_guide_id);


--
-- Name: plant_care_guides plant_care_guides_plant_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_care_guides
    ADD CONSTRAINT plant_care_guides_plant_id_key UNIQUE (plant_id);


--
-- Name: plant_categories plant_categories_category_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_categories
    ADD CONSTRAINT plant_categories_category_name_key UNIQUE (category_name);


--
-- Name: plant_categories plant_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_categories
    ADD CONSTRAINT plant_categories_pkey PRIMARY KEY (category_id);


--
-- Name: plant_category_mappings plant_category_mappings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_category_mappings
    ADD CONSTRAINT plant_category_mappings_pkey PRIMARY KEY (plant_id, category_id);


--
-- Name: plant_images plant_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_images
    ADD CONSTRAINT plant_images_pkey PRIMARY KEY (image_id);


--
-- Name: plant_names plant_names_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_names
    ADD CONSTRAINT plant_names_pkey PRIMARY KEY (plant_name_id);


--
-- Name: plant_names plant_names_plant_id_language_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_names
    ADD CONSTRAINT plant_names_plant_id_language_id_key UNIQUE (plant_id, language_id);


--
-- Name: plant_request_responses plant_request_responses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_request_responses
    ADD CONSTRAINT plant_request_responses_pkey PRIMARY KEY (response_id);


--
-- Name: plant_request_responses plant_request_responses_request_id_supplier_nursery_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_request_responses
    ADD CONSTRAINT plant_request_responses_request_id_supplier_nursery_id_key UNIQUE (request_id, supplier_nursery_id);


--
-- Name: plant_requests plant_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_requests
    ADD CONSTRAINT plant_requests_pkey PRIMARY KEY (request_id);


--
-- Name: plant_requests plant_requests_request_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_requests
    ADD CONSTRAINT plant_requests_request_code_key UNIQUE (request_code);


--
-- Name: plant_sizes plant_sizes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_sizes
    ADD CONSTRAINT plant_sizes_pkey PRIMARY KEY (size_id);


--
-- Name: plant_sizes plant_sizes_size_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_sizes
    ADD CONSTRAINT plant_sizes_size_code_key UNIQUE (size_code);


--
-- Name: plants plants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plants
    ADD CONSTRAINT plants_pkey PRIMARY KEY (plant_id);


--
-- Name: plants plants_plant_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plants
    ADD CONSTRAINT plants_plant_code_key UNIQUE (plant_code);


--
-- Name: plants plants_scientific_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plants
    ADD CONSTRAINT plants_scientific_name_key UNIQUE (scientific_name);


--
-- Name: platform_config platform_config_config_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_config
    ADD CONSTRAINT platform_config_config_key_key UNIQUE (config_key);


--
-- Name: platform_config platform_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_config
    ADD CONSTRAINT platform_config_pkey PRIMARY KEY (config_id);


--
-- Name: public_code_sequences public_code_sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_code_sequences
    ADD CONSTRAINT public_code_sequences_pkey PRIMARY KEY (code_key, date_key);


--
-- Name: quotation_documents quotation_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotation_documents
    ADD CONSTRAINT quotation_documents_pkey PRIMARY KEY (doc_id);


--
-- Name: quotation_documents quotation_documents_quotation_id_version_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotation_documents
    ADD CONSTRAINT quotation_documents_quotation_id_version_key UNIQUE (quotation_id, version);


--
-- Name: quotation_items quotation_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotation_items
    ADD CONSTRAINT quotation_items_pkey PRIMARY KEY (quotation_item_id);


--
-- Name: quotation_verifications quotation_verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotation_verifications
    ADD CONSTRAINT quotation_verifications_pkey PRIMARY KEY (verification_id);


--
-- Name: quotation_verifications quotation_verifications_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotation_verifications
    ADD CONSTRAINT quotation_verifications_token_key UNIQUE (token);


--
-- Name: quotations quotations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotations
    ADD CONSTRAINT quotations_pkey PRIMARY KEY (quotation_id);


--
-- Name: quotations quotations_quotation_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotations
    ADD CONSTRAINT quotations_quotation_code_key UNIQUE (quotation_code);


--
-- Name: ratings ratings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_pkey PRIMARY KEY (rating_id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (role_id);


--
-- Name: roles roles_role_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_role_code_key UNIQUE (role_code);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: security_audit_logs security_audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security_audit_logs
    ADD CONSTRAINT security_audit_logs_pkey PRIMARY KEY (security_audit_log_id);


--
-- Name: sms_dlt_entities sms_dlt_entities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sms_dlt_entities
    ADD CONSTRAINT sms_dlt_entities_pkey PRIMARY KEY (entity_id);


--
-- Name: sms_headers sms_headers_header_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sms_headers
    ADD CONSTRAINT sms_headers_header_key UNIQUE (header);


--
-- Name: sms_headers sms_headers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sms_headers
    ADD CONSTRAINT sms_headers_pkey PRIMARY KEY (header_id);


--
-- Name: sms_messages sms_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sms_messages
    ADD CONSTRAINT sms_messages_pkey PRIMARY KEY (sms_message_id);


--
-- Name: sms_preferences sms_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sms_preferences
    ADD CONSTRAINT sms_preferences_pkey PRIMARY KEY (user_id);


--
-- Name: sms_templates sms_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sms_templates
    ADD CONSTRAINT sms_templates_pkey PRIMARY KEY (sms_template_id);


--
-- Name: sms_templates sms_templates_template_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sms_templates
    ADD CONSTRAINT sms_templates_template_code_key UNIQUE (template_code);


--
-- Name: sourcing_network_members sourcing_network_members_nursery_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_network_members
    ADD CONSTRAINT sourcing_network_members_nursery_id_key UNIQUE (nursery_id);


--
-- Name: sourcing_network_members sourcing_network_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_network_members
    ADD CONSTRAINT sourcing_network_members_pkey PRIMARY KEY (member_id);


--
-- Name: sourcing_post_photos sourcing_post_photos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_post_photos
    ADD CONSTRAINT sourcing_post_photos_pkey PRIMARY KEY (photo_id);


--
-- Name: sourcing_post_responses sourcing_post_responses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_post_responses
    ADD CONSTRAINT sourcing_post_responses_pkey PRIMARY KEY (response_id);


--
-- Name: sourcing_post_responses sourcing_post_responses_post_id_responder_nursery_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_post_responses
    ADD CONSTRAINT sourcing_post_responses_post_id_responder_nursery_id_key UNIQUE (post_id, responder_nursery_id);


--
-- Name: sourcing_posts sourcing_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_posts
    ADD CONSTRAINT sourcing_posts_pkey PRIMARY KEY (post_id);


--
-- Name: sourcing_posts sourcing_posts_post_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_posts
    ADD CONSTRAINT sourcing_posts_post_code_key UNIQUE (post_code);


--
-- Name: subscription_plans subscription_plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_plans
    ADD CONSTRAINT subscription_plans_pkey PRIMARY KEY (plan_id);


--
-- Name: subscription_plans subscription_plans_plan_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_plans
    ADD CONSTRAINT subscription_plans_plan_code_key UNIQUE (plan_code);


--
-- Name: subscription_promos subscription_promos_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_promos
    ADD CONSTRAINT subscription_promos_code_key UNIQUE (promo_code);


--
-- Name: subscription_promos subscription_promos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_promos
    ADD CONSTRAINT subscription_promos_pkey PRIMARY KEY (promo_id);


--
-- Name: trip_events trip_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_events
    ADD CONSTRAINT trip_events_pkey PRIMARY KEY (trip_event_id);


--
-- Name: trip_tracking_links trip_tracking_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_tracking_links
    ADD CONSTRAINT trip_tracking_links_pkey PRIMARY KEY (trip_tracking_link_id);


--
-- Name: trip_tracking_links trip_tracking_links_tracking_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_tracking_links
    ADD CONSTRAINT trip_tracking_links_tracking_uuid_key UNIQUE (tracking_uuid);


--
-- Name: user_activities user_activities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_activities
    ADD CONSTRAINT user_activities_pkey PRIMARY KEY (activity_id);


--
-- Name: user_addresses user_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_addresses
    ADD CONSTRAINT user_addresses_pkey PRIMARY KEY (address_id);


--
-- Name: user_notification_devices user_notification_devices_fcm_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_notification_devices
    ADD CONSTRAINT user_notification_devices_fcm_token_key UNIQUE (fcm_token);


--
-- Name: user_notification_devices user_notification_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_notification_devices
    ADD CONSTRAINT user_notification_devices_pkey PRIMARY KEY (device_id);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role_id);


--
-- Name: user_sessions user_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_pkey PRIMARY KEY (session_id);


--
-- Name: user_subscriptions user_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subscriptions
    ADD CONSTRAINT user_subscriptions_pkey PRIMARY KEY (user_subscription_id);


--
-- Name: user_subscriptions user_subscriptions_subscription_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subscriptions
    ADD CONSTRAINT user_subscriptions_subscription_code_key UNIQUE (subscription_code);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_mobile_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_mobile_key UNIQUE (mobile);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- Name: users users_user_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_user_code_key UNIQUE (user_code);


--
-- Name: vehicle_locations vehicle_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_locations
    ADD CONSTRAINT vehicle_locations_pkey PRIMARY KEY (location_id);


--
-- Name: vehicle_tracking vehicle_tracking_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_tracking
    ADD CONSTRAINT vehicle_tracking_pkey PRIMARY KEY (tracking_id);


--
-- Name: vehicles vehicles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT vehicles_pkey PRIMARY KEY (vehicle_id);


--
-- Name: vehicles vehicles_vehicle_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT vehicles_vehicle_code_key UNIQUE (vehicle_code);


--
-- Name: vehicles vehicles_vehicle_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT vehicles_vehicle_number_key UNIQUE (vehicle_number);


--
-- Name: idx_audit_logs_changed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_logs_changed_at ON public.audit_logs USING btree (changed_at DESC);


--
-- Name: idx_audit_logs_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_logs_entity ON public.audit_logs USING btree (entity_type, record_id) WHERE (entity_type IS NOT NULL);


--
-- Name: idx_audit_logs_module; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_logs_module ON public.audit_logs USING btree (module) WHERE (module IS NOT NULL);


--
-- Name: idx_audit_logs_nursery_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_logs_nursery_id ON public.audit_logs USING btree (nursery_id) WHERE (nursery_id IS NOT NULL);


--
-- Name: idx_audit_logs_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_logs_request_id ON public.audit_logs USING btree (request_id) WHERE (request_id IS NOT NULL);


--
-- Name: idx_audit_logs_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_logs_user_id ON public.audit_logs USING btree (user_id) WHERE (user_id IS NOT NULL);


--
-- Name: idx_botanical_names_accepted_wfo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_botanical_names_accepted_wfo_id ON public.botanical_names USING btree (accepted_wfo_id) WHERE (accepted_wfo_id IS NOT NULL);


--
-- Name: idx_botanical_names_family; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_botanical_names_family ON public.botanical_names USING btree (family, scientific_name, wfo_id);


--
-- Name: idx_botanical_names_name_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_botanical_names_name_order ON public.botanical_names USING btree (scientific_name, wfo_id);


--
-- Name: idx_botanical_names_search; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_botanical_names_search ON public.botanical_names USING gin (public.botanical_search_key(scientific_name) public.gin_trgm_ops);


--
-- Name: idx_client_crash_reports_app_version; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_crash_reports_app_version ON public.client_crash_reports USING btree (app_version, received_at DESC);


--
-- Name: idx_client_crash_reports_received_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_crash_reports_received_at ON public.client_crash_reports USING btree (received_at DESC);


--
-- Name: idx_client_crash_reports_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_crash_reports_user_id ON public.client_crash_reports USING btree (user_id) WHERE (user_id IS NOT NULL);


--
-- Name: idx_dispatch_assignments_dispatch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dispatch_assignments_dispatch ON public.dispatch_assignments USING btree (dispatch_id);


--
-- Name: idx_dispatch_items_dispatch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dispatch_items_dispatch ON public.dispatch_items USING btree (dispatch_id);


--
-- Name: idx_dispatches_deleted; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dispatches_deleted ON public.dispatches USING btree (deleted_at) WHERE (deleted_at IS NOT NULL);


--
-- Name: idx_dispatches_driver; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dispatches_driver ON public.dispatches USING btree (driver_id);


--
-- Name: idx_dispatches_driver_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dispatches_driver_user ON public.dispatches USING btree (driver_user_id);


--
-- Name: idx_dispatches_manager; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dispatches_manager ON public.dispatches USING btree (assigned_manager_user_id);


--
-- Name: idx_dispatches_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dispatches_nursery ON public.dispatches USING btree (nursery_id);


--
-- Name: idx_dispatches_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dispatches_order ON public.dispatches USING btree (order_id);


--
-- Name: idx_dispatches_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dispatches_status ON public.dispatches USING btree (status);


--
-- Name: idx_dispatches_vehicle; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dispatches_vehicle ON public.dispatches USING btree (vehicle_id);


--
-- Name: idx_driver_locations_driver_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_driver_locations_driver_time ON public.driver_locations USING btree (driver_id, recorded_at DESC);


--
-- Name: idx_drivers_approval_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_drivers_approval_status ON public.drivers USING btree (approval_status);


--
-- Name: idx_drivers_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_drivers_user_id ON public.drivers USING btree (user_id);


--
-- Name: idx_email_messages_status_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_email_messages_status_created ON public.email_messages USING btree (status, created_at DESC);


--
-- Name: idx_email_messages_template_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_email_messages_template_created ON public.email_messages USING btree (template_code, created_at DESC);


--
-- Name: idx_email_messages_to_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_email_messages_to_created ON public.email_messages USING btree (to_email, created_at DESC);


--
-- Name: idx_invites_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invites_nursery ON public.invites USING btree (nursery_id);


--
-- Name: idx_invites_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invites_status ON public.invites USING btree (status);


--
-- Name: idx_invites_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invites_uuid ON public.invites USING btree (invite_uuid);


--
-- Name: idx_market_ad_saves_nursery_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_ad_saves_nursery_id ON public.market_ad_saves USING btree (nursery_id);


--
-- Name: idx_market_ads_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_ads_expires_at ON public.market_ads USING btree (expires_at) WHERE ((status)::text = 'PUBLISHED'::text);


--
-- Name: idx_market_ads_nursery_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_ads_nursery_id ON public.market_ads USING btree (nursery_id);


--
-- Name: idx_market_ads_plant_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_ads_plant_name ON public.market_ads USING btree (plant_name);


--
-- Name: idx_market_ads_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_ads_status ON public.market_ads USING btree (status);


--
-- Name: idx_market_enquiries_enquiring; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_enquiries_enquiring ON public.market_enquiries USING btree (enquiring_nursery_id);


--
-- Name: idx_market_enquiries_listing; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_enquiries_listing ON public.market_enquiries USING btree (ad_id);


--
-- Name: idx_market_enquiries_listing_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_enquiries_listing_nursery ON public.market_enquiries USING btree (ad_nursery_id);


--
-- Name: idx_market_enquiry_messages_enquiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_enquiry_messages_enquiry ON public.market_enquiry_messages USING btree (enquiry_id);


--
-- Name: idx_notification_templates_code_channel; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notification_templates_code_channel ON public.notification_templates USING btree (template_code, channel);


--
-- Name: idx_notifications_user_type_status_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_user_type_status_created ON public.notifications USING btree (user_id, notification_type, status, created_at DESC);


--
-- Name: idx_nurseries_approved_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nurseries_approved_by ON public.nurseries USING btree (approved_by_user_id);


--
-- Name: idx_nurseries_deleted; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nurseries_deleted ON public.nurseries USING btree (deleted_at) WHERE (deleted_at IS NOT NULL);


--
-- Name: idx_nurseries_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nurseries_owner ON public.nurseries USING btree (owner_user_id);


--
-- Name: idx_nurseries_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nurseries_status ON public.nurseries USING btree (status);


--
-- Name: idx_nursery_addresses_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nursery_addresses_nursery ON public.nursery_addresses USING btree (nursery_id);


--
-- Name: idx_nursery_applications_applicant_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nursery_applications_applicant_user_id ON public.nursery_applications USING btree (applicant_user_id);


--
-- Name: idx_nursery_applications_nursery_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nursery_applications_nursery_id ON public.nursery_applications USING btree (nursery_id);


--
-- Name: idx_nursery_applications_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nursery_applications_status ON public.nursery_applications USING btree (status);


--
-- Name: idx_nursery_drivers_driver; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nursery_drivers_driver ON public.nursery_drivers USING btree (driver_user_id);


--
-- Name: idx_nursery_drivers_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nursery_drivers_nursery ON public.nursery_drivers USING btree (nursery_id);


--
-- Name: idx_nursery_top_items_nursery_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nursery_top_items_nursery_order ON public.nursery_top_items USING btree (nursery_id, display_order);


--
-- Name: idx_nursery_top_items_plant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nursery_top_items_plant_id ON public.nursery_top_items USING btree (plant_id);


--
-- Name: idx_nursery_users_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nursery_users_nursery ON public.nursery_users USING btree (nursery_id);


--
-- Name: idx_nursery_users_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nursery_users_user ON public.nursery_users USING btree (user_id);


--
-- Name: idx_order_delivery_snapshots_driver_ack; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_delivery_snapshots_driver_ack ON public.order_delivery_snapshots USING btree (requires_driver_ack) WHERE (requires_driver_ack = true);


--
-- Name: idx_order_delivery_snapshots_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_delivery_snapshots_location ON public.order_delivery_snapshots USING gist (location);


--
-- Name: idx_order_items_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_items_order ON public.order_items USING btree (order_id);


--
-- Name: idx_order_items_plant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_items_plant ON public.order_items USING btree (plant_id);


--
-- Name: idx_order_verifications_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_verifications_token ON public.order_verifications USING btree (token);


--
-- Name: idx_orders_buyer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_buyer ON public.orders USING btree (buyer_user_id);


--
-- Name: idx_orders_buyer_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_buyer_nursery ON public.orders USING btree (buyer_nursery_id);


--
-- Name: idx_orders_customer_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_customer_user ON public.orders USING btree (customer_user_id);


--
-- Name: idx_orders_deleted; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_deleted ON public.orders USING btree (deleted_at) WHERE (deleted_at IS NOT NULL);


--
-- Name: idx_orders_manager; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_manager ON public.orders USING btree (assigned_manager_user_id);


--
-- Name: idx_orders_quotation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_quotation ON public.orders USING btree (quotation_id);


--
-- Name: idx_orders_seller; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_seller ON public.orders USING btree (seller_nursery_id);


--
-- Name: idx_orders_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_status ON public.orders USING btree (status);


--
-- Name: idx_otp_requests_mobile_purpose_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_otp_requests_mobile_purpose_expires_at ON public.otp_requests USING btree (mobile, purpose, expires_at) WHERE (is_used = false);


--
-- Name: idx_payments_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_order ON public.payments USING btree (order_id);


--
-- Name: idx_payments_payer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_payer ON public.payments USING btree (payer_user_id);


--
-- Name: idx_payments_payment_for; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_payment_for ON public.payments USING btree (payment_for);


--
-- Name: idx_payments_subscription; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_subscription ON public.payments USING btree (user_subscription_id);


--
-- Name: idx_plant_category_mappings_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_plant_category_mappings_category_id ON public.plant_category_mappings USING btree (category_id);


--
-- Name: idx_plant_category_mappings_plant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_plant_category_mappings_plant_id ON public.plant_category_mappings USING btree (plant_id);


--
-- Name: idx_plant_images_plant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_plant_images_plant ON public.plant_images USING btree (plant_id);


--
-- Name: idx_plant_names_language; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_plant_names_language ON public.plant_names USING btree (language_id);


--
-- Name: idx_plant_names_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_plant_names_name ON public.plant_names USING btree (plant_name);


--
-- Name: idx_plant_request_responses_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_plant_request_responses_request_id ON public.plant_request_responses USING btree (request_id);


--
-- Name: idx_plant_request_responses_supplier_nursery_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_plant_request_responses_supplier_nursery_id ON public.plant_request_responses USING btree (supplier_nursery_id);


--
-- Name: idx_plant_requests_plant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_plant_requests_plant_id ON public.plant_requests USING btree (plant_id);


--
-- Name: idx_plant_requests_requesting_nursery_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_plant_requests_requesting_nursery_id ON public.plant_requests USING btree (requesting_nursery_id);


--
-- Name: idx_plant_requests_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_plant_requests_status ON public.plant_requests USING btree (status);


--
-- Name: idx_plants_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_plants_is_active ON public.plants USING btree (is_active);


--
-- Name: idx_plants_scientific_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_plants_scientific_name ON public.plants USING btree (scientific_name);


--
-- Name: idx_platform_config_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_platform_config_active ON public.platform_config USING btree (config_key) WHERE (is_active = true);


--
-- Name: idx_quotation_items_quotation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quotation_items_quotation_id ON public.quotation_items USING btree (quotation_id);


--
-- Name: idx_quotations_assigned_manager; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quotations_assigned_manager ON public.quotations USING btree (assigned_manager_user_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_quotations_buyer_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quotations_buyer_nursery ON public.quotations USING btree (buyer_nursery_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_quotations_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quotations_created_by ON public.quotations USING btree (created_by_user_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_quotations_customer_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quotations_customer_user_id ON public.quotations USING btree (customer_user_id) WHERE ((deleted_at IS NULL) AND (customer_user_id IS NOT NULL));


--
-- Name: idx_quotations_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quotations_nursery ON public.quotations USING btree (nursery_id, status) WHERE (deleted_at IS NULL);


--
-- Name: idx_quotations_recipient_mobile; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quotations_recipient_mobile ON public.quotations USING btree (recipient_mobile, status) WHERE ((deleted_at IS NULL) AND (recipient_mobile IS NOT NULL));


--
-- Name: idx_ratings_dispatch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ratings_dispatch ON public.ratings USING btree (dispatch_id) WHERE (dispatch_id IS NOT NULL);


--
-- Name: idx_ratings_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ratings_order ON public.ratings USING btree (order_id) WHERE (order_id IS NOT NULL);


--
-- Name: idx_ratings_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ratings_user ON public.ratings USING btree (rated_by_user_id);


--
-- Name: idx_security_audit_logs_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_security_audit_logs_created_at ON public.security_audit_logs USING btree (created_at DESC);


--
-- Name: idx_security_audit_logs_event_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_security_audit_logs_event_type ON public.security_audit_logs USING btree (event_type);


--
-- Name: idx_security_audit_logs_nursery_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_security_audit_logs_nursery_id ON public.security_audit_logs USING btree (nursery_id) WHERE (nursery_id IS NOT NULL);


--
-- Name: idx_security_audit_logs_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_security_audit_logs_request_id ON public.security_audit_logs USING btree (request_id) WHERE (request_id IS NOT NULL);


--
-- Name: idx_security_audit_logs_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_security_audit_logs_user_id ON public.security_audit_logs USING btree (user_id) WHERE (user_id IS NOT NULL);


--
-- Name: idx_sms_messages_mobile_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sms_messages_mobile_created ON public.sms_messages USING btree (mobile, created_at DESC);


--
-- Name: idx_sms_messages_status_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sms_messages_status_created ON public.sms_messages USING btree (status, created_at DESC);


--
-- Name: idx_sms_messages_template_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sms_messages_template_created ON public.sms_messages USING btree (template_code, created_at DESC);


--
-- Name: idx_sourcing_network_members_nursery_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sourcing_network_members_nursery_id ON public.sourcing_network_members USING btree (nursery_id) WHERE (is_active = true);


--
-- Name: idx_sourcing_network_members_nursery_id_2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sourcing_network_members_nursery_id_2 ON public.sourcing_network_members USING btree (nursery_id);


--
-- Name: idx_sourcing_post_photos_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sourcing_post_photos_post_id ON public.sourcing_post_photos USING btree (post_id);


--
-- Name: idx_sourcing_post_responses_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sourcing_post_responses_post_id ON public.sourcing_post_responses USING btree (post_id);


--
-- Name: idx_sourcing_post_responses_responder_nursery_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sourcing_post_responses_responder_nursery_id ON public.sourcing_post_responses USING btree (responder_nursery_id);


--
-- Name: idx_sourcing_posts_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sourcing_posts_nursery ON public.sourcing_posts USING btree (nursery_id);


--
-- Name: idx_sourcing_posts_open; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sourcing_posts_open ON public.sourcing_posts USING btree (post_type, created_at DESC) WHERE (((status)::text = 'OPEN'::text) AND (deleted_at IS NULL));


--
-- Name: idx_sourcing_posts_plant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sourcing_posts_plant ON public.sourcing_posts USING btree (plant_id) WHERE (plant_id IS NOT NULL);


--
-- Name: idx_subscription_plans_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_subscription_plans_active ON public.subscription_plans USING btree (is_active);


--
-- Name: idx_subscription_promos_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_subscription_promos_active ON public.subscription_promos USING btree (is_active, valid_from, valid_until);


--
-- Name: idx_subscription_promos_active_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_subscription_promos_active_dates ON public.subscription_promos USING btree (is_active, valid_from, valid_until);


--
-- Name: idx_subscription_promos_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_subscription_promos_code ON public.subscription_promos USING btree (promo_code);


--
-- Name: idx_trip_events_dispatch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_trip_events_dispatch ON public.trip_events USING btree (dispatch_id);


--
-- Name: idx_trip_tracking_links_dispatch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_trip_tracking_links_dispatch_id ON public.trip_tracking_links USING btree (dispatch_id);


--
-- Name: idx_trip_tracking_links_tracking_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_trip_tracking_links_tracking_uuid ON public.trip_tracking_links USING btree (tracking_uuid);


--
-- Name: idx_user_activities_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_activities_entity ON public.user_activities USING btree (entity_type, entity_id);


--
-- Name: idx_user_activities_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_activities_timestamp ON public.user_activities USING btree (occurred_at);


--
-- Name: idx_user_activities_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_activities_type ON public.user_activities USING btree (activity_type);


--
-- Name: idx_user_activities_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_activities_user ON public.user_activities USING btree (user_id);


--
-- Name: idx_user_addresses_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_addresses_user ON public.user_addresses USING btree (user_id);


--
-- Name: idx_user_notification_devices_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_notification_devices_user ON public.user_notification_devices USING btree (user_id, is_active);


--
-- Name: idx_user_sessions_last_activity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_sessions_last_activity ON public.user_sessions USING btree (last_activity_at);


--
-- Name: idx_user_sessions_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_sessions_user ON public.user_sessions USING btree (user_id);


--
-- Name: idx_user_subscriptions_plan; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_subscriptions_plan ON public.user_subscriptions USING btree (plan_id);


--
-- Name: idx_user_subscriptions_user_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_subscriptions_user_status ON public.user_subscriptions USING btree (user_id, status);


--
-- Name: idx_users_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_deleted_at ON public.users USING btree (deleted_at);


--
-- Name: idx_users_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_status ON public.users USING btree (status);


--
-- Name: idx_vehicle_locations_recorded; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vehicle_locations_recorded ON public.vehicle_locations USING btree (recorded_at);


--
-- Name: idx_vehicle_locations_vehicle; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vehicle_locations_vehicle ON public.vehicle_locations USING btree (vehicle_id);


--
-- Name: idx_vehicle_tracking_dispatch_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vehicle_tracking_dispatch_time ON public.vehicle_tracking USING btree (dispatch_id, tracked_at DESC);


--
-- Name: uq_dispatches_driver_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_dispatches_driver_user_id ON public.dispatches USING btree (driver_user_id) WHERE ((status)::text = ANY (ARRAY[('ACCEPTED'::character varying)::text, ('DISPATCHED'::character varying)::text, ('IN_TRANSIT'::character varying)::text]));


--
-- Name: uq_dispatches_trip_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_dispatches_trip_uuid ON public.dispatches USING btree (trip_uuid);


--
-- Name: uq_email_senders_expr; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_email_senders_expr ON public.email_senders USING btree ((true));


--
-- Name: uq_nursery_users_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_nursery_users_user_id ON public.nursery_users USING btree (user_id) WHERE ((status)::text = 'ACTIVE'::text);


--
-- Name: uq_order_documents_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_order_documents_order_id ON public.order_documents USING btree (order_id) WHERE (is_current = true);


--
-- Name: uq_order_verifications_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_order_verifications_order_id ON public.order_verifications USING btree (order_id) WHERE ((status)::text = 'ACTIVE'::text);


--
-- Name: uq_payments_provider_payment; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_payments_provider_payment ON public.payments USING btree (provider, provider_payment_id) WHERE (provider_payment_id IS NOT NULL);


--
-- Name: uq_plants_wfo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_plants_wfo_id ON public.plants USING btree (wfo_id) WHERE (wfo_id IS NOT NULL);


--
-- Name: uq_quotation_documents_quotation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_quotation_documents_quotation_id ON public.quotation_documents USING btree (quotation_id) WHERE (is_current = true);


--
-- Name: uq_quotation_verifications_quotation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_quotation_verifications_quotation_id ON public.quotation_verifications USING btree (quotation_id) WHERE ((status)::text = 'ACTIVE'::text);


--
-- Name: uq_ratings_app; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_ratings_app ON public.ratings USING btree (rated_by_user_id) WHERE (rating_type = 'APP'::text);


--
-- Name: uq_ratings_order; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_ratings_order ON public.ratings USING btree (rated_by_user_id, order_id) WHERE ((rating_type = 'ORDER'::text) AND (order_id IS NOT NULL));


--
-- Name: uq_ratings_trip; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_ratings_trip ON public.ratings USING btree (rated_by_user_id, dispatch_id) WHERE ((rating_type = 'TRIP'::text) AND (dispatch_id IS NOT NULL));


--
-- Name: uq_sms_dlt_entities_singleton; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_sms_dlt_entities_singleton ON public.sms_dlt_entities USING btree ((true));


--
-- Name: dispatches trg_dispatches_version; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_dispatches_version BEFORE UPDATE ON public.dispatches FOR EACH ROW EXECUTE FUNCTION public.bump_row_version();


--
-- Name: nursery_top_items trg_nursery_top_items_version; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_nursery_top_items_version BEFORE UPDATE ON public.nursery_top_items FOR EACH ROW EXECUTE FUNCTION public.bump_row_version();


--
-- Name: orders trg_orders_version; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_orders_version BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.bump_row_version();


--
-- Name: payments trg_payments_version; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_payments_version BEFORE UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.bump_row_version();


--
-- Name: quotations trg_quotations_version; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_quotations_version BEFORE UPDATE ON public.quotations FOR EACH ROW EXECUTE FUNCTION public.bump_row_version();


--
-- Name: attachments attachments_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachments
    ADD CONSTRAINT attachments_uploaded_by_fkey FOREIGN KEY (uploaded_by_user_id) REFERENCES public.users(user_id);


--
-- Name: client_crash_reports client_crash_reports_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_crash_reports
    ADD CONSTRAINT client_crash_reports_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE SET NULL;


--
-- Name: dispatch_assignments dispatch_assignments_assigned_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatch_assignments
    ADD CONSTRAINT dispatch_assignments_assigned_by_user_id_fkey FOREIGN KEY (assigned_by_user_id) REFERENCES public.users(user_id);


--
-- Name: dispatch_assignments dispatch_assignments_dispatch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatch_assignments
    ADD CONSTRAINT dispatch_assignments_dispatch_id_fkey FOREIGN KEY (dispatch_id) REFERENCES public.dispatches(dispatch_id) ON DELETE CASCADE;


--
-- Name: dispatch_assignments dispatch_assignments_driver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatch_assignments
    ADD CONSTRAINT dispatch_assignments_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.drivers(driver_id);


--
-- Name: dispatch_assignments dispatch_assignments_vehicle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatch_assignments
    ADD CONSTRAINT dispatch_assignments_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(vehicle_id);


--
-- Name: dispatch_items dispatch_items_dispatch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatch_items
    ADD CONSTRAINT dispatch_items_dispatch_id_fkey FOREIGN KEY (dispatch_id) REFERENCES public.dispatches(dispatch_id) ON DELETE CASCADE;


--
-- Name: dispatch_items dispatch_items_order_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatch_items
    ADD CONSTRAINT dispatch_items_order_item_id_fkey FOREIGN KEY (order_item_id) REFERENCES public.order_items(order_item_id);


--
-- Name: dispatches dispatches_customer_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_customer_user_id_fkey FOREIGN KEY (customer_user_id) REFERENCES public.users(user_id);


--
-- Name: dispatches dispatches_dispatched_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_dispatched_by_fkey FOREIGN KEY (dispatched_by_user_id) REFERENCES public.users(user_id);


--
-- Name: dispatches dispatches_driver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.drivers(driver_id);


--
-- Name: dispatches dispatches_driver_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_driver_user_id_fkey FOREIGN KEY (driver_user_id) REFERENCES public.users(user_id);


--
-- Name: dispatches dispatches_manager_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_manager_fkey FOREIGN KEY (assigned_manager_user_id) REFERENCES public.users(user_id);


--
-- Name: dispatches dispatches_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_nursery_id_fkey FOREIGN KEY (nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: dispatches dispatches_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(order_id);


--
-- Name: dispatches dispatches_owner_snapshot_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_owner_snapshot_fkey FOREIGN KEY (snapshot_owner_user_id) REFERENCES public.users(user_id);


--
-- Name: dispatches dispatches_trip_started_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_trip_started_by_fkey FOREIGN KEY (trip_started_by_user_id) REFERENCES public.users(user_id);


--
-- Name: dispatches dispatches_vehicle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(vehicle_id);


--
-- Name: driver_locations driver_locations_driver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.driver_locations
    ADD CONSTRAINT driver_locations_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.drivers(driver_id) ON DELETE CASCADE;


--
-- Name: drivers drivers_approved_by_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT drivers_approved_by_user_fkey FOREIGN KEY (approved_by_user_id) REFERENCES public.users(user_id);


--
-- Name: drivers drivers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT drivers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id);


--
-- Name: email_messages email_messages_email_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_messages
    ADD CONSTRAINT email_messages_email_template_id_fkey FOREIGN KEY (email_template_id) REFERENCES public.email_templates(email_template_id);


--
-- Name: email_messages email_messages_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_messages
    ADD CONSTRAINT email_messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE SET NULL;


--
-- Name: invites invites_accepted_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invites
    ADD CONSTRAINT invites_accepted_by_user_id_fkey FOREIGN KEY (accepted_by_user_id) REFERENCES public.users(user_id);


--
-- Name: invites invites_invited_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invites
    ADD CONSTRAINT invites_invited_by_user_id_fkey FOREIGN KEY (invited_by_user_id) REFERENCES public.users(user_id);


--
-- Name: invites invites_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invites
    ADD CONSTRAINT invites_nursery_id_fkey FOREIGN KEY (nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: market_ad_reports market_ad_reports_ad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_reports
    ADD CONSTRAINT market_ad_reports_ad_id_fkey FOREIGN KEY (ad_id) REFERENCES public.market_ads(ad_id);


--
-- Name: market_ad_reports market_ad_reports_reported_by_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_reports
    ADD CONSTRAINT market_ad_reports_reported_by_nursery_id_fkey FOREIGN KEY (reported_by_nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: market_ad_reports market_ad_reports_reported_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_reports
    ADD CONSTRAINT market_ad_reports_reported_by_user_id_fkey FOREIGN KEY (reported_by_user_id) REFERENCES public.users(user_id);


--
-- Name: market_ad_saves market_ad_saves_ad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_saves
    ADD CONSTRAINT market_ad_saves_ad_id_fkey FOREIGN KEY (ad_id) REFERENCES public.market_ads(ad_id);


--
-- Name: market_ad_saves market_ad_saves_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_saves
    ADD CONSTRAINT market_ad_saves_nursery_id_fkey FOREIGN KEY (nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: market_ad_saves market_ad_saves_saved_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_saves
    ADD CONSTRAINT market_ad_saves_saved_by_user_id_fkey FOREIGN KEY (saved_by_user_id) REFERENCES public.users(user_id);


--
-- Name: market_ad_views market_ad_views_ad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_views
    ADD CONSTRAINT market_ad_views_ad_id_fkey FOREIGN KEY (ad_id) REFERENCES public.market_ads(ad_id);


--
-- Name: market_ad_views market_ad_views_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_views
    ADD CONSTRAINT market_ad_views_nursery_id_fkey FOREIGN KEY (nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: market_ads market_ads_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ads
    ADD CONSTRAINT market_ads_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(user_id);


--
-- Name: market_ads market_ads_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ads
    ADD CONSTRAINT market_ads_nursery_id_fkey FOREIGN KEY (nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: market_ads market_ads_plant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ads
    ADD CONSTRAINT market_ads_plant_id_fkey FOREIGN KEY (plant_id) REFERENCES public.plants(plant_id);


--
-- Name: market_ads market_ads_updated_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ads
    ADD CONSTRAINT market_ads_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES public.users(user_id);


--
-- Name: market_enquiries market_enquiries_enquiring_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_enquiries
    ADD CONSTRAINT market_enquiries_enquiring_fkey FOREIGN KEY (enquiring_nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: market_enquiries market_enquiries_listing_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_enquiries
    ADD CONSTRAINT market_enquiries_listing_fkey FOREIGN KEY (ad_id) REFERENCES public.market_ads(ad_id);


--
-- Name: market_enquiries market_enquiries_listing_nursery_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_enquiries
    ADD CONSTRAINT market_enquiries_listing_nursery_fkey FOREIGN KEY (ad_nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: market_enquiries market_enquiries_quotation_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_enquiries
    ADD CONSTRAINT market_enquiries_quotation_fkey FOREIGN KEY (quotation_id) REFERENCES public.quotations(quotation_id);


--
-- Name: market_enquiries market_enquiries_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_enquiries
    ADD CONSTRAINT market_enquiries_user_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(user_id);


--
-- Name: market_enquiry_messages market_enquiry_messages_enquiry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_enquiry_messages
    ADD CONSTRAINT market_enquiry_messages_enquiry_id_fkey FOREIGN KEY (enquiry_id) REFERENCES public.market_enquiries(enquiry_id);


--
-- Name: market_enquiry_messages market_enquiry_messages_sent_by_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_enquiry_messages
    ADD CONSTRAINT market_enquiry_messages_sent_by_nursery_id_fkey FOREIGN KEY (sent_by_nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: market_enquiry_messages market_enquiry_messages_sent_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_enquiry_messages
    ADD CONSTRAINT market_enquiry_messages_sent_by_user_id_fkey FOREIGN KEY (sent_by_user_id) REFERENCES public.users(user_id);


--
-- Name: notifications notifications_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.notification_templates(template_id);


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id);


--
-- Name: nurseries nurseries_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nurseries
    ADD CONSTRAINT nurseries_approved_by_fkey FOREIGN KEY (approved_by_user_id) REFERENCES public.users(user_id);


--
-- Name: nurseries nurseries_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nurseries
    ADD CONSTRAINT nurseries_created_by_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(user_id);


--
-- Name: nurseries nurseries_owner_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nurseries
    ADD CONSTRAINT nurseries_owner_user_id_fkey FOREIGN KEY (owner_user_id) REFERENCES public.users(user_id);


--
-- Name: nurseries nurseries_rejected_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nurseries
    ADD CONSTRAINT nurseries_rejected_by_fkey FOREIGN KEY (rejected_by_user_id) REFERENCES public.users(user_id);


--
-- Name: nursery_addresses nursery_addresses_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_addresses
    ADD CONSTRAINT nursery_addresses_nursery_id_fkey FOREIGN KEY (nursery_id) REFERENCES public.nurseries(nursery_id) ON DELETE CASCADE;


--
-- Name: nursery_applications nursery_applications_applicant_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_applications
    ADD CONSTRAINT nursery_applications_applicant_user_id_fkey FOREIGN KEY (applicant_user_id) REFERENCES public.users(user_id);


--
-- Name: nursery_applications nursery_applications_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_applications
    ADD CONSTRAINT nursery_applications_nursery_id_fkey FOREIGN KEY (nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: nursery_applications nursery_applications_reviewed_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_applications
    ADD CONSTRAINT nursery_applications_reviewed_by_user_id_fkey FOREIGN KEY (reviewed_by_user_id) REFERENCES public.users(user_id);


--
-- Name: nursery_drivers nursery_drivers_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_drivers
    ADD CONSTRAINT nursery_drivers_approved_by_fkey FOREIGN KEY (approved_by_user_id) REFERENCES public.users(user_id);


--
-- Name: nursery_drivers nursery_drivers_disconnected_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_drivers
    ADD CONSTRAINT nursery_drivers_disconnected_by_fkey FOREIGN KEY (disconnected_by_user_id) REFERENCES public.users(user_id);


--
-- Name: nursery_drivers nursery_drivers_driver_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_drivers
    ADD CONSTRAINT nursery_drivers_driver_user_id_fkey FOREIGN KEY (driver_user_id) REFERENCES public.users(user_id);


--
-- Name: nursery_drivers nursery_drivers_invited_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_drivers
    ADD CONSTRAINT nursery_drivers_invited_by_fkey FOREIGN KEY (invited_by_user_id) REFERENCES public.users(user_id);


--
-- Name: nursery_drivers nursery_drivers_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_drivers
    ADD CONSTRAINT nursery_drivers_nursery_id_fkey FOREIGN KEY (nursery_id) REFERENCES public.nurseries(nursery_id) ON DELETE CASCADE;


--
-- Name: nursery_top_items nursery_top_items_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_top_items
    ADD CONSTRAINT nursery_top_items_nursery_id_fkey FOREIGN KEY (nursery_id) REFERENCES public.nurseries(nursery_id) ON DELETE CASCADE;


--
-- Name: nursery_top_items nursery_top_items_plant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_top_items
    ADD CONSTRAINT nursery_top_items_plant_id_fkey FOREIGN KEY (plant_id) REFERENCES public.plants(plant_id);


--
-- Name: nursery_top_items nursery_top_items_size_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_top_items
    ADD CONSTRAINT nursery_top_items_size_id_fkey FOREIGN KEY (size_id) REFERENCES public.plant_sizes(size_id);


--
-- Name: nursery_top_items nursery_top_items_updated_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_top_items
    ADD CONSTRAINT nursery_top_items_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES public.users(user_id);


--
-- Name: nursery_users nursery_users_invited_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_users
    ADD CONSTRAINT nursery_users_invited_by_fkey FOREIGN KEY (invited_by_user_id) REFERENCES public.users(user_id);


--
-- Name: nursery_users nursery_users_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_users
    ADD CONSTRAINT nursery_users_nursery_id_fkey FOREIGN KEY (nursery_id) REFERENCES public.nurseries(nursery_id) ON DELETE CASCADE;


--
-- Name: nursery_users nursery_users_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_users
    ADD CONSTRAINT nursery_users_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: order_delivery_snapshots order_delivery_snapshots_confirmed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_delivery_snapshots
    ADD CONSTRAINT order_delivery_snapshots_confirmed_by_fkey FOREIGN KEY (confirmed_by_user_id) REFERENCES public.users(user_id);


--
-- Name: order_delivery_snapshots order_delivery_snapshots_driver_acknowledged_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_delivery_snapshots
    ADD CONSTRAINT order_delivery_snapshots_driver_acknowledged_by_fkey FOREIGN KEY (driver_acknowledged_by_user_id) REFERENCES public.users(user_id);


--
-- Name: order_delivery_snapshots order_delivery_snapshots_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_delivery_snapshots
    ADD CONSTRAINT order_delivery_snapshots_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(order_id) ON DELETE CASCADE;


--
-- Name: order_documents order_documents_generated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_documents
    ADD CONSTRAINT order_documents_generated_by_fkey FOREIGN KEY (generated_by_user_id) REFERENCES public.users(user_id);


--
-- Name: order_documents order_documents_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_documents
    ADD CONSTRAINT order_documents_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(order_id) ON DELETE CASCADE;


--
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(order_id) ON DELETE CASCADE;


--
-- Name: order_items order_items_plant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_plant_id_fkey FOREIGN KEY (plant_id) REFERENCES public.plants(plant_id);


--
-- Name: order_items order_items_size_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_size_id_fkey FOREIGN KEY (size_id) REFERENCES public.plant_sizes(size_id);


--
-- Name: order_verifications order_verifications_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_verifications
    ADD CONSTRAINT order_verifications_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(order_id) ON DELETE CASCADE;


--
-- Name: order_verifications order_verifications_revoked_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_verifications
    ADD CONSTRAINT order_verifications_revoked_by_fkey FOREIGN KEY (revoked_by_user_id) REFERENCES public.users(user_id);


--
-- Name: orders orders_assigned_manager_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_assigned_manager_fkey FOREIGN KEY (assigned_manager_user_id) REFERENCES public.users(user_id);


--
-- Name: orders orders_buyer_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_buyer_nursery_id_fkey FOREIGN KEY (buyer_nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: orders orders_buyer_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_buyer_user_id_fkey FOREIGN KEY (buyer_user_id) REFERENCES public.users(user_id);


--
-- Name: orders orders_cancelled_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_cancelled_by_user_id_fkey FOREIGN KEY (cancelled_by_user_id) REFERENCES public.users(user_id);


--
-- Name: orders orders_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(user_id);


--
-- Name: orders orders_customer_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_customer_user_id_fkey FOREIGN KEY (customer_user_id) REFERENCES public.users(user_id);


--
-- Name: orders orders_loading_completed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_loading_completed_by_fkey FOREIGN KEY (loading_completed_by_user_id) REFERENCES public.users(user_id);


--
-- Name: orders orders_quotation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_quotation_id_fkey FOREIGN KEY (quotation_id) REFERENCES public.quotations(quotation_id);


--
-- Name: orders orders_seller_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_seller_nursery_id_fkey FOREIGN KEY (seller_nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: orders orders_updated_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_updated_by_user_id_fkey FOREIGN KEY (updated_by_user_id) REFERENCES public.users(user_id);


--
-- Name: payments payments_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(order_id);


--
-- Name: payments payments_payer_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_payer_user_id_fkey FOREIGN KEY (payer_user_id) REFERENCES public.users(user_id);


--
-- Name: payments payments_user_subscription_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_user_subscription_id_fkey FOREIGN KEY (user_subscription_id) REFERENCES public.user_subscriptions(user_subscription_id);


--
-- Name: plant_care_guides plant_care_guides_plant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_care_guides
    ADD CONSTRAINT plant_care_guides_plant_id_fkey FOREIGN KEY (plant_id) REFERENCES public.plants(plant_id) ON DELETE CASCADE;


--
-- Name: plant_category_mappings plant_category_mappings_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_category_mappings
    ADD CONSTRAINT plant_category_mappings_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.plant_categories(category_id);


--
-- Name: plant_category_mappings plant_category_mappings_plant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_category_mappings
    ADD CONSTRAINT plant_category_mappings_plant_id_fkey FOREIGN KEY (plant_id) REFERENCES public.plants(plant_id) ON DELETE CASCADE;


--
-- Name: plant_images plant_images_plant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_images
    ADD CONSTRAINT plant_images_plant_id_fkey FOREIGN KEY (plant_id) REFERENCES public.plants(plant_id) ON DELETE CASCADE;


--
-- Name: plant_names plant_names_language_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_names
    ADD CONSTRAINT plant_names_language_id_fkey FOREIGN KEY (language_id) REFERENCES public.languages(language_id);


--
-- Name: plant_names plant_names_plant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_names
    ADD CONSTRAINT plant_names_plant_id_fkey FOREIGN KEY (plant_id) REFERENCES public.plants(plant_id) ON DELETE CASCADE;


--
-- Name: plant_request_responses plant_request_responses_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_request_responses
    ADD CONSTRAINT plant_request_responses_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.plant_requests(request_id) ON DELETE CASCADE;


--
-- Name: plant_request_responses plant_request_responses_responded_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_request_responses
    ADD CONSTRAINT plant_request_responses_responded_by_user_id_fkey FOREIGN KEY (responded_by_user_id) REFERENCES public.users(user_id);


--
-- Name: plant_request_responses plant_request_responses_supplier_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_request_responses
    ADD CONSTRAINT plant_request_responses_supplier_nursery_id_fkey FOREIGN KEY (supplier_nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: plant_requests plant_requests_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_requests
    ADD CONSTRAINT plant_requests_nursery_id_fkey FOREIGN KEY (requesting_nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: plant_requests plant_requests_plant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_requests
    ADD CONSTRAINT plant_requests_plant_id_fkey FOREIGN KEY (plant_id) REFERENCES public.plants(plant_id);


--
-- Name: plant_requests plant_requests_size_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_requests
    ADD CONSTRAINT plant_requests_size_id_fkey FOREIGN KEY (size_id) REFERENCES public.plant_sizes(size_id);


--
-- Name: plant_requests plant_requests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_requests
    ADD CONSTRAINT plant_requests_user_id_fkey FOREIGN KEY (requested_by_user_id) REFERENCES public.users(user_id);


--
-- Name: platform_config platform_config_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_config
    ADD CONSTRAINT platform_config_updated_by_fkey FOREIGN KEY (updated_by_user_id) REFERENCES public.users(user_id);


--
-- Name: quotation_documents quotation_documents_generated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotation_documents
    ADD CONSTRAINT quotation_documents_generated_by_fkey FOREIGN KEY (generated_by_user_id) REFERENCES public.users(user_id);


--
-- Name: quotation_documents quotation_documents_quotation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotation_documents
    ADD CONSTRAINT quotation_documents_quotation_id_fkey FOREIGN KEY (quotation_id) REFERENCES public.quotations(quotation_id) ON DELETE CASCADE;


--
-- Name: quotation_items quotation_items_plant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotation_items
    ADD CONSTRAINT quotation_items_plant_id_fkey FOREIGN KEY (plant_id) REFERENCES public.plants(plant_id);


--
-- Name: quotation_items quotation_items_quotation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotation_items
    ADD CONSTRAINT quotation_items_quotation_id_fkey FOREIGN KEY (quotation_id) REFERENCES public.quotations(quotation_id) ON DELETE CASCADE;


--
-- Name: quotation_verifications quotation_verifications_quotation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotation_verifications
    ADD CONSTRAINT quotation_verifications_quotation_id_fkey FOREIGN KEY (quotation_id) REFERENCES public.quotations(quotation_id) ON DELETE CASCADE;


--
-- Name: quotation_verifications quotation_verifications_revoked_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotation_verifications
    ADD CONSTRAINT quotation_verifications_revoked_by_fkey FOREIGN KEY (revoked_by_user_id) REFERENCES public.users(user_id);


--
-- Name: quotations quotations_assigned_manager_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotations
    ADD CONSTRAINT quotations_assigned_manager_fkey FOREIGN KEY (assigned_manager_user_id) REFERENCES public.users(user_id);


--
-- Name: quotations quotations_buyer_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotations
    ADD CONSTRAINT quotations_buyer_nursery_id_fkey FOREIGN KEY (buyer_nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: quotations quotations_converted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotations
    ADD CONSTRAINT quotations_converted_by_fkey FOREIGN KEY (converted_by_user_id) REFERENCES public.users(user_id);


--
-- Name: quotations quotations_converted_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotations
    ADD CONSTRAINT quotations_converted_order_id_fkey FOREIGN KEY (converted_order_id) REFERENCES public.orders(order_id);


--
-- Name: quotations quotations_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotations
    ADD CONSTRAINT quotations_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(user_id);


--
-- Name: quotations quotations_customer_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotations
    ADD CONSTRAINT quotations_customer_user_id_fkey FOREIGN KEY (customer_user_id) REFERENCES public.users(user_id);


--
-- Name: quotations quotations_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotations
    ADD CONSTRAINT quotations_nursery_id_fkey FOREIGN KEY (nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: ratings ratings_dispatch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_dispatch_id_fkey FOREIGN KEY (dispatch_id) REFERENCES public.dispatches(dispatch_id) ON DELETE SET NULL;


--
-- Name: ratings ratings_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(order_id) ON DELETE SET NULL;


--
-- Name: ratings ratings_rated_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_rated_by_user_id_fkey FOREIGN KEY (rated_by_user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: sms_messages sms_messages_sms_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sms_messages
    ADD CONSTRAINT sms_messages_sms_template_id_fkey FOREIGN KEY (sms_template_id) REFERENCES public.sms_templates(sms_template_id);


--
-- Name: sms_messages sms_messages_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sms_messages
    ADD CONSTRAINT sms_messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE SET NULL;


--
-- Name: sms_preferences sms_preferences_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sms_preferences
    ADD CONSTRAINT sms_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: sms_templates sms_templates_header_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sms_templates
    ADD CONSTRAINT sms_templates_header_id_fkey FOREIGN KEY (header_id) REFERENCES public.sms_headers(header_id);


--
-- Name: sourcing_network_members sourcing_network_members_joined_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_network_members
    ADD CONSTRAINT sourcing_network_members_joined_by_fkey FOREIGN KEY (joined_by_user_id) REFERENCES public.users(user_id) ON DELETE SET NULL;


--
-- Name: sourcing_network_members sourcing_network_members_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_network_members
    ADD CONSTRAINT sourcing_network_members_nursery_id_fkey FOREIGN KEY (nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: sourcing_post_photos sourcing_post_photos_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_post_photos
    ADD CONSTRAINT sourcing_post_photos_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.sourcing_posts(post_id) ON DELETE CASCADE;


--
-- Name: sourcing_post_photos sourcing_post_photos_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_post_photos
    ADD CONSTRAINT sourcing_post_photos_uploaded_by_fkey FOREIGN KEY (uploaded_by_user_id) REFERENCES public.users(user_id) ON DELETE SET NULL;


--
-- Name: sourcing_post_responses sourcing_post_responses_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_post_responses
    ADD CONSTRAINT sourcing_post_responses_nursery_id_fkey FOREIGN KEY (responder_nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: sourcing_post_responses sourcing_post_responses_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_post_responses
    ADD CONSTRAINT sourcing_post_responses_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.sourcing_posts(post_id);


--
-- Name: sourcing_post_responses sourcing_post_responses_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_post_responses
    ADD CONSTRAINT sourcing_post_responses_user_id_fkey FOREIGN KEY (responded_by_user_id) REFERENCES public.users(user_id);


--
-- Name: sourcing_posts sourcing_posts_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_posts
    ADD CONSTRAINT sourcing_posts_nursery_id_fkey FOREIGN KEY (nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: sourcing_posts sourcing_posts_plant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_posts
    ADD CONSTRAINT sourcing_posts_plant_id_fkey FOREIGN KEY (plant_id) REFERENCES public.plants(plant_id) ON DELETE SET NULL;


--
-- Name: sourcing_posts sourcing_posts_posted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_posts
    ADD CONSTRAINT sourcing_posts_posted_by_fkey FOREIGN KEY (posted_by_user_id) REFERENCES public.users(user_id);


--
-- Name: subscription_promos subscription_promos_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_promos
    ADD CONSTRAINT subscription_promos_created_by_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(user_id);


--
-- Name: trip_events trip_events_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_events
    ADD CONSTRAINT trip_events_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(user_id);


--
-- Name: trip_events trip_events_dispatch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_events
    ADD CONSTRAINT trip_events_dispatch_id_fkey FOREIGN KEY (dispatch_id) REFERENCES public.dispatches(dispatch_id) ON DELETE CASCADE;


--
-- Name: trip_tracking_links trip_tracking_links_customer_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_tracking_links
    ADD CONSTRAINT trip_tracking_links_customer_user_id_fkey FOREIGN KEY (customer_user_id) REFERENCES public.users(user_id);


--
-- Name: trip_tracking_links trip_tracking_links_dispatch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_tracking_links
    ADD CONSTRAINT trip_tracking_links_dispatch_id_fkey FOREIGN KEY (dispatch_id) REFERENCES public.dispatches(dispatch_id) ON DELETE CASCADE;


--
-- Name: user_activities user_activities_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_activities
    ADD CONSTRAINT user_activities_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.user_sessions(session_id) ON DELETE SET NULL;


--
-- Name: user_activities user_activities_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_activities
    ADD CONSTRAINT user_activities_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: user_addresses user_addresses_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_addresses
    ADD CONSTRAINT user_addresses_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: user_notification_devices user_notification_devices_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_notification_devices
    ADD CONSTRAINT user_notification_devices_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_assigned_by_fkey FOREIGN KEY (assigned_by_user_id) REFERENCES public.users(user_id) ON DELETE SET NULL;


--
-- Name: user_roles user_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(role_id);


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: user_sessions user_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: user_subscriptions user_subscriptions_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subscriptions
    ADD CONSTRAINT user_subscriptions_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.subscription_plans(plan_id);


--
-- Name: user_subscriptions user_subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subscriptions
    ADD CONSTRAINT user_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id);


--
-- Name: users users_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_created_by_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(user_id);


--
-- Name: users users_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_updated_by_fkey FOREIGN KEY (updated_by_user_id) REFERENCES public.users(user_id);


--
-- Name: vehicle_locations vehicle_locations_vehicle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_locations
    ADD CONSTRAINT vehicle_locations_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(vehicle_id) ON DELETE CASCADE;


--
-- Name: vehicle_tracking vehicle_tracking_dispatch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_tracking
    ADD CONSTRAINT vehicle_tracking_dispatch_id_fkey FOREIGN KEY (dispatch_id) REFERENCES public.dispatches(dispatch_id) ON DELETE SET NULL;


--
-- Name: vehicle_tracking vehicle_tracking_driver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_tracking
    ADD CONSTRAINT vehicle_tracking_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.drivers(driver_id);


--
-- Name: vehicle_tracking vehicle_tracking_vehicle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_tracking
    ADD CONSTRAINT vehicle_tracking_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(vehicle_id);


--
-- PostgreSQL database dump complete
--


