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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_events (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    run_id bigint,
    channel character varying NOT NULL,
    action character varying NOT NULL,
    status character varying NOT NULL,
    scope character varying,
    subject character varying,
    client_id character varying,
    remote_ip character varying,
    request_id character varying,
    duration_ms integer,
    detail character varying,
    arguments jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.audit_events FORCE ROW LEVEL SECURITY;


--
-- Name: audit_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audit_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audit_events_id_seq OWNED BY public.audit_events.id;


--
-- Name: feeds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feeds (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    slug character varying NOT NULL,
    name character varying,
    prompt text NOT NULL,
    role character varying DEFAULT 'agent'::character varying NOT NULL,
    turns integer,
    ran_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.feeds FORCE ROW LEVEL SECURITY;


--
-- Name: feeds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.feeds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: feeds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.feeds_id_seq OWNED BY public.feeds.id;


--
-- Name: gates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gates (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    key character varying NOT NULL,
    reference_type character varying,
    reference_id bigint,
    enabled boolean DEFAULT true NOT NULL,
    live boolean DEFAULT true NOT NULL,
    note character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.gates FORCE ROW LEVEL SECURITY;


--
-- Name: gates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.gates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.gates_id_seq OWNED BY public.gates.id;


--
-- Name: item_references; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.item_references (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    item_id bigint NOT NULL,
    resource_id bigint NOT NULL,
    locator jsonb DEFAULT '{}'::jsonb NOT NULL,
    locator_key character varying,
    analysis jsonb DEFAULT '{}'::jsonb NOT NULL,
    analyzed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    version character varying,
    source_version character varying,
    changed_at timestamp(6) without time zone
);

ALTER TABLE ONLY public.item_references FORCE ROW LEVEL SECURITY;


--
-- Name: item_references_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.item_references_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: item_references_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.item_references_id_seq OWNED BY public.item_references.id;


--
-- Name: items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.items (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    kind character varying NOT NULL,
    title character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    parent_id bigint
);

ALTER TABLE ONLY public.items FORCE ROW LEVEL SECURITY;


--
-- Name: items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.items_id_seq OWNED BY public.items.id;


--
-- Name: merge_proposals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.merge_proposals (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    blocking_key character varying NOT NULL,
    reason character varying NOT NULL,
    item_ids jsonb DEFAULT '[]'::jsonb NOT NULL,
    status character varying DEFAULT 'open'::character varying NOT NULL,
    settled_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.merge_proposals FORCE ROW LEVEL SECURITY;


--
-- Name: merge_proposals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.merge_proposals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: merge_proposals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.merge_proposals_id_seq OWNED BY public.merge_proposals.id;


--
-- Name: prompts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.prompts (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    resource_id bigint NOT NULL,
    promptable_type character varying,
    promptable_id bigint,
    role character varying NOT NULL,
    model character varying NOT NULL,
    attempt integer DEFAULT 1 NOT NULL,
    request text NOT NULL,
    response jsonb DEFAULT '{}'::jsonb NOT NULL,
    started_at timestamp(6) without time zone,
    finished_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.prompts FORCE ROW LEVEL SECURITY;


--
-- Name: prompts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.prompts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: prompts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.prompts_id_seq OWNED BY public.prompts.id;


--
-- Name: resource_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resource_blobs (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    resource_id bigint NOT NULL,
    key character varying NOT NULL,
    content_type character varying,
    bytes bytea NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.resource_blobs FORCE ROW LEVEL SECURITY;


--
-- Name: resource_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.resource_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: resource_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.resource_blobs_id_seq OWNED BY public.resource_blobs.id;


--
-- Name: resources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resources (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    type character varying NOT NULL,
    key character varying NOT NULL,
    name character varying,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    credentials text,
    archived_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    sync_interval integer,
    next_sync_at timestamp(6) without time zone,
    sync_started_at timestamp(6) without time zone,
    synced_at timestamp(6) without time zone,
    checked_at timestamp(6) without time zone,
    check_error character varying,
    default_storage boolean DEFAULT false NOT NULL,
    default_inference boolean DEFAULT false NOT NULL,
    via_id bigint
);

ALTER TABLE ONLY public.resources FORCE ROW LEVEL SECURITY;


--
-- Name: resources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.resources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: resources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.resources_id_seq OWNED BY public.resources.id;


--
-- Name: runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.runs (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    resource_id bigint,
    kind character varying NOT NULL,
    status character varying DEFAULT 'queued'::character varying NOT NULL,
    selector jsonb DEFAULT '{}'::jsonb NOT NULL,
    processed integer DEFAULT 0 NOT NULL,
    started_at timestamp(6) without time zone,
    finished_at timestamp(6) without time zone,
    deadline timestamp(6) without time zone,
    error character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    feed_id bigint
);

ALTER TABLE ONLY public.runs FORCE ROW LEVEL SECURITY;


--
-- Name: runs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: runs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.runs_id_seq OWNED BY public.runs.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.settings (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    subject character varying,
    key character varying NOT NULL,
    value jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.settings FORCE ROW LEVEL SECURITY;


--
-- Name: settings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.settings_id_seq OWNED BY public.settings.id;


--
-- Name: tenants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenants (
    id bigint NOT NULL,
    subdomain character varying NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    client_id character varying,
    client_secret text,
    registration_access_token text,
    registration_client_uri character varying,
    connected_at timestamp(6) without time zone
);


--
-- Name: tenants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tenants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tenants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tenants_id_seq OWNED BY public.tenants.id;


--
-- Name: audit_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events ALTER COLUMN id SET DEFAULT nextval('public.audit_events_id_seq'::regclass);


--
-- Name: feeds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feeds ALTER COLUMN id SET DEFAULT nextval('public.feeds_id_seq'::regclass);


--
-- Name: gates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gates ALTER COLUMN id SET DEFAULT nextval('public.gates_id_seq'::regclass);


--
-- Name: item_references id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_references ALTER COLUMN id SET DEFAULT nextval('public.item_references_id_seq'::regclass);


--
-- Name: items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items ALTER COLUMN id SET DEFAULT nextval('public.items_id_seq'::regclass);


--
-- Name: merge_proposals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_proposals ALTER COLUMN id SET DEFAULT nextval('public.merge_proposals_id_seq'::regclass);


--
-- Name: prompts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prompts ALTER COLUMN id SET DEFAULT nextval('public.prompts_id_seq'::regclass);


--
-- Name: resource_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_blobs ALTER COLUMN id SET DEFAULT nextval('public.resource_blobs_id_seq'::regclass);


--
-- Name: resources id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resources ALTER COLUMN id SET DEFAULT nextval('public.resources_id_seq'::regclass);


--
-- Name: runs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.runs ALTER COLUMN id SET DEFAULT nextval('public.runs_id_seq'::regclass);


--
-- Name: settings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settings ALTER COLUMN id SET DEFAULT nextval('public.settings_id_seq'::regclass);


--
-- Name: tenants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants ALTER COLUMN id SET DEFAULT nextval('public.tenants_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


--
-- Name: feeds feeds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feeds
    ADD CONSTRAINT feeds_pkey PRIMARY KEY (id);


--
-- Name: gates gates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gates
    ADD CONSTRAINT gates_pkey PRIMARY KEY (id);


--
-- Name: item_references item_references_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_references
    ADD CONSTRAINT item_references_pkey PRIMARY KEY (id);


--
-- Name: items items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_pkey PRIMARY KEY (id);


--
-- Name: merge_proposals merge_proposals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_proposals
    ADD CONSTRAINT merge_proposals_pkey PRIMARY KEY (id);


--
-- Name: prompts prompts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prompts
    ADD CONSTRAINT prompts_pkey PRIMARY KEY (id);


--
-- Name: resource_blobs resource_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_blobs
    ADD CONSTRAINT resource_blobs_pkey PRIMARY KEY (id);


--
-- Name: resources resources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resources
    ADD CONSTRAINT resources_pkey PRIMARY KEY (id);


--
-- Name: runs runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.runs
    ADD CONSTRAINT runs_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: settings settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT settings_pkey PRIMARY KEY (id);


--
-- Name: tenants tenants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_pkey PRIMARY KEY (id);


--
-- Name: index_audit_events_on_run_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_run_id ON public.audit_events USING btree (run_id);


--
-- Name: index_audit_events_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_tenant_id ON public.audit_events USING btree (tenant_id);


--
-- Name: index_audit_events_on_tenant_id_and_action_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_tenant_id_and_action_and_id ON public.audit_events USING btree (tenant_id, action, id);


--
-- Name: index_audit_events_on_tenant_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_tenant_id_and_id ON public.audit_events USING btree (tenant_id, id);


--
-- Name: index_audit_events_on_tenant_id_and_status_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_tenant_id_and_status_and_id ON public.audit_events USING btree (tenant_id, status, id);


--
-- Name: index_feeds_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_feeds_on_tenant_id ON public.feeds USING btree (tenant_id);


--
-- Name: index_feeds_on_tenant_id_and_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_feeds_on_tenant_id_and_slug ON public.feeds USING btree (tenant_id, slug);


--
-- Name: index_gates_on_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_gates_on_scope ON public.gates USING btree (tenant_id, key, reference_type, reference_id) NULLS NOT DISTINCT;


--
-- Name: index_gates_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_gates_on_tenant_id ON public.gates USING btree (tenant_id);


--
-- Name: index_item_references_on_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_item_references_on_item_id ON public.item_references USING btree (item_id);


--
-- Name: index_item_references_on_locator; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_item_references_on_locator ON public.item_references USING btree (tenant_id, resource_id, locator_key) WHERE (locator_key IS NOT NULL);


--
-- Name: index_item_references_on_resource_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_item_references_on_resource_id ON public.item_references USING btree (resource_id);


--
-- Name: index_item_references_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_item_references_on_tenant_id ON public.item_references USING btree (tenant_id);


--
-- Name: index_item_references_on_tenant_id_and_analyzed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_item_references_on_tenant_id_and_analyzed_at ON public.item_references USING btree (tenant_id, analyzed_at);


--
-- Name: index_items_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_items_on_parent_id ON public.items USING btree (parent_id);


--
-- Name: index_items_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_items_on_tenant_id ON public.items USING btree (tenant_id);


--
-- Name: index_items_on_tenant_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_items_on_tenant_id_and_created_at ON public.items USING btree (tenant_id, created_at);


--
-- Name: index_items_on_tenant_id_and_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_items_on_tenant_id_and_kind ON public.items USING btree (tenant_id, kind);


--
-- Name: index_items_on_tenant_id_and_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_items_on_tenant_id_and_parent_id ON public.items USING btree (tenant_id, parent_id);


--
-- Name: index_merge_proposals_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_merge_proposals_on_tenant_id ON public.merge_proposals USING btree (tenant_id);


--
-- Name: index_merge_proposals_on_tenant_id_and_status_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_merge_proposals_on_tenant_id_and_status_and_id ON public.merge_proposals USING btree (tenant_id, status, id);


--
-- Name: index_open_merge_proposals_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_open_merge_proposals_on_key ON public.merge_proposals USING btree (tenant_id, blocking_key) WHERE ((status)::text = 'open'::text);


--
-- Name: index_prompts_on_promptable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_prompts_on_promptable ON public.prompts USING btree (promptable_type, promptable_id);


--
-- Name: index_prompts_on_resource_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_prompts_on_resource_id ON public.prompts USING btree (resource_id);


--
-- Name: index_prompts_on_tenant_and_promptable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_prompts_on_tenant_and_promptable ON public.prompts USING btree (tenant_id, promptable_type, promptable_id);


--
-- Name: index_prompts_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_prompts_on_tenant_id ON public.prompts USING btree (tenant_id);


--
-- Name: index_prompts_on_tenant_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_prompts_on_tenant_id_and_id ON public.prompts USING btree (tenant_id, id);


--
-- Name: index_resource_blobs_on_resource_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_resource_blobs_on_resource_id ON public.resource_blobs USING btree (resource_id);


--
-- Name: index_resource_blobs_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_resource_blobs_on_tenant_id ON public.resource_blobs USING btree (tenant_id);


--
-- Name: index_resource_blobs_on_tenant_id_and_resource_id_and_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_resource_blobs_on_tenant_id_and_resource_id_and_key ON public.resource_blobs USING btree (tenant_id, resource_id, key);


--
-- Name: index_resources_on_id_and_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_resources_on_id_and_tenant_id ON public.resources USING btree (id, tenant_id);


--
-- Name: index_resources_on_one_default_inference_per_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_resources_on_one_default_inference_per_tenant ON public.resources USING btree (tenant_id) WHERE default_inference;


--
-- Name: index_resources_on_one_default_storage_per_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_resources_on_one_default_storage_per_tenant ON public.resources USING btree (tenant_id) WHERE default_storage;


--
-- Name: index_resources_on_sync_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_resources_on_sync_due ON public.resources USING btree (tenant_id, next_sync_at) WHERE (sync_interval IS NOT NULL);


--
-- Name: index_resources_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_resources_on_tenant_id ON public.resources USING btree (tenant_id);


--
-- Name: index_resources_on_tenant_id_and_type_and_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_resources_on_tenant_id_and_type_and_key ON public.resources USING btree (tenant_id, type, key);


--
-- Name: index_resources_on_via; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_resources_on_via ON public.resources USING btree (tenant_id, via_id) WHERE (via_id IS NOT NULL);


--
-- Name: index_runs_on_feed_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_runs_on_feed_id ON public.runs USING btree (feed_id);


--
-- Name: index_runs_on_resource_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_runs_on_resource_id ON public.runs USING btree (resource_id);


--
-- Name: index_runs_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_runs_on_tenant_id ON public.runs USING btree (tenant_id);


--
-- Name: index_runs_on_tenant_id_and_kind_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_runs_on_tenant_id_and_kind_and_id ON public.runs USING btree (tenant_id, kind, id);


--
-- Name: index_runs_on_tenant_id_and_status_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_runs_on_tenant_id_and_status_and_id ON public.runs USING btree (tenant_id, status, id);


--
-- Name: index_settings_on_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_settings_on_scope ON public.settings USING btree (tenant_id, subject, key) NULLS NOT DISTINCT;


--
-- Name: index_settings_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_settings_on_tenant_id ON public.settings USING btree (tenant_id);


--
-- Name: index_tenants_on_subdomain; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tenants_on_subdomain ON public.tenants USING btree (subdomain);


--
-- Name: resource_blobs fk_rails_0740d6922f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_blobs
    ADD CONSTRAINT fk_rails_0740d6922f FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: runs fk_rails_0b416d37a1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.runs
    ADD CONSTRAINT fk_rails_0b416d37a1 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: gates fk_rails_1402937732; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gates
    ADD CONSTRAINT fk_rails_1402937732 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: runs fk_rails_1e6c1e0ed1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.runs
    ADD CONSTRAINT fk_rails_1e6c1e0ed1 FOREIGN KEY (feed_id) REFERENCES public.feeds(id);


--
-- Name: settings fk_rails_3a7e6495d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT fk_rails_3a7e6495d2 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: item_references fk_rails_3ba42c6c80; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_references
    ADD CONSTRAINT fk_rails_3ba42c6c80 FOREIGN KEY (resource_id) REFERENCES public.resources(id);


--
-- Name: prompts fk_rails_49bef51511; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prompts
    ADD CONSTRAINT fk_rails_49bef51511 FOREIGN KEY (resource_id) REFERENCES public.resources(id);


--
-- Name: item_references fk_rails_89e5ab95a5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_references
    ADD CONSTRAINT fk_rails_89e5ab95a5 FOREIGN KEY (item_id) REFERENCES public.items(id);


--
-- Name: item_references fk_rails_babac667d3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_references
    ADD CONSTRAINT fk_rails_babac667d3 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: merge_proposals fk_rails_cb45b638ed; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merge_proposals
    ADD CONSTRAINT fk_rails_cb45b638ed FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: resource_blobs fk_rails_cdd1132dc5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_blobs
    ADD CONSTRAINT fk_rails_cdd1132dc5 FOREIGN KEY (resource_id) REFERENCES public.resources(id);


--
-- Name: runs fk_rails_d4068a5e91; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.runs
    ADD CONSTRAINT fk_rails_d4068a5e91 FOREIGN KEY (resource_id) REFERENCES public.resources(id);


--
-- Name: resources fk_rails_dc32a866bd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resources
    ADD CONSTRAINT fk_rails_dc32a866bd FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: items fk_rails_e34bd51df4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT fk_rails_e34bd51df4 FOREIGN KEY (parent_id) REFERENCES public.items(id);


--
-- Name: items fk_rails_e34f2f4c48; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT fk_rails_e34f2f4c48 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: audit_events fk_rails_e392adc554; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_e392adc554 FOREIGN KEY (run_id) REFERENCES public.runs(id);


--
-- Name: feeds fk_rails_e5c16162e1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feeds
    ADD CONSTRAINT fk_rails_e5c16162e1 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: prompts fk_rails_eaab65bd59; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prompts
    ADD CONSTRAINT fk_rails_eaab65bd59 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: audit_events fk_rails_fcd253d0d8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_fcd253d0d8 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: resources fk_resources_via; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resources
    ADD CONSTRAINT fk_resources_via FOREIGN KEY (via_id, tenant_id) REFERENCES public.resources(id, tenant_id) ON DELETE RESTRICT;


--
-- Name: audit_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_events ENABLE ROW LEVEL SECURITY;

--
-- Name: feeds; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.feeds ENABLE ROW LEVEL SECURITY;

--
-- Name: gates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.gates ENABLE ROW LEVEL SECURITY;

--
-- Name: item_references; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.item_references ENABLE ROW LEVEL SECURITY;

--
-- Name: items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;

--
-- Name: merge_proposals; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.merge_proposals ENABLE ROW LEVEL SECURITY;

--
-- Name: prompts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.prompts ENABLE ROW LEVEL SECURITY;

--
-- Name: resource_blobs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.resource_blobs ENABLE ROW LEVEL SECURITY;

--
-- Name: resources; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.resources ENABLE ROW LEVEL SECURITY;

--
-- Name: runs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.runs ENABLE ROW LEVEL SECURITY;

--
-- Name: settings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_events tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.audit_events USING ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint)) WITH CHECK ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint));


--
-- Name: feeds tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.feeds USING ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint)) WITH CHECK ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint));


--
-- Name: gates tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.gates USING ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint)) WITH CHECK ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint));


--
-- Name: item_references tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.item_references USING ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint)) WITH CHECK ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint));


--
-- Name: items tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.items USING ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint)) WITH CHECK ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint));


--
-- Name: merge_proposals tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.merge_proposals USING ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint)) WITH CHECK ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint));


--
-- Name: prompts tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.prompts USING ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint)) WITH CHECK ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint));


--
-- Name: resource_blobs tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.resource_blobs USING ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint)) WITH CHECK ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint));


--
-- Name: resources tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.resources USING ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint)) WITH CHECK ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint));


--
-- Name: runs tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.runs USING ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint)) WITH CHECK ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint));


--
-- Name: settings tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.settings USING ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint)) WITH CHECK ((tenant_id = (NULLIF(current_setting('uris.tenant_id'::text, true), ''::text))::bigint));


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260906021000'),
('20260906020000'),
('20260905233000'),
('20260905230001'),
('20260905230000'),
('20260905130002'),
('20260905130001'),
('20260905130000'),
('20260905120000'),
('20260831170000'),
('20260831160000'),
('20260831130000'),
('20260830160000'),
('20260830000009'),
('20260830000008'),
('20260830000007'),
('20260830000006'),
('20260830000005'),
('20260830000004'),
('20260830000003'),
('20260830000002'),
('20260830000001'),
('20260829000005'),
('20260829000004'),
('20260829000003'),
('20260829000002'),
('20260829000001');

