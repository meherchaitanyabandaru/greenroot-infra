--
-- PostgreSQL database dump
--

\restrict zH2Y3cfVT2NFaXPdgPnOtha05GdbFJAK8rgInCtUgBO47xkinHq4hvO3X1E1hcT

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

CREATE SCHEMA public;


CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


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
    uploaded_by bigint,
    uploaded_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    deleted_at timestamp without time zone
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
    changed_by bigint,
    source_ip character varying(100),
    user_agent text,
    changed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
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
-- Name: dispatch_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dispatch_assignments (
    dispatch_assignment_id bigint NOT NULL,
    dispatch_id bigint NOT NULL,
    vehicle_id bigint NOT NULL,
    driver_id bigint NOT NULL,
    assigned_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    assigned_by bigint,
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
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    dispatch_status character varying(30) DEFAULT 'PENDING'::character varying,
    dispatched_by bigint,
    assigned_manager_user_id bigint,
    vehicle_id bigint,
    driver_id bigint,
    driver_user_id bigint,
    owner_user_id_snapshot bigint,
    customer_user_id bigint,
    customer_name_snapshot character varying(255),
    customer_mobile_snapshot character varying(20),
    destination_address text,
    dispatch_date timestamp without time zone,
    delivery_date timestamp without time zone,
    trip_started_at timestamp without time zone,
    trip_started_by_user_id bigint,
    completed_at timestamp without time zone,
    notes text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    driver_accepted_at timestamp without time zone,
    driver_rejected_at timestamp without time zone,
    driver_reject_reason text,
    deleted_at timestamp without time zone,
    trip_uuid uuid DEFAULT gen_random_uuid() NOT NULL
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
    recorded_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint
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
    approved_at timestamp without time zone,
    status character varying(20) DEFAULT 'ACTIVE'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
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
-- Name: invites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invites (
    id bigint NOT NULL,
    invite_uuid uuid DEFAULT gen_random_uuid() NOT NULL,
    invite_type character varying(50) NOT NULL,
    invited_by_user_id bigint,
    nursery_id bigint,
    role character varying(50),
    target_mobile character varying(20),
    target_email character varying(255),
    target_name character varying(255),
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    expires_at timestamp without time zone,
    accepted_by_user_id bigint,
    accepted_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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

ALTER SEQUENCE public.invites_id_seq OWNED BY public.invites.id;


--
-- Name: languages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.languages (
    language_id smallint NOT NULL,
    language_code character varying(10) NOT NULL,
    language_name character varying(100) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    reviewed_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_market_report_reason CHECK (((reason)::text = ANY (ARRAY[('SPAM'::character varying)::text, ('WRONG_PLANT'::character varying)::text, ('DUPLICATE'::character varying)::text, ('FRAUD'::character varying)::text, ('OTHER'::character varying)::text]))),
    CONSTRAINT chk_market_report_status CHECK (((status)::text = ANY (ARRAY[('PENDING'::character varying)::text, ('REVIEWED'::character varying)::text, ('DISMISSED'::character varying)::text])))
);


--
-- Name: market_ad_saves; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.market_ad_saves (
    save_id bigint NOT NULL,
    ad_id bigint NOT NULL,
    nursery_id bigint NOT NULL,
    saved_by_user_id bigint NOT NULL,
    saved_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: market_ad_views; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.market_ad_views (
    view_id bigint NOT NULL,
    ad_id bigint NOT NULL,
    nursery_id bigint,
    viewed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    price_per_unit numeric(12,2),
    price_unit character varying(50),
    photos jsonb DEFAULT '[]'::jsonb NOT NULL,
    pickup_address text,
    pickup_landmark character varying(255),
    pickup_latitude numeric(10,7),
    pickup_longitude numeric(10,7),
    pickup_gps_accuracy_meters numeric(8,2),
    pickup_location_source character varying(50),
    pickup_confirmed_by bigint,
    pickup_confirmed_at timestamp without time zone,
    pickup_location public.geography(Point,4326),
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    view_count integer DEFAULT 0 NOT NULL,
    save_count integer DEFAULT 0 NOT NULL,
    enquiry_count integer DEFAULT 0 NOT NULL,
    published_at timestamp without time zone,
    paused_at timestamp without time zone,
    expired_at timestamp without time zone,
    archived_at timestamp without time zone,
    expires_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_market_listing_status CHECK (((status)::text = ANY (ARRAY[('DRAFT'::character varying)::text, ('PUBLISHED'::character varying)::text, ('PAUSED'::character varying)::text, ('EXPIRED'::character varying)::text, ('ARCHIVED'::character varying)::text])))
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
    viewed_at timestamp without time zone,
    replied_at timestamp without time zone,
    closed_at timestamp without time zone,
    cancelled_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_market_enquiry_status CHECK (((status)::text = ANY (ARRAY[('NEW'::character varying)::text, ('IN_PROGRESS'::character varying)::text, ('QUOTATION_CREATED'::character varying)::text, ('CLOSED'::character varying)::text, ('CANCELLED'::character varying)::text])))
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
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
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
    notification_status character varying(30) DEFAULT 'PENDING'::character varying,
    sent_at timestamp without time zone,
    read_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint,
    updated_by bigint,
    approved_by bigint,
    approved_at timestamp without time zone,
    rejected_by bigint,
    rejected_at timestamp without time zone,
    rejection_reason text,
    deleted_at timestamp without time zone
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
    location_confirmed_by bigint,
    location_confirmed_at timestamp without time zone,
    location public.geography(Point,4326),
    is_primary boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
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
    reviewed_by bigint,
    reviewed_at timestamp without time zone,
    rejection_reason text,
    nursery_id bigint,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    id bigint NOT NULL,
    nursery_id bigint NOT NULL,
    driver_user_id bigint NOT NULL,
    invited_by_user_id bigint,
    approved_by_user_id bigint,
    connection_status character varying(20) DEFAULT 'REQUESTED'::character varying NOT NULL,
    connected_at timestamp without time zone,
    disconnected_at timestamp without time zone,
    disconnected_by bigint,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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

ALTER SEQUENCE public.nursery_drivers_id_seq OWNED BY public.nursery_drivers.id;


--
-- Name: nursery_featured_plants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nursery_featured_plants (
    featured_id bigint NOT NULL,
    nursery_id bigint NOT NULL,
    plant_id bigint NOT NULL,
    display_order smallint DEFAULT 1 NOT NULL,
    approximate_quantity integer,
    approximate_size character varying(50),
    quality_notes text,
    photos jsonb DEFAULT '[]'::jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    added_by_user_id bigint,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_featured_display_order CHECK (((display_order >= 1) AND (display_order <= 20)))
);


--
-- Name: nursery_featured_plants_featured_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.nursery_featured_plants_featured_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nursery_featured_plants_featured_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.nursery_featured_plants_featured_id_seq OWNED BY public.nursery_featured_plants.featured_id;


--
-- Name: nursery_inventory; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nursery_inventory (
    inventory_id bigint NOT NULL,
    inventory_code character varying(20) DEFAULT public.next_public_code('nursery_inventory'::text, 'INV'::text, 6, false) NOT NULL,
    nursery_id bigint NOT NULL,
    plant_id bigint NOT NULL,
    size_id smallint NOT NULL,
    available_quantity integer DEFAULT 0 NOT NULL,
    inventory_status character varying(20) DEFAULT 'AVAILABLE'::character varying NOT NULL,
    last_updated_by bigint,
    last_updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: nursery_inventory_inventory_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.nursery_inventory_inventory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nursery_inventory_inventory_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.nursery_inventory_inventory_id_seq OWNED BY public.nursery_inventory.inventory_id;


--
-- Name: nursery_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nursery_roles (
    nursery_role_id smallint NOT NULL,
    role_code character varying(50) NOT NULL,
    role_name character varying(100) NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: nursery_roles_nursery_role_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.nursery_roles_nursery_role_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nursery_roles_nursery_role_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.nursery_roles_nursery_role_id_seq OWNED BY public.nursery_roles.nursery_role_id;


--
-- Name: nursery_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nursery_users (
    nursery_user_id bigint NOT NULL,
    nursery_id bigint NOT NULL,
    user_id bigint NOT NULL,
    role character varying(50) DEFAULT 'MANAGER'::character varying NOT NULL,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    nursery_role_id smallint,
    invited_by_user_id bigint,
    joined_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    is_active boolean DEFAULT true
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
    confirmed_by bigint,
    confirmed_at timestamp without time zone,
    emergency_updated boolean DEFAULT false NOT NULL,
    requires_driver_ack boolean DEFAULT false NOT NULL,
    driver_acknowledged_by bigint,
    driver_acknowledged_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_order_delivery_snapshot_latitude CHECK (((latitude IS NULL) OR ((latitude >= ('-90'::integer)::numeric) AND (latitude <= (90)::numeric)))),
    CONSTRAINT chk_order_delivery_snapshot_location_source CHECK (((location_source IS NULL) OR ((location_source)::text = ANY ((ARRAY['gps_confirmed'::character varying, 'nursery_default'::character varying, 'map_selected'::character varying, 'address_search'::character varying, 'admin_updated'::character varying])::text[])))),
    CONSTRAINT chk_order_delivery_snapshot_longitude CHECK (((longitude IS NULL) OR ((longitude >= ('-180'::integer)::numeric) AND (longitude <= (180)::numeric))))
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
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    loaded_quantity numeric(12,2)
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
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    order_id bigint NOT NULL,
    order_code character varying(30) DEFAULT public.next_public_code('orders'::text, 'ORD'::text, 4, true) NOT NULL,
    order_number character varying(50) NOT NULL,
    nursery_id bigint,
    seller_nursery_id bigint,
    buyer_nursery_id bigint,
    quotation_id bigint,
    buyer_user_id bigint,
    customer_user_id bigint,
    customer_name character varying(255),
    customer_mobile character varying(20),
    assigned_manager_user_id bigint,
    created_by_user_id bigint,
    order_status character varying(30) DEFAULT 'PENDING'::character varying NOT NULL,
    total_amount numeric(15,2) DEFAULT 0,
    notes text,
    order_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    loading_started_at timestamp without time zone,
    loading_completed_at timestamp without time zone,
    loading_completed_by_user_id bigint,
    cancelled_by_user_id bigint,
    cancelled_at timestamp without time zone,
    cancel_reason text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by bigint,
    updated_by bigint,
    deleted_at timestamp without time zone
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
    expires_at timestamp without time zone NOT NULL,
    is_used boolean DEFAULT false NOT NULL,
    used_at timestamp without time zone,
    attempt_count integer DEFAULT 0 NOT NULL,
    ip_address character varying(100),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    payment_status character varying(30) DEFAULT 'PENDING'::character varying NOT NULL,
    payment_date timestamp without time zone,
    provider character varying(50),
    provider_payment_id character varying(255),
    provider_order_id character varying(255),
    provider_signature text,
    transaction_reference character varying(255),
    raw_response jsonb,
    notes text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
-- Name: plant_category_mapping; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plant_category_mapping (
    plant_id bigint NOT NULL,
    category_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    expires_at timestamp without time zone,
    fulfilled_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    updated_by bigint,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


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
    unit_price numeric(12,2),
    total_price numeric(12,2),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    total_amount numeric(12,2) DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'CUSTOMER_DRAFT'::character varying NOT NULL,
    sent_at timestamp without time zone,
    customer_responded_at timestamp without time zone,
    converted_order_id bigint,
    converted_by_user_id bigint,
    converted_at timestamp without time zone,
    deleted_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    quotation_type character varying(20) DEFAULT 'CUSTOMER'::character varying NOT NULL,
    valid_until timestamp without time zone,
    CONSTRAINT chk_quotation_status CHECK (((status)::text = ANY ((ARRAY['INTERNAL_DRAFT'::character varying, 'CUSTOMER_DRAFT'::character varying, 'CUSTOMER_SENT'::character varying, 'CUSTOMER_ACCEPTED'::character varying, 'CUSTOMER_REJECTED'::character varying, 'CONVERTED'::character varying, 'EXPIRED'::character varying])::text[]))),
    CONSTRAINT chk_quotation_type CHECK (((quotation_type)::text = ANY (ARRAY[('INTERNAL'::character varying)::text, ('CUSTOMER'::character varying)::text])))
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
-- Name: quotation_documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quotation_documents (
    doc_id bigserial PRIMARY KEY,
    quotation_id bigint NOT NULL,
    version integer NOT NULL DEFAULT 1,
    object_key text NOT NULL,
    sha256_hash character varying(64) NOT NULL,
    mime_type character varying(100) NOT NULL DEFAULT 'application/pdf',
    file_size bigint NOT NULL DEFAULT 0,
    generated_by bigint,
    generated_by_name character varying(255),
    is_current boolean NOT NULL DEFAULT true,
    created_at timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT quotation_documents_version_positive CHECK (version > 0),
    CONSTRAINT quotation_documents_file_size_nonnegative CHECK (file_size >= 0),
    CONSTRAINT quotation_documents_unique_version UNIQUE (quotation_id, version)
);


--
-- Name: quotation_verifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quotation_verifications (
    verification_id bigserial PRIMARY KEY,
    quotation_id bigint NOT NULL,
    token character varying(128) NOT NULL UNIQUE,
    status character varying(20) NOT NULL DEFAULT 'ACTIVE',
    created_at timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revoked_at timestamp without time zone,
    revoked_by bigint,
    CONSTRAINT quotation_verifications_status_check CHECK (status IN ('ACTIVE', 'REVOKED'))
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    role_id smallint NOT NULL,
    role_code character varying(50) NOT NULL,
    role_name character varying(100) NOT NULL,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
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
    applied_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: security_audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.security_audit_logs (
    id bigint NOT NULL,
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

ALTER SEQUENCE public.security_audit_logs_id_seq OWNED BY public.security_audit_logs.id;


--
-- Name: sourcing_network_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sourcing_network_members (
    member_id bigint NOT NULL,
    nursery_id bigint NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    road_accessible boolean DEFAULT true NOT NULL,
    lorry_accessible boolean DEFAULT true NOT NULL,
    contact_visible boolean DEFAULT false NOT NULL,
    service_radius_km integer DEFAULT 50 NOT NULL,
    joined_by_user_id bigint,
    joined_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deactivated_at timestamp without time zone,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    responded_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    expires_at timestamp without time zone,
    closed_at timestamp without time zone,
    deleted_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_sourcing_post_type CHECK (((post_type)::text = ANY (ARRAY[('NEED'::character varying)::text, ('AVAILABLE'::character varying)::text]))),
    CONSTRAINT chk_sourcing_urgency CHECK (((urgency)::text = ANY (ARRAY[('TODAY'::character varying)::text, ('URGENT'::character varying)::text, ('FLEXIBLE'::character varying)::text])))
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
    monthly_price numeric(12,2),
    yearly_price numeric(12,2),
    max_users integer,
    max_nurseries integer,
    is_active boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    max_managers integer,
    features jsonb DEFAULT '{}'::jsonb
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
    discount_value numeric(10,2) DEFAULT 0 NOT NULL,
    max_discount_cap numeric(10,2),
    applicable_plans jsonb DEFAULT '[]'::jsonb NOT NULL,
    applicable_cycles jsonb DEFAULT '[]'::jsonb NOT NULL,
    valid_from date NOT NULL,
    valid_until date NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    max_uses integer,
    used_count integer DEFAULT 0 NOT NULL,
    created_by bigint,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone,
    CONSTRAINT subscription_promos_discount_type_check CHECK (((discount_type)::text = ANY (ARRAY[('PERCENTAGE'::character varying)::text, ('FLAT'::character varying)::text])))
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
    id bigint NOT NULL,
    dispatch_id bigint NOT NULL,
    event_type character varying(50) NOT NULL,
    latitude numeric(10,7),
    longitude numeric(10,7),
    photo_url text,
    remarks text,
    created_by_user_id bigint,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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

ALTER SEQUENCE public.trip_events_id_seq OWNED BY public.trip_events.id;


--
-- Name: trip_tracking_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trip_tracking_links (
    id bigint NOT NULL,
    tracking_uuid uuid DEFAULT gen_random_uuid() NOT NULL,
    dispatch_id bigint NOT NULL,
    customer_user_id bigint,
    customer_mobile character varying(20),
    expires_at timestamp without time zone,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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

ALTER SEQUENCE public.trip_tracking_links_id_seq OWNED BY public.trip_tracking_links.id;


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
    activity_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    location_confirmed_by bigint,
    location_confirmed_at timestamp without time zone,
    location public.geography(Point,4326),
    is_default boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
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
    last_seen_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    assigned_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    assigned_by bigint
);


--
-- Name: user_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_sessions (
    session_id bigint NOT NULL,
    user_id bigint NOT NULL,
    session_token character varying(255),
    login_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_activity_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    session_status character varying(20) DEFAULT 'ACTIVE'::character varying,
    device_type character varying(50),
    os_name character varying(50),
    app_version character varying(50),
    ip_address character varying(100),
    user_agent text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
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
    subscription_status character varying(30) DEFAULT 'ACTIVE'::character varying,
    auto_renew boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
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
    mobile_verified boolean DEFAULT false,
    email_verified boolean DEFAULT false,
    gender public.gender_type,
    status character varying(20) DEFAULT 'ACTIVE'::character varying,
    last_login_at timestamp without time zone,
    deleted_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_by bigint,
    updated_by bigint
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
    recorded_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
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
    tracked_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
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
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
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
-- Name: invites id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invites ALTER COLUMN id SET DEFAULT nextval('public.invites_id_seq'::regclass);


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
-- Name: nursery_drivers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_drivers ALTER COLUMN id SET DEFAULT nextval('public.nursery_drivers_id_seq'::regclass);


--
-- Name: nursery_featured_plants featured_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_featured_plants ALTER COLUMN featured_id SET DEFAULT nextval('public.nursery_featured_plants_featured_id_seq'::regclass);


--
-- Name: nursery_inventory inventory_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_inventory ALTER COLUMN inventory_id SET DEFAULT nextval('public.nursery_inventory_inventory_id_seq'::regclass);


--
-- Name: nursery_roles nursery_role_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_roles ALTER COLUMN nursery_role_id SET DEFAULT nextval('public.nursery_roles_nursery_role_id_seq'::regclass);


--
-- Name: nursery_users nursery_user_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_users ALTER COLUMN nursery_user_id SET DEFAULT nextval('public.nursery_users_nursery_user_id_seq'::regclass);


--
-- Name: order_delivery_snapshots snapshot_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_delivery_snapshots ALTER COLUMN snapshot_id SET DEFAULT nextval('public.order_delivery_snapshots_snapshot_id_seq'::regclass);


--
-- Name: order_items order_item_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items ALTER COLUMN order_item_id SET DEFAULT nextval('public.order_items_order_item_id_seq'::regclass);


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
-- Name: quotation_items quotation_item_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotation_items ALTER COLUMN quotation_item_id SET DEFAULT nextval('public.quotation_items_quotation_item_id_seq'::regclass);


--
-- Name: quotations quotation_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotations ALTER COLUMN quotation_id SET DEFAULT nextval('public.quotations_quotation_id_seq'::regclass);


--
-- Name: roles role_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles ALTER COLUMN role_id SET DEFAULT nextval('public.roles_role_id_seq'::regclass);


--
-- Name: security_audit_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security_audit_logs ALTER COLUMN id SET DEFAULT nextval('public.security_audit_logs_id_seq'::regclass);


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
-- Name: trip_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_events ALTER COLUMN id SET DEFAULT nextval('public.trip_events_id_seq'::regclass);


--
-- Name: trip_tracking_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_tracking_links ALTER COLUMN id SET DEFAULT nextval('public.trip_tracking_links_id_seq'::regclass);


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
-- Name: invites invites_invite_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invites
    ADD CONSTRAINT invites_invite_uuid_key UNIQUE (invite_uuid);


--
-- Name: invites invites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invites
    ADD CONSTRAINT invites_pkey PRIMARY KEY (id);


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
-- Name: market_ad_reports market_listing_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_reports
    ADD CONSTRAINT market_listing_reports_pkey PRIMARY KEY (report_id);


--
-- Name: market_ad_saves market_listing_saves_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_saves
    ADD CONSTRAINT market_listing_saves_pkey PRIMARY KEY (save_id);


--
-- Name: market_ad_views market_listing_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_views
    ADD CONSTRAINT market_listing_views_pkey PRIMARY KEY (view_id);


--
-- Name: market_ads market_listings_listing_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ads
    ADD CONSTRAINT market_listings_listing_code_key UNIQUE (ad_code);


--
-- Name: market_ads market_listings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ads
    ADD CONSTRAINT market_listings_pkey PRIMARY KEY (ad_id);


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
-- Name: nursery_drivers nursery_drivers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_drivers
    ADD CONSTRAINT nursery_drivers_pkey PRIMARY KEY (id);


--
-- Name: nursery_featured_plants nursery_featured_plants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_featured_plants
    ADD CONSTRAINT nursery_featured_plants_pkey PRIMARY KEY (featured_id);


--
-- Name: nursery_inventory nursery_inventory_inventory_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_inventory
    ADD CONSTRAINT nursery_inventory_inventory_code_key UNIQUE (inventory_code);


--
-- Name: nursery_inventory nursery_inventory_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_inventory
    ADD CONSTRAINT nursery_inventory_pkey PRIMARY KEY (inventory_id);


--
-- Name: nursery_roles nursery_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_roles
    ADD CONSTRAINT nursery_roles_pkey PRIMARY KEY (nursery_role_id);


--
-- Name: nursery_roles nursery_roles_role_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_roles
    ADD CONSTRAINT nursery_roles_role_code_key UNIQUE (role_code);


--
-- Name: nursery_users nursery_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_users
    ADD CONSTRAINT nursery_users_pkey PRIMARY KEY (nursery_user_id);


--
-- Name: nursery_users nursery_users_uq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_users
    ADD CONSTRAINT nursery_users_uq UNIQUE (nursery_id, user_id, nursery_role_id);


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
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (order_item_id);


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
-- Name: plant_category_mapping plant_category_mapping_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_category_mapping
    ADD CONSTRAINT plant_category_mapping_pkey PRIMARY KEY (plant_id, category_id);


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
-- Name: plant_request_responses plant_request_responses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_request_responses
    ADD CONSTRAINT plant_request_responses_pkey PRIMARY KEY (response_id);


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
-- Name: quotation_items quotation_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotation_items
    ADD CONSTRAINT quotation_items_pkey PRIMARY KEY (quotation_item_id);


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
    ADD CONSTRAINT security_audit_logs_pkey PRIMARY KEY (id);


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
    ADD CONSTRAINT trip_events_pkey PRIMARY KEY (id);


--
-- Name: trip_tracking_links trip_tracking_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_tracking_links
    ADD CONSTRAINT trip_tracking_links_pkey PRIMARY KEY (id);


--
-- Name: trip_tracking_links trip_tracking_links_tracking_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_tracking_links
    ADD CONSTRAINT trip_tracking_links_tracking_uuid_key UNIQUE (tracking_uuid);


--
-- Name: nursery_inventory uq_inventory; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_inventory
    ADD CONSTRAINT uq_inventory UNIQUE (nursery_id, plant_id, size_id);


--
-- Name: market_enquiries uq_market_enquiry; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_enquiries
    ADD CONSTRAINT uq_market_enquiry UNIQUE (ad_id, enquiring_nursery_id);


--
-- Name: market_ad_reports uq_market_listing_report; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_reports
    ADD CONSTRAINT uq_market_listing_report UNIQUE (ad_id, reported_by_user_id);


--
-- Name: market_ad_saves uq_market_listing_save; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_saves
    ADD CONSTRAINT uq_market_listing_save UNIQUE (ad_id, nursery_id);


--
-- Name: market_ad_views uq_market_listing_view; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_views
    ADD CONSTRAINT uq_market_listing_view UNIQUE (ad_id, nursery_id);


--
-- Name: nursery_drivers uq_nursery_driver; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_drivers
    ADD CONSTRAINT uq_nursery_driver UNIQUE (nursery_id, driver_user_id);


--
-- Name: nursery_featured_plants uq_nursery_featured_plant; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_featured_plants
    ADD CONSTRAINT uq_nursery_featured_plant UNIQUE (nursery_id, plant_id);


--
-- Name: plant_names uq_plant_language; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_names
    ADD CONSTRAINT uq_plant_language UNIQUE (plant_id, language_id);


--
-- Name: sourcing_post_responses uq_post_response; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_post_responses
    ADD CONSTRAINT uq_post_response UNIQUE (post_id, responder_nursery_id);


--
-- Name: plant_request_responses uq_request_supplier; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_request_responses
    ADD CONSTRAINT uq_request_supplier UNIQUE (request_id, supplier_nursery_id);


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
-- Name: dispatches_trip_uuid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX dispatches_trip_uuid_idx ON public.dispatches USING btree (trip_uuid);


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

CREATE INDEX idx_dispatches_status ON public.dispatches USING btree (dispatch_status);


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
-- Name: idx_inventory_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_nursery ON public.nursery_inventory USING btree (nursery_id);


--
-- Name: idx_inventory_plant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_plant ON public.nursery_inventory USING btree (plant_id);


--
-- Name: idx_inventory_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_status ON public.nursery_inventory USING btree (inventory_status);


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
-- Name: idx_market_listings_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_listings_expires_at ON public.market_ads USING btree (expires_at) WHERE ((status)::text = 'PUBLISHED'::text);


--
-- Name: idx_market_listings_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_listings_nursery ON public.market_ads USING btree (nursery_id);


--
-- Name: idx_market_listings_plant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_listings_plant ON public.market_ads USING btree (plant_name);


--
-- Name: idx_market_listings_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_listings_status ON public.market_ads USING btree (status);


--
-- Name: idx_market_saves_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_saves_nursery ON public.market_ad_saves USING btree (nursery_id);


--
-- Name: idx_notification_templates_code_channel; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notification_templates_code_channel ON public.notification_templates USING btree (template_code, channel);


--
-- Name: idx_notifications_user_type_status_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_user_type_status_created ON public.notifications USING btree (user_id, notification_type, notification_status, created_at DESC);


--
-- Name: idx_nurseries_approved_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nurseries_approved_by ON public.nurseries USING btree (approved_by);


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
-- Name: idx_nursery_apps_applicant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nursery_apps_applicant ON public.nursery_applications USING btree (applicant_user_id);


--
-- Name: idx_nursery_apps_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nursery_apps_nursery ON public.nursery_applications USING btree (nursery_id);


--
-- Name: idx_nursery_apps_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nursery_apps_status ON public.nursery_applications USING btree (status);


--
-- Name: idx_nursery_drivers_driver; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nursery_drivers_driver ON public.nursery_drivers USING btree (driver_user_id);


--
-- Name: idx_nursery_drivers_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nursery_drivers_nursery ON public.nursery_drivers USING btree (nursery_id);


--
-- Name: idx_nursery_featured_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nursery_featured_nursery ON public.nursery_featured_plants USING btree (nursery_id, display_order);


--
-- Name: idx_nursery_featured_plant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nursery_featured_plant ON public.nursery_featured_plants USING btree (plant_id);


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
-- Name: idx_orders_buyer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_buyer ON public.orders USING btree (buyer_user_id);


--
-- Name: idx_orders_buyer_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_buyer_nursery ON public.orders USING btree (buyer_nursery_id);


--
-- Name: idx_orders_deleted; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_deleted ON public.orders USING btree (deleted_at) WHERE (deleted_at IS NOT NULL);


--
-- Name: idx_orders_manager; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_manager ON public.orders USING btree (assigned_manager_user_id);


--
-- Name: idx_orders_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_nursery ON public.orders USING btree (nursery_id);


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

CREATE INDEX idx_orders_status ON public.orders USING btree (order_status);


--
-- Name: idx_otp_mobile_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_otp_mobile_active ON public.otp_requests USING btree (mobile, purpose, expires_at) WHERE (is_used = false);


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
-- Name: idx_pcm_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pcm_category ON public.plant_category_mapping USING btree (category_id);


--
-- Name: idx_pcm_plant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pcm_plant ON public.plant_category_mapping USING btree (plant_id);


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
-- Name: idx_plant_request_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_plant_request_nursery ON public.plant_requests USING btree (requesting_nursery_id);


--
-- Name: idx_plant_request_plant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_plant_request_plant ON public.plant_requests USING btree (plant_id);


--
-- Name: idx_plant_request_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_plant_request_status ON public.plant_requests USING btree (status);


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
-- Name: idx_quotation_documents_current; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_quotation_documents_current ON public.quotation_documents USING btree (quotation_id) WHERE (is_current = true);


--
-- Name: idx_quotation_verifications_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_quotation_verifications_active ON public.quotation_verifications USING btree (quotation_id) WHERE ((status)::text = 'ACTIVE'::text);


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
-- Name: idx_request_response_request; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_request_response_request ON public.plant_request_responses USING btree (request_id);


--
-- Name: idx_request_response_supplier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_request_response_supplier ON public.plant_request_responses USING btree (supplier_nursery_id);


--
-- Name: idx_sec_audit_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sec_audit_created_at ON public.security_audit_logs USING btree (created_at DESC);


--
-- Name: idx_sec_audit_event_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sec_audit_event_type ON public.security_audit_logs USING btree (event_type);


--
-- Name: idx_sec_audit_nursery_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sec_audit_nursery_id ON public.security_audit_logs USING btree (nursery_id) WHERE (nursery_id IS NOT NULL);


--
-- Name: idx_sec_audit_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sec_audit_request_id ON public.security_audit_logs USING btree (request_id) WHERE (request_id IS NOT NULL);


--
-- Name: idx_sec_audit_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sec_audit_user_id ON public.security_audit_logs USING btree (user_id) WHERE (user_id IS NOT NULL);


--
-- Name: idx_sourcing_members_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sourcing_members_active ON public.sourcing_network_members USING btree (nursery_id) WHERE (is_active = true);


--
-- Name: idx_sourcing_members_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sourcing_members_nursery ON public.sourcing_network_members USING btree (nursery_id);


--
-- Name: idx_sourcing_photos_post; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sourcing_photos_post ON public.sourcing_post_photos USING btree (post_id);


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
-- Name: idx_sourcing_responses_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sourcing_responses_nursery ON public.sourcing_post_responses USING btree (responder_nursery_id);


--
-- Name: idx_sourcing_responses_post; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sourcing_responses_post ON public.sourcing_post_responses USING btree (post_id);


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
-- Name: idx_tracking_links_dispatch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tracking_links_dispatch ON public.trip_tracking_links USING btree (dispatch_id);


--
-- Name: idx_tracking_links_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tracking_links_uuid ON public.trip_tracking_links USING btree (tracking_uuid);


--
-- Name: idx_trip_events_dispatch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_trip_events_dispatch ON public.trip_events USING btree (dispatch_id);


--
-- Name: idx_user_activities_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_activities_entity ON public.user_activities USING btree (entity_type, entity_id);


--
-- Name: idx_user_activities_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_activities_timestamp ON public.user_activities USING btree (activity_timestamp);


--
-- Name: idx_user_activities_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_activities_type ON public.user_activities USING btree (activity_type);


--
-- Name: idx_user_activities_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_activities_user ON public.user_activities USING btree (user_id);


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

CREATE INDEX idx_user_subscriptions_user_status ON public.user_subscriptions USING btree (user_id, subscription_status);


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
-- Name: uq_driver_one_active_trip; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_driver_one_active_trip ON public.dispatches USING btree (driver_user_id) WHERE ((dispatch_status)::text = ANY ((ARRAY['ACCEPTED'::character varying, 'DISPATCHED'::character varying, 'IN_TRANSIT'::character varying])::text[]));


--
-- Name: uq_manager_one_active_nursery; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_manager_one_active_nursery ON public.nursery_users USING btree (user_id) WHERE ((status)::text = 'ACTIVE'::text);


--
-- Name: attachments attachments_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachments
    ADD CONSTRAINT attachments_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.users(user_id);


--
-- Name: dispatch_assignments da_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatch_assignments
    ADD CONSTRAINT da_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.users(user_id);


--
-- Name: dispatch_assignments da_dispatch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatch_assignments
    ADD CONSTRAINT da_dispatch_id_fkey FOREIGN KEY (dispatch_id) REFERENCES public.dispatches(dispatch_id) ON DELETE CASCADE;


--
-- Name: dispatch_assignments da_driver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatch_assignments
    ADD CONSTRAINT da_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.drivers(driver_id);


--
-- Name: dispatch_assignments da_vehicle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispatch_assignments
    ADD CONSTRAINT da_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(vehicle_id);


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
    ADD CONSTRAINT dispatches_dispatched_by_fkey FOREIGN KEY (dispatched_by) REFERENCES public.users(user_id);


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
    ADD CONSTRAINT dispatches_owner_snapshot_fkey FOREIGN KEY (owner_user_id_snapshot) REFERENCES public.users(user_id);


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
-- Name: quotation_items fk_quot_items_quotation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotation_items
    ADD CONSTRAINT fk_quot_items_quotation FOREIGN KEY (quotation_id) REFERENCES public.quotations(quotation_id) ON DELETE CASCADE;


--
-- Name: quotations fk_quotations_converted_order; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotations
    ADD CONSTRAINT fk_quotations_converted_order FOREIGN KEY (converted_order_id) REFERENCES public.orders(order_id);


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
-- Name: market_ads market_listings_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ads
    ADD CONSTRAINT market_listings_created_by_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(user_id);


--
-- Name: market_ads market_listings_nursery_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ads
    ADD CONSTRAINT market_listings_nursery_fkey FOREIGN KEY (nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: market_ads market_listings_plant_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ads
    ADD CONSTRAINT market_listings_plant_fkey FOREIGN KEY (plant_id) REFERENCES public.plants(plant_id);


--
-- Name: market_ads market_listings_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ads
    ADD CONSTRAINT market_listings_updated_by_fkey FOREIGN KEY (updated_by_user_id) REFERENCES public.users(user_id);


--
-- Name: market_enquiry_messages market_msg_enquiry_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_enquiry_messages
    ADD CONSTRAINT market_msg_enquiry_fkey FOREIGN KEY (enquiry_id) REFERENCES public.market_enquiries(enquiry_id);


--
-- Name: market_enquiry_messages market_msg_nursery_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_enquiry_messages
    ADD CONSTRAINT market_msg_nursery_fkey FOREIGN KEY (sent_by_nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: market_enquiry_messages market_msg_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_enquiry_messages
    ADD CONSTRAINT market_msg_user_fkey FOREIGN KEY (sent_by_user_id) REFERENCES public.users(user_id);


--
-- Name: market_ad_reports market_reports_listing_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_reports
    ADD CONSTRAINT market_reports_listing_fkey FOREIGN KEY (ad_id) REFERENCES public.market_ads(ad_id);


--
-- Name: market_ad_reports market_reports_nursery_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_reports
    ADD CONSTRAINT market_reports_nursery_fkey FOREIGN KEY (reported_by_nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: market_ad_reports market_reports_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_reports
    ADD CONSTRAINT market_reports_user_fkey FOREIGN KEY (reported_by_user_id) REFERENCES public.users(user_id);


--
-- Name: market_ad_saves market_saves_listing_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_saves
    ADD CONSTRAINT market_saves_listing_fkey FOREIGN KEY (ad_id) REFERENCES public.market_ads(ad_id);


--
-- Name: market_ad_saves market_saves_nursery_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_saves
    ADD CONSTRAINT market_saves_nursery_fkey FOREIGN KEY (nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: market_ad_saves market_saves_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_saves
    ADD CONSTRAINT market_saves_user_fkey FOREIGN KEY (saved_by_user_id) REFERENCES public.users(user_id);


--
-- Name: market_ad_views market_views_listing_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_views
    ADD CONSTRAINT market_views_listing_fkey FOREIGN KEY (ad_id) REFERENCES public.market_ads(ad_id);


--
-- Name: market_ad_views market_views_nursery_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_ad_views
    ADD CONSTRAINT market_views_nursery_fkey FOREIGN KEY (nursery_id) REFERENCES public.nurseries(nursery_id);


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
    ADD CONSTRAINT nurseries_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(user_id);


--
-- Name: nurseries nurseries_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nurseries
    ADD CONSTRAINT nurseries_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(user_id);


--
-- Name: nurseries nurseries_owner_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nurseries
    ADD CONSTRAINT nurseries_owner_user_id_fkey FOREIGN KEY (owner_user_id) REFERENCES public.users(user_id);


--
-- Name: nurseries nurseries_rejected_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nurseries
    ADD CONSTRAINT nurseries_rejected_by_fkey FOREIGN KEY (rejected_by) REFERENCES public.users(user_id);


--
-- Name: nursery_addresses nursery_addresses_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_addresses
    ADD CONSTRAINT nursery_addresses_nursery_id_fkey FOREIGN KEY (nursery_id) REFERENCES public.nurseries(nursery_id) ON DELETE CASCADE;


--
-- Name: nursery_applications nursery_apps_applicant_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_applications
    ADD CONSTRAINT nursery_apps_applicant_fkey FOREIGN KEY (applicant_user_id) REFERENCES public.users(user_id);


--
-- Name: nursery_applications nursery_apps_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_applications
    ADD CONSTRAINT nursery_apps_nursery_id_fkey FOREIGN KEY (nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: nursery_applications nursery_apps_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_applications
    ADD CONSTRAINT nursery_apps_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.users(user_id);


--
-- Name: nursery_drivers nursery_drivers_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_drivers
    ADD CONSTRAINT nursery_drivers_approved_by_fkey FOREIGN KEY (approved_by_user_id) REFERENCES public.users(user_id);


--
-- Name: nursery_drivers nursery_drivers_disconnected_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_drivers
    ADD CONSTRAINT nursery_drivers_disconnected_by_fkey FOREIGN KEY (disconnected_by) REFERENCES public.users(user_id);


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
-- Name: nursery_featured_plants nursery_featured_plants_added_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_featured_plants
    ADD CONSTRAINT nursery_featured_plants_added_by_fkey FOREIGN KEY (added_by_user_id) REFERENCES public.users(user_id) ON DELETE SET NULL;


--
-- Name: nursery_featured_plants nursery_featured_plants_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_featured_plants
    ADD CONSTRAINT nursery_featured_plants_nursery_id_fkey FOREIGN KEY (nursery_id) REFERENCES public.nurseries(nursery_id);


--
-- Name: nursery_featured_plants nursery_featured_plants_plant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_featured_plants
    ADD CONSTRAINT nursery_featured_plants_plant_id_fkey FOREIGN KEY (plant_id) REFERENCES public.plants(plant_id);


--
-- Name: nursery_inventory nursery_inventory_last_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_inventory
    ADD CONSTRAINT nursery_inventory_last_updated_by_fkey FOREIGN KEY (last_updated_by) REFERENCES public.users(user_id);


--
-- Name: nursery_inventory nursery_inventory_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_inventory
    ADD CONSTRAINT nursery_inventory_nursery_id_fkey FOREIGN KEY (nursery_id) REFERENCES public.nurseries(nursery_id) ON DELETE CASCADE;


--
-- Name: nursery_inventory nursery_inventory_plant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_inventory
    ADD CONSTRAINT nursery_inventory_plant_id_fkey FOREIGN KEY (plant_id) REFERENCES public.plants(plant_id);


--
-- Name: nursery_inventory nursery_inventory_size_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_inventory
    ADD CONSTRAINT nursery_inventory_size_id_fkey FOREIGN KEY (size_id) REFERENCES public.plant_sizes(size_id);


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
-- Name: nursery_users nursery_users_nursery_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_users
    ADD CONSTRAINT nursery_users_nursery_role_id_fkey FOREIGN KEY (nursery_role_id) REFERENCES public.nursery_roles(nursery_role_id);


--
-- Name: nursery_users nursery_users_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nursery_users
    ADD CONSTRAINT nursery_users_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: order_delivery_snapshots order_delivery_snapshots_confirmed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_delivery_snapshots
    ADD CONSTRAINT order_delivery_snapshots_confirmed_by_fkey FOREIGN KEY (confirmed_by) REFERENCES public.users(user_id);


--
-- Name: order_delivery_snapshots order_delivery_snapshots_driver_acknowledged_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_delivery_snapshots
    ADD CONSTRAINT order_delivery_snapshots_driver_acknowledged_by_fkey FOREIGN KEY (driver_acknowledged_by) REFERENCES public.users(user_id);


--
-- Name: order_delivery_snapshots order_delivery_snapshots_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_delivery_snapshots
    ADD CONSTRAINT order_delivery_snapshots_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(order_id) ON DELETE CASCADE;


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
-- Name: orders orders_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_nursery_id_fkey FOREIGN KEY (nursery_id) REFERENCES public.nurseries(nursery_id);


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
-- Name: plant_category_mapping pcm_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_category_mapping
    ADD CONSTRAINT pcm_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.plant_categories(category_id);


--
-- Name: plant_category_mapping pcm_plant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_category_mapping
    ADD CONSTRAINT pcm_plant_id_fkey FOREIGN KEY (plant_id) REFERENCES public.plants(plant_id) ON DELETE CASCADE;


--
-- Name: plant_care_guides plant_care_guides_plant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_care_guides
    ADD CONSTRAINT plant_care_guides_plant_id_fkey FOREIGN KEY (plant_id) REFERENCES public.plants(plant_id) ON DELETE CASCADE;


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
    ADD CONSTRAINT platform_config_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(user_id);


--
-- Name: plant_request_responses prr_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_request_responses
    ADD CONSTRAINT prr_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.plant_requests(request_id) ON DELETE CASCADE;


--
-- Name: plant_request_responses prr_responded_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_request_responses
    ADD CONSTRAINT prr_responded_by_user_id_fkey FOREIGN KEY (responded_by_user_id) REFERENCES public.users(user_id);


--
-- Name: plant_request_responses prr_supplier_nursery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plant_request_responses
    ADD CONSTRAINT prr_supplier_nursery_id_fkey FOREIGN KEY (supplier_nursery_id) REFERENCES public.nurseries(nursery_id);


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
-- Name: quotation_documents quotation_documents_generated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotation_documents
    ADD CONSTRAINT quotation_documents_generated_by_fkey FOREIGN KEY (generated_by) REFERENCES public.users(user_id);


--
-- Name: quotation_documents quotation_documents_quotation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotation_documents
    ADD CONSTRAINT quotation_documents_quotation_id_fkey FOREIGN KEY (quotation_id) REFERENCES public.quotations(quotation_id) ON DELETE CASCADE;


--
-- Name: quotation_verifications quotation_verifications_quotation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotation_verifications
    ADD CONSTRAINT quotation_verifications_quotation_id_fkey FOREIGN KEY (quotation_id) REFERENCES public.quotations(quotation_id) ON DELETE CASCADE;


--
-- Name: quotation_verifications quotation_verifications_revoked_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotation_verifications
    ADD CONSTRAINT quotation_verifications_revoked_by_fkey FOREIGN KEY (revoked_by) REFERENCES public.users(user_id);


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
    ADD CONSTRAINT subscription_promos_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(user_id);


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
-- Name: trip_tracking_links ttl_customer_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_tracking_links
    ADD CONSTRAINT ttl_customer_user_id_fkey FOREIGN KEY (customer_user_id) REFERENCES public.users(user_id);


--
-- Name: trip_tracking_links ttl_dispatch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_tracking_links
    ADD CONSTRAINT ttl_dispatch_id_fkey FOREIGN KEY (dispatch_id) REFERENCES public.dispatches(dispatch_id) ON DELETE CASCADE;


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
    ADD CONSTRAINT user_roles_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.users(user_id) ON DELETE SET NULL;


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
    ADD CONSTRAINT users_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(user_id);


--
-- Name: users users_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(user_id);


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

\unrestrict zH2Y3cfVT2NFaXPdgPnOtha05GdbFJAK8rgInCtUgBO47xkinHq4hvO3X1E1hcT
