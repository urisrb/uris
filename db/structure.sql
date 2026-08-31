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
    default_storage boolean DEFAULT false NOT NULL
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
    updated_at timestamp(6) without time zone NOT NULL
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
-- Name: thing_references; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thing_references (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    thing_id bigint NOT NULL,
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

ALTER TABLE ONLY public.thing_references FORCE ROW LEVEL SECURITY;


--
-- Name: thing_references_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.thing_references_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: thing_references_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.thing_references_id_seq OWNED BY public.thing_references.id;


--
-- Name: things; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.things (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    kind character varying NOT NULL,
    title character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.things FORCE ROW LEVEL SECURITY;


--
-- Name: things_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.things_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: things_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.things_id_seq OWNED BY public.things.id;


--
-- Name: gates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gates ALTER COLUMN id SET DEFAULT nextval('public.gates_id_seq'::regclass);


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
-- Name: tenants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants ALTER COLUMN id SET DEFAULT nextval('public.tenants_id_seq'::regclass);


--
-- Name: thing_references id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thing_references ALTER COLUMN id SET DEFAULT nextval('public.thing_references_id_seq'::regclass);


--
-- Name: things id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.things ALTER COLUMN id SET DEFAULT nextval('public.things_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: gates gates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gates
    ADD CONSTRAINT gates_pkey PRIMARY KEY (id);


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
-- Name: tenants tenants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_pkey PRIMARY KEY (id);


--
-- Name: thing_references thing_references_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thing_references
    ADD CONSTRAINT thing_references_pkey PRIMARY KEY (id);


--
-- Name: things things_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.things
    ADD CONSTRAINT things_pkey PRIMARY KEY (id);


--
-- Name: index_gates_on_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_gates_on_scope ON public.gates USING btree (tenant_id, key, reference_type, reference_id) NULLS NOT DISTINCT;


--
-- Name: index_gates_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_gates_on_tenant_id ON public.gates USING btree (tenant_id);


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
-- Name: index_tenants_on_subdomain; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tenants_on_subdomain ON public.tenants USING btree (subdomain);


--
-- Name: index_thing_references_on_locator; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_thing_references_on_locator ON public.thing_references USING btree (tenant_id, resource_id, locator_key) WHERE (locator_key IS NOT NULL);


--
-- Name: index_thing_references_on_resource_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_references_on_resource_id ON public.thing_references USING btree (resource_id);


--
-- Name: index_thing_references_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_references_on_tenant_id ON public.thing_references USING btree (tenant_id);


--
-- Name: index_thing_references_on_tenant_id_and_analyzed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_references_on_tenant_id_and_analyzed_at ON public.thing_references USING btree (tenant_id, analyzed_at);


--
-- Name: index_thing_references_on_thing_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thing_references_on_thing_id ON public.thing_references USING btree (thing_id);


--
-- Name: index_things_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_tenant_id ON public.things USING btree (tenant_id);


--
-- Name: index_things_on_tenant_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_tenant_id_and_created_at ON public.things USING btree (tenant_id, created_at);


--
-- Name: index_things_on_tenant_id_and_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_things_on_tenant_id_and_kind ON public.things USING btree (tenant_id, kind);


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
-- Name: thing_references fk_rails_3ba42c6c80; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thing_references
    ADD CONSTRAINT fk_rails_3ba42c6c80 FOREIGN KEY (resource_id) REFERENCES public.resources(id);


--
-- Name: thing_references fk_rails_89e5ab95a5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thing_references
    ADD CONSTRAINT fk_rails_89e5ab95a5 FOREIGN KEY (thing_id) REFERENCES public.things(id);


--
-- Name: thing_references fk_rails_babac667d3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thing_references
    ADD CONSTRAINT fk_rails_babac667d3 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


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
-- Name: things fk_rails_e34f2f4c48; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.things
    ADD CONSTRAINT fk_rails_e34f2f4c48 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: gates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.gates ENABLE ROW LEVEL SECURITY;

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
-- Name: gates tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.gates USING ((tenant_id = (NULLIF(current_setting('things.tenant_id'::text, true), ''::text))::bigint)) WITH CHECK ((tenant_id = (NULLIF(current_setting('things.tenant_id'::text, true), ''::text))::bigint));


--
-- Name: resource_blobs tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.resource_blobs USING ((tenant_id = (NULLIF(current_setting('things.tenant_id'::text, true), ''::text))::bigint)) WITH CHECK ((tenant_id = (NULLIF(current_setting('things.tenant_id'::text, true), ''::text))::bigint));


--
-- Name: resources tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.resources USING ((tenant_id = (NULLIF(current_setting('things.tenant_id'::text, true), ''::text))::bigint)) WITH CHECK ((tenant_id = (NULLIF(current_setting('things.tenant_id'::text, true), ''::text))::bigint));


--
-- Name: runs tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.runs USING ((tenant_id = (NULLIF(current_setting('things.tenant_id'::text, true), ''::text))::bigint)) WITH CHECK ((tenant_id = (NULLIF(current_setting('things.tenant_id'::text, true), ''::text))::bigint));


--
-- Name: thing_references tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.thing_references USING ((tenant_id = (NULLIF(current_setting('things.tenant_id'::text, true), ''::text))::bigint)) WITH CHECK ((tenant_id = (NULLIF(current_setting('things.tenant_id'::text, true), ''::text))::bigint));


--
-- Name: things tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.things USING ((tenant_id = (NULLIF(current_setting('things.tenant_id'::text, true), ''::text))::bigint)) WITH CHECK ((tenant_id = (NULLIF(current_setting('things.tenant_id'::text, true), ''::text))::bigint));


--
-- Name: thing_references; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.thing_references ENABLE ROW LEVEL SECURITY;

--
-- Name: things; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.things ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
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

