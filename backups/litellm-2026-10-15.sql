--
-- PostgreSQL database dump
--

\restrict GGrmIiveQagJSX1rGjFJv6PNW8Pc7ibD22afze12DGDpW1RHWSDXAvBIhInqY9L

-- Dumped from database version 16.15
-- Dumped by pg_dump version 16.15

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: JobStatus; Type: TYPE; Schema: public; Owner: litellm
--

CREATE TYPE public."JobStatus" AS ENUM (
    'ACTIVE',
    'INACTIVE'
);


ALTER TYPE public."JobStatus" OWNER TO litellm;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: LiteLLM_SpendLogs; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_SpendLogs" (
    request_id text NOT NULL,
    call_type text NOT NULL,
    api_key text DEFAULT ''::text NOT NULL,
    spend double precision DEFAULT 0.0 NOT NULL,
    total_tokens integer DEFAULT 0 NOT NULL,
    prompt_tokens integer DEFAULT 0 NOT NULL,
    completion_tokens integer DEFAULT 0 NOT NULL,
    "startTime" timestamp(3) without time zone NOT NULL,
    "endTime" timestamp(3) without time zone NOT NULL,
    "completionStartTime" timestamp(3) without time zone,
    model text DEFAULT ''::text NOT NULL,
    model_id text DEFAULT ''::text,
    model_group text DEFAULT ''::text,
    custom_llm_provider text DEFAULT ''::text,
    api_base text DEFAULT ''::text,
    "user" text DEFAULT ''::text,
    metadata jsonb DEFAULT '{}'::jsonb,
    cache_hit text DEFAULT ''::text,
    cache_key text DEFAULT ''::text,
    request_tags jsonb DEFAULT '[]'::jsonb,
    team_id text,
    end_user text,
    requester_ip_address text,
    messages jsonb DEFAULT '{}'::jsonb,
    response jsonb DEFAULT '{}'::jsonb,
    proxy_server_request jsonb DEFAULT '{}'::jsonb,
    session_id text,
    status text,
    mcp_namespaced_tool_name text,
    organization_id text,
    agent_id text,
    request_duration_ms integer,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    litellm_call_id text,
    billing_agent_id text
);


ALTER TABLE public."LiteLLM_SpendLogs" OWNER TO litellm;

--
-- Name: DailyTagSpend; Type: VIEW; Schema: public; Owner: litellm
--

CREATE VIEW public."DailyTagSpend" AS
 SELECT jsonb_array_elements_text(request_tags) AS individual_request_tag,
    date("startTime") AS spend_date,
    count(*) AS log_count,
    sum(spend) AS total_spend
   FROM public."LiteLLM_SpendLogs" s
  GROUP BY (jsonb_array_elements_text(request_tags)), (date("startTime"));


ALTER VIEW public."DailyTagSpend" OWNER TO litellm;

--
-- Name: LiteLLM_VerificationToken; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_VerificationToken" (
    token text NOT NULL,
    key_name text,
    key_alias text,
    soft_budget_cooldown boolean DEFAULT false NOT NULL,
    spend double precision DEFAULT 0.0 NOT NULL,
    expires timestamp(3) without time zone,
    models text[],
    aliases jsonb DEFAULT '{}'::jsonb NOT NULL,
    config jsonb DEFAULT '{}'::jsonb NOT NULL,
    user_id text,
    team_id text,
    permissions jsonb DEFAULT '{}'::jsonb NOT NULL,
    max_parallel_requests integer,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    blocked boolean,
    tpm_limit bigint,
    rpm_limit bigint,
    max_budget double precision,
    budget_duration text,
    budget_reset_at timestamp(3) without time zone,
    allowed_cache_controls text[] DEFAULT ARRAY[]::text[],
    model_spend jsonb DEFAULT '{}'::jsonb NOT NULL,
    model_max_budget jsonb DEFAULT '{}'::jsonb NOT NULL,
    budget_id text,
    organization_id text,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP,
    created_by text,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_by text,
    allowed_routes text[] DEFAULT ARRAY[]::text[],
    object_permission_id text,
    auto_rotate boolean DEFAULT false,
    key_rotation_at timestamp(3) without time zone,
    last_rotation_at timestamp(3) without time zone,
    rotation_count integer DEFAULT 0,
    rotation_interval text,
    project_id text,
    router_settings jsonb DEFAULT '{}'::jsonb,
    policies text[] DEFAULT ARRAY[]::text[],
    access_group_ids text[] DEFAULT ARRAY[]::text[],
    last_active timestamp(3) without time zone,
    agent_id text,
    budget_limits jsonb,
    budget_fallbacks jsonb DEFAULT '{}'::jsonb NOT NULL,
    key_type text,
    settings_updated_at timestamp(3) without time zone,
    tpd_limit bigint,
    total_spend double precision DEFAULT 0.0 NOT NULL
);


ALTER TABLE public."LiteLLM_VerificationToken" OWNER TO litellm;

--
-- Name: Last30dKeysBySpend; Type: VIEW; Schema: public; Owner: litellm
--

CREATE VIEW public."Last30dKeysBySpend" AS
 SELECT l.api_key,
    v.key_alias,
    v.key_name,
    sum(l.spend) AS total_spend
   FROM (public."LiteLLM_SpendLogs" l
     LEFT JOIN public."LiteLLM_VerificationToken" v ON ((l.api_key = v.token)))
  WHERE (l."startTime" >= (CURRENT_DATE - '30 days'::interval))
  GROUP BY l.api_key, v.key_alias, v.key_name
  ORDER BY (sum(l.spend)) DESC;


ALTER VIEW public."Last30dKeysBySpend" OWNER TO litellm;

--
-- Name: Last30dModelsBySpend; Type: VIEW; Schema: public; Owner: litellm
--

CREATE VIEW public."Last30dModelsBySpend" AS
 SELECT model,
    sum(spend) AS total_spend
   FROM public."LiteLLM_SpendLogs"
  WHERE (("startTime" >= (CURRENT_DATE - '30 days'::interval)) AND (model <> ''::text))
  GROUP BY model
  ORDER BY (sum(spend)) DESC;


ALTER VIEW public."Last30dModelsBySpend" OWNER TO litellm;

--
-- Name: Last30dTopEndUsersSpend; Type: VIEW; Schema: public; Owner: litellm
--

CREATE VIEW public."Last30dTopEndUsersSpend" AS
 SELECT end_user,
    count(*) AS total_events,
    sum(spend) AS total_spend
   FROM public."LiteLLM_SpendLogs"
  WHERE ((end_user <> ''::text) AND (end_user <> USER) AND ("startTime" >= (CURRENT_DATE - '30 days'::interval)))
  GROUP BY end_user
  ORDER BY (sum(spend)) DESC
 LIMIT 100;


ALTER VIEW public."Last30dTopEndUsersSpend" OWNER TO litellm;

--
-- Name: LiteLLM_AccessGroupTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_AccessGroupTable" (
    access_group_id text NOT NULL,
    access_group_name text NOT NULL,
    description text,
    access_mcp_server_ids text[] DEFAULT ARRAY[]::text[],
    access_agent_ids text[] DEFAULT ARRAY[]::text[],
    assigned_team_ids text[] DEFAULT ARRAY[]::text[],
    assigned_key_ids text[] DEFAULT ARRAY[]::text[],
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by text,
    access_model_names text[] DEFAULT ARRAY[]::text[]
);


ALTER TABLE public."LiteLLM_AccessGroupTable" OWNER TO litellm;

--
-- Name: LiteLLM_AdaptiveRouterSession; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_AdaptiveRouterSession" (
    session_id text NOT NULL,
    router_name text NOT NULL,
    model_name text NOT NULL,
    classified_type text NOT NULL,
    misalignment_count integer DEFAULT 0 NOT NULL,
    stagnation_count integer DEFAULT 0 NOT NULL,
    disengagement_count integer DEFAULT 0 NOT NULL,
    satisfaction_count integer DEFAULT 0 NOT NULL,
    failure_count integer DEFAULT 0 NOT NULL,
    loop_count integer DEFAULT 0 NOT NULL,
    exhaustion_count integer DEFAULT 0 NOT NULL,
    last_user_content text,
    last_assistant_content text,
    tool_call_history jsonb DEFAULT '[]'::jsonb NOT NULL,
    pending_tool_calls jsonb DEFAULT '{}'::jsonb NOT NULL,
    turn_count integer DEFAULT 0 NOT NULL,
    last_processed_turn integer DEFAULT '-1'::integer NOT NULL,
    clean_credit_awarded boolean DEFAULT false NOT NULL,
    terminal_status integer,
    last_activity_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."LiteLLM_AdaptiveRouterSession" OWNER TO litellm;

--
-- Name: LiteLLM_AdaptiveRouterState; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_AdaptiveRouterState" (
    router_name text NOT NULL,
    request_type text NOT NULL,
    model_name text NOT NULL,
    alpha double precision NOT NULL,
    beta double precision NOT NULL,
    total_samples integer DEFAULT 0 NOT NULL,
    last_updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."LiteLLM_AdaptiveRouterState" OWNER TO litellm;

--
-- Name: LiteLLM_AgentIdentity; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_AgentIdentity" (
    agent_id text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    provider text NOT NULL,
    issuer text NOT NULL,
    tenant_id text NOT NULL,
    client_id text NOT NULL,
    service_principal_id text,
    required_roles text[] DEFAULT ARRAY[]::text[],
    required_scopes text[] DEFAULT ARRAY['user_impersonation'::text],
    revision text NOT NULL,
    last_authenticated_at timestamp(3) without time zone
);


ALTER TABLE public."LiteLLM_AgentIdentity" OWNER TO litellm;

--
-- Name: LiteLLM_AgentsTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_AgentsTable" (
    agent_id text NOT NULL,
    agent_name text NOT NULL,
    litellm_params jsonb,
    agent_card_params jsonb NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text NOT NULL,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by text NOT NULL,
    agent_access_groups text[] DEFAULT ARRAY[]::text[],
    object_permission_id text,
    spend double precision DEFAULT 0.0 NOT NULL,
    static_headers jsonb DEFAULT '{}'::jsonb,
    extra_headers text[] DEFAULT ARRAY[]::text[],
    tpm_limit integer,
    rpm_limit integer,
    session_tpm_limit integer,
    session_rpm_limit integer,
    access_group_ids text[] DEFAULT ARRAY[]::text[],
    enabled boolean DEFAULT true NOT NULL,
    execution_mode text DEFAULT 'autonomous'::text NOT NULL,
    identity_managed boolean DEFAULT false NOT NULL,
    kill_switch jsonb
);


ALTER TABLE public."LiteLLM_AgentsTable" OWNER TO litellm;

--
-- Name: LiteLLM_AuditLog; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_AuditLog" (
    id text NOT NULL,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    changed_by text DEFAULT ''::text NOT NULL,
    changed_by_api_key text DEFAULT ''::text NOT NULL,
    action text NOT NULL,
    table_name text NOT NULL,
    object_id text NOT NULL,
    before_value jsonb,
    updated_values jsonb
);


ALTER TABLE public."LiteLLM_AuditLog" OWNER TO litellm;

--
-- Name: LiteLLM_AutoRouterBaselineComparison; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_AutoRouterBaselineComparison" (
    scope text NOT NULL,
    api_key text NOT NULL,
    session_id text NOT NULL,
    router_name text NOT NULL,
    initial_equivalent boolean NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    published_revision bigint DEFAULT 0 NOT NULL,
    history text,
    attempted_at timestamp(3) without time zone,
    retired boolean DEFAULT false NOT NULL,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."LiteLLM_AutoRouterBaselineComparison" OWNER TO litellm;

--
-- Name: LiteLLM_AutoRouterBaselineObservation; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_AutoRouterBaselineObservation" (
    request_id text NOT NULL,
    scope text NOT NULL,
    started_at double precision NOT NULL,
    revision bigint NOT NULL,
    data text NOT NULL,
    publication text,
    conflicted boolean DEFAULT false NOT NULL
);


ALTER TABLE public."LiteLLM_AutoRouterBaselineObservation" OWNER TO litellm;

--
-- Name: LiteLLM_AutoRouterSession; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_AutoRouterSession" (
    api_key text NOT NULL,
    session_id text NOT NULL,
    router_name text NOT NULL,
    router_type text NOT NULL,
    first_turn_at timestamp(3) without time zone NOT NULL,
    last_turn_at timestamp(3) without time zone NOT NULL,
    last_model text NOT NULL,
    models jsonb DEFAULT '{}'::jsonb NOT NULL,
    turns integer DEFAULT 0 NOT NULL,
    unordered_turns integer DEFAULT 0 NOT NULL,
    covered_turns integer DEFAULT 0 NOT NULL,
    cache_hits integer DEFAULT 0 NOT NULL,
    same_model_turns integer DEFAULT 0 NOT NULL,
    same_model_hits integer DEFAULT 0 NOT NULL,
    first_visit_turns integer DEFAULT 0 NOT NULL,
    first_visit_hits integer DEFAULT 0 NOT NULL,
    return_turns integer DEFAULT 0 NOT NULL,
    return_hits integer DEFAULT 0 NOT NULL,
    return_expired_misses integer DEFAULT 0 NOT NULL,
    return_within_ttl_misses integer DEFAULT 0 NOT NULL,
    ttl_5m_turns integer DEFAULT 0 NOT NULL,
    ttl_1h_turns integer DEFAULT 0 NOT NULL,
    total_tokens bigint DEFAULT 0 NOT NULL,
    spend double precision DEFAULT 0 NOT NULL,
    saved_spend double precision DEFAULT 0 NOT NULL,
    tier_turns jsonb DEFAULT '{}'::jsonb NOT NULL,
    classifier_cost double precision DEFAULT 0 NOT NULL,
    classifier_cost_recorded_turns integer DEFAULT 0 NOT NULL,
    baseline_models jsonb DEFAULT '{}'::jsonb NOT NULL,
    savings_estimated_turns integer DEFAULT 0 NOT NULL,
    savings_estimated_actual_spend double precision DEFAULT 0 NOT NULL,
    savings_estimated_saved_spend double precision DEFAULT 0 NOT NULL,
    savings_estimated_baseline_models jsonb DEFAULT '{}'::jsonb NOT NULL
);


ALTER TABLE public."LiteLLM_AutoRouterSession" OWNER TO litellm;

--
-- Name: LiteLLM_AutoRouterUserSession; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_AutoRouterUserSession" (
    user_id text NOT NULL,
    api_key text NOT NULL,
    session_id text NOT NULL,
    router_name text NOT NULL,
    router_type text NOT NULL,
    first_turn_at timestamp(3) without time zone NOT NULL,
    last_turn_at timestamp(3) without time zone NOT NULL,
    last_model text NOT NULL,
    models jsonb DEFAULT '{}'::jsonb NOT NULL,
    turns integer DEFAULT 0 NOT NULL,
    unordered_turns integer DEFAULT 0 NOT NULL,
    covered_turns integer DEFAULT 0 NOT NULL,
    cache_hits integer DEFAULT 0 NOT NULL,
    same_model_turns integer DEFAULT 0 NOT NULL,
    same_model_hits integer DEFAULT 0 NOT NULL,
    first_visit_turns integer DEFAULT 0 NOT NULL,
    first_visit_hits integer DEFAULT 0 NOT NULL,
    return_turns integer DEFAULT 0 NOT NULL,
    return_hits integer DEFAULT 0 NOT NULL,
    return_expired_misses integer DEFAULT 0 NOT NULL,
    return_within_ttl_misses integer DEFAULT 0 NOT NULL,
    ttl_5m_turns integer DEFAULT 0 NOT NULL,
    ttl_1h_turns integer DEFAULT 0 NOT NULL,
    total_tokens bigint DEFAULT 0 NOT NULL,
    spend double precision DEFAULT 0 NOT NULL,
    saved_spend double precision DEFAULT 0 NOT NULL,
    savings_estimated_turns integer DEFAULT 0 NOT NULL,
    savings_estimated_actual_spend double precision DEFAULT 0 NOT NULL,
    savings_estimated_saved_spend double precision DEFAULT 0 NOT NULL,
    savings_estimated_baseline_models jsonb DEFAULT '{}'::jsonb NOT NULL,
    classifier_cost double precision DEFAULT 0 NOT NULL,
    classifier_cost_recorded_turns integer DEFAULT 0 NOT NULL,
    tier_turns jsonb DEFAULT '{}'::jsonb NOT NULL,
    baseline_models jsonb DEFAULT '{}'::jsonb NOT NULL
);


ALTER TABLE public."LiteLLM_AutoRouterUserSession" OWNER TO litellm;

--
-- Name: LiteLLM_BudgetTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_BudgetTable" (
    budget_id text NOT NULL,
    max_budget double precision,
    soft_budget double precision,
    max_parallel_requests integer,
    tpm_limit bigint,
    rpm_limit bigint,
    model_max_budget jsonb,
    budget_duration text,
    budget_reset_at timestamp(3) without time zone,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text NOT NULL,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by text NOT NULL,
    allowed_models text[] DEFAULT ARRAY[]::text[],
    tpd_limit bigint,
    temp_budget_increase double precision,
    temp_budget_expiry timestamp(3) without time zone
);


ALTER TABLE public."LiteLLM_BudgetTable" OWNER TO litellm;

--
-- Name: LiteLLM_BudgetWindowSpend; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_BudgetWindowSpend" (
    entity_type text NOT NULL,
    entity_id text NOT NULL,
    window_duration text NOT NULL,
    window_start timestamp(3) without time zone NOT NULL,
    spend double precision DEFAULT 0.0 NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."LiteLLM_BudgetWindowSpend" OWNER TO litellm;

--
-- Name: LiteLLM_CacheConfig; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_CacheConfig" (
    id text DEFAULT 'cache_config'::text NOT NULL,
    cache_settings jsonb NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."LiteLLM_CacheConfig" OWNER TO litellm;

--
-- Name: LiteLLM_ClaudeCodePluginTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_ClaudeCodePluginTable" (
    id text NOT NULL,
    name text NOT NULL,
    version text,
    description text,
    manifest_json text,
    files_json text DEFAULT '{}'::text,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP,
    created_by text
);


ALTER TABLE public."LiteLLM_ClaudeCodePluginTable" OWNER TO litellm;

--
-- Name: LiteLLM_Config; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_Config" (
    param_name text NOT NULL,
    param_value jsonb,
    last_run_at timestamp(3) without time zone,
    reload_revision bigint DEFAULT 0 NOT NULL
);


ALTER TABLE public."LiteLLM_Config" OWNER TO litellm;

--
-- Name: LiteLLM_ConfigOverrides; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_ConfigOverrides" (
    config_type text NOT NULL,
    config_value jsonb NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."LiteLLM_ConfigOverrides" OWNER TO litellm;

--
-- Name: LiteLLM_CredentialsTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_CredentialsTable" (
    credential_id text NOT NULL,
    credential_name text NOT NULL,
    credential_values jsonb NOT NULL,
    credential_info jsonb,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text NOT NULL,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by text NOT NULL
);


ALTER TABLE public."LiteLLM_CredentialsTable" OWNER TO litellm;

--
-- Name: LiteLLM_CronJob; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_CronJob" (
    cronjob_id text NOT NULL,
    pod_id text NOT NULL,
    status public."JobStatus" DEFAULT 'INACTIVE'::public."JobStatus" NOT NULL,
    last_updated timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    ttl timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."LiteLLM_CronJob" OWNER TO litellm;

--
-- Name: LiteLLM_DailyAgentSpend; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_DailyAgentSpend" (
    id text NOT NULL,
    agent_id text,
    date text NOT NULL,
    api_key text NOT NULL,
    model text,
    model_group text,
    custom_llm_provider text,
    mcp_namespaced_tool_name text,
    prompt_tokens bigint DEFAULT 0 NOT NULL,
    completion_tokens bigint DEFAULT 0 NOT NULL,
    cache_read_input_tokens bigint DEFAULT 0 NOT NULL,
    cache_creation_input_tokens bigint DEFAULT 0 NOT NULL,
    spend double precision DEFAULT 0.0 NOT NULL,
    api_requests bigint DEFAULT 0 NOT NULL,
    successful_requests bigint DEFAULT 0 NOT NULL,
    failed_requests bigint DEFAULT 0 NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL,
    endpoint text,
    compression_saved_tokens bigint DEFAULT 0 NOT NULL,
    compression_savings_spend double precision DEFAULT 0.0 NOT NULL,
    prompt_caching_savings_spend double precision DEFAULT 0.0 NOT NULL,
    autorouter_savings_spend double precision DEFAULT 0.0 NOT NULL,
    gateway_injected_caching_savings_spend double precision DEFAULT 0.0 NOT NULL,
    total_response_time_ms bigint DEFAULT 0 NOT NULL,
    timed_requests bigint DEFAULT 0 NOT NULL
);


ALTER TABLE public."LiteLLM_DailyAgentSpend" OWNER TO litellm;

--
-- Name: LiteLLM_DailyEndUserSpend; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_DailyEndUserSpend" (
    id text NOT NULL,
    end_user_id text,
    date text NOT NULL,
    api_key text NOT NULL,
    model text,
    model_group text,
    custom_llm_provider text,
    mcp_namespaced_tool_name text,
    prompt_tokens bigint DEFAULT 0 NOT NULL,
    completion_tokens bigint DEFAULT 0 NOT NULL,
    cache_read_input_tokens bigint DEFAULT 0 NOT NULL,
    cache_creation_input_tokens bigint DEFAULT 0 NOT NULL,
    spend double precision DEFAULT 0.0 NOT NULL,
    api_requests bigint DEFAULT 0 NOT NULL,
    successful_requests bigint DEFAULT 0 NOT NULL,
    failed_requests bigint DEFAULT 0 NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL,
    endpoint text,
    compression_saved_tokens bigint DEFAULT 0 NOT NULL,
    compression_savings_spend double precision DEFAULT 0.0 NOT NULL,
    prompt_caching_savings_spend double precision DEFAULT 0.0 NOT NULL,
    autorouter_savings_spend double precision DEFAULT 0.0 NOT NULL,
    gateway_injected_caching_savings_spend double precision DEFAULT 0.0 NOT NULL,
    total_response_time_ms bigint DEFAULT 0 NOT NULL,
    timed_requests bigint DEFAULT 0 NOT NULL
);


ALTER TABLE public."LiteLLM_DailyEndUserSpend" OWNER TO litellm;

--
-- Name: LiteLLM_DailyGatewayRequests; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_DailyGatewayRequests" (
    date text NOT NULL,
    category text NOT NULL,
    route text NOT NULL,
    successful_requests bigint DEFAULT 0 NOT NULL,
    failed_requests bigint DEFAULT 0 NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."LiteLLM_DailyGatewayRequests" OWNER TO litellm;

--
-- Name: LiteLLM_DailyGlobalSpend; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_DailyGlobalSpend" (
    id text NOT NULL,
    date text NOT NULL,
    model text,
    model_group text,
    custom_llm_provider text,
    mcp_namespaced_tool_name text,
    endpoint text,
    prompt_tokens bigint DEFAULT 0 NOT NULL,
    completion_tokens bigint DEFAULT 0 NOT NULL,
    cache_read_input_tokens bigint DEFAULT 0 NOT NULL,
    cache_creation_input_tokens bigint DEFAULT 0 NOT NULL,
    compression_saved_tokens bigint DEFAULT 0 NOT NULL,
    compression_savings_spend double precision DEFAULT 0.0 NOT NULL,
    prompt_caching_savings_spend double precision DEFAULT 0.0 NOT NULL,
    gateway_injected_caching_savings_spend double precision DEFAULT 0.0 NOT NULL,
    autorouter_savings_spend double precision DEFAULT 0.0 NOT NULL,
    spend double precision DEFAULT 0.0 NOT NULL,
    api_requests bigint DEFAULT 0 NOT NULL,
    successful_requests bigint DEFAULT 0 NOT NULL,
    failed_requests bigint DEFAULT 0 NOT NULL,
    total_response_time_ms bigint DEFAULT 0 NOT NULL,
    timed_requests bigint DEFAULT 0 NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."LiteLLM_DailyGlobalSpend" OWNER TO litellm;

--
-- Name: LiteLLM_DailyGuardrailMetrics; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_DailyGuardrailMetrics" (
    guardrail_id text NOT NULL,
    date text NOT NULL,
    requests_evaluated bigint DEFAULT 0 NOT NULL,
    passed_count bigint DEFAULT 0 NOT NULL,
    blocked_count bigint DEFAULT 0 NOT NULL,
    flagged_count bigint DEFAULT 0 NOT NULL,
    avg_score double precision,
    avg_latency_ms double precision,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."LiteLLM_DailyGuardrailMetrics" OWNER TO litellm;

--
-- Name: LiteLLM_DailyGuardrailUsageUnits; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_DailyGuardrailUsageUnits" (
    guardrail_id text NOT NULL,
    date text NOT NULL,
    team_id text NOT NULL,
    api_key text NOT NULL,
    usage_unit text NOT NULL,
    units bigint DEFAULT 0 NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL,
    cost double precision,
    untracked_units bigint DEFAULT 0 NOT NULL
);


ALTER TABLE public."LiteLLM_DailyGuardrailUsageUnits" OWNER TO litellm;

--
-- Name: LiteLLM_DailyModelUsage; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_DailyModelUsage" (
    date text NOT NULL,
    model_group text NOT NULL,
    model text NOT NULL,
    custom_llm_provider text NOT NULL,
    task_type text NOT NULL,
    spend double precision DEFAULT 0.0 NOT NULL,
    prompt_tokens bigint DEFAULT 0 NOT NULL,
    completion_tokens bigint DEFAULT 0 NOT NULL,
    request_count bigint DEFAULT 0 NOT NULL,
    successful_requests bigint DEFAULT 0 NOT NULL,
    failed_requests bigint DEFAULT 0 NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."LiteLLM_DailyModelUsage" OWNER TO litellm;

--
-- Name: LiteLLM_DailyOrganizationSpend; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_DailyOrganizationSpend" (
    id text NOT NULL,
    organization_id text,
    date text NOT NULL,
    api_key text NOT NULL,
    model text,
    model_group text,
    custom_llm_provider text,
    mcp_namespaced_tool_name text,
    prompt_tokens bigint DEFAULT 0 NOT NULL,
    completion_tokens bigint DEFAULT 0 NOT NULL,
    cache_read_input_tokens bigint DEFAULT 0 NOT NULL,
    cache_creation_input_tokens bigint DEFAULT 0 NOT NULL,
    spend double precision DEFAULT 0.0 NOT NULL,
    api_requests bigint DEFAULT 0 NOT NULL,
    successful_requests bigint DEFAULT 0 NOT NULL,
    failed_requests bigint DEFAULT 0 NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL,
    endpoint text,
    compression_saved_tokens bigint DEFAULT 0 NOT NULL,
    compression_savings_spend double precision DEFAULT 0.0 NOT NULL,
    prompt_caching_savings_spend double precision DEFAULT 0.0 NOT NULL,
    autorouter_savings_spend double precision DEFAULT 0.0 NOT NULL,
    gateway_injected_caching_savings_spend double precision DEFAULT 0.0 NOT NULL,
    total_response_time_ms bigint DEFAULT 0 NOT NULL,
    timed_requests bigint DEFAULT 0 NOT NULL
);


ALTER TABLE public."LiteLLM_DailyOrganizationSpend" OWNER TO litellm;

--
-- Name: LiteLLM_DailyPolicyMetrics; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_DailyPolicyMetrics" (
    policy_id text NOT NULL,
    date text NOT NULL,
    requests_evaluated bigint DEFAULT 0 NOT NULL,
    passed_count bigint DEFAULT 0 NOT NULL,
    blocked_count bigint DEFAULT 0 NOT NULL,
    flagged_count bigint DEFAULT 0 NOT NULL,
    avg_score double precision,
    avg_latency_ms double precision,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."LiteLLM_DailyPolicyMetrics" OWNER TO litellm;

--
-- Name: LiteLLM_DailyTagSpend; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_DailyTagSpend" (
    id text NOT NULL,
    tag text,
    date text NOT NULL,
    api_key text NOT NULL,
    model text,
    model_group text,
    custom_llm_provider text,
    prompt_tokens bigint DEFAULT 0 NOT NULL,
    completion_tokens bigint DEFAULT 0 NOT NULL,
    cache_read_input_tokens bigint DEFAULT 0 NOT NULL,
    cache_creation_input_tokens bigint DEFAULT 0 NOT NULL,
    spend double precision DEFAULT 0.0 NOT NULL,
    api_requests bigint DEFAULT 0 NOT NULL,
    successful_requests bigint DEFAULT 0 NOT NULL,
    failed_requests bigint DEFAULT 0 NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL,
    mcp_namespaced_tool_name text,
    request_id text,
    endpoint text,
    compression_saved_tokens bigint DEFAULT 0 NOT NULL,
    compression_savings_spend double precision DEFAULT 0.0 NOT NULL,
    prompt_caching_savings_spend double precision DEFAULT 0.0 NOT NULL,
    autorouter_savings_spend double precision DEFAULT 0.0 NOT NULL,
    gateway_injected_caching_savings_spend double precision DEFAULT 0.0 NOT NULL,
    total_response_time_ms bigint DEFAULT 0 NOT NULL,
    timed_requests bigint DEFAULT 0 NOT NULL
);


ALTER TABLE public."LiteLLM_DailyTagSpend" OWNER TO litellm;

--
-- Name: LiteLLM_DailyTeamSpend; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_DailyTeamSpend" (
    id text NOT NULL,
    team_id text,
    date text NOT NULL,
    api_key text NOT NULL,
    model text,
    model_group text,
    custom_llm_provider text,
    prompt_tokens bigint DEFAULT 0 NOT NULL,
    completion_tokens bigint DEFAULT 0 NOT NULL,
    spend double precision DEFAULT 0.0 NOT NULL,
    api_requests bigint DEFAULT 0 NOT NULL,
    successful_requests bigint DEFAULT 0 NOT NULL,
    failed_requests bigint DEFAULT 0 NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL,
    cache_creation_input_tokens bigint DEFAULT 0 NOT NULL,
    cache_read_input_tokens bigint DEFAULT 0 NOT NULL,
    mcp_namespaced_tool_name text,
    endpoint text,
    ptu_flat_cost double precision DEFAULT 0.0 NOT NULL,
    compression_saved_tokens bigint DEFAULT 0 NOT NULL,
    compression_savings_spend double precision DEFAULT 0.0 NOT NULL,
    prompt_caching_savings_spend double precision DEFAULT 0.0 NOT NULL,
    autorouter_savings_spend double precision DEFAULT 0.0 NOT NULL,
    gateway_injected_caching_savings_spend double precision DEFAULT 0.0 NOT NULL,
    total_response_time_ms bigint DEFAULT 0 NOT NULL,
    timed_requests bigint DEFAULT 0 NOT NULL
);


ALTER TABLE public."LiteLLM_DailyTeamSpend" OWNER TO litellm;

--
-- Name: LiteLLM_DailyToolSpend; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_DailyToolSpend" (
    date text NOT NULL,
    tool_name text NOT NULL,
    spend double precision DEFAULT 0.0 NOT NULL,
    total_tokens bigint DEFAULT 0 NOT NULL,
    request_count bigint DEFAULT 0 NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."LiteLLM_DailyToolSpend" OWNER TO litellm;

--
-- Name: LiteLLM_DailyUserSpend; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_DailyUserSpend" (
    id text NOT NULL,
    user_id text,
    date text NOT NULL,
    api_key text NOT NULL,
    model text,
    model_group text,
    custom_llm_provider text,
    prompt_tokens bigint DEFAULT 0 NOT NULL,
    completion_tokens bigint DEFAULT 0 NOT NULL,
    spend double precision DEFAULT 0.0 NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL,
    api_requests bigint DEFAULT 0 NOT NULL,
    failed_requests bigint DEFAULT 0 NOT NULL,
    successful_requests bigint DEFAULT 0 NOT NULL,
    cache_creation_input_tokens bigint DEFAULT 0 NOT NULL,
    cache_read_input_tokens bigint DEFAULT 0 NOT NULL,
    mcp_namespaced_tool_name text,
    endpoint text,
    compression_saved_tokens bigint DEFAULT 0 NOT NULL,
    compression_savings_spend double precision DEFAULT 0.0 NOT NULL,
    prompt_caching_savings_spend double precision DEFAULT 0.0 NOT NULL,
    autorouter_savings_spend double precision DEFAULT 0.0 NOT NULL,
    gateway_injected_caching_savings_spend double precision DEFAULT 0.0 NOT NULL,
    total_response_time_ms bigint DEFAULT 0 NOT NULL,
    timed_requests bigint DEFAULT 0 NOT NULL
);


ALTER TABLE public."LiteLLM_DailyUserSpend" OWNER TO litellm;

--
-- Name: LiteLLM_DeletedTeamTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_DeletedTeamTable" (
    id text NOT NULL,
    team_id text NOT NULL,
    team_alias text,
    organization_id text,
    object_permission_id text,
    admins text[],
    members text[],
    members_with_roles jsonb DEFAULT '{}'::jsonb NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    max_budget double precision,
    spend double precision DEFAULT 0.0 NOT NULL,
    models text[],
    max_parallel_requests integer,
    tpm_limit bigint,
    rpm_limit bigint,
    budget_duration text,
    budget_reset_at timestamp(3) without time zone,
    blocked boolean DEFAULT false NOT NULL,
    model_spend jsonb DEFAULT '{}'::jsonb NOT NULL,
    model_max_budget jsonb DEFAULT '{}'::jsonb NOT NULL,
    team_member_permissions text[] DEFAULT ARRAY[]::text[],
    model_id integer,
    created_at timestamp(3) without time zone,
    updated_at timestamp(3) without time zone,
    deleted_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted_by text,
    deleted_by_api_key text,
    litellm_changed_by text,
    router_settings jsonb DEFAULT '{}'::jsonb,
    policies text[] DEFAULT ARRAY[]::text[],
    allow_team_guardrail_config boolean DEFAULT false NOT NULL,
    soft_budget double precision,
    access_group_ids text[] DEFAULT ARRAY[]::text[],
    tpd_limit bigint
);


ALTER TABLE public."LiteLLM_DeletedTeamTable" OWNER TO litellm;

--
-- Name: LiteLLM_DeletedVerificationToken; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_DeletedVerificationToken" (
    id text NOT NULL,
    token text NOT NULL,
    key_name text,
    key_alias text,
    soft_budget_cooldown boolean DEFAULT false NOT NULL,
    spend double precision DEFAULT 0.0 NOT NULL,
    expires timestamp(3) without time zone,
    models text[],
    aliases jsonb DEFAULT '{}'::jsonb NOT NULL,
    config jsonb DEFAULT '{}'::jsonb NOT NULL,
    user_id text,
    team_id text,
    permissions jsonb DEFAULT '{}'::jsonb NOT NULL,
    max_parallel_requests integer,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    blocked boolean,
    tpm_limit bigint,
    rpm_limit bigint,
    max_budget double precision,
    budget_duration text,
    budget_reset_at timestamp(3) without time zone,
    allowed_cache_controls text[] DEFAULT ARRAY[]::text[],
    allowed_routes text[] DEFAULT ARRAY[]::text[],
    model_spend jsonb DEFAULT '{}'::jsonb NOT NULL,
    model_max_budget jsonb DEFAULT '{}'::jsonb NOT NULL,
    budget_id text,
    organization_id text,
    object_permission_id text,
    created_at timestamp(3) without time zone,
    created_by text,
    updated_at timestamp(3) without time zone,
    updated_by text,
    rotation_count integer DEFAULT 0,
    auto_rotate boolean DEFAULT false,
    rotation_interval text,
    last_rotation_at timestamp(3) without time zone,
    key_rotation_at timestamp(3) without time zone,
    deleted_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted_by text,
    deleted_by_api_key text,
    litellm_changed_by text,
    router_settings jsonb DEFAULT '{}'::jsonb,
    policies text[] DEFAULT ARRAY[]::text[],
    access_group_ids text[] DEFAULT ARRAY[]::text[],
    last_active timestamp(3) without time zone,
    project_id text,
    agent_id text,
    budget_fallbacks jsonb DEFAULT '{}'::jsonb NOT NULL,
    key_type text,
    settings_updated_at timestamp(3) without time zone,
    tpd_limit bigint,
    total_spend double precision DEFAULT 0.0 NOT NULL
);


ALTER TABLE public."LiteLLM_DeletedVerificationToken" OWNER TO litellm;

--
-- Name: LiteLLM_DeprecatedVerificationToken; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_DeprecatedVerificationToken" (
    id text NOT NULL,
    token text NOT NULL,
    active_token_id text NOT NULL,
    revoke_at timestamp(3) without time zone NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."LiteLLM_DeprecatedVerificationToken" OWNER TO litellm;

--
-- Name: LiteLLM_EndUserTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_EndUserTable" (
    user_id text NOT NULL,
    alias text,
    spend double precision DEFAULT 0.0 NOT NULL,
    allowed_model_region text,
    default_model text,
    budget_id text,
    blocked boolean DEFAULT false NOT NULL,
    object_permission_id text
);


ALTER TABLE public."LiteLLM_EndUserTable" OWNER TO litellm;

--
-- Name: LiteLLM_ErrorLogs; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_ErrorLogs" (
    request_id text NOT NULL,
    "startTime" timestamp(3) without time zone NOT NULL,
    "endTime" timestamp(3) without time zone NOT NULL,
    api_base text DEFAULT ''::text NOT NULL,
    model_group text DEFAULT ''::text NOT NULL,
    litellm_model_name text DEFAULT ''::text NOT NULL,
    model_id text DEFAULT ''::text NOT NULL,
    request_kwargs jsonb DEFAULT '{}'::jsonb NOT NULL,
    exception_type text DEFAULT ''::text NOT NULL,
    exception_string text DEFAULT ''::text NOT NULL,
    status_code text DEFAULT ''::text NOT NULL
);


ALTER TABLE public."LiteLLM_ErrorLogs" OWNER TO litellm;

--
-- Name: LiteLLM_GuardrailsTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_GuardrailsTable" (
    guardrail_id text NOT NULL,
    guardrail_name text NOT NULL,
    litellm_params jsonb NOT NULL,
    guardrail_info jsonb,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL,
    team_id text,
    reviewed_at timestamp(3) without time zone,
    status text DEFAULT 'active'::text NOT NULL,
    submitted_at timestamp(3) without time zone
);


ALTER TABLE public."LiteLLM_GuardrailsTable" OWNER TO litellm;

--
-- Name: LiteLLM_HealthCheckTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_HealthCheckTable" (
    health_check_id text NOT NULL,
    model_name text NOT NULL,
    model_id text,
    status text NOT NULL,
    healthy_count integer DEFAULT 0 NOT NULL,
    unhealthy_count integer DEFAULT 0 NOT NULL,
    error_message text,
    response_time_ms double precision,
    details jsonb,
    checked_by text,
    checked_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."LiteLLM_HealthCheckTable" OWNER TO litellm;

--
-- Name: LiteLLM_InvitationLink; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_InvitationLink" (
    id text NOT NULL,
    user_id text NOT NULL,
    is_accepted boolean DEFAULT false NOT NULL,
    accepted_at timestamp(3) without time zone,
    expires_at timestamp(3) without time zone NOT NULL,
    created_at timestamp(3) without time zone NOT NULL,
    created_by text NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL,
    updated_by text NOT NULL
);


ALTER TABLE public."LiteLLM_InvitationLink" OWNER TO litellm;

--
-- Name: LiteLLM_JWTKeyMapping; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_JWTKeyMapping" (
    id text NOT NULL,
    jwt_claim_name text NOT NULL,
    jwt_claim_value text NOT NULL,
    token text NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by text,
    jwt_issuer text DEFAULT ''::text NOT NULL
);


ALTER TABLE public."LiteLLM_JWTKeyMapping" OWNER TO litellm;

--
-- Name: LiteLLM_Lens; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_Lens" (
    id text NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    data jsonb NOT NULL
);


ALTER TABLE public."LiteLLM_Lens" OWNER TO litellm;

--
-- Name: LiteLLM_LensRun; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_LensRun" (
    id text NOT NULL,
    lens_id text NOT NULL,
    created_at timestamp(3) without time zone NOT NULL,
    data jsonb NOT NULL
);


ALTER TABLE public."LiteLLM_LensRun" OWNER TO litellm;

--
-- Name: LiteLLM_LensWorker; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_LensWorker" (
    id text NOT NULL,
    token_hash text NOT NULL,
    data jsonb NOT NULL
);


ALTER TABLE public."LiteLLM_LensWorker" OWNER TO litellm;

--
-- Name: LiteLLM_MCPServerOAuthClient; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_MCPServerOAuthClient" (
    server_id text NOT NULL,
    credentials jsonb,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."LiteLLM_MCPServerOAuthClient" OWNER TO litellm;

--
-- Name: LiteLLM_MCPServerTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_MCPServerTable" (
    server_id text NOT NULL,
    server_name text,
    description text,
    url text,
    transport text DEFAULT 'sse'::text NOT NULL,
    auth_type text,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP,
    created_by text,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_by text,
    status text DEFAULT 'unknown'::text,
    last_health_check timestamp(3) without time zone,
    health_check_error text,
    mcp_info jsonb DEFAULT '{}'::jsonb,
    args text[] DEFAULT ARRAY[]::text[],
    command text,
    env jsonb DEFAULT '{}'::jsonb,
    mcp_access_groups text[],
    alias text,
    allowed_tools text[] DEFAULT ARRAY[]::text[],
    extra_headers text[] DEFAULT ARRAY[]::text[],
    static_headers jsonb DEFAULT '{}'::jsonb,
    credentials jsonb DEFAULT '{}'::jsonb,
    authorization_url text,
    registration_url text,
    token_url text,
    allow_all_keys boolean DEFAULT false NOT NULL,
    available_on_public_internet boolean DEFAULT true NOT NULL,
    spec_path text,
    byok_api_key_help_url text,
    byok_description text[] DEFAULT ARRAY[]::text[],
    is_byok boolean DEFAULT false NOT NULL,
    tool_name_to_description jsonb DEFAULT '{}'::jsonb,
    tool_name_to_display_name jsonb DEFAULT '{}'::jsonb,
    approval_status text DEFAULT 'active'::text,
    submitted_by text,
    submitted_at timestamp(3) without time zone,
    reviewed_at timestamp(3) without time zone,
    review_notes text,
    source_url text,
    instructions text,
    delegate_auth_to_upstream boolean DEFAULT false NOT NULL,
    env_vars jsonb DEFAULT '[]'::jsonb,
    oauth_passthrough boolean DEFAULT false NOT NULL,
    oauth2_flow text,
    timeout double precision,
    max_concurrent_requests integer,
    token_exchange_endpoint text,
    audience text,
    subject_token_type text,
    token_exchange_profile text,
    dcr_bridge boolean,
    issuer text,
    per_server_oauth_discovery boolean DEFAULT false NOT NULL,
    pinned_tools jsonb DEFAULT '{}'::jsonb
);


ALTER TABLE public."LiteLLM_MCPServerTable" OWNER TO litellm;

--
-- Name: LiteLLM_MCPToolsetTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_MCPToolsetTable" (
    toolset_id text NOT NULL,
    toolset_name text NOT NULL,
    description text,
    tools jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by text
);


ALTER TABLE public."LiteLLM_MCPToolsetTable" OWNER TO litellm;

--
-- Name: LiteLLM_MCPUserCredentials; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_MCPUserCredentials" (
    id text NOT NULL,
    user_id text NOT NULL,
    server_id text NOT NULL,
    credential_b64 text NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."LiteLLM_MCPUserCredentials" OWNER TO litellm;

--
-- Name: LiteLLM_MCPUserEnvVars; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_MCPUserEnvVars" (
    id text NOT NULL,
    user_id text NOT NULL,
    server_id text NOT NULL,
    values_b64 text NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."LiteLLM_MCPUserEnvVars" OWNER TO litellm;

--
-- Name: LiteLLM_ManagedFileContentTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_ManagedFileContentTable" (
    id text NOT NULL,
    content bytea NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."LiteLLM_ManagedFileContentTable" OWNER TO litellm;

--
-- Name: LiteLLM_ManagedFileTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_ManagedFileTable" (
    id text NOT NULL,
    unified_file_id text NOT NULL,
    file_object jsonb,
    model_mappings jsonb NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL,
    created_by text,
    flat_model_file_ids text[] DEFAULT ARRAY[]::text[],
    updated_by text,
    storage_backend text,
    storage_url text,
    team_id text
);


ALTER TABLE public."LiteLLM_ManagedFileTable" OWNER TO litellm;

--
-- Name: LiteLLM_ManagedObjectTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_ManagedObjectTable" (
    id text NOT NULL,
    unified_object_id text NOT NULL,
    model_object_id text NOT NULL,
    file_object jsonb NOT NULL,
    file_purpose text NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text,
    updated_at timestamp(3) without time zone NOT NULL,
    updated_by text,
    status text,
    batch_processed boolean DEFAULT false NOT NULL,
    team_id text,
    api_key text,
    request_tags jsonb DEFAULT '[]'::jsonb,
    org_id text
);


ALTER TABLE public."LiteLLM_ManagedObjectTable" OWNER TO litellm;

--
-- Name: LiteLLM_ManagedVectorStoreIndexTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_ManagedVectorStoreIndexTable" (
    id text NOT NULL,
    index_name text NOT NULL,
    litellm_params jsonb NOT NULL,
    index_info jsonb,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text,
    updated_at timestamp(3) without time zone NOT NULL,
    updated_by text
);


ALTER TABLE public."LiteLLM_ManagedVectorStoreIndexTable" OWNER TO litellm;

--
-- Name: LiteLLM_ManagedVectorStoreTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_ManagedVectorStoreTable" (
    id text NOT NULL,
    unified_resource_id text NOT NULL,
    resource_object jsonb,
    model_mappings jsonb NOT NULL,
    flat_model_resource_ids text[] DEFAULT ARRAY[]::text[],
    storage_backend text,
    storage_url text,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text,
    updated_at timestamp(3) without time zone NOT NULL,
    updated_by text,
    team_id text
);


ALTER TABLE public."LiteLLM_ManagedVectorStoreTable" OWNER TO litellm;

--
-- Name: LiteLLM_ManagedVectorStoresTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_ManagedVectorStoresTable" (
    vector_store_id text NOT NULL,
    custom_llm_provider text NOT NULL,
    vector_store_name text,
    vector_store_description text,
    vector_store_metadata jsonb,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL,
    litellm_credential_name text,
    litellm_params jsonb,
    team_id text,
    user_id text
);


ALTER TABLE public."LiteLLM_ManagedVectorStoresTable" OWNER TO litellm;

--
-- Name: LiteLLM_MemoryTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_MemoryTable" (
    memory_id text NOT NULL,
    key text NOT NULL,
    value text NOT NULL,
    metadata jsonb,
    user_id text,
    team_id text,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by text
);


ALTER TABLE public."LiteLLM_MemoryTable" OWNER TO litellm;

--
-- Name: LiteLLM_ModelAccessGroupBudgetTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_ModelAccessGroupBudgetTable" (
    access_group_name text NOT NULL,
    spend double precision DEFAULT 0.0 NOT NULL,
    budget_id text,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by text
);


ALTER TABLE public."LiteLLM_ModelAccessGroupBudgetTable" OWNER TO litellm;

--
-- Name: LiteLLM_ModelTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_ModelTable" (
    id integer NOT NULL,
    aliases jsonb,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text NOT NULL,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by text NOT NULL
);


ALTER TABLE public."LiteLLM_ModelTable" OWNER TO litellm;

--
-- Name: LiteLLM_ModelTable_id_seq; Type: SEQUENCE; Schema: public; Owner: litellm
--

CREATE SEQUENCE public."LiteLLM_ModelTable_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."LiteLLM_ModelTable_id_seq" OWNER TO litellm;

--
-- Name: LiteLLM_ModelTable_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: litellm
--

ALTER SEQUENCE public."LiteLLM_ModelTable_id_seq" OWNED BY public."LiteLLM_ModelTable".id;


--
-- Name: LiteLLM_ObjectPermissionTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_ObjectPermissionTable" (
    object_permission_id text NOT NULL,
    mcp_servers text[] DEFAULT ARRAY[]::text[],
    vector_stores text[] DEFAULT ARRAY[]::text[],
    mcp_access_groups text[] DEFAULT ARRAY[]::text[],
    mcp_tool_permissions jsonb,
    agents text[] DEFAULT ARRAY[]::text[],
    agent_access_groups text[] DEFAULT ARRAY[]::text[],
    blocked_tools text[] DEFAULT ARRAY[]::text[],
    models text[] DEFAULT ARRAY[]::text[],
    mcp_toolsets text[] DEFAULT ARRAY[]::text[],
    search_tools text[] DEFAULT ARRAY[]::text[],
    mcp_tool_search_enabled boolean,
    skills text[] DEFAULT ARRAY[]::text[]
);


ALTER TABLE public."LiteLLM_ObjectPermissionTable" OWNER TO litellm;

--
-- Name: LiteLLM_OrganizationMembership; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_OrganizationMembership" (
    user_id text NOT NULL,
    organization_id text NOT NULL,
    user_role text,
    spend double precision DEFAULT 0.0,
    budget_id text,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public."LiteLLM_OrganizationMembership" OWNER TO litellm;

--
-- Name: LiteLLM_OrganizationTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_OrganizationTable" (
    organization_id text NOT NULL,
    organization_alias text NOT NULL,
    budget_id text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    models text[],
    spend double precision DEFAULT 0.0 NOT NULL,
    model_spend jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text NOT NULL,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by text NOT NULL,
    object_permission_id text
);


ALTER TABLE public."LiteLLM_OrganizationTable" OWNER TO litellm;

--
-- Name: LiteLLM_PolicyAttachmentTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_PolicyAttachmentTable" (
    attachment_id text NOT NULL,
    policy_name text NOT NULL,
    scope text,
    teams text[] DEFAULT ARRAY[]::text[],
    keys text[] DEFAULT ARRAY[]::text[],
    models text[] DEFAULT ARRAY[]::text[],
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by text,
    tags text[] DEFAULT ARRAY[]::text[],
    priority integer,
    is_default boolean DEFAULT false NOT NULL
);


ALTER TABLE public."LiteLLM_PolicyAttachmentTable" OWNER TO litellm;

--
-- Name: LiteLLM_PolicyTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_PolicyTable" (
    policy_id text NOT NULL,
    policy_name text NOT NULL,
    inherit text,
    description text,
    guardrails_add text[] DEFAULT ARRAY[]::text[],
    guardrails_remove text[] DEFAULT ARRAY[]::text[],
    condition jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by text,
    pipeline jsonb,
    is_latest boolean DEFAULT true NOT NULL,
    parent_version_id text,
    production_at timestamp(3) without time zone,
    published_at timestamp(3) without time zone,
    version_number integer DEFAULT 1 NOT NULL,
    version_status text DEFAULT 'production'::text NOT NULL
);


ALTER TABLE public."LiteLLM_PolicyTable" OWNER TO litellm;

--
-- Name: LiteLLM_ProjectTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_ProjectTable" (
    project_id text NOT NULL,
    project_alias text,
    team_id text,
    budget_id text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    models text[],
    spend double precision DEFAULT 0.0 NOT NULL,
    model_spend jsonb DEFAULT '{}'::jsonb NOT NULL,
    blocked boolean DEFAULT false NOT NULL,
    object_permission_id text,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text NOT NULL,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by text NOT NULL,
    description text,
    model_rpm_limit jsonb DEFAULT '{}'::jsonb NOT NULL,
    model_tpm_limit jsonb DEFAULT '{}'::jsonb NOT NULL
);


ALTER TABLE public."LiteLLM_ProjectTable" OWNER TO litellm;

--
-- Name: LiteLLM_PromptTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_PromptTable" (
    id text NOT NULL,
    prompt_id text NOT NULL,
    litellm_params jsonb NOT NULL,
    prompt_info jsonb,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    environment text DEFAULT 'development'::text NOT NULL,
    created_by text
);


ALTER TABLE public."LiteLLM_PromptTable" OWNER TO litellm;

--
-- Name: LiteLLM_ProxyModelTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_ProxyModelTable" (
    model_id text NOT NULL,
    model_name text NOT NULL,
    litellm_params jsonb NOT NULL,
    model_info jsonb,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text NOT NULL,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by text NOT NULL,
    blocked boolean DEFAULT false NOT NULL
);


ALTER TABLE public."LiteLLM_ProxyModelTable" OWNER TO litellm;

--
-- Name: LiteLLM_ProxyWorkerHeartbeat; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_ProxyWorkerHeartbeat" (
    worker_id text NOT NULL,
    hostname text NOT NULL,
    started_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_heartbeat_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."LiteLLM_ProxyWorkerHeartbeat" OWNER TO litellm;

--
-- Name: LiteLLM_RetiredAgent; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_RetiredAgent" (
    original_agent_id text NOT NULL,
    retired_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."LiteLLM_RetiredAgent" OWNER TO litellm;

--
-- Name: LiteLLM_RetiredAgentIdentity; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_RetiredAgentIdentity" (
    binding_id text NOT NULL,
    agent_id text,
    provider text NOT NULL,
    issuer text NOT NULL,
    tenant_id text NOT NULL,
    client_id text NOT NULL
);


ALTER TABLE public."LiteLLM_RetiredAgentIdentity" OWNER TO litellm;

--
-- Name: LiteLLM_SSOConfig; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_SSOConfig" (
    id text DEFAULT 'sso_config'::text NOT NULL,
    sso_settings jsonb NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."LiteLLM_SSOConfig" OWNER TO litellm;

--
-- Name: LiteLLM_SSOIdentityAssertion; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_SSOIdentityAssertion" (
    user_id text NOT NULL,
    assertion_b64 text NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."LiteLLM_SSOIdentityAssertion" OWNER TO litellm;

--
-- Name: LiteLLM_SearchToolsTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_SearchToolsTable" (
    search_tool_id text NOT NULL,
    search_tool_name text NOT NULL,
    litellm_params jsonb NOT NULL,
    search_tool_info jsonb,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."LiteLLM_SearchToolsTable" OWNER TO litellm;

--
-- Name: LiteLLM_ShadowEvalAttempt; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_ShadowEvalAttempt" (
    id text NOT NULL,
    job_id text NOT NULL,
    request_id text NOT NULL,
    outcome text NOT NULL,
    tier text,
    real_model text,
    shadow_model text,
    confidence double precision,
    judge_cost double precision DEFAULT 0 NOT NULL,
    error text,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    shadow_cost double precision DEFAULT 0 NOT NULL,
    real_cost double precision,
    real_classifier_cost double precision DEFAULT 0 NOT NULL,
    shadow_classifier_cost double precision DEFAULT 0 NOT NULL,
    real_cache_hit boolean DEFAULT false NOT NULL,
    router_name text
);


ALTER TABLE public."LiteLLM_ShadowEvalAttempt" OWNER TO litellm;

--
-- Name: LiteLLM_ShadowEvalFunnel; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_ShadowEvalFunnel" (
    job_id text NOT NULL,
    not_sampled integer DEFAULT 0 NOT NULL,
    unjudgeable integer DEFAULT 0 NOT NULL,
    shed integer DEFAULT 0 NOT NULL,
    withheld integer DEFAULT 0 NOT NULL
);


ALTER TABLE public."LiteLLM_ShadowEvalFunnel" OWNER TO litellm;

--
-- Name: LiteLLM_ShadowEvalJob; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_ShadowEvalJob" (
    id text NOT NULL,
    target_id text NOT NULL,
    router_name text NOT NULL,
    judge_model text NOT NULL,
    shadow_percentage double precision NOT NULL,
    max_turns integer NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text,
    ends_at timestamp(3) without time zone NOT NULL,
    stopped_at timestamp(3) without time zone,
    baseline_model text,
    direction text DEFAULT 'forward'::text NOT NULL,
    group_id text NOT NULL,
    stopped_by text,
    max_budget double precision,
    target_type text DEFAULT 'key'::text NOT NULL,
    router_names text[] DEFAULT ARRAY[]::text[] NOT NULL,
    models text[] DEFAULT ARRAY[]::text[] NOT NULL
);


ALTER TABLE public."LiteLLM_ShadowEvalJob" OWNER TO litellm;

--
-- Name: LiteLLM_SkillsTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_SkillsTable" (
    skill_id text NOT NULL,
    display_title text,
    description text,
    instructions text,
    source text DEFAULT 'custom'::text NOT NULL,
    latest_version text,
    file_content bytea,
    file_name text,
    file_type text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by text
);


ALTER TABLE public."LiteLLM_SkillsTable" OWNER TO litellm;

--
-- Name: LiteLLM_SpendLogGuardrailIndex; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_SpendLogGuardrailIndex" (
    request_id text NOT NULL,
    guardrail_id text NOT NULL,
    policy_id text,
    start_time timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."LiteLLM_SpendLogGuardrailIndex" OWNER TO litellm;

--
-- Name: LiteLLM_SpendLogToolIndex; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_SpendLogToolIndex" (
    request_id text NOT NULL,
    tool_name text NOT NULL,
    start_time timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."LiteLLM_SpendLogToolIndex" OWNER TO litellm;

--
-- Name: LiteLLM_TagTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_TagTable" (
    tag_name text NOT NULL,
    description text,
    models text[],
    model_info jsonb,
    spend double precision DEFAULT 0.0 NOT NULL,
    budget_id text,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."LiteLLM_TagTable" OWNER TO litellm;

--
-- Name: LiteLLM_TeamMembership; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_TeamMembership" (
    user_id text NOT NULL,
    team_id text NOT NULL,
    spend double precision DEFAULT 0.0 NOT NULL,
    budget_id text,
    total_spend double precision DEFAULT 0.0 NOT NULL
);


ALTER TABLE public."LiteLLM_TeamMembership" OWNER TO litellm;

--
-- Name: LiteLLM_TeamTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_TeamTable" (
    team_id text NOT NULL,
    team_alias text,
    organization_id text,
    admins text[],
    members text[],
    members_with_roles jsonb DEFAULT '{}'::jsonb NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    max_budget double precision,
    spend double precision DEFAULT 0.0 NOT NULL,
    models text[],
    max_parallel_requests integer,
    tpm_limit bigint,
    rpm_limit bigint,
    budget_duration text,
    budget_reset_at timestamp(3) without time zone,
    blocked boolean DEFAULT false NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    model_spend jsonb DEFAULT '{}'::jsonb NOT NULL,
    model_max_budget jsonb DEFAULT '{}'::jsonb NOT NULL,
    model_id integer,
    team_member_permissions text[] DEFAULT ARRAY[]::text[],
    object_permission_id text,
    router_settings jsonb DEFAULT '{}'::jsonb,
    policies text[] DEFAULT ARRAY[]::text[],
    allow_team_guardrail_config boolean DEFAULT false NOT NULL,
    soft_budget double precision,
    access_group_ids text[] DEFAULT ARRAY[]::text[],
    budget_limits jsonb,
    default_team_member_models text[] DEFAULT ARRAY[]::text[],
    tpd_limit bigint
);


ALTER TABLE public."LiteLLM_TeamTable" OWNER TO litellm;

--
-- Name: LiteLLM_ToolTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_ToolTable" (
    tool_id text NOT NULL,
    tool_name text NOT NULL,
    origin text,
    input_policy text DEFAULT 'untrusted'::text NOT NULL,
    call_count integer DEFAULT 0 NOT NULL,
    assignments jsonb DEFAULT '{}'::jsonb,
    key_hash text,
    team_id text,
    key_alias text,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by text,
    output_policy text DEFAULT 'untrusted'::text NOT NULL,
    user_agent text,
    last_used_at timestamp(3) without time zone
);


ALTER TABLE public."LiteLLM_ToolTable" OWNER TO litellm;

--
-- Name: LiteLLM_UISettings; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_UISettings" (
    id text DEFAULT 'ui_settings'::text NOT NULL,
    ui_settings jsonb NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."LiteLLM_UISettings" OWNER TO litellm;

--
-- Name: LiteLLM_UserNotifications; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_UserNotifications" (
    request_id text NOT NULL,
    user_id text NOT NULL,
    models text[],
    justification text NOT NULL,
    status text NOT NULL
);


ALTER TABLE public."LiteLLM_UserNotifications" OWNER TO litellm;

--
-- Name: LiteLLM_UserTable; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_UserTable" (
    user_id text NOT NULL,
    user_alias text,
    team_id text,
    sso_user_id text,
    organization_id text,
    password text,
    teams text[] DEFAULT ARRAY[]::text[],
    user_role text,
    max_budget double precision,
    spend double precision DEFAULT 0.0 NOT NULL,
    user_email text,
    models text[],
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    max_parallel_requests integer,
    tpm_limit bigint,
    rpm_limit bigint,
    budget_duration text,
    budget_reset_at timestamp(3) without time zone,
    allowed_cache_controls text[] DEFAULT ARRAY[]::text[],
    model_spend jsonb DEFAULT '{}'::jsonb NOT NULL,
    model_max_budget jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP,
    object_permission_id text,
    policies text[] DEFAULT ARRAY[]::text[],
    password_reset_required boolean,
    last_breach_check_at timestamp(3) without time zone
);


ALTER TABLE public."LiteLLM_UserTable" OWNER TO litellm;

--
-- Name: LiteLLM_VerificationTokenView; Type: VIEW; Schema: public; Owner: litellm
--

CREATE VIEW public."LiteLLM_VerificationTokenView" AS
 SELECT v.token,
    v.key_name,
    v.key_alias,
    v.soft_budget_cooldown,
    v.spend,
    v.expires,
    v.models,
    v.aliases,
    v.config,
    v.user_id,
    v.team_id,
    v.permissions,
    v.max_parallel_requests,
    v.metadata,
    v.blocked,
    v.tpm_limit,
    v.rpm_limit,
    v.max_budget,
    v.budget_duration,
    v.budget_reset_at,
    v.allowed_cache_controls,
    v.model_spend,
    v.model_max_budget,
    v.budget_id,
    v.organization_id,
    v.created_at,
    v.created_by,
    v.updated_at,
    v.updated_by,
    v.allowed_routes,
    v.object_permission_id,
    v.auto_rotate,
    v.key_rotation_at,
    v.last_rotation_at,
    v.rotation_count,
    v.rotation_interval,
    v.project_id,
    v.router_settings,
    v.policies,
    v.access_group_ids,
    v.last_active,
    v.agent_id,
    v.budget_limits,
    v.budget_fallbacks,
    v.key_type,
    v.settings_updated_at,
    v.tpd_limit,
    v.total_spend,
    t.spend AS team_spend,
    t.max_budget AS team_max_budget,
    t.model_max_budget AS team_model_max_budget,
    t.tpm_limit AS team_tpm_limit,
    t.rpm_limit AS team_rpm_limit,
    t.tpd_limit AS team_tpd_limit,
    p.project_alias
   FROM ((public."LiteLLM_VerificationToken" v
     LEFT JOIN public."LiteLLM_TeamTable" t ON ((v.team_id = t.team_id)))
     LEFT JOIN public."LiteLLM_ProjectTable" p ON ((v.project_id = p.project_id)));


ALTER VIEW public."LiteLLM_VerificationTokenView" OWNER TO litellm;

--
-- Name: LiteLLM_VerifiedSubject; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_VerifiedSubject" (
    subject_id text NOT NULL,
    issuer text NOT NULL,
    tenant_id text NOT NULL,
    oid text NOT NULL,
    kind text DEFAULT 'human'::text NOT NULL,
    user_id text,
    verified_via text DEFAULT 'sso_interactive'::text NOT NULL,
    verified_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."LiteLLM_VerifiedSubject" OWNER TO litellm;

--
-- Name: LiteLLM_WorkflowEvent; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_WorkflowEvent" (
    event_id text NOT NULL,
    run_id text NOT NULL,
    event_type text NOT NULL,
    step_name text NOT NULL,
    sequence_number integer NOT NULL,
    data jsonb,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."LiteLLM_WorkflowEvent" OWNER TO litellm;

--
-- Name: LiteLLM_WorkflowMessage; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_WorkflowMessage" (
    message_id text NOT NULL,
    run_id text NOT NULL,
    role text NOT NULL,
    content text NOT NULL,
    sequence_number integer NOT NULL,
    session_id text,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."LiteLLM_WorkflowMessage" OWNER TO litellm;

--
-- Name: LiteLLM_WorkflowRun; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public."LiteLLM_WorkflowRun" (
    run_id text NOT NULL,
    session_id text NOT NULL,
    workflow_type text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    created_by text,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL,
    input jsonb,
    output jsonb,
    metadata jsonb
);


ALTER TABLE public."LiteLLM_WorkflowRun" OWNER TO litellm;

--
-- Name: MonthlyGlobalSpend; Type: VIEW; Schema: public; Owner: litellm
--

CREATE VIEW public."MonthlyGlobalSpend" AS
 SELECT date("startTime") AS date,
    sum(spend) AS spend
   FROM public."LiteLLM_SpendLogs"
  WHERE ("startTime" >= (CURRENT_DATE - '30 days'::interval))
  GROUP BY (date("startTime"));


ALTER VIEW public."MonthlyGlobalSpend" OWNER TO litellm;

--
-- Name: MonthlyGlobalSpendPerKey; Type: VIEW; Schema: public; Owner: litellm
--

CREATE VIEW public."MonthlyGlobalSpendPerKey" AS
 SELECT date("startTime") AS date,
    sum(spend) AS spend,
    api_key
   FROM public."LiteLLM_SpendLogs"
  WHERE ("startTime" >= (CURRENT_DATE - '30 days'::interval))
  GROUP BY (date("startTime")), api_key;


ALTER VIEW public."MonthlyGlobalSpendPerKey" OWNER TO litellm;

--
-- Name: MonthlyGlobalSpendPerUserPerKey; Type: VIEW; Schema: public; Owner: litellm
--

CREATE VIEW public."MonthlyGlobalSpendPerUserPerKey" AS
 SELECT date("startTime") AS date,
    sum(spend) AS spend,
    api_key,
    "user"
   FROM public."LiteLLM_SpendLogs"
  WHERE ("startTime" >= (CURRENT_DATE - '30 days'::interval))
  GROUP BY (date("startTime")), "user", api_key;


ALTER VIEW public."MonthlyGlobalSpendPerUserPerKey" OWNER TO litellm;

--
-- Name: _prisma_migrations; Type: TABLE; Schema: public; Owner: litellm
--

CREATE TABLE public._prisma_migrations (
    id character varying(36) NOT NULL,
    checksum character varying(64) NOT NULL,
    finished_at timestamp with time zone,
    migration_name character varying(255) NOT NULL,
    logs text,
    rolled_back_at timestamp with time zone,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    applied_steps_count integer DEFAULT 0 NOT NULL
);


ALTER TABLE public._prisma_migrations OWNER TO litellm;

--
-- Name: LiteLLM_ModelTable id; Type: DEFAULT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ModelTable" ALTER COLUMN id SET DEFAULT nextval('public."LiteLLM_ModelTable_id_seq"'::regclass);


--
-- Data for Name: LiteLLM_AccessGroupTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_AccessGroupTable" (access_group_id, access_group_name, description, access_mcp_server_ids, access_agent_ids, assigned_team_ids, assigned_key_ids, created_at, created_by, updated_at, updated_by, access_model_names) FROM stdin;
\.


--
-- Data for Name: LiteLLM_AdaptiveRouterSession; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_AdaptiveRouterSession" (session_id, router_name, model_name, classified_type, misalignment_count, stagnation_count, disengagement_count, satisfaction_count, failure_count, loop_count, exhaustion_count, last_user_content, last_assistant_content, tool_call_history, pending_tool_calls, turn_count, last_processed_turn, clean_credit_awarded, terminal_status, last_activity_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_AdaptiveRouterState; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_AdaptiveRouterState" (router_name, request_type, model_name, alpha, beta, total_samples, last_updated_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_AgentIdentity; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_AgentIdentity" (agent_id, active, provider, issuer, tenant_id, client_id, service_principal_id, required_roles, required_scopes, revision, last_authenticated_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_AgentsTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_AgentsTable" (agent_id, agent_name, litellm_params, agent_card_params, created_at, created_by, updated_at, updated_by, agent_access_groups, object_permission_id, spend, static_headers, extra_headers, tpm_limit, rpm_limit, session_tpm_limit, session_rpm_limit, access_group_ids, enabled, execution_mode, identity_managed, kill_switch) FROM stdin;
\.


--
-- Data for Name: LiteLLM_AuditLog; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_AuditLog" (id, updated_at, changed_by, changed_by_api_key, action, table_name, object_id, before_value, updated_values) FROM stdin;
\.


--
-- Data for Name: LiteLLM_AutoRouterBaselineComparison; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_AutoRouterBaselineComparison" (scope, api_key, session_id, router_name, initial_equivalent, revision, published_revision, history, attempted_at, retired, updated_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_AutoRouterBaselineObservation; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_AutoRouterBaselineObservation" (request_id, scope, started_at, revision, data, publication, conflicted) FROM stdin;
\.


--
-- Data for Name: LiteLLM_AutoRouterSession; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_AutoRouterSession" (api_key, session_id, router_name, router_type, first_turn_at, last_turn_at, last_model, models, turns, unordered_turns, covered_turns, cache_hits, same_model_turns, same_model_hits, first_visit_turns, first_visit_hits, return_turns, return_hits, return_expired_misses, return_within_ttl_misses, ttl_5m_turns, ttl_1h_turns, total_tokens, spend, saved_spend, tier_turns, classifier_cost, classifier_cost_recorded_turns, baseline_models, savings_estimated_turns, savings_estimated_actual_spend, savings_estimated_saved_spend, savings_estimated_baseline_models) FROM stdin;
\.


--
-- Data for Name: LiteLLM_AutoRouterUserSession; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_AutoRouterUserSession" (user_id, api_key, session_id, router_name, router_type, first_turn_at, last_turn_at, last_model, models, turns, unordered_turns, covered_turns, cache_hits, same_model_turns, same_model_hits, first_visit_turns, first_visit_hits, return_turns, return_hits, return_expired_misses, return_within_ttl_misses, ttl_5m_turns, ttl_1h_turns, total_tokens, spend, saved_spend, savings_estimated_turns, savings_estimated_actual_spend, savings_estimated_saved_spend, savings_estimated_baseline_models, classifier_cost, classifier_cost_recorded_turns, tier_turns, baseline_models) FROM stdin;
\.


--
-- Data for Name: LiteLLM_BudgetTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_BudgetTable" (budget_id, max_budget, soft_budget, max_parallel_requests, tpm_limit, rpm_limit, model_max_budget, budget_duration, budget_reset_at, created_at, created_by, updated_at, updated_by, allowed_models, tpd_limit, temp_budget_increase, temp_budget_expiry) FROM stdin;
\.


--
-- Data for Name: LiteLLM_BudgetWindowSpend; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_BudgetWindowSpend" (entity_type, entity_id, window_duration, window_start, spend, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_CacheConfig; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_CacheConfig" (id, cache_settings, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_ClaudeCodePluginTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_ClaudeCodePluginTable" (id, name, version, description, manifest_json, files_json, enabled, created_at, updated_at, created_by) FROM stdin;
\.


--
-- Data for Name: LiteLLM_Config; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_Config" (param_name, param_value, last_run_at, reload_revision) FROM stdin;
auto_router_tuning_baseline_v3	{}	\N	0
\.


--
-- Data for Name: LiteLLM_ConfigOverrides; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_ConfigOverrides" (config_type, config_value, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_CredentialsTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_CredentialsTable" (credential_id, credential_name, credential_values, credential_info, created_at, created_by, updated_at, updated_by) FROM stdin;
\.


--
-- Data for Name: LiteLLM_CronJob; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_CronJob" (cronjob_id, pod_id, status, last_updated, ttl) FROM stdin;
\.


--
-- Data for Name: LiteLLM_DailyAgentSpend; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_DailyAgentSpend" (id, agent_id, date, api_key, model, model_group, custom_llm_provider, mcp_namespaced_tool_name, prompt_tokens, completion_tokens, cache_read_input_tokens, cache_creation_input_tokens, spend, api_requests, successful_requests, failed_requests, created_at, updated_at, endpoint, compression_saved_tokens, compression_savings_spend, prompt_caching_savings_spend, autorouter_savings_spend, gateway_injected_caching_savings_spend, total_response_time_ms, timed_requests) FROM stdin;
\.


--
-- Data for Name: LiteLLM_DailyEndUserSpend; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_DailyEndUserSpend" (id, end_user_id, date, api_key, model, model_group, custom_llm_provider, mcp_namespaced_tool_name, prompt_tokens, completion_tokens, cache_read_input_tokens, cache_creation_input_tokens, spend, api_requests, successful_requests, failed_requests, created_at, updated_at, endpoint, compression_saved_tokens, compression_savings_spend, prompt_caching_savings_spend, autorouter_savings_spend, gateway_injected_caching_savings_spend, total_response_time_ms, timed_requests) FROM stdin;
\.


--
-- Data for Name: LiteLLM_DailyGatewayRequests; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_DailyGatewayRequests" (date, category, route, successful_requests, failed_requests, created_at, updated_at) FROM stdin;
2026-10-15	llm	/v1/messages	27	0	2026-10-15 14:58:43.707	2026-10-15 15:05:42.771
2026-10-15	llm	/chat/completions	2	1	2026-10-15 15:06:15.724	2026-10-15 15:14:57.045
\.


--
-- Data for Name: LiteLLM_DailyGlobalSpend; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_DailyGlobalSpend" (id, date, model, model_group, custom_llm_provider, mcp_namespaced_tool_name, endpoint, prompt_tokens, completion_tokens, cache_read_input_tokens, cache_creation_input_tokens, compression_saved_tokens, compression_savings_spend, prompt_caching_savings_spend, gateway_injected_caching_savings_spend, autorouter_savings_spend, spend, api_requests, successful_requests, failed_requests, total_response_time_ms, timed_requests, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_DailyGuardrailMetrics; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_DailyGuardrailMetrics" (guardrail_id, date, requests_evaluated, passed_count, blocked_count, flagged_count, avg_score, avg_latency_ms, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_DailyGuardrailUsageUnits; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_DailyGuardrailUsageUnits" (guardrail_id, date, team_id, api_key, usage_unit, units, created_at, updated_at, cost, untracked_units) FROM stdin;
\.


--
-- Data for Name: LiteLLM_DailyModelUsage; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_DailyModelUsage" (date, model_group, model, custom_llm_provider, task_type, spend, prompt_tokens, completion_tokens, request_count, successful_requests, failed_requests, created_at, updated_at) FROM stdin;
2026-10-15	bank-primary	anthropic/claude-haiku-5-5	anthropic	uncategorized	0.0018466	12231	1247	28	27	1	2026-10-15 14:58:42.131	2026-10-15 15:06:01.893
2026-10-15	bank-fallback	anthropic/claude-opus-5-5	anthropic	uncategorized	0.005052	28	247	2	2	0	2026-10-15 15:14:42.866	2026-10-15 15:14:48.167
2026-10-15	unknown	unknown	unknown	uncategorized	0	0	0	69	0	69	2026-10-15 12:25:30.587	2026-10-15 14:22:39.829
\.


--
-- Data for Name: LiteLLM_DailyOrganizationSpend; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_DailyOrganizationSpend" (id, organization_id, date, api_key, model, model_group, custom_llm_provider, mcp_namespaced_tool_name, prompt_tokens, completion_tokens, cache_read_input_tokens, cache_creation_input_tokens, spend, api_requests, successful_requests, failed_requests, created_at, updated_at, endpoint, compression_saved_tokens, compression_savings_spend, prompt_caching_savings_spend, autorouter_savings_spend, gateway_injected_caching_savings_spend, total_response_time_ms, timed_requests) FROM stdin;
\.


--
-- Data for Name: LiteLLM_DailyPolicyMetrics; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_DailyPolicyMetrics" (policy_id, date, requests_evaluated, passed_count, blocked_count, flagged_count, avg_score, avg_latency_ms, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_DailyTagSpend; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_DailyTagSpend" (id, tag, date, api_key, model, model_group, custom_llm_provider, prompt_tokens, completion_tokens, cache_read_input_tokens, cache_creation_input_tokens, spend, api_requests, successful_requests, failed_requests, created_at, updated_at, mcp_namespaced_tool_name, request_id, endpoint, compression_saved_tokens, compression_savings_spend, prompt_caching_savings_spend, autorouter_savings_spend, gateway_injected_caching_savings_spend, total_response_time_ms, timed_requests) FROM stdin;
8c49f426-e8bd-4cfd-b4da-450833b434f9	User-Agent: Anthropic	2026-10-15	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	anthropic/claude-haiku-5-5	bank-primary	anthropic	9116	924	0	0	0.0013736	20	20	0	2026-10-15 14:58:58.707	2026-10-15 15:05:56.771		msg_011Cg4EFUQHTRjDz7uirEoTP		0	0	0	0	0	24246	19
8db7f65e-a33c-44c4-a89f-0ac19e67d2ec	User-Agent: Anthropic/Python 1.13.0	2026-10-15	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	anthropic/claude-haiku-5-5	bank-primary	anthropic	9116	924	0	0	0.0013736	20	20	0	2026-10-15 14:58:58.707	2026-10-15 15:05:56.771		msg_011Cg4EFUQHTRjDz7uirEoTP		0	0	0	0	0	24246	19
11e7dad3-785f-48e7-8c96-c70b020cd2be	bank-agent	2026-10-15	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	anthropic/claude-haiku-5-5	bank-primary	anthropic	9116	924	0	0	0.0013736	20	20	0	2026-10-15 14:58:58.707	2026-10-15 15:05:56.771		msg_011Cg4EFUQHTRjDz7uirEoTP		0	0	0	0	0	24246	19
512f6f03-fa74-45d3-aeab-8f7e365bf94e	User-Agent: curl	2026-10-15	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	anthropic/claude-haiku-5-5	bank-primary	anthropic	0	0	0	0	0	1	0	1	2026-10-15 15:06:07.726	2026-10-15 15:06:07.726		9c92e5c1-8b21-4b9a-8cb7-3adcbd3aac1d	/chat/completions	0	0	0	0	0	0	0
2e7277f7-24ba-4ffd-a7e8-4b4de81a1285	User-Agent: curl/8.5.0	2026-10-15	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	anthropic/claude-haiku-5-5	bank-primary	anthropic	0	0	0	0	0	1	0	1	2026-10-15 15:06:07.726	2026-10-15 15:06:07.726		9c92e5c1-8b21-4b9a-8cb7-3adcbd3aac1d	/chat/completions	0	0	0	0	0	0	0
3e91da67-cf54-4169-835b-716c2ac7aa2c	User-Agent: curl	2026-10-15	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	anthropic/claude-opus-5-5	bank-fallback	anthropic	28	247	0	0	0.005052	2	2	0	2026-10-15 15:14:43.041	2026-10-15 15:15:10.043		chatcmpl-99da3d8f-3c92-40a7-bde5-9a2c82ba2da9	/chat/completions	0	0	0	0	0	4966	2
537f0d90-65ae-4436-91aa-73f4063708fe	User-Agent: curl/8.5.0	2026-10-15	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	anthropic/claude-opus-5-5	bank-fallback	anthropic	28	247	0	0	0.005052	2	2	0	2026-10-15 15:14:43.041	2026-10-15 15:15:10.043		chatcmpl-99da3d8f-3c92-40a7-bde5-9a2c82ba2da9	/chat/completions	0	0	0	0	0	4966	2
\.


--
-- Data for Name: LiteLLM_DailyTeamSpend; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_DailyTeamSpend" (id, team_id, date, api_key, model, model_group, custom_llm_provider, prompt_tokens, completion_tokens, spend, api_requests, successful_requests, failed_requests, created_at, updated_at, cache_creation_input_tokens, cache_read_input_tokens, mcp_namespaced_tool_name, endpoint, ptu_flat_cost, compression_saved_tokens, compression_savings_spend, prompt_caching_savings_spend, autorouter_savings_spend, gateway_injected_caching_savings_spend, total_response_time_ms, timed_requests) FROM stdin;
a1284e99-6d88-426f-9404-df7545247b37		2026-10-15	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a				0	0	0	69	0	69	2026-10-15 12:25:43.224	2026-10-15 14:22:51.765	0	0			0	0	0	0	0	0	0	0
c135cb1e-7325-4c23-839d-a013627c784b	41649881-c262-402e-9754-b5c44ce947a4	2026-10-15	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	anthropic/claude-haiku-5-5	bank-primary	anthropic	12231	1247	0.0018465999999999999	27	27	0	2026-10-15 14:58:52.496	2026-10-15 15:05:41.984	0	0			0	0	0	0	0	0	32660	26
53a02931-d11b-4c83-92dd-891373030af0	41649881-c262-402e-9754-b5c44ce947a4	2026-10-15	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	anthropic/claude-haiku-5-5	bank-primary	anthropic	0	0	0	1	0	1	2026-10-15 15:06:07.872	2026-10-15 15:06:07.872	0	0		/chat/completions	0	0	0	0	0	0	0	0
bc04fcf6-09d3-4648-aa34-75c5e71e9c77	41649881-c262-402e-9754-b5c44ce947a4	2026-10-15	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	anthropic/claude-opus-5-5	bank-fallback	anthropic	28	247	0.005052000000000001	2	2	0	2026-10-15 15:14:53.249	2026-10-15 15:14:53.249	0	0		/chat/completions	0	0	0	0	0	0	4966	2
\.


--
-- Data for Name: LiteLLM_DailyToolSpend; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_DailyToolSpend" (date, tool_name, spend, total_tokens, request_count, created_at, updated_at) FROM stdin;
2026-10-15	get_account_balance	0.0001482	1026	2	2026-10-15 14:58:51.921	2026-10-15 14:59:31.103
\.


--
-- Data for Name: LiteLLM_DailyUserSpend; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_DailyUserSpend" (id, user_id, date, api_key, model, model_group, custom_llm_provider, prompt_tokens, completion_tokens, spend, created_at, updated_at, api_requests, failed_requests, successful_requests, cache_creation_input_tokens, cache_read_input_tokens, mcp_namespaced_tool_name, endpoint, compression_saved_tokens, compression_savings_spend, prompt_caching_savings_spend, autorouter_savings_spend, gateway_injected_caching_savings_spend, total_response_time_ms, timed_requests) FROM stdin;
4d9854d2-1a43-40b8-a4dd-fdca49e5ce3a		2026-10-15	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a				0	0	0	2026-10-15 12:25:43.196	2026-10-15 14:22:51.709	69	69	0	0	0			0	0	0	0	0	0	0
849b7a75-f468-48cd-b993-40bde04c726a	default_user_id	2026-10-15	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	anthropic/claude-haiku-5-5	bank-primary	anthropic	12231	1247	0.0018465999999999999	2026-10-15 14:58:52.41	2026-10-15 15:05:41.944	27	0	27	0	0			0	0	0	0	0	32660	26
1838d47f-ef47-492b-be6c-a70040d10431	default_user_id	2026-10-15	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	anthropic/claude-haiku-5-5	bank-primary	anthropic	0	0	0	2026-10-15 15:06:07.768	2026-10-15 15:06:07.768	1	1	0	0	0		/chat/completions	0	0	0	0	0	0	0
5d4337ef-c74b-445d-89d2-85ef0c057ccb	default_user_id	2026-10-15	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	anthropic/claude-opus-5-5	bank-fallback	anthropic	28	247	0.005052000000000001	2026-10-15 15:14:53.206	2026-10-15 15:14:53.206	2	0	2	0	0		/chat/completions	0	0	0	0	0	4966	2
\.


--
-- Data for Name: LiteLLM_DeletedTeamTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_DeletedTeamTable" (id, team_id, team_alias, organization_id, object_permission_id, admins, members, members_with_roles, metadata, max_budget, spend, models, max_parallel_requests, tpm_limit, rpm_limit, budget_duration, budget_reset_at, blocked, model_spend, model_max_budget, team_member_permissions, model_id, created_at, updated_at, deleted_at, deleted_by, deleted_by_api_key, litellm_changed_by, router_settings, policies, allow_team_guardrail_config, soft_budget, access_group_ids, tpd_limit) FROM stdin;
\.


--
-- Data for Name: LiteLLM_DeletedVerificationToken; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_DeletedVerificationToken" (id, token, key_name, key_alias, soft_budget_cooldown, spend, expires, models, aliases, config, user_id, team_id, permissions, max_parallel_requests, metadata, blocked, tpm_limit, rpm_limit, max_budget, budget_duration, budget_reset_at, allowed_cache_controls, allowed_routes, model_spend, model_max_budget, budget_id, organization_id, object_permission_id, created_at, created_by, updated_at, updated_by, rotation_count, auto_rotate, rotation_interval, last_rotation_at, key_rotation_at, deleted_at, deleted_by, deleted_by_api_key, litellm_changed_by, router_settings, policies, access_group_ids, last_active, project_id, agent_id, budget_fallbacks, key_type, settings_updated_at, tpd_limit, total_spend) FROM stdin;
\.


--
-- Data for Name: LiteLLM_DeprecatedVerificationToken; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_DeprecatedVerificationToken" (id, token, active_token_id, revoke_at, created_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_EndUserTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_EndUserTable" (user_id, alias, spend, allowed_model_region, default_model, budget_id, blocked, object_permission_id) FROM stdin;
\.


--
-- Data for Name: LiteLLM_ErrorLogs; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_ErrorLogs" (request_id, "startTime", "endTime", api_base, model_group, litellm_model_name, model_id, request_kwargs, exception_type, exception_string, status_code) FROM stdin;
\.


--
-- Data for Name: LiteLLM_GuardrailsTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_GuardrailsTable" (guardrail_id, guardrail_name, litellm_params, guardrail_info, created_at, updated_at, team_id, reviewed_at, status, submitted_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_HealthCheckTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_HealthCheckTable" (health_check_id, model_name, model_id, status, healthy_count, unhealthy_count, error_message, response_time_ms, details, checked_by, checked_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_InvitationLink; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_InvitationLink" (id, user_id, is_accepted, accepted_at, expires_at, created_at, created_by, updated_at, updated_by) FROM stdin;
\.


--
-- Data for Name: LiteLLM_JWTKeyMapping; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_JWTKeyMapping" (id, jwt_claim_name, jwt_claim_value, token, description, is_active, created_at, created_by, updated_at, updated_by, jwt_issuer) FROM stdin;
\.


--
-- Data for Name: LiteLLM_Lens; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_Lens" (id, version, data) FROM stdin;
\.


--
-- Data for Name: LiteLLM_LensRun; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_LensRun" (id, lens_id, created_at, data) FROM stdin;
\.


--
-- Data for Name: LiteLLM_LensWorker; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_LensWorker" (id, token_hash, data) FROM stdin;
\.


--
-- Data for Name: LiteLLM_MCPServerOAuthClient; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_MCPServerOAuthClient" (server_id, credentials, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_MCPServerTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_MCPServerTable" (server_id, server_name, description, url, transport, auth_type, created_at, created_by, updated_at, updated_by, status, last_health_check, health_check_error, mcp_info, args, command, env, mcp_access_groups, alias, allowed_tools, extra_headers, static_headers, credentials, authorization_url, registration_url, token_url, allow_all_keys, available_on_public_internet, spec_path, byok_api_key_help_url, byok_description, is_byok, tool_name_to_description, tool_name_to_display_name, approval_status, submitted_by, submitted_at, reviewed_at, review_notes, source_url, instructions, delegate_auth_to_upstream, env_vars, oauth_passthrough, oauth2_flow, timeout, max_concurrent_requests, token_exchange_endpoint, audience, subject_token_type, token_exchange_profile, dcr_bridge, issuer, per_server_oauth_discovery, pinned_tools) FROM stdin;
\.


--
-- Data for Name: LiteLLM_MCPToolsetTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_MCPToolsetTable" (toolset_id, toolset_name, description, tools, created_at, created_by, updated_at, updated_by) FROM stdin;
\.


--
-- Data for Name: LiteLLM_MCPUserCredentials; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_MCPUserCredentials" (id, user_id, server_id, credential_b64, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_MCPUserEnvVars; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_MCPUserEnvVars" (id, user_id, server_id, values_b64, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_ManagedFileContentTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_ManagedFileContentTable" (id, content, created_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_ManagedFileTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_ManagedFileTable" (id, unified_file_id, file_object, model_mappings, created_at, updated_at, created_by, flat_model_file_ids, updated_by, storage_backend, storage_url, team_id) FROM stdin;
\.


--
-- Data for Name: LiteLLM_ManagedObjectTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_ManagedObjectTable" (id, unified_object_id, model_object_id, file_object, file_purpose, created_at, created_by, updated_at, updated_by, status, batch_processed, team_id, api_key, request_tags, org_id) FROM stdin;
\.


--
-- Data for Name: LiteLLM_ManagedVectorStoreIndexTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_ManagedVectorStoreIndexTable" (id, index_name, litellm_params, index_info, created_at, created_by, updated_at, updated_by) FROM stdin;
\.


--
-- Data for Name: LiteLLM_ManagedVectorStoreTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_ManagedVectorStoreTable" (id, unified_resource_id, resource_object, model_mappings, flat_model_resource_ids, storage_backend, storage_url, created_at, created_by, updated_at, updated_by, team_id) FROM stdin;
\.


--
-- Data for Name: LiteLLM_ManagedVectorStoresTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_ManagedVectorStoresTable" (vector_store_id, custom_llm_provider, vector_store_name, vector_store_description, vector_store_metadata, created_at, updated_at, litellm_credential_name, litellm_params, team_id, user_id) FROM stdin;
\.


--
-- Data for Name: LiteLLM_MemoryTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_MemoryTable" (memory_id, key, value, metadata, user_id, team_id, created_at, created_by, updated_at, updated_by) FROM stdin;
\.


--
-- Data for Name: LiteLLM_ModelAccessGroupBudgetTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_ModelAccessGroupBudgetTable" (access_group_name, spend, budget_id, created_at, created_by, updated_at, updated_by) FROM stdin;
\.


--
-- Data for Name: LiteLLM_ModelTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_ModelTable" (id, aliases, created_at, created_by, updated_at, updated_by) FROM stdin;
\.


--
-- Data for Name: LiteLLM_ObjectPermissionTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_ObjectPermissionTable" (object_permission_id, mcp_servers, vector_stores, mcp_access_groups, mcp_tool_permissions, agents, agent_access_groups, blocked_tools, models, mcp_toolsets, search_tools, mcp_tool_search_enabled, skills) FROM stdin;
\.


--
-- Data for Name: LiteLLM_OrganizationMembership; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_OrganizationMembership" (user_id, organization_id, user_role, spend, budget_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_OrganizationTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_OrganizationTable" (organization_id, organization_alias, budget_id, metadata, models, spend, model_spend, created_at, created_by, updated_at, updated_by, object_permission_id) FROM stdin;
\.


--
-- Data for Name: LiteLLM_PolicyAttachmentTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_PolicyAttachmentTable" (attachment_id, policy_name, scope, teams, keys, models, created_at, created_by, updated_at, updated_by, tags, priority, is_default) FROM stdin;
\.


--
-- Data for Name: LiteLLM_PolicyTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_PolicyTable" (policy_id, policy_name, inherit, description, guardrails_add, guardrails_remove, condition, created_at, created_by, updated_at, updated_by, pipeline, is_latest, parent_version_id, production_at, published_at, version_number, version_status) FROM stdin;
\.


--
-- Data for Name: LiteLLM_ProjectTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_ProjectTable" (project_id, project_alias, team_id, budget_id, metadata, models, spend, model_spend, blocked, object_permission_id, created_at, created_by, updated_at, updated_by, description, model_rpm_limit, model_tpm_limit) FROM stdin;
\.


--
-- Data for Name: LiteLLM_PromptTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_PromptTable" (id, prompt_id, litellm_params, prompt_info, created_at, updated_at, version, environment, created_by) FROM stdin;
\.


--
-- Data for Name: LiteLLM_ProxyModelTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_ProxyModelTable" (model_id, model_name, litellm_params, model_info, created_at, created_by, updated_at, updated_by, blocked) FROM stdin;
\.


--
-- Data for Name: LiteLLM_ProxyWorkerHeartbeat; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_ProxyWorkerHeartbeat" (worker_id, hostname, started_at, last_heartbeat_at) FROM stdin;
0f356326-d982-41de-8844-712c93ada464	litellm-7c58cf95fc-qnhjt	2026-10-15 15:12:28.872	2026-10-15 15:15:22.042
b0e7d7ad-4e17-4de7-9aa0-a5403b83b1a6	litellm-7c58cf95fc-kg4wf	2026-10-15 15:12:53.827	2026-10-15 15:15:26.856
\.


--
-- Data for Name: LiteLLM_RetiredAgent; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_RetiredAgent" (original_agent_id, retired_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_RetiredAgentIdentity; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_RetiredAgentIdentity" (binding_id, agent_id, provider, issuer, tenant_id, client_id) FROM stdin;
\.


--
-- Data for Name: LiteLLM_SSOConfig; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_SSOConfig" (id, sso_settings, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_SSOIdentityAssertion; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_SSOIdentityAssertion" (user_id, assertion_b64, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_SearchToolsTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_SearchToolsTable" (search_tool_id, search_tool_name, litellm_params, search_tool_info, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_ShadowEvalAttempt; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_ShadowEvalAttempt" (id, job_id, request_id, outcome, tier, real_model, shadow_model, confidence, judge_cost, error, created_at, shadow_cost, real_cost, real_classifier_cost, shadow_classifier_cost, real_cache_hit, router_name) FROM stdin;
\.


--
-- Data for Name: LiteLLM_ShadowEvalFunnel; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_ShadowEvalFunnel" (job_id, not_sampled, unjudgeable, shed, withheld) FROM stdin;
\.


--
-- Data for Name: LiteLLM_ShadowEvalJob; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_ShadowEvalJob" (id, target_id, router_name, judge_model, shadow_percentage, max_turns, created_at, created_by, ends_at, stopped_at, baseline_model, direction, group_id, stopped_by, max_budget, target_type, router_names, models) FROM stdin;
\.


--
-- Data for Name: LiteLLM_SkillsTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_SkillsTable" (skill_id, display_title, description, instructions, source, latest_version, file_content, file_name, file_type, metadata, created_at, created_by, updated_at, updated_by) FROM stdin;
\.


--
-- Data for Name: LiteLLM_SpendLogGuardrailIndex; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_SpendLogGuardrailIndex" (request_id, guardrail_id, policy_id, start_time) FROM stdin;
\.


--
-- Data for Name: LiteLLM_SpendLogToolIndex; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_SpendLogToolIndex" (request_id, tool_name, start_time) FROM stdin;
msg_011Cg4Djeeqhg96bhiFBRnVs	get_account_balance	2026-10-15 14:58:40.605
msg_011Cg4DncaQSV2uPSRdBvChy	get_account_balance	2026-10-15 14:59:21.643
\.


--
-- Data for Name: LiteLLM_SpendLogs; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_SpendLogs" (request_id, call_type, api_key, spend, total_tokens, prompt_tokens, completion_tokens, "startTime", "endTime", "completionStartTime", model, model_id, model_group, custom_llm_provider, api_base, "user", metadata, cache_hit, cache_key, request_tags, team_id, end_user, requester_ip_address, messages, response, proxy_server_request, session_id, status, mcp_namespaced_tool_name, organization_id, agent_id, request_duration_ms, created_at, updated_at, litellm_call_id, billing_agent_id) FROM stdin;
06123017-65ab-406a-ac2b-5c2cab9db4ca	/sso/get/ui_settings	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 12:25:30.452	2026-10-15 12:25:30.516	2026-10-15 12:25:30.516							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "06123017-65ab-406a-ac2b-5c2cab9db4ca", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	a9b85d29-dadb-47d0-8cb6-ac37eb81b83d	failure	\N		\N	64	2026-10-15 12:25:43.275	2026-10-15 12:25:43.275	06123017-65ab-406a-ac2b-5c2cab9db4ca	\N
0bfbf04c-60b4-4e21-a9e1-be86fc784914	/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 12:25:30.46	2026-10-15 12:25:30.588	2026-10-15 12:25:30.588							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "0bfbf04c-60b4-4e21-a9e1-be86fc784914", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	9303d9bb-81f8-4f10-b8e6-fadb2dd67fd1	failure	\N		\N	128	2026-10-15 12:25:43.275	2026-10-15 12:25:43.275	0bfbf04c-60b4-4e21-a9e1-be86fc784914	\N
6786c0c5-04d6-4b20-9696-e2dffecbbd13	/models	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 12:25:30.514	2026-10-15 12:25:30.612	2026-10-15 12:25:30.611							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "6786c0c5-04d6-4b20-9696-e2dffecbbd13", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	45393811-b902-4a70-a5f2-cbe321dcdf0d	failure	\N		\N	97	2026-10-15 12:25:43.275	2026-10-15 12:25:43.275	6786c0c5-04d6-4b20-9696-e2dffecbbd13	\N
21681d12-fd42-4793-87d1-213a6aaf2b8f	/models	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 12:25:30.646	2026-10-15 12:25:30.672	2026-10-15 12:25:30.672							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "21681d12-fd42-4793-87d1-213a6aaf2b8f", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	a56e7471-5597-41f2-97d3-d7e5e4de7a90	failure	\N		\N	26	2026-10-15 12:25:43.275	2026-10-15 12:25:43.275	21681d12-fd42-4793-87d1-213a6aaf2b8f	\N
msg_011Cg4E8BBVun81VMCkyAcjQ	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	6.45e-05	485	445	40	2026-10-15 15:03:46.145	2026-10-15 15:03:47.283	2026-10-15 15:03:47.282	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 485, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 40, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 40, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.0000645, "output_cost": 0.000019999999999999998, "service_tier": null, "original_cost": 0.0000645, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "d963ea88-54c0-4a4d-b4e1-2e082e038028", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.52", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 40, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 9.8979, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.52	{}	{}	{}	c5c39aa9-c418-4d32-af14-f4507dadeb35	success	\N		\N	1137	2026-10-15 15:03:50.404	2026-10-15 15:03:50.404	d963ea88-54c0-4a4d-b4e1-2e082e038028	\N
a1174745-91a3-4ca1-b845-f94d50c849c8	/key/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 12:25:30.651	2026-10-15 12:25:30.686	2026-10-15 12:25:30.685							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "a1174745-91a3-4ca1-b845-f94d50c849c8", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	14d84ee8-332d-4b58-ae61-5286c4b17788	failure	\N		\N	34	2026-10-15 12:25:43.275	2026-10-15 12:25:43.275	a1174745-91a3-4ca1-b845-f94d50c849c8	\N
8a85e417-cc3b-4004-afc0-b4b26054e561	/v2/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 12:25:30.656	2026-10-15 12:25:30.704	2026-10-15 12:25:30.703							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "8a85e417-cc3b-4004-afc0-b4b26054e561", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	12f768ad-df8f-439c-afc2-1fc8389dc39b	failure	\N		\N	47	2026-10-15 12:25:43.275	2026-10-15 12:25:43.275	8a85e417-cc3b-4004-afc0-b4b26054e561	\N
9973eb54-4b00-42ac-afc8-4ef8545ec3d0	/get/user_banner	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 12:25:30.666	2026-10-15 12:25:30.715	2026-10-15 12:25:30.715							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "9973eb54-4b00-42ac-afc8-4ef8545ec3d0", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	f5cb8b73-a32f-4397-a786-a0eb255deaa9	failure	\N		\N	49	2026-10-15 12:25:43.275	2026-10-15 12:25:43.275	9973eb54-4b00-42ac-afc8-4ef8545ec3d0	\N
7e82619b-7023-4dda-a8ef-7f1a16d0632f	/get/latest_release_info	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 12:25:30.733	2026-10-15 12:25:30.755	2026-10-15 12:25:30.754							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "7e82619b-7023-4dda-a8ef-7f1a16d0632f", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	e15118a3-3bfc-4198-a8a0-4186ab22ab0e	failure	\N		\N	22	2026-10-15 12:25:43.275	2026-10-15 12:25:43.275	7e82619b-7023-4dda-a8ef-7f1a16d0632f	\N
msg_011Cg4E8Kst2mbnBdn8kafRt	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	7.099999999999999e-05	498	445	53	2026-10-15 15:03:48.309	2026-10-15 15:03:49.517	2026-10-15 15:03:49.516	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 498, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 53, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 53, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.00007099999999999999, "output_cost": 0.0000265, "service_tier": null, "original_cost": 0.00007099999999999999, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "13d4859f-2006-43eb-8a29-92059f0e10cc", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.51", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 53, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 13.1979, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.51	{}	{}	{}	cbbd87b9-d4de-4f65-bcaa-818165c16daa	success	\N		\N	1208	2026-10-15 15:03:50.404	2026-10-15 15:03:50.404	13d4859f-2006-43eb-8a29-92059f0e10cc	\N
193821b4-2d6b-4be2-a288-27a1d8c1bf3c	/v2/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 12:25:30.794	2026-10-15 12:25:30.825	2026-10-15 12:25:30.824							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "193821b4-2d6b-4be2-a288-27a1d8c1bf3c", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	b5edae25-10b6-45e0-bddc-d70fff7b26ae	failure	\N		\N	30	2026-10-15 12:25:43.275	2026-10-15 12:25:43.275	193821b4-2d6b-4be2-a288-27a1d8c1bf3c	\N
1d60f641-2989-412e-8fba-0a0eed2ee385	/sso/get/ui_settings	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 12:25:31.549	2026-10-15 12:25:31.559	2026-10-15 12:25:31.559							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "1d60f641-2989-412e-8fba-0a0eed2ee385", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	bf53cc22-fb5a-4fcd-9b73-b4afea258333	failure	\N		\N	10	2026-10-15 12:25:43.275	2026-10-15 12:25:43.275	1d60f641-2989-412e-8fba-0a0eed2ee385	\N
4e0e40f1-1f42-477f-8733-eb42a5ecf9ac	/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 12:25:31.651	2026-10-15 12:25:31.658	2026-10-15 12:25:31.658							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "4e0e40f1-1f42-477f-8733-eb42a5ecf9ac", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	41a99af7-61af-4814-aaac-51bf0bbaaeb3	failure	\N		\N	7	2026-10-15 12:25:43.275	2026-10-15 12:25:43.275	4e0e40f1-1f42-477f-8733-eb42a5ecf9ac	\N
77f488c6-1f78-4a33-b2d1-5e9d08949585	/key/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 12:25:31.699	2026-10-15 12:25:31.704	2026-10-15 12:25:31.703							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "77f488c6-1f78-4a33-b2d1-5e9d08949585", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	ea9bc0cc-1680-4215-9da4-d4f4e1780fe6	failure	\N		\N	4	2026-10-15 12:25:43.275	2026-10-15 12:25:43.275	77f488c6-1f78-4a33-b2d1-5e9d08949585	\N
msg_011Cg4EDCbxQ6D9epF2LEhZE	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	7.15e-05	499	445	54	2026-10-15 15:04:55.013	2026-10-15 15:04:56.243	2026-10-15 15:04:56.243	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 499, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 54, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 54, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.0000715, "output_cost": 0.000027, "service_tier": null, "original_cost": 0.0000715, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "63cf423e-28f5-4b2e-8b77-cd8253bc5aa0", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.52", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 54, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 293.752, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.52	{}	{}	{}	7ddb5683-981a-4a20-9433-9d0894f0c5ec	success	\N		\N	1230	2026-10-15 15:04:57.26	2026-10-15 15:04:57.26	63cf423e-28f5-4b2e-8b77-cd8253bc5aa0	\N
c40786fe-eb74-4216-91f7-e01476a598a5	/v2/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 12:25:31.717	2026-10-15 12:25:31.721	2026-10-15 12:25:31.721							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "c40786fe-eb74-4216-91f7-e01476a598a5", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	72a7d22a-62b3-48c4-aea2-51ca3e6279da	failure	\N		\N	4	2026-10-15 12:25:43.275	2026-10-15 12:25:43.275	c40786fe-eb74-4216-91f7-e01476a598a5	\N
de3fc06b-9409-4688-885b-cfa6cfcc0e9c	/get/user_banner	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 12:25:31.731	2026-10-15 12:25:31.736	2026-10-15 12:25:31.735							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "de3fc06b-9409-4688-885b-cfa6cfcc0e9c", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	8bd844b1-692d-4982-b926-4b1857cb1952	failure	\N		\N	4	2026-10-15 12:25:43.275	2026-10-15 12:25:43.275	de3fc06b-9409-4688-885b-cfa6cfcc0e9c	\N
396b1481-8fae-4d27-8ecc-fca0c7b37aeb	/sso/get/ui_settings	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 12:25:33.579	2026-10-15 12:25:33.584	2026-10-15 12:25:33.583							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "396b1481-8fae-4d27-8ecc-fca0c7b37aeb", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	d5faa58b-98b8-483e-b9f7-9fe33645eeb8	failure	\N		\N	4	2026-10-15 12:25:43.275	2026-10-15 12:25:43.275	396b1481-8fae-4d27-8ecc-fca0c7b37aeb	\N
bb3bb6ee-88e8-4df8-b0cc-68cda6432722	/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 12:25:33.669	2026-10-15 12:25:33.673	2026-10-15 12:25:33.672							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "bb3bb6ee-88e8-4df8-b0cc-68cda6432722", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	011b2f85-9113-4893-aa1a-7e556ae7de55	failure	\N		\N	4	2026-10-15 12:25:43.275	2026-10-15 12:25:43.275	bb3bb6ee-88e8-4df8-b0cc-68cda6432722	\N
msg_011Cg4EE2eTZtxGjKg8jtxeR	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	6.599999999999999e-05	488	445	43	2026-10-15 15:05:05.159	2026-10-15 15:05:06.319	2026-10-15 15:05:06.319	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 488, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 43, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 43, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.00006599999999999999, "output_cost": 0.000021499999999999997, "service_tier": null, "original_cost": 0.00006599999999999999, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "b29acfcf-0729-4e0c-af6f-33114610112a", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.51", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 43, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 265.6562, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.51	{}	{}	{}	ae494eb1-a28a-4fdf-a857-4461e4dc9d78	success	\N		\N	1160	2026-10-15 15:05:11.69	2026-10-15 15:05:11.69	b29acfcf-0729-4e0c-af6f-33114610112a	\N
b161628e-00ab-4c5c-bdec-0f82a3dc83ff	/key/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 12:25:33.719	2026-10-15 12:25:33.724	2026-10-15 12:25:33.723							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "b161628e-00ab-4c5c-bdec-0f82a3dc83ff", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	35c1f154-8dbd-445e-b4c9-ffde11c82c95	failure	\N		\N	4	2026-10-15 12:25:43.275	2026-10-15 12:25:43.275	b161628e-00ab-4c5c-bdec-0f82a3dc83ff	\N
b6b4beef-7d94-4b50-95ce-5f14d69eedd5	/v2/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 12:25:33.734	2026-10-15 12:25:33.738	2026-10-15 12:25:33.738							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "b6b4beef-7d94-4b50-95ce-5f14d69eedd5", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	19e085c2-8544-4ee6-9b9c-10e171758f61	failure	\N		\N	4	2026-10-15 12:25:43.275	2026-10-15 12:25:43.275	b6b4beef-7d94-4b50-95ce-5f14d69eedd5	\N
0721eae3-d738-4322-a2ae-1180ac12e0bc	/get/user_banner	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 12:25:33.749	2026-10-15 12:25:33.753	2026-10-15 12:25:33.753							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "0721eae3-d738-4322-a2ae-1180ac12e0bc", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	2bc5a8db-3e62-4aa0-b386-c48f94f88e15	failure	\N		\N	4	2026-10-15 12:25:43.275	2026-10-15 12:25:43.275	0721eae3-d738-4322-a2ae-1180ac12e0bc	\N
08710300-3eda-448d-b446-bed11addf5db	/get/latest_release_info	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:21:37.801	2026-10-15 14:21:37.883	2026-10-15 14:21:37.883							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "08710300-3eda-448d-b446-bed11addf5db", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	c75baa43-0697-4ce4-a32c-9ebacc5023b1	failure	\N		\N	82	2026-10-15 14:21:46.073	2026-10-15 14:21:46.073	08710300-3eda-448d-b446-bed11addf5db	\N
msg_011Cg4EELFc6Cn485pxeuJLk	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	7.15e-05	499	445	54	2026-10-15 15:05:09.579	2026-10-15 15:05:10.83	2026-10-15 15:05:10.829	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 499, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 54, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 54, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.0000715, "output_cost": 0.000027, "service_tier": null, "original_cost": 0.0000715, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "92053aef-7229-44ec-9778-b43ee80c4537", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.51", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 54, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 9.3381, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.51	{}	{}	{}	759e1280-cd7d-4798-9d60-477982037c9d	success	\N		\N	1251	2026-10-15 15:05:11.69	2026-10-15 15:05:11.69	92053aef-7229-44ec-9778-b43ee80c4537	\N
68f05230-c715-4f0d-a5b9-fe9939153cdf	/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:21:37.857	2026-10-15 14:21:37.959	2026-10-15 14:21:37.958							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "68f05230-c715-4f0d-a5b9-fe9939153cdf", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	7b7a0f43-3284-4380-b0fe-3cc65ea9c5f5	failure	\N		\N	101	2026-10-15 14:21:46.073	2026-10-15 14:21:46.073	68f05230-c715-4f0d-a5b9-fe9939153cdf	\N
7a45e1c8-0bdb-4773-8c0c-6a182826c59d	/sso/get/ui_settings	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:21:37.864	2026-10-15 14:21:37.96	2026-10-15 14:21:37.96							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "7a45e1c8-0bdb-4773-8c0c-6a182826c59d", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	0fa20a20-bb07-4abd-baeb-a04d803366ee	failure	\N		\N	96	2026-10-15 14:21:46.073	2026-10-15 14:21:46.073	7a45e1c8-0bdb-4773-8c0c-6a182826c59d	\N
32e46859-5ec2-4091-a01b-d17fcacfe737	/key/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:21:37.873	2026-10-15 14:21:37.973	2026-10-15 14:21:37.972							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "32e46859-5ec2-4091-a01b-d17fcacfe737", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	38db1098-59c4-4427-8a1a-22e7b851f476	failure	\N		\N	99	2026-10-15 14:21:46.073	2026-10-15 14:21:46.073	32e46859-5ec2-4091-a01b-d17fcacfe737	\N
46b84ced-4347-4c7c-af7e-7c1a89e394d0	/v2/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:21:37.952	2026-10-15 14:21:37.989	2026-10-15 14:21:37.988							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "46b84ced-4347-4c7c-af7e-7c1a89e394d0", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	20a0ac4d-3e1c-4878-873f-c97f6fe8d2ad	failure	\N		\N	36	2026-10-15 14:21:46.073	2026-10-15 14:21:46.073	46b84ced-4347-4c7c-af7e-7c1a89e394d0	\N
msg_011Cg4EDMegTFknGMTnr94Sz	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	6.599999999999999e-05	488	445	43	2026-10-15 15:04:57.284	2026-10-15 15:04:58.489	2026-10-15 15:04:58.489	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 488, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 43, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 43, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.00006599999999999999, "output_cost": 0.000021499999999999997, "service_tier": null, "original_cost": 0.00006599999999999999, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "dcdac8f8-e0eb-4387-a6fb-02f9323104ac", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.51", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 43, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 23.093, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.51	{}	{}	{}	f8bba857-acdb-4eb1-a098-585fc35ec97a	success	\N		\N	1204	2026-10-15 15:05:12.167	2026-10-15 15:05:12.167	dcdac8f8-e0eb-4387-a6fb-02f9323104ac	\N
a411d314-f0af-41a6-8284-336aaec57f03	/get/user_banner	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:21:37.877	2026-10-15 14:21:38	2026-10-15 14:21:38							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "a411d314-f0af-41a6-8284-336aaec57f03", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	13339dec-f50c-49ff-ae33-99401579074a	failure	\N		\N	123	2026-10-15 14:21:46.073	2026-10-15 14:21:46.073	a411d314-f0af-41a6-8284-336aaec57f03	\N
c06cba48-1c6c-422e-ac05-f9cd5230b203	/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:25.293	2026-10-15 14:22:25.317	2026-10-15 14:22:25.316							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "c06cba48-1c6c-422e-ac05-f9cd5230b203", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	ef330232-d5f4-4211-aead-e1d99d6ddbad	failure	\N		\N	24	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	c06cba48-1c6c-422e-ac05-f9cd5230b203	\N
da807199-3139-401c-b48d-2f641316d609	/sso/get/ui_settings	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:25.302	2026-10-15 14:22:25.333	2026-10-15 14:22:25.332							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "da807199-3139-401c-b48d-2f641316d609", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	37c42c75-8b48-46b1-ab16-3c23f941b838	failure	\N		\N	31	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	da807199-3139-401c-b48d-2f641316d609	\N
4413bcd8-87a3-4608-bb79-dee00b9ad0ef	/get/user_banner	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:25.313	2026-10-15 14:22:25.348	2026-10-15 14:22:25.347							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "4413bcd8-87a3-4608-bb79-dee00b9ad0ef", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	6024b12f-54f6-455c-a794-98ac78ea6de3	failure	\N		\N	34	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	4413bcd8-87a3-4608-bb79-dee00b9ad0ef	\N
msg_011Cg4EDWYTTj7Jz8Y3XLMhL	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	6.599999999999999e-05	488	445	43	2026-10-15 15:04:59.51	2026-10-15 15:05:00.716	2026-10-15 15:05:00.715	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 488, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 43, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 43, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.00006599999999999999, "output_cost": 0.000021499999999999997, "service_tier": null, "original_cost": 0.00006599999999999999, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "c412a5c0-e342-4ac7-b194-f0c9737f7bb6", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.52", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 43, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 8.8289, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.52	{}	{}	{}	665223d9-5afa-441d-b2ca-91c5de3a0393	success	\N		\N	1205	2026-10-15 15:05:12.167	2026-10-15 15:05:12.167	c412a5c0-e342-4ac7-b194-f0c9737f7bb6	\N
ed02924d-d7cd-44f2-a9ec-9eb64ad75304	/key/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:25.353	2026-10-15 14:22:25.378	2026-10-15 14:22:25.378							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "ed02924d-d7cd-44f2-a9ec-9eb64ad75304", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	5a03aae9-b34a-4a46-b421-1651b7667b6e	failure	\N		\N	25	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	ed02924d-d7cd-44f2-a9ec-9eb64ad75304	\N
04d6aac4-9707-477a-8ecc-c1c5a0b63227	/v2/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:25.358	2026-10-15 14:22:25.383	2026-10-15 14:22:25.383							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "04d6aac4-9707-477a-8ecc-c1c5a0b63227", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	04e7a318-ff08-441b-889d-29ac688a076f	failure	\N		\N	24	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	04d6aac4-9707-477a-8ecc-c1c5a0b63227	\N
4945f00b-6dae-4dcf-adae-64ef5bce51c9	/get/latest_release_info	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:25.375	2026-10-15 14:22:25.389	2026-10-15 14:22:25.388							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "4945f00b-6dae-4dcf-adae-64ef5bce51c9", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	8bf99013-067b-4bde-a408-706af619593c	failure	\N		\N	14	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	4945f00b-6dae-4dcf-adae-64ef5bce51c9	\N
b4bb9776-1d4e-48c2-96fe-0bb21331e307	/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:26.348	2026-10-15 14:22:26.353	2026-10-15 14:22:26.353							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "b4bb9776-1d4e-48c2-96fe-0bb21331e307", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	fce2f514-3318-4d62-a4df-6b93af3e2271	failure	\N		\N	5	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	b4bb9776-1d4e-48c2-96fe-0bb21331e307	\N
msg_011Cg4EDfVyK2HPPTkUCMHqZ	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	7.15e-05	499	445	54	2026-10-15 15:05:01.746	2026-10-15 15:05:03.377	2026-10-15 15:05:03.377	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 499, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 54, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 54, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.0000715, "output_cost": 0.000027, "service_tier": null, "original_cost": 0.0000715, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "fdd191d5-c49e-4273-8d92-a4f176b13dfe", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.52", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 54, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 18.7089, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.52	{}	{}	{}	31be6a0a-5664-4ade-8d6a-9f6f8451432e	success	\N		\N	1631	2026-10-15 15:05:12.167	2026-10-15 15:05:12.167	fdd191d5-c49e-4273-8d92-a4f176b13dfe	\N
3ebd2ed6-5a64-434b-b364-10b7d1b474bf	/sso/get/ui_settings	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:26.37	2026-10-15 14:22:26.377	2026-10-15 14:22:26.376							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "3ebd2ed6-5a64-434b-b364-10b7d1b474bf", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	acb74773-2fdd-4956-8b20-f799153d7ccb	failure	\N		\N	7	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	3ebd2ed6-5a64-434b-b364-10b7d1b474bf	\N
fbb1fe57-0a2b-44f7-8acc-02ba44901579	/get/user_banner	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:26.368	2026-10-15 14:22:26.379	2026-10-15 14:22:26.378							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "fbb1fe57-0a2b-44f7-8acc-02ba44901579", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	d2a10325-347d-48f3-892d-5a52e1c1fe18	failure	\N		\N	10	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	fbb1fe57-0a2b-44f7-8acc-02ba44901579	\N
294be135-acc9-4ce1-ae88-08c2c2d5a1fb	/key/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:26.412	2026-10-15 14:22:26.417	2026-10-15 14:22:26.417							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "294be135-acc9-4ce1-ae88-08c2c2d5a1fb", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	4477251a-08df-43c6-ad14-24ad354e1c94	failure	\N		\N	5	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	294be135-acc9-4ce1-ae88-08c2c2d5a1fb	\N
44e74c19-29a3-4f2b-96f5-592dd368990c	/v2/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:26.41	2026-10-15 14:22:26.419	2026-10-15 14:22:26.419							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "44e74c19-29a3-4f2b-96f5-592dd368990c", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	ccd8aedc-96a8-47a2-a0b2-9ea6bece8713	failure	\N		\N	9	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	44e74c19-29a3-4f2b-96f5-592dd368990c	\N
msg_011Cg4EDrJqx1heS7HoYxKM7	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	6.599999999999999e-05	488	445	43	2026-10-15 15:05:04.4	2026-10-15 15:05:03.893	2026-10-15 15:05:03.893	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 488, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 43, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 43, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.00006599999999999999, "output_cost": 0.000021499999999999997, "service_tier": null, "original_cost": 0.00006599999999999999, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "9760e671-4740-4a27-aa9e-a153d84939c9", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.52", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 43, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 9.3071, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.52	{}	{}	{}	5da46e85-a5ad-4500-9a08-2375167f20eb	success	\N		\N	-507	2026-10-15 15:05:12.167	2026-10-15 15:05:12.167	9760e671-4740-4a27-aa9e-a153d84939c9	\N
762a6110-fb71-4a83-afa2-fabf71eb712d	/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:28.369	2026-10-15 14:22:28.377	2026-10-15 14:22:28.377							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "762a6110-fb71-4a83-afa2-fabf71eb712d", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	9e4787ee-e5f2-4dde-8adb-081a679754ba	failure	\N		\N	8	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	762a6110-fb71-4a83-afa2-fabf71eb712d	\N
90828ce2-666c-4768-bd45-35ed490efd37	/get/user_banner	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:28.398	2026-10-15 14:22:28.413	2026-10-15 14:22:28.413							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "90828ce2-666c-4768-bd45-35ed490efd37", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	eb5fd205-39bb-46e8-a44c-5c215ffa1c1c	failure	\N		\N	15	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	90828ce2-666c-4768-bd45-35ed490efd37	\N
998aec26-2203-429c-9d69-a5d41fc3df0e	/sso/get/ui_settings	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:28.396	2026-10-15 14:22:28.416	2026-10-15 14:22:28.415							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "998aec26-2203-429c-9d69-a5d41fc3df0e", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	3b3946d7-3d38-44f0-8dd3-ff524bab920c	failure	\N		\N	19	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	998aec26-2203-429c-9d69-a5d41fc3df0e	\N
a87d01dc-3f74-47e9-9409-08476a4ed4c3	/key/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:28.43	2026-10-15 14:22:28.437	2026-10-15 14:22:28.436							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "a87d01dc-3f74-47e9-9409-08476a4ed4c3", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	4d21d0db-7a71-4c59-ac93-10126d770791	failure	\N		\N	6	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	a87d01dc-3f74-47e9-9409-08476a4ed4c3	\N
msg_011Cg4EEBQ3tVnENrrfMaX6N	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	7.15e-05	499	445	54	2026-10-15 15:05:07.347	2026-10-15 15:05:08.556	2026-10-15 15:05:08.555	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 499, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 54, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 54, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.0000715, "output_cost": 0.000027, "service_tier": null, "original_cost": 0.0000715, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "d71363cd-248e-40a4-bee1-10333cd94273", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.52", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 54, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 11.605, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.52	{}	{}	{}	ad783140-0540-407f-a1c8-547fc27b3a67	success	\N		\N	1208	2026-10-15 15:05:12.167	2026-10-15 15:05:12.167	d71363cd-248e-40a4-bee1-10333cd94273	\N
bd0d7a5a-9059-4e71-ae42-8cf9d2d0307b	/v2/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:28.429	2026-10-15 14:22:28.439	2026-10-15 14:22:28.439							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "bd0d7a5a-9059-4e71-ae42-8cf9d2d0307b", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	f57e2302-398a-4d37-98c8-a317e9946c97	failure	\N		\N	10	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	bd0d7a5a-9059-4e71-ae42-8cf9d2d0307b	\N
c07ce3e0-0353-4893-9cc3-312e846968df	/v2/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:29.752	2026-10-15 14:22:29.847	2026-10-15 14:22:29.846							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "c07ce3e0-0353-4893-9cc3-312e846968df", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	125f6d64-8bb8-4ec2-8fe2-0ad45d8055f1	failure	\N		\N	94	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	c07ce3e0-0353-4893-9cc3-312e846968df	\N
ffa0ab22-2897-4f32-ae62-24c39566d0fc	/team/metadata_schema	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:29.766	2026-10-15 14:22:29.85	2026-10-15 14:22:29.849							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "ffa0ab22-2897-4f32-ae62-24c39566d0fc", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	54f9034f-6350-4409-acb3-f1613e79474b	failure	\N		\N	83	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	ffa0ab22-2897-4f32-ae62-24c39566d0fc	\N
75be2a68-87ce-4a32-b12c-130bd5487830	/models	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:29.787	2026-10-15 14:22:29.856	2026-10-15 14:22:29.856							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "75be2a68-87ce-4a32-b12c-130bd5487830", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	0f138ac7-b89e-4055-99aa-d24ceeab5553	failure	\N		\N	69	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	75be2a68-87ce-4a32-b12c-130bd5487830	\N
msg_011Cg4EEgU33enj84gu5y2mL	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	7.049999999999999e-05	497	445	52	2026-10-15 15:05:14.589	2026-10-15 15:05:15.761	2026-10-15 15:05:15.761	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 497, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 52, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 52, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.00007049999999999999, "output_cost": 0.000026, "service_tier": null, "original_cost": 0.00007049999999999999, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "6bfaa040-33e9-4951-87d2-ac37428742e6", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.51", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 52, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 12.188, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.51	{}	{}	{}	7cc33464-9a32-46df-8c03-3458c407be70	success	\N		\N	1172	2026-10-15 15:05:18.788	2026-10-15 15:05:18.788	6bfaa040-33e9-4951-87d2-ac37428742e6	\N
ce60b11f-e455-4e2d-af7f-c41bf24e9bf3	/v2/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:30.906	2026-10-15 14:22:30.915	2026-10-15 14:22:30.914							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "ce60b11f-e455-4e2d-af7f-c41bf24e9bf3", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	aecf5fbf-4f30-41dd-927f-7fa24ef2d3ff	failure	\N		\N	8	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	ce60b11f-e455-4e2d-af7f-c41bf24e9bf3	\N
ab81dfa8-b337-4191-bc34-8afa99023bce	/team/metadata_schema	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:30.91	2026-10-15 14:22:30.918	2026-10-15 14:22:30.918							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "ab81dfa8-b337-4191-bc34-8afa99023bce", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	b76b09e3-fc15-4e49-9c65-99fa40a89c51	failure	\N		\N	7	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	ab81dfa8-b337-4191-bc34-8afa99023bce	\N
862a0f7d-a18d-48a5-bdd4-029c6292fbc0	/models	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:31.121	2026-10-15 14:22:31.128	2026-10-15 14:22:31.128							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "862a0f7d-a18d-48a5-bdd4-029c6292fbc0", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	3f449e4f-fa66-40d9-a734-5f6d6209fc27	failure	\N		\N	7	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	862a0f7d-a18d-48a5-bdd4-029c6292fbc0	\N
cd271fa3-8233-4013-80f5-571c12619ef9	/v2/user/info	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:31.119	2026-10-15 14:22:31.131	2026-10-15 14:22:31.13							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "cd271fa3-8233-4013-80f5-571c12619ef9", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	11f4db5b-02d7-4b9d-ae4f-72e5752ed19a	failure	\N		\N	11	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	cd271fa3-8233-4013-80f5-571c12619ef9	\N
msg_011Cg4EEVcgWJpdTMDJauGfP	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	6.599999999999999e-05	488	445	43	2026-10-15 15:05:11.858	2026-10-15 15:05:13.565	2026-10-15 15:05:13.564	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 488, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 43, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 43, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.00006599999999999999, "output_cost": 0.000021499999999999997, "service_tier": null, "original_cost": 0.00006599999999999999, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "d1542054-9215-4687-b67b-24072166b7cb", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.52", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 43, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 10.818, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.52	{}	{}	{}	5b250150-8aa3-4308-84f2-f3353ef0923b	success	\N		\N	1706	2026-10-15 15:05:19.002	2026-10-15 15:05:19.002	d1542054-9215-4687-b67b-24072166b7cb	\N
6ff6e477-5827-42a7-a44e-c8ccd1981c72	/models	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:32.234	2026-10-15 14:22:32.241	2026-10-15 14:22:32.24							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "6ff6e477-5827-42a7-a44e-c8ccd1981c72", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	2a58ea89-e45a-4bff-aaf6-1d5e92adfaa4	failure	\N		\N	6	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	6ff6e477-5827-42a7-a44e-c8ccd1981c72	\N
1d873829-cacf-496b-ab49-365e2e27b98f	/v2/user/info	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:32.232	2026-10-15 14:22:32.243	2026-10-15 14:22:32.242							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "1d873829-cacf-496b-ab49-365e2e27b98f", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	4e622e20-2bb8-47d6-814e-db801005dcb7	failure	\N		\N	10	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	1d873829-cacf-496b-ab49-365e2e27b98f	\N
c3e81ecb-7cc7-4b95-b532-617186c272e6	/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:32.564	2026-10-15 14:22:32.569	2026-10-15 14:22:32.568							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "c3e81ecb-7cc7-4b95-b532-617186c272e6", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	3fd84e3b-e85d-486b-b368-afd6b343e1e2	failure	\N		\N	5	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	c3e81ecb-7cc7-4b95-b532-617186c272e6	\N
e5cb6c23-2826-401f-9be4-4075509e370b	/get/user_banner	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:32.598	2026-10-15 14:22:32.608	2026-10-15 14:22:32.608							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "e5cb6c23-2826-401f-9be4-4075509e370b", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	e96ea4f9-8ce7-447b-8917-475b6edfcf85	failure	\N		\N	10	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	e5cb6c23-2826-401f-9be4-4075509e370b	\N
msg_011Cg4EEqPKAxXFiZv37j7mv	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	6.549999999999999e-05	487	445	42	2026-10-15 15:05:16.79	2026-10-15 15:05:17.941	2026-10-15 15:05:17.94	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 487, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 42, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 42, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.00006549999999999999, "output_cost": 0.000021, "service_tier": null, "original_cost": 0.00006549999999999999, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "ea48b662-5086-40d2-88a9-5694b0bee8d3", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.52", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 42, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 16.8071, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.52	{}	{}	{}	ab96503b-673b-42cc-8300-3fb5646f5f8e	success	\N		\N	1150	2026-10-15 15:05:19.002	2026-10-15 15:05:19.002	ea48b662-5086-40d2-88a9-5694b0bee8d3	\N
58f18375-75f1-4921-963e-c54d78afb99d	/sso/get/ui_settings	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:32.605	2026-10-15 14:22:32.614	2026-10-15 14:22:32.613							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "58f18375-75f1-4921-963e-c54d78afb99d", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	ece97b9e-0c29-4b34-a102-baa5e7afc257	failure	\N		\N	8	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	58f18375-75f1-4921-963e-c54d78afb99d	\N
443678e4-cf4e-4b61-99d9-7bc7d3c389a5	/v2/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:33.09	2026-10-15 14:22:33.095	2026-10-15 14:22:33.095							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "443678e4-cf4e-4b61-99d9-7bc7d3c389a5", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	1cfa6258-3078-4e53-bed5-931380bbe49c	failure	\N		\N	5	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	443678e4-cf4e-4b61-99d9-7bc7d3c389a5	\N
5556b435-8d68-4ce5-a507-847b48a3072a	/models	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:34.422	2026-10-15 14:22:34.429	2026-10-15 14:22:34.428							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "5556b435-8d68-4ce5-a507-847b48a3072a", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	516d9c92-917a-4b9e-8fbb-4daa9b2f6f04	failure	\N		\N	6	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	5556b435-8d68-4ce5-a507-847b48a3072a	\N
4a7a47f2-7984-4991-abc2-2314a75268d9	/v2/user/info	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:34.42	2026-10-15 14:22:34.431	2026-10-15 14:22:34.431							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "4a7a47f2-7984-4991-abc2-2314a75268d9", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	96ae40c2-064c-4caf-911c-33b455e99694	failure	\N		\N	11	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	4a7a47f2-7984-4991-abc2-2314a75268d9	\N
msg_011Cg4EEzTXKT4rL82m5SjZ3	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	6.35e-05	483	445	38	2026-10-15 15:05:18.965	2026-10-15 15:05:20.249	2026-10-15 15:05:20.248	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 483, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 38, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 38, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.0000635, "output_cost": 0.000018999999999999998, "service_tier": null, "original_cost": 0.0000635, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "1dbb401d-b1e2-4f6a-a322-a96b8ae4989f", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.51", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 38, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 9.6097, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.51	{}	{}	{}	7f380ae1-9a0f-41b1-a67a-0e393944fc25	success	\N		\N	1283	2026-10-15 15:05:25.042	2026-10-15 15:05:25.042	1dbb401d-b1e2-4f6a-a322-a96b8ae4989f	\N
cdf8307e-4231-4cfe-82fb-323425ceb9a6	/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:36.446	2026-10-15 14:22:36.472	2026-10-15 14:22:36.471							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "cdf8307e-4231-4cfe-82fb-323425ceb9a6", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	fad78ac1-c8c4-483c-bef6-1e250f355d9a	failure	\N		\N	25	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	cdf8307e-4231-4cfe-82fb-323425ceb9a6	\N
4b01c52d-5b1c-4c11-8501-b3270f8df16d	/sso/get/ui_settings	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:36.464	2026-10-15 14:22:36.505	2026-10-15 14:22:36.504							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "4b01c52d-5b1c-4c11-8501-b3270f8df16d", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	27556197-c266-49aa-b699-2d69e7e12f95	failure	\N		\N	40	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	4b01c52d-5b1c-4c11-8501-b3270f8df16d	\N
9a3e3520-df34-49fd-920c-d0c770c1b29e	/get/user_banner	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:36.485	2026-10-15 14:22:36.513	2026-10-15 14:22:36.513							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "9a3e3520-df34-49fd-920c-d0c770c1b29e", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	69b48681-0178-4305-bbaf-de4ba7e71a19	failure	\N		\N	28	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	9a3e3520-df34-49fd-920c-d0c770c1b29e	\N
81fd4e99-73dc-46a4-8dde-e348c8989e16	/team/metadata_schema	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:36.482	2026-10-15 14:22:36.519	2026-10-15 14:22:36.519							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "81fd4e99-73dc-46a4-8dde-e348c8989e16", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	d089be54-978c-4b6e-8d7f-11bb11d1f182	failure	\N		\N	36	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	81fd4e99-73dc-46a4-8dde-e348c8989e16	\N
msg_011Cg4EF9SX4Q7vCtzMwz3dw	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	7.15e-05	499	445	54	2026-10-15 15:05:21.277	2026-10-15 15:05:22.572	2026-10-15 15:05:22.571	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 499, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 54, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 54, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.0000715, "output_cost": 0.000027, "service_tier": null, "original_cost": 0.0000715, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "2f2f4234-a5a5-40ed-8bda-851bff7ecc7e", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.51", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 54, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 11.436, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.51	{}	{}	{}	f8b72162-f4e2-4cff-83c9-73f537ad9fe0	success	\N		\N	1295	2026-10-15 15:05:25.042	2026-10-15 15:05:25.042	2f2f4234-a5a5-40ed-8bda-851bff7ecc7e	\N
a4d4cbc0-57cb-409c-beb1-008d8f1a3900	/get/latest_release_info	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:36.531	2026-10-15 14:22:36.538	2026-10-15 14:22:36.538							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "a4d4cbc0-57cb-409c-beb1-008d8f1a3900", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	3594041e-5f79-439d-9ed5-0c14b8f292b9	failure	\N		\N	6	2026-10-15 14:22:36.788	2026-10-15 14:22:36.788	a4d4cbc0-57cb-409c-beb1-008d8f1a3900	\N
03412824-eb80-4746-affe-4f8efe36cd17	/v2/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:37.436	2026-10-15 14:22:37.441	2026-10-15 14:22:37.44							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "03412824-eb80-4746-affe-4f8efe36cd17", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	841888bd-0ce4-4ea8-a65e-3e0a40951c31	failure	\N		\N	4	2026-10-15 14:22:45.031	2026-10-15 14:22:45.031	03412824-eb80-4746-affe-4f8efe36cd17	\N
76653a4f-78bc-40ee-b05f-b10c1807aa7b	/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:37.574	2026-10-15 14:22:37.582	2026-10-15 14:22:37.581							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "76653a4f-78bc-40ee-b05f-b10c1807aa7b", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	8eb5e1ba-b26f-40ea-9156-5151ee9faf08	failure	\N		\N	7	2026-10-15 14:22:45.031	2026-10-15 14:22:45.031	76653a4f-78bc-40ee-b05f-b10c1807aa7b	\N
15aa6e66-c66f-479e-bbc3-429769e8aeb0	/sso/get/ui_settings	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:37.604	2026-10-15 14:22:37.61	2026-10-15 14:22:37.609							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "15aa6e66-c66f-479e-bbc3-429769e8aeb0", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	76ce38e3-a0b6-4be1-9f39-c32f747286f8	failure	\N		\N	5	2026-10-15 14:22:45.031	2026-10-15 14:22:45.031	15aa6e66-c66f-479e-bbc3-429769e8aeb0	\N
msg_011Cg4EFK8RH2NinusG5ohNm	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	7.15e-05	499	445	54	2026-10-15 15:05:23.592	2026-10-15 15:05:24.871	2026-10-15 15:05:24.87	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 499, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 54, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 54, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.0000715, "output_cost": 0.000027, "service_tier": null, "original_cost": 0.0000715, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "439edce2-91ca-4868-a63e-f92c017bebcc", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.51", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 54, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 8.63, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.51	{}	{}	{}	120a1bde-3687-497d-abff-f9b47a4aca69	success	\N		\N	1278	2026-10-15 15:05:25.042	2026-10-15 15:05:25.042	439edce2-91ca-4868-a63e-f92c017bebcc	\N
11be4b8b-5c36-4500-936d-b2bc193048cc	/get/user_banner	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:37.624	2026-10-15 14:22:37.638	2026-10-15 14:22:37.637							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "11be4b8b-5c36-4500-936d-b2bc193048cc", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	2d4dc979-437b-462f-9555-adb616b1ece0	failure	\N		\N	14	2026-10-15 14:22:45.031	2026-10-15 14:22:45.031	11be4b8b-5c36-4500-936d-b2bc193048cc	\N
ecfff064-f91c-4b8c-b5a3-5ab025d871ea	/team/metadata_schema	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:37.627	2026-10-15 14:22:37.64	2026-10-15 14:22:37.64							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "ecfff064-f91c-4b8c-b5a3-5ab025d871ea", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	9e8d2b3b-e0e3-402a-bec0-0799c2111068	failure	\N		\N	13	2026-10-15 14:22:45.031	2026-10-15 14:22:45.031	ecfff064-f91c-4b8c-b5a3-5ab025d871ea	\N
70872421-ef33-4538-94c4-ba5b23a7a1f8	/team/list	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:39.766	2026-10-15 14:22:39.771	2026-10-15 14:22:39.77							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "70872421-ef33-4538-94c4-ba5b23a7a1f8", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	538c6601-952e-4cf8-8915-a9f67af3dbe3	failure	\N		\N	4	2026-10-15 14:22:45.031	2026-10-15 14:22:45.031	70872421-ef33-4538-94c4-ba5b23a7a1f8	\N
3009cd02-48fb-493b-a858-e0562c0cdc5b	/sso/get/ui_settings	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:39.783	2026-10-15 14:22:39.788	2026-10-15 14:22:39.787							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "3009cd02-48fb-493b-a858-e0562c0cdc5b", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	ea26e64c-dc75-4ffb-9b1d-d3aa60d38aef	failure	\N		\N	4	2026-10-15 14:22:45.031	2026-10-15 14:22:45.031	3009cd02-48fb-493b-a858-e0562c0cdc5b	\N
msg_011Cg4EFUQHTRjDz7uirEoTP	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	6.599999999999999e-05	488	445	43	2026-10-15 15:05:25.895	2026-10-15 15:05:27.092	2026-10-15 15:05:27.092	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 488, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 43, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 43, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.00006599999999999999, "output_cost": 0.000021499999999999997, "service_tier": null, "original_cost": 0.00006599999999999999, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "0f38f1dd-4d01-445a-a62a-964fa1051d11", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.52", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 43, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 12.5213, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.52	{}	{}	{}	fdbddb7c-b62c-4fea-9ace-85f4aaf74932	success	\N		\N	1196	2026-10-15 15:05:42.032	2026-10-15 15:05:42.032	0f38f1dd-4d01-445a-a62a-964fa1051d11	\N
1c05b197-6626-4e1d-a8af-f400f2e99244	/get/user_banner	fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a	0	0	0	0	2026-10-15 14:22:39.819	2026-10-15 14:22:39.825	2026-10-15 14:22:39.825							{"status": "failure", "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "1c05b197-6626-4e1d-a8af-f400f2e99244", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "401", "error_class": "KeyNotFoundError", "llm_provider": "", "error_message": "Authentication Error, Invalid proxy server token passed. Received API Key = sk-...guLw, Key Hash (Token) =fe552e043cc1ac799444af3851b2deebaaca0615259edce41239f869ed2af65a. Unable to find token in cache or `LiteLLM_VerificationTokenTable`", "normalized_error": "401_AUTHENTICATION_FAILED", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": null, "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": null, "user_api_key_user_id": null, "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "", "model_map_value": null}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": null, "user_api_key_project_id": null, "user_api_key_team_alias": null, "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	[]			127.0.0.1	{}	{}	{}	99d8e4a8-3b58-43c0-a0ee-51a66bdeb2d8	failure	\N		\N	5	2026-10-15 14:22:45.031	2026-10-15 14:22:45.031	1c05b197-6626-4e1d-a8af-f400f2e99244	\N
msg_011Cg4Djeeqhg96bhiFBRnVs	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	7.41e-05	513	456	57	2026-10-15 14:58:40.606	2026-10-15 14:58:42.106	2026-10-15 14:58:42.105	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 513, "inference_geo": "global", "prompt_tokens": 456, "completion_tokens": 57, "prompt_tokens_details": {"text_tokens": 456, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 57, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000456, "total_cost": 0.0000741, "output_cost": 0.000028499999999999998, "service_tier": null, "original_cost": 0.0000741, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "c5f78120-502f-4bf7-94a4-505b5af2b614", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.51", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 456, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 57, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 791.2369, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.51	{}	{}	{}	5b38507f-4623-4c3e-8696-0d121762fd2f	success	\N		\N	1500	2026-10-15 14:58:51.588	2026-10-15 14:58:51.588	c5f78120-502f-4bf7-94a4-505b5af2b614	\N
msg_011Cg4DjkAE8nJDuXJijJHFt	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	6.52e-05	564	542	22	2026-10-15 14:58:42.172	2026-10-15 14:58:43.373	2026-10-15 14:58:43.373	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 564, "inference_geo": "global", "prompt_tokens": 542, "completion_tokens": 22, "prompt_tokens_details": {"text_tokens": 542, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 22, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.000054199999999999996, "total_cost": 0.0000652, "output_cost": 0.000011, "service_tier": null, "original_cost": 0.0000652, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "603e6ea1-4f33-419e-9b8b-6883a1bc5c01", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.51", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 542, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 22, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 28.1999, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.51	{}	{}	{}	5b38507f-4623-4c3e-8696-0d121762fd2f	success	\N		\N	1201	2026-10-15 14:58:51.588	2026-10-15 14:58:51.588	603e6ea1-4f33-419e-9b8b-6883a1bc5c01	\N
msg_011Cg4DncaQSV2uPSRdBvChy	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	7.41e-05	513	456	57	2026-10-15 14:59:21.644	2026-10-15 14:59:22.927	2026-10-15 14:59:22.927	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 513, "inference_geo": "global", "prompt_tokens": 456, "completion_tokens": 57, "prompt_tokens_details": {"text_tokens": 456, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 57, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000456, "total_cost": 0.0000741, "output_cost": 0.000028499999999999998, "service_tier": null, "original_cost": 0.0000741, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "053cd3b5-50f9-46e1-b2c6-31ea76ea961e", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.52", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 456, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 57, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 1133.3251, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.52	{}	{}	{}	043b168d-807c-46a6-8db4-15db5d1eb575	success	\N		\N	1283	2026-10-15 14:59:30.964	2026-10-15 14:59:30.964	053cd3b5-50f9-46e1-b2c6-31ea76ea961e	\N
msg_011Cg4DnhkDLxP1AyUtzts5v	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	6.52e-05	564	542	22	2026-10-15 14:59:23.039	2026-10-15 14:59:24.095	2026-10-15 14:59:24.095	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 564, "inference_geo": "global", "prompt_tokens": 542, "completion_tokens": 22, "prompt_tokens_details": {"text_tokens": 542, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 22, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.000054199999999999996, "total_cost": 0.0000652, "output_cost": 0.000011, "service_tier": null, "original_cost": 0.0000652, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "5970faa0-dbad-42c6-a2b1-187829ffd27f", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.52", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 542, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 22, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 44.6031, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.52	{}	{}	{}	043b168d-807c-46a6-8db4-15db5d1eb575	success	\N		\N	1055	2026-10-15 14:59:30.964	2026-10-15 14:59:30.964	5970faa0-dbad-42c6-a2b1-187829ffd27f	\N
msg_011Cg4E7Qeq31tN6sTubLADj	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	6.45e-05	485	445	40	2026-10-15 15:03:36.628	2026-10-15 15:03:37.973	2026-10-15 15:03:37.972	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 485, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 40, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 40, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.0000645, "output_cost": 0.000019999999999999998, "service_tier": null, "original_cost": 0.0000645, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "f2442e55-b89a-473d-b278-2f5ea45bee63", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.51", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 40, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 29.9237, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.51	{}	{}	{}	2a1cd0b9-0bd3-4ff0-9679-3ee1f9f104a7	success	\N		\N	1345	2026-10-15 15:03:50.404	2026-10-15 15:03:50.404	f2442e55-b89a-473d-b278-2f5ea45bee63	\N
msg_011Cg4E7Zc6nZLhwi9UERuK4	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	7.15e-05	499	445	54	2026-10-15 15:03:38.996	2026-10-15 15:03:40.2	2026-10-15 15:03:40.199	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 499, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 54, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 54, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.0000715, "output_cost": 0.000027, "service_tier": null, "original_cost": 0.0000715, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "8550a2d0-232f-4a5b-975a-b1e42194eebd", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.51", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 54, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 9.5959, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.51	{}	{}	{}	4298945c-e56d-4314-8779-e6a7db263cfe	success	\N		\N	1203	2026-10-15 15:03:50.404	2026-10-15 15:03:50.404	8550a2d0-232f-4a5b-975a-b1e42194eebd	\N
msg_011Cg4E7iVsnGywXN4CUH4M6	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	7.199999999999999e-05	500	445	55	2026-10-15 15:03:39.54	2026-10-15 15:03:40.757	2026-10-15 15:03:40.756	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 500, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 55, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 55, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.00007199999999999999, "output_cost": 0.000027499999999999998, "service_tier": null, "original_cost": 0.00007199999999999999, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "54c8e3be-7728-4d38-879a-64ffa3af39ff", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.51", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 55, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 12.115, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.51	{}	{}	{}	b68a63a0-c968-47b0-ba55-2f5a12bb8bbc	success	\N		\N	1216	2026-10-15 15:03:50.404	2026-10-15 15:03:50.404	54c8e3be-7728-4d38-879a-64ffa3af39ff	\N
msg_011Cg4E7siX21WiNfkLokdBw	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	6.599999999999999e-05	488	445	43	2026-10-15 15:03:41.789	2026-10-15 15:03:43.004	2026-10-15 15:03:43.004	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 488, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 43, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 43, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.00006599999999999999, "output_cost": 0.000021499999999999997, "service_tier": null, "original_cost": 0.00006599999999999999, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "23a727e9-a663-439a-9894-224b81ee42db", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.51", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 43, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 19.383, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.51	{}	{}	{}	7f3ff2ab-b55d-4000-a58c-833425174137	success	\N		\N	1214	2026-10-15 15:03:50.404	2026-10-15 15:03:50.404	23a727e9-a663-439a-9894-224b81ee42db	\N
msg_011Cg4E82aaJ16B2vTSgaBdP	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	6.35e-05	483	445	38	2026-10-15 15:03:44.029	2026-10-15 15:03:45.12	2026-10-15 15:03:45.119	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 483, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 38, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 38, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.0000635, "output_cost": 0.000018999999999999998, "service_tier": null, "original_cost": 0.0000635, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "9eafd50a-e9c0-4072-9e6d-ba655ca44740", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.51", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 38, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 11.6611, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.51	{}	{}	{}	68b3586e-f536-4703-9eff-385a04a08f1e	success	\N		\N	1091	2026-10-15 15:03:50.404	2026-10-15 15:03:50.404	9eafd50a-e9c0-4072-9e6d-ba655ca44740	\N
msg_011Cg4EFd5BHGVwZvgorkFnC	anthropic_messages	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	7.049999999999999e-05	497	445	52	2026-10-15 15:05:28.121	2026-10-15 15:05:29.359	2026-10-15 15:05:29.358	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "Anthropic/Python 1.13.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 497, "inference_geo": "global", "prompt_tokens": 445, "completion_tokens": 52, "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 52, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.0000445, "total_cost": 0.00007049999999999999, "output_cost": 0.000026, "service_tier": null, "original_cost": 0.00007049999999999999, "data_residency": null, "margin_percent": 0.0, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "be16876d-13aa-4a51-8777-8acac6953838", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 0, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "10.1.0.52", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 445, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 52, "reasoning_tokens": 0}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 11.2271, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["bank-agent", "User-Agent: Anthropic", "User-Agent: Anthropic/Python 1.13.0"]	41649881-c262-402e-9754-b5c44ce947a4		10.1.0.52	{}	{}	{}	59a90886-b1b4-4534-bf23-429cd0208e67	success	\N		\N	1238	2026-10-15 15:05:42.032	2026-10-15 15:05:42.032	be16876d-13aa-4a51-8777-8acac6953838	\N
9c92e5c1-8b21-4b9a-8cb7-3adcbd3aac1d	acompletion	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	0	0	0	0	2026-10-15 15:06:01.882	2026-10-15 15:06:01.889	2026-10-15 15:06:01.889	anthropic/claude-haiku-5-5	d8cba387c0a5eb5526dd82a8bc6572b21aaaebfb9cb7c1ac5c95771fe8ae44c9	bank-primary	anthropic		default_user_id	{"status": "failure", "user_agent": "curl/8.5.0", "max_retries": null, "batch_models": null, "usage_object": {"total_tokens": 0, "prompt_tokens": 0, "completion_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": null, "azure_spillover": null, "litellm_call_id": "9c92e5c1-8b21-4b9a-8cb7-3adcbd3aac1d", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": null, "error_information": {"traceback": "", "error_code": "400", "error_class": "MockTestingParamsDisabledError", "llm_provider": "", "error_message": "400: {'error': 'Mock testing request params are disabled on this proxy: mock_testing_fallbacks. An admin can enable them by setting `general_settings.dangerously_allow_mock_testing_request_params: true` in config.yaml. This setting cannot be changed from the Admin UI or the API.'}", "normalized_error": "400_INVALID_REQUEST", "error_budget_limit": null, "error_budget_spend": null, "error_rate_limit_type": null, "error_budget_entity_id": null, "error_budget_entity_type": null, "error_provider_request_id": null, "error_rate_limit_category": null}, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": null, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": null, "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-haiku-5-5", "model_map_value": {"key": "claude-haiku-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": false, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.0000001, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.0000005, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.00000001, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.00000005, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00000025, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000000125, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.000000005, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_100k_tokens": 0.0000005, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000000625, "output_cost_per_token_above_100k_tokens": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.0000002, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_100k_tokens": 0.00000005, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_100k_tokens": 0.000000625, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_1hr_above_100k_tokens": 0.000001, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": null, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	False	Cache OFF	["User-Agent: curl", "User-Agent: curl/8.5.0"]	41649881-c262-402e-9754-b5c44ce947a4		127.0.0.1	{}	{}	{}	51a06348-76a6-41aa-a2e8-c467c7d4587f	failure	\N		\N	6	2026-10-15 15:06:07.953	2026-10-15 15:06:07.953	9c92e5c1-8b21-4b9a-8cb7-3adcbd3aac1d	\N
chatcmpl-9c10aaf8-c4bf-4007-ba8c-cf9410baeb81	acompletion	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	0.002656	144	14	130	2026-10-15 15:14:40.219	2026-10-15 15:14:42.845	2026-10-15 15:14:42.844	anthropic/claude-opus-5-5	eb2ac3674ff0afed0e9cfa015ce9b3f5d31c3d66f15e5dc0c78d1784ddf5b2eb	bank-fallback	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "curl/8.5.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 144, "inference_geo": "global", "prompt_tokens": 14, "completion_tokens": 130, "prompt_tokens_details": {"text_tokens": 14, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 64, "reasoning_tokens": 66}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.000056, "total_cost": 0.0026560000000000004, "output_cost": 0.0026000000000000003, "service_tier": null, "original_cost": 0.0026560000000000004, "data_residency": null, "margin_percent": 0.0, "reasoning_cost": 0.0013200000000000002, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "85665b71-8e6e-4bbc-8b09-6929da3363af", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 1, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-opus-5-5", "model_map_value": {"key": "claude-opus-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": true, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.000004, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.00002, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1, "fast": 2}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.0000002, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.000002, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00001, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000005, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.0000001, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.000008, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 14, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 64, "reasoning_tokens": 66}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 202.95, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["User-Agent: curl", "User-Agent: curl/8.5.0"]	41649881-c262-402e-9754-b5c44ce947a4		127.0.0.1	{}	{}	{}	a543cec6-42de-41fe-8e0c-3cfd3c81d9ac	success	\N		\N	2626	2026-10-15 15:14:52.806	2026-10-15 15:14:52.806	85665b71-8e6e-4bbc-8b09-6929da3363af	\N
chatcmpl-99da3d8f-3c92-40a7-bde5-9a2c82ba2da9	acompletion	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	0.002396	131	14	117	2026-10-15 15:14:45.816	2026-10-15 15:14:48.156	2026-10-15 15:14:48.156	anthropic/claude-opus-5-5	eb2ac3674ff0afed0e9cfa015ce9b3f5d31c3d66f15e5dc0c78d1784ddf5b2eb	bank-fallback	anthropic	https://api.anthropic.com/v1/messages	default_user_id	{"status": null, "user_agent": "curl/8.5.0", "max_retries": 2, "batch_models": null, "usage_object": {"speed": null, "iterations": null, "service_tier": "standard", "total_tokens": 131, "inference_geo": "global", "prompt_tokens": 14, "completion_tokens": 117, "prompt_tokens_details": {"text_tokens": 14, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 58, "reasoning_tokens": 59}, "cache_creation_input_tokens": 0}, "user_api_key": "f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61", "actor_agent_id": null, "cost_breakdown": {"input_cost": 0.000056, "total_cost": 0.002396, "output_cost": 0.00234, "service_tier": null, "original_cost": 0.002396, "data_residency": null, "margin_percent": 0.0, "reasoning_cost": 0.00118, "discount_amount": 0.0, "tool_usage_cost": 0.0, "vertex_location": null, "discount_percent": 0.0, "margin_fixed_amount": 0.0, "margin_total_amount": 0.0}, "azure_spillover": null, "litellm_call_id": "9fb69741-98d3-480e-8e36-09176674b5fa", "router_metadata": null, "target_agent_id": null, "billing_agent_id": null, "eval_information": null, "routing_decision": null, "attempted_retries": 0, "error_information": null, "applied_guardrails": [], "autorouter_savings": null, "user_api_key_alias": "bank-agent-k8s", "attempted_fallbacks": 1, "compression_savings": null, "spend_logs_metadata": null, "user_api_key_org_id": null, "agent_execution_mode": null, "internal_call_origin": null, "original_model_group": "bank-primary", "proxy_server_request": null, "requester_ip_address": "127.0.0.1", "user_api_key_team_id": "41649881-c262-402e-9754-b5c44ce947a4", "user_api_key_user_id": "default_user_id", "batch_failed_requests": null, "guardrail_information": null, "model_map_information": {"model_map_key": "anthropic/claude-opus-5-5", "model_map_value": {"key": "claude-opus-5-5", "rpm": null, "tpm": null, "mode": "chat", "max_tokens": 128000, "tiered_pricing": null, "cost_per_second": null, "supports_vision": true, "litellm_provider": "anthropic", "max_input_tokens": 1000000, "off_peak_pricing": null, "max_output_tokens": 128000, "ocr_cost_per_page": null, "output_vector_size": null, "supports_pdf_input": true, "supports_reasoning": true, "thinking_always_on": true, "uses_embed_content": null, "ocr_cost_per_credit": null, "supported_endpoints": null, "supports_image_size": null, "supports_web_search": true, "vertex_ai_audio_api": null, "input_cost_per_image": null, "input_cost_per_query": null, "input_cost_per_token": 0.000004, "supports_audio_input": null, "supports_tool_choice": true, "supports_tool_search": true, "supports_url_context": null, "input_cost_per_second": null, "output_cost_per_image": null, "output_cost_per_pixel": null, "output_cost_per_token": 0.00002, "supports_audio_output": null, "supports_computer_use": true, "output_cost_per_second": null, "citation_cost_per_token": null, "prompt_cache_min_tokens": 512, "provider_specific_entry": {"us": 1.1, "fast": 2}, "reasoning_effort_levels": null, "supported_audio_formats": null, "supported_openai_params": ["stream", "stop", "temperature", "top_p", "max_tokens", "max_completion_tokens", "tools", "tool_choice", "extra_headers", "parallel_tool_calls", "response_format", "user", "web_search_options", "speed", "context_management", "cache_control", "thinking", "reasoning_effort"], "supports_prompt_caching": true, "web_search_billing_unit": null, "annotation_cost_per_page": null, "default_reasoning_effort": null, "input_cost_per_character": null, "supports_legacy_thinking": null, "supports_response_schema": true, "supports_system_messages": null, "input_cost_per_token_flex": null, "ocr_cost_per_page_batches": null, "output_cost_per_character": null, "output_cost_per_second_2k": null, "output_cost_per_second_4k": null, "supports_function_calling": true, "supports_native_streaming": null, "input_cost_per_audio_token": null, "input_cost_per_image_token": null, "input_cost_per_video_token": null, "output_cost_per_token_flex": null, "supports_adaptive_thinking": true, "supports_assistant_prefill": false, "cache_read_input_token_cost": 0.0000002, "output_cost_per_audio_token": null, "output_cost_per_image_token": null, "output_cost_per_second_480p": null, "output_cost_per_second_720p": null, "output_cost_per_second_768p": null, "output_cost_per_video_token": null, "input_cost_per_token_batches": 0.000002, "output_cost_per_second_1080p": null, "input_cost_per_token_balanced": null, "input_cost_per_token_priority": null, "output_cost_per_token_batches": 0.00001, "search_context_cost_per_query": {"search_context_size_low": 0.01, "search_context_size_high": 0.01, "search_context_size_medium": 0.01}, "supports_anthropic_compaction": true, "supports_low_reasoning_effort": null, "supports_max_reasoning_effort": true, "input_cost_per_token_ultrafast": null, "output_cost_per_token_balanced": null, "output_cost_per_token_priority": null, "supports_embedding_image_input": null, "supports_none_reasoning_effort": null, "cache_creation_input_token_cost": 0.000005, "input_cost_per_audio_per_second": null, "input_cost_per_video_per_second": null, "output_cost_per_reasoning_token": null, "output_cost_per_token_ultrafast": null, "supports_xhigh_reasoning_effort": true, "annotation_cost_per_page_batches": null, "cache_read_input_token_cost_flex": null, "output_cost_per_video_per_second": null, "supports_mid_conversation_system": true, "supports_prompt_cache_breakpoint": null, "cache_read_input_audio_token_cost": null, "supports_minimal_reasoning_effort": null, "supports_native_structured_output": true, "input_cost_per_audio_token_batches": null, "input_cost_per_image_token_batches": null, "input_cost_per_video_token_batches": null, "supports_parallel_function_calling": null, "cache_read_input_token_cost_batches": 0.0000001, "regional_endpoint_uplift_multiplier": null, "supports_anthropic_thinking_payload": null, "bedrock_output_config_effort_ceiling": null, "cache_creation_input_token_cost_flex": null, "cache_read_input_token_cost_balanced": null, "cache_read_input_token_cost_priority": null, "google_maps_grounding_cost_per_query": null, "output_cost_per_reasoning_token_flex": null, "supports_thinking_cache_preservation": null, "cache_read_input_token_cost_ultrafast": null, "bedrock_converse_supports_strict_tools": null, "input_cost_per_token_above_128k_tokens": null, "input_cost_per_token_above_200k_tokens": null, "input_cost_per_token_above_272k_tokens": null, "input_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_batches": 0.0000025, "output_cost_per_token_above_128k_tokens": null, "output_cost_per_token_above_200k_tokens": null, "output_cost_per_token_above_272k_tokens": null, "output_cost_per_token_above_512k_tokens": null, "cache_creation_input_token_cost_priority": null, "output_cost_per_reasoning_token_priority": null, "regional_processing_uplift_multiplier_eu": null, "regional_processing_uplift_multiplier_us": null, "cache_creation_input_token_cost_above_1hr": 0.000008, "cache_creation_input_token_cost_ultrafast": null, "input_cost_per_token_above_272k_tokens_flex": null, "output_cost_per_character_above_128k_tokens": null, "output_cost_per_token_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens": null, "cache_read_input_token_cost_above_272k_tokens": null, "cache_read_input_token_cost_above_512k_tokens": null, "input_cost_per_token_above_200k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_200k_tokens_priority": null, "input_cost_per_token_above_272k_tokens_priority": null, "output_cost_per_token_above_200k_tokens_batches": null, "output_cost_per_token_above_272k_tokens_batches": null, "input_cost_per_token_above_272k_tokens_ultrafast": null, "output_cost_per_token_above_200k_tokens_priority": null, "output_cost_per_token_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_200k_tokens": null, "cache_creation_input_token_cost_above_272k_tokens": null, "output_cost_per_token_above_272k_tokens_ultrafast": null, "cache_read_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_batches": null, "cache_read_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_flex": null, "cache_read_input_token_cost_above_200k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_priority": null, "cache_read_input_token_cost_above_272k_tokens_ultrafast": null, "cache_creation_input_token_cost_above_200k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_batches": null, "cache_creation_input_token_cost_above_272k_tokens_priority": null, "cache_creation_input_token_cost_above_272k_tokens_ultrafast": null}}, "mcp_tool_call_metadata": null, "verified_human_user_id": null, "additional_usage_values": {"speed": null, "iterations": null, "service_tier": "standard", "inference_geo": "global", "prompt_tokens_details": {"text_tokens": 14, "audio_tokens": null, "image_tokens": null, "video_tokens": null, "cached_tokens": 0, "cache_write_tokens": 0, "cache_creation_tokens": 0, "cache_creation_token_details": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}}, "cache_read_input_tokens": 0, "completion_tokens_details": {"text_tokens": 58, "reasoning_tokens": 59}, "cache_creation_input_tokens": 0}, "cold_storage_object_key": null, "used_client_oauth_token": false, "user_api_key_project_id": null, "user_api_key_team_alias": "bank-agent-dev", "litellm_overhead_time_ms": 20.8118, "batch_successful_requests": null, "user_api_key_project_alias": null, "autorouter_savings_estimate": null, "vector_store_request_metadata": null, "litellm_gateway_injected_cache": null, "autorouter_baseline_observation": null}	None	Cache OFF	["User-Agent: curl", "User-Agent: curl/8.5.0"]	41649881-c262-402e-9754-b5c44ce947a4		127.0.0.1	{}	{}	{}	8b5e788c-e763-421f-8d78-b26e17a1e9cb	success	\N		\N	2340	2026-10-15 15:14:52.806	2026-10-15 15:14:52.806	9fb69741-98d3-480e-8e36-09176674b5fa	\N
\.


--
-- Data for Name: LiteLLM_TagTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_TagTable" (tag_name, description, models, model_info, spend, budget_id, created_at, created_by, updated_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_TeamMembership; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_TeamMembership" (user_id, team_id, spend, budget_id, total_spend) FROM stdin;
default_user_id	41649881-c262-402e-9754-b5c44ce947a4	0.006898600000000001	\N	0.006898600000000001
\.


--
-- Data for Name: LiteLLM_TeamTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_TeamTable" (team_id, team_alias, organization_id, admins, members, members_with_roles, metadata, max_budget, spend, models, max_parallel_requests, tpm_limit, rpm_limit, budget_duration, budget_reset_at, blocked, created_at, updated_at, model_spend, model_max_budget, model_id, team_member_permissions, object_permission_id, router_settings, policies, allow_team_guardrail_config, soft_budget, access_group_ids, budget_limits, default_team_member_models, tpd_limit) FROM stdin;
41649881-c262-402e-9754-b5c44ce947a4	bank-agent-dev	\N	{}	{}	[{"role": "admin", "user_id": "default_user_id", "user_email": null}]	{}	5	0.006898600000000001	{bank-primary,bank-fallback}	\N	\N	\N	\N	\N	f	2026-10-15 14:30:32.629	2026-10-15 15:14:53.119	{}	{}	\N	{}	\N	{}	{}	f	\N	{}	\N	{}	\N
\.


--
-- Data for Name: LiteLLM_ToolTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_ToolTable" (tool_id, tool_name, origin, input_policy, call_count, assignments, key_hash, team_id, key_alias, created_at, created_by, updated_at, updated_by, output_policy, user_agent, last_used_at) FROM stdin;
13985554-f136-4a90-8123-7e3b41d8e8d6	get_account_balance	user_defined	untrusted	2	{}	f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	41649881-c262-402e-9754-b5c44ce947a4	bank-agent-k8s	2026-10-15 14:58:52.58	system	2026-10-15 14:59:30.844	system	untrusted	Anthropic/Python 1.13.0	2026-10-15 14:59:30.844
\.


--
-- Data for Name: LiteLLM_UISettings; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_UISettings" (id, ui_settings, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_UserNotifications; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_UserNotifications" (request_id, user_id, models, justification, status) FROM stdin;
\.


--
-- Data for Name: LiteLLM_UserTable; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_UserTable" (user_id, user_alias, team_id, sso_user_id, organization_id, password, teams, user_role, max_budget, spend, user_email, models, metadata, max_parallel_requests, tpm_limit, rpm_limit, budget_duration, budget_reset_at, allowed_cache_controls, model_spend, model_max_budget, created_at, updated_at, object_permission_id, policies, password_reset_required, last_breach_check_at) FROM stdin;
default_user_id	\N	\N	\N	\N	\N	{41649881-c262-402e-9754-b5c44ce947a4}	proxy_admin	\N	0.006898600000000001	\N	\N	{}	\N	\N	\N	\N	\N	{}	{}	{}	2026-10-15 14:29:46.433	2026-10-15 15:14:53.041	\N	{}	\N	\N
\.


--
-- Data for Name: LiteLLM_VerificationToken; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_VerificationToken" (token, key_name, key_alias, soft_budget_cooldown, spend, expires, models, aliases, config, user_id, team_id, permissions, max_parallel_requests, metadata, blocked, tpm_limit, rpm_limit, max_budget, budget_duration, budget_reset_at, allowed_cache_controls, model_spend, model_max_budget, budget_id, organization_id, created_at, created_by, updated_at, updated_by, allowed_routes, object_permission_id, auto_rotate, key_rotation_at, last_rotation_at, rotation_count, rotation_interval, project_id, router_settings, policies, access_group_ids, last_active, agent_id, budget_limits, budget_fallbacks, key_type, settings_updated_at, tpd_limit, total_spend) FROM stdin;
d6a1d450984c4aebddedfe27c75f117ce49c8ea8b52016fd9853fc9a2098df37	sk-...Cplg	\N	f	0	2026-10-16 14:29:46.479	{}	{}	{}	default_user_id	litellm-dashboard	{}	\N	{}	\N	\N	\N	1	\N	\N	{}	{}	{}	\N	\N	2026-10-15 14:29:46.493	\N	2026-10-15 14:29:46.493	\N	{}	\N	f	\N	\N	0	\N	\N	{}	{}	{}	\N	\N	\N	{}	\N	\N	\N	0
6b12f686481120d4cad863734c13a1aef556d860cb1bb5f5692b0e137153fa68	sk-..._lfg	bank-agent-k8s-api	f	0	\N	{bank-primary}	{}	{}	\N	\N	{}	\N	{}	\N	\N	60	2	30d	2026-11-01 00:00:00	{}	{}	{}	\N	\N	2026-10-15 14:31:52.794	default_user_id	2026-10-15 14:31:52.794	default_user_id	{}	\N	f	\N	\N	0	\N	\N	{}	{}	{}	\N	\N	\N	{}	default	\N	\N	0
85fbca50fc4e779742344e836664764c59ed9b12b453199f56735401e69d60f4	sk-...ohOA	bank-agent-k8s-api-2	f	0	\N	{bank-primary}	{}	{}	\N	\N	{}	\N	{}	\N	\N	60	2	30d	2026-11-01 00:00:00	{}	{}	{}	\N	\N	2026-10-15 14:33:16.305	default_user_id	2026-10-15 14:33:16.305	default_user_id	{}	\N	f	\N	\N	0	\N	\N	{}	{}	{}	\N	\N	\N	{}	default	\N	\N	0
657fd711a33fd728196c8f46601332faa1be29ab790130c524986a4dbf6b727e	sk-...EFJg	bank-agent-k8s-api-3	f	0	\N	{bank-primary}	{}	{}	\N	\N	{}	\N	{}	\N	\N	60	2	30d	2026-11-01 00:00:00	{}	{}	{}	\N	\N	2026-10-15 14:33:40.141	default_user_id	2026-10-15 14:33:40.141	default_user_id	{}	\N	f	\N	\N	0	\N	\N	{}	{}	{}	\N	\N	\N	{}	default	\N	\N	0
f1759977d11320e2aab83f94268f5976090fdb91de0b03f8eb7d2fd87a60cd61	sk-...oYpg	bank-agent-k8s	f	0.006898600000000001	\N	{bank-primary}	{}	{}	default_user_id	41649881-c262-402e-9754-b5c44ce947a4	{}	\N	{}	\N	\N	\N	2	\N	\N	{}	{}	{}	\N	\N	2026-10-15 14:31:01.641	default_user_id	2026-10-15 15:14:53.083	default_user_id	{llm_api_routes}	\N	f	\N	\N	0	\N	\N	{}	{}	{}	2026-10-15 15:14:53.084	\N	\N	{}	llm_api	\N	\N	0.006898600000000001
\.


--
-- Data for Name: LiteLLM_VerifiedSubject; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_VerifiedSubject" (subject_id, issuer, tenant_id, oid, kind, user_id, verified_via, verified_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_WorkflowEvent; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_WorkflowEvent" (event_id, run_id, event_type, step_name, sequence_number, data, created_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_WorkflowMessage; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_WorkflowMessage" (message_id, run_id, role, content, sequence_number, session_id, created_at) FROM stdin;
\.


--
-- Data for Name: LiteLLM_WorkflowRun; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public."LiteLLM_WorkflowRun" (run_id, session_id, workflow_type, status, created_by, created_at, updated_at, input, output, metadata) FROM stdin;
\.


--
-- Data for Name: _prisma_migrations; Type: TABLE DATA; Schema: public; Owner: litellm
--

COPY public._prisma_migrations (id, checksum, finished_at, migration_name, logs, rolled_back_at, started_at, applied_steps_count) FROM stdin;
00904808-f349-4062-b374-387babf8293e	35afca4826335f8bd2bc2b733c0540de51c6a199d39c27a2d1910c53e1a02647	2026-10-15 12:22:14.171505+00	20250326162113_baseline	\N	\N	2026-10-15 12:22:06.851345+00	1
882591d8-f973-42fd-a81d-53457ebbedee	48b046b5dcfe063869b28fd4c47ed4aa553707ccb02a42be276c43ae0d7cd612	2026-10-15 12:22:15.500655+00	20250326171002_add_daily_user_table	\N	\N	2026-10-15 12:22:14.260864+00	1
dcb098ba-8260-41d6-a7c0-bb57afd911ae	47ffc522eec4af95fc48c18d4f92b86a6dd6c755b2afb40dc4585b69ebd109da	2026-10-15 12:22:15.832612+00	20250327180120_add_api_requests_to_daily_user_table	\N	\N	2026-10-15 12:22:15.578117+00	1
b968de35-1699-4b61-a23f-acc072be8655	050f9d2bf329e99b1c294a5c137d73859dded58324af55696d5c7f51f7e281d4	2026-10-15 12:22:16.34161+00	20250329084805_new_cron_job_table	\N	\N	2026-10-15 12:22:15.911807+00	1
f8bc807c-b543-4a4b-ac8c-7bfbbeddcf50	049767abdd55f43520a1c2201a9a99f7356be451bec8c7e52895301fa0e2eb61	2026-10-15 12:22:16.585527+00	20250331215456_track_success_and_failed_requests_daily_agg_table	\N	\N	2026-10-15 12:22:16.40851+00	1
4abb802a-fde7-4c0c-a44b-44ab462ad70c	477ee9e678d0a6f4a3e97898b085a0dfb6ddd24730c28f46e68a700f37ee2d2f	2026-10-15 12:22:17.172945+00	20250411215431_add_managed_file_table	\N	\N	2026-10-15 12:22:16.629775+00	1
4d4ee0d0-05ca-4b2f-8ca0-42cfe472e1e9	67b629914bbb8f6fa26c52fac9fd4940a96e5c1371d76dbadc620de66a554244	2026-10-15 12:22:17.362019+00	20250412081753_team_member_permissions	\N	\N	2026-10-15 12:22:17.205886+00	1
8c9702d0-7e6e-4fa6-8874-60cc0a815e9a	bc904bdd0befbb6e2fb96b6f4bb7699d1c85518b85cce7f1822524d64d67c3ff	2026-10-15 12:22:17.78141+00	20250415151647_add_cache_read_write_tokens_daily_spend_transactions	\N	\N	2026-10-15 12:22:17.575718+00	1
a8d4b53a-983e-419f-9d9e-758d7c44ec86	f07d74cf601a93592bf6fb0cd732d21a261a23c461b4d64a5eb500b82f38e1c8	2026-10-15 12:22:19.354252+00	20250415191926_add_daily_team_table	\N	\N	2026-10-15 12:22:17.903918+00	1
2cfbfc6d-2a6d-47c1-a63e-74833d7c7947	7a4a9a98c40803f33f46ece325a233687df1d69402e7536b5e0ae3fb7cdb94d8	2026-10-15 12:22:20.704695+00	20250416115320_add_tag_table_to_db	\N	\N	2026-10-15 12:22:19.43228+00	1
5c5b6d46-daaf-42b4-bfda-1c5675bee739	e795d3fc96efff0b386425d5d1090319280317dd5954a01614f828a6e020302a	2026-10-15 12:22:21.016022+00	20250416151339_drop_tag_uniqueness_requirement	\N	\N	2026-10-15 12:22:20.760482+00	1
52d5746f-22ea-4975-91a9-7dd640449922	35377cad4aaf835bd319f56811c344d53654ea664216f39c15ddd20434c1b69c	2026-10-15 12:22:21.29174+00	20250416185146_add_allowed_routes_litellm_verification_token	\N	\N	2026-10-15 12:22:21.104068+00	1
97ce1856-999f-48d7-9430-7c2377074d9a	1cb236b5c18b69b62b58e8c92cb762cb0be309cfdf2bfd935733ba198673d726	2026-10-15 12:22:21.557458+00	20250425182129_add_session_id	\N	\N	2026-10-15 12:22:21.346899+00	1
ba3c658c-4243-4ae5-9d7a-d861c54c49f8	d89c388b45a1367f0ad93543e56bfeaa32a391ff8adf1c18ab74003635446261	2026-10-15 12:22:21.967345+00	20250430193429_add_managed_vector_stores	\N	\N	2026-10-15 12:22:21.61304+00	1
19f035d6-a8b1-49d9-a582-a3c94d6bdd11	f03c48cd15a994d4e6727cf4749ad27d52277da0d76561e9d7f50de94e8379b0	2026-10-15 12:22:22.620432+00	20250507161526_add_mcp_table_to_db	\N	\N	2026-10-15 12:22:22.056406+00	1
25c05ecf-80c0-4ef5-8189-f68e9b02a810	b0cb512a90b674c5531b2c722048c936efefe834b3050715483d1b9c3c195de2	2026-10-15 12:22:23.092397+00	20250507161527_add_health_check_fields_to_mcp_servers	\N	\N	2026-10-15 12:22:22.724901+00	1
a9740374-bffb-4ce2-9b02-72d792df87ea	3fc693f5dbdbb9968a6d95f2c940a04646b258eb671c70ff01bf4772e27e5979	2026-10-15 12:22:23.894592+00	20250507184818_add_mcp_key_team_permission_mgmt	\N	\N	2026-10-15 12:22:23.226388+00	1
f234d4eb-481a-425f-b67e-2ddfd449d4e8	ad1052154ae85e7a3beac99764f23ee50feb0eb745a0970935a471d5e730f433	2026-10-15 12:22:24.116599+00	20250508072103_add_status_to_spendlogs	\N	\N	2026-10-15 12:22:23.950122+00	1
d5106f9a-136c-4e71-b0a9-4b0b37a50ae3	50f6805ecaf21af5594ff4a739ffb5c87bb96ca3d356bda03f7cd8eb814a47ba	2026-10-15 12:22:28.549768+00	20250509141545_use_big_int_for_daily_spend_tables	\N	\N	2026-10-15 12:22:24.172405+00	1
77c68a0c-d5d7-4c6f-9953-766fc1ca3caf	f718b2a74f2a8529c079242e36330206a17b985d31d36e16fc31861090a74c93	2026-10-15 12:22:29.200742+00	20250510142544_add_session_id_index_spend_logs	\N	\N	2026-10-15 12:22:28.604603+00	1
763f75d6-e542-4768-b814-f1cc11650dc5	67fdce0f3f25d350bc661f8f32b747ee7cd3e18dab46a90f72ef7e46024098af	2026-10-15 12:22:30.326777+00	20250514142245_add_guardrails_table	\N	\N	2026-10-15 12:22:29.312492+00	1
9bd29067-9668-4f70-9d6c-a8c7a5afcee6	9f4099edfb29658b8330afec322d97f2f1233fae81946c51521bbdcde5bf67e0	2026-10-15 12:22:31.419701+00	20250522223020_managed_object_table	\N	\N	2026-10-15 12:22:30.393628+00	1
d76e6f74-4310-4dbf-9951-4e54c017c210	3bd0b7fd731a1d2e43aaefc346dca6f3d6e1b29022792422429c4ad4c4d06604	2026-10-15 12:22:31.795811+00	20250526154401_allow_null_entity_id	\N	\N	2026-10-15 12:22:31.508183+00	1
84025b14-1037-43de-8daa-b6e2fb0c7686	55939a32735a821668ea76cf37ad550e0f567225eec6d7595221a9f7445e5854	2026-10-15 12:22:32.160394+00	20250528185438_add_vector_stores_to_object_permissions	\N	\N	2026-10-15 12:22:31.862551+00	1
1192c051-18e1-43e6-9347-7ef8089b0bd8	c2eb9e521552dbb2f7f14652a7f0d66c892589745ef121c1799e06fa5bd53e2d	2026-10-15 12:22:32.513665+00	20250603210143_cascade_budget_changes	\N	\N	2026-10-15 12:22:32.259487+00	1
2bbdc481-69ee-4aec-94ee-3344c1962adf	9e8723ee10d9ce8c5dcad41da4bcb2f8db2d7cab415eff59eb3ecc38b698d2e9	2026-10-15 12:22:33.563572+00	20250618225828_add_health_check_table	\N	\N	2026-10-15 12:22:32.571756+00	1
3589f730-53e2-4ca5-b2b3-a5671562330d	4ae034e93702511a6641b53102836f239cfee44393703b4ac0be0a5849f69bde	2026-10-15 12:22:33.762412+00	20250625145206_cascade_budget_and_loosen_managed_file_json	\N	\N	2026-10-15 12:22:33.619863+00	1
3fa76171-e6b8-4b3b-93cb-4da3f4026484	a397ffbfaba32f88d7d453b28f24e3dc8dc240974926e0456d9eaab06fb34b09	2026-10-15 12:22:33.950489+00	20250625213625_add_status_to_managed_object_table	\N	\N	2026-10-15 12:22:33.807221+00	1
c6913c4a-1de6-432f-8bc0-4ead42631bb2	820dbb9d88eba37648b5e65c2beedfaa022276fc5a704a8fddafb5e36dcc9038	2026-10-15 12:22:34.34863+00	20250707212517_add_mcp_info_column_mcp_servers	\N	\N	2026-10-15 12:22:34.019262+00	1
6e7ce953-c266-472a-9cea-85e5b982a9f3	f345c94a2d1ba5250b8185f86068dc29c8cb1535f13cf5b670dc25f5fb03d2e6	2026-10-15 12:22:35.597672+00	20250707230009_add_mcp_namespaced_tool_name	\N	\N	2026-10-15 12:22:34.415801+00	1
56e968fd-4085-4827-9c08-407960b3a231	b1d0f71ed415833ebf31efbad070bc73e2fafce59ec148d3087071848d5282b9	2026-10-15 12:22:35.840972+00	20250711220620_add_stdio_mcp	\N	\N	2026-10-15 12:22:35.642326+00	1
5c9e8c8b-2f7a-4b3e-9892-5a6be0598c31	11655e562e501337d5b19c56e7d2785f9f3964c16d0bda4f701f9c26c4bedc8e	2026-10-15 12:22:36.040108+00	20250718125714_add_litellm_params_to_vector_stores	\N	\N	2026-10-15 12:22:35.896829+00	1
9a2f0e83-7803-4d3d-a7f0-b7a93a7e5512	bf163aaf3bcb043f81cdaba361207009399bc74e64417b30289f241206fd5dfd	2026-10-15 12:22:37.036144+00	20250802162330_prompt_table	\N	\N	2026-10-15 12:22:36.162253+00	1
82c07309-aec4-4b31-87a9-086440b93abd	0607b76d63bdea31615737631d7e6c0fb4b308b9ebad832affa8a5cc914043ac	2026-10-15 12:22:37.357273+00	20250806095134_rename_alias_to_server_name_mcp_table	\N	\N	2026-10-15 12:22:37.114987+00	1
253e2495-8bfe-48b1-8980-87ea700d2261	9bda666c0d3ce21746477a5a28c2b35a715579e9c55460c50dbc334d790aff1b	2026-10-15 12:22:37.62296+00	20250918083359_drop_spec_version_column_from_mcp_table	\N	\N	2026-10-15 12:22:37.457+00	1
da020356-b439-4c13-939b-115db2fe7079	425b6e795967c9f494c5a2d612d0d0d3203d263b843727941ce3a262064c398a	2026-10-15 12:22:37.811223+00	20250926194702_unnamed_migration	\N	\N	2026-10-15 12:22:37.668017+00	1
75601c6d-a7c1-45c8-9be1-2bf0b1741c7f	4f9c1595a2d6bddf693ec845058f9413aeffc8a6ea8b46b53566a36b6d93f1e2	2026-10-15 12:22:38.009584+00	20251003165142_add_allowed_tools_to_mcp	\N	\N	2026-10-15 12:22:37.854709+00	1
34c669f9-6ca5-471e-b78e-320196696a66	fe1ae32b28502546173d9345e4d55d05f9644f87750ba9e0a1b28c35c9291f51	2026-10-15 12:22:38.263943+00	20251003190954_extra_headers_to_mcp_table	\N	\N	2026-10-15 12:22:38.064764+00	1
e0c4a4dd-6fcf-4f3c-8bb2-eefedfb3f08f	6562a695c0bc052bfbb76da2ee4db808d6070e0c9e421d54ddf69bf943ec922d	2026-10-15 12:22:38.418845+00	20251006143948_add_mcp_tool_permissions	\N	\N	2026-10-15 12:22:38.30805+00	1
56fbb1fe-0cee-4830-8d1b-51a376ed7a74	aa1d44f4a4762cb046d6c1103fcbcb9bd43625188e864d76da236190289194b4	2026-10-15 12:22:39.094356+00	20251011084309_add_tag_table	\N	\N	2026-10-15 12:22:38.463133+00	1
4e35e5f3-52e0-480a-b50a-0a02519667a4	663483c4470c0ede72f80da33da2361d94bba8700387d748960dc20ea7785ccb	2026-10-15 12:22:39.725003+00	20251023141814_add_search_tool_table	\N	\N	2026-10-15 12:22:39.127764+00	1
0263966b-82a0-42ba-a154-76a56ee1806b	2f4cd52ea467195bd838bd8fc9df0ae1c443db0fe4985fa1a83a7032f9b36018	2026-10-15 12:22:40.289563+00	20251031181430_add_cache_config_table	\N	\N	2026-10-15 12:22:39.780332+00	1
8569bbd5-5376-403d-bc55-560615211285	95564113904a3f141e4470aa3dfc1f559e3d23a8a3f64e9986833d725ea83b28	2026-10-15 12:22:40.809085+00	20251101131415_add_managed_vector_store_index_table	\N	\N	2026-10-15 12:22:40.323345+00	1
3a78e623-c63d-4be9-855d-4ce4d6d89abb	5a06bdfc76f654b56cb4b6e6f7a8cbc8710d8bf8a956fbec315befa047c0851d	2026-10-15 12:22:41.053073+00	20251103072422_add_static_headers	\N	\N	2026-10-15 12:22:40.875793+00	1
9bc32ea0-f197-4e72-86e0-6e597d758651	d41ba79c0256b803302c6af066885c779a1b1ce5d697347fa8853871d851fc65	2026-10-15 12:22:41.307299+00	20251104220043_add_credentials_to_mcp_servers	\N	\N	2026-10-15 12:22:41.097691+00	1
6e110ab6-e8b7-406d-8827-b17dd504a374	f9ca207f007c9d80c433f918d6d432598614df5dc89ec7fc8d9effe5ebf23744	2026-10-15 12:22:42.005255+00	20251113000000_add_project_table	\N	\N	2026-10-15 12:22:41.362715+00	1
f1a24a45-6781-426d-9ecf-98957066c0ac	bb9657c76de699e4527516929492dbb173c2d800b242a5db30c1ff803f56a0b1	2026-10-15 12:22:42.204076+00	20251113000001_add_project_fields	\N	\N	2026-10-15 12:22:42.071448+00	1
a1bfc314-1254-4428-be70-1f490e848638	756a19475ebee069e8847fa65f3210ba7bb5b816929a477588c67dfa8adf743f	2026-10-15 12:22:42.569579+00	20251114173537_add_request_id_to_daily_tag_spend	\N	\N	2026-10-15 12:22:42.413164+00	1
bfb48167-3116-4dde-9439-191ffd64b00a	83ba27846dec4011f8b17df50b47cfb9200f6198c5398a47bf2c0be32fffd430	2026-10-15 12:22:43.798532+00	20251114180624_Add_org_usage_table	\N	\N	2026-10-15 12:22:42.614403+00	1
85bfcbe1-76ed-4df2-a1aa-5f3580e8f7ec	04abaf00e118987d0a9de36954f2fddc97c456e4af4f0e203b5141427743f33c	2026-10-15 12:22:44.484258+00	20251114182247_agents_table	\N	\N	2026-10-15 12:22:43.865386+00	1
2e5217ea-b9b6-4f9a-8b6a-8ec1a5df43bb	9796ddf9bc6994b507ff9f6a9e460a284230ab3f4dde4cd1a9224f21f08e19c5	2026-10-15 12:22:44.883117+00	20251119131227_add_prompt_versioning	\N	\N	2026-10-15 12:22:44.539926+00	1
e792dae5-faa9-44dc-9f4d-ede69d46f726	d2723db3432cddfb6f6e0cf85b14297fe0e2157fc4b8dd1e2f7819a740cccc36	2026-10-15 12:22:45.060354+00	20251122125322_Add organization_id to spend logs	\N	\N	2026-10-15 12:22:44.92756+00	1
987b2007-93b3-43c2-a9d1-35c14e900ce4	bc1914aefc7203fdcaadb7b70ae513b2e75bd72b268f5fde8e144caabb3a1b45	2026-10-15 12:22:47.008826+00	20251204124859_add_end_user_spend_table	\N	\N	2026-10-15 12:22:45.10516+00	1
d3eac2d8-833f-41fe-8ea3-28b4c32605cb	86038393c8ebaf7bb60df05dfa7024a17fe8c03aa7fac858beaaf8f07ec753bc	2026-10-15 12:22:47.384894+00	20251204142718_add_agent_permissions	\N	\N	2026-10-15 12:22:47.088776+00	1
bf0a9e2f-fdbc-4822-9c6d-1123cc3517fb	3ad6c3f157817a4b3d37832d0e0cb78455a50466315c20e6462f07ccd166f882	2026-10-15 12:22:48.07148+00	20251209112246_add_ui_settings_table	\N	\N	2026-10-15 12:22:47.463209+00	1
2f485ff3-be01-496a-83bd-6bd855048e44	2b23aa2aee91f35133eb0e38e413c5979df9ff9949d57ac70550a5a17ad1a53f	2026-10-15 12:22:48.337271+00	20251210125210_add_storage_backend_to_managed_files	\N	\N	2026-10-15 12:22:48.140044+00	1
c0cdecf5-ee7a-460f-a387-09a4c80326b7	43177e6394f79b21baa869588551f62b41349536239891113d3016eae7552353	2026-10-15 12:22:49.478206+00	20251210205007_add_daily_agent_spend_table	\N	\N	2026-10-15 12:22:48.403803+00	1
d4b444e9-e286-4ac9-98c5-47e3b54f0b28	375bcf8045e6cacdaeeca5e120516aa9bd57743e926f48cad66dbaeb09f6ad57	2026-10-15 12:22:49.755325+00	20251211100212_schema_sync	\N	\N	2026-10-15 12:22:49.545313+00	1
24bd48c2-06ba-459c-82ed-dc7aa84735a3	3b3de59c965b5fec61886f09fa0c3e406c1d1194b8674353ea4b7baac3cba3af	2026-10-15 12:22:51.57188+00	20251219110931_add_deleted_keys_and_deleted_teams_tables	\N	\N	2026-10-15 12:22:49.845465+00	1
e8c97fc0-d926-4c64-8b7c-471f6580516b	8e219b15b4e476b22c1716992fd513152039de1c5951a0ac694d1ffba26111b3	2026-10-15 12:22:52.102805+00	20251220144550_schema_update	\N	\N	2026-10-15 12:22:51.639148+00	1
33be08d0-daae-4de0-8118-d2b88c8d9264	eee02bb2a33b6bdf324081d9006f8da5f1298a0c7f8fa4ae52391d4b3fdd2d2e	2026-10-15 12:22:52.412885+00	20260102131258_add_metadata_urls_to_mcp_servers	\N	\N	2026-10-15 12:22:52.157921+00	1
32036034-c9fc-4f5b-a449-c3f4cb531aeb	b28ffa7014e196d4b1a8e7d52371be91d5633a6b661f0e5e6346b3fc18fd6456	2026-10-15 12:22:52.666739+00	20260105151539_add_allow_all_keys_to_mcp_servers	\N	\N	2026-10-15 12:22:52.500869+00	1
d3b956d1-da28-4b30-bb41-32d640c5be2b	ccfeb894b1fab623593531f189dcd0c098352f9c65c407cb70d2ea9a6086a656	2026-10-15 12:22:54.928003+00	20260106155622_add_endpoint_to_daily_activity_tables	\N	\N	2026-10-15 12:22:52.711636+00	1
409396de-a705-4571-842f-628bab1a1395	9aebf31dd752cf36c8f084d00053ff83af52bf45845549cbb9cb901147d8f2d5	2026-10-15 12:22:55.171341+00	20260107111013_add_router_settings_to_keys_teams	\N	\N	2026-10-15 12:22:54.971807+00	1
191c0458-b8d4-4716-bd29-cecd89ff19bb	3cb5404a0f325ccf199bb63b283e4da752d97c5012c736cb9cd00755f8ebae03	2026-10-15 12:22:55.525864+00	20260108_add_user_email_lower_idx	\N	\N	2026-10-15 12:22:55.215515+00	1
b246e998-90c6-447d-9e38-027d359cac0e	b73e82dcb5dd5607c3635a651f7fbc7d7b9d943504e28e4ae58384d3c970706f	2026-10-15 12:22:55.724681+00	20260116142756_update_deleted_keys_teams_table_routing_settings	\N	\N	2026-10-15 12:22:55.592222+00	1
adaf5372-3931-4f37-b5bd-78e0016ed96d	45714f4a2e87eb33b7ef53a5320235b5cafc8a0cc307b00743e74dae6719ea67	2026-10-15 12:22:56.740209+00	20260123131407_add_policy_tables_and_policies_field	\N	\N	2026-10-15 12:22:55.7693+00	1
42cefb61-851a-4dfc-a411-656e42fb80d3	547773d84d26f9f215bd7d2674ed404811e541358755220bb716c0b97c81fe86	2026-10-15 12:22:57.335778+00	20260131150814_add_team_user_to_vector_stores	\N	\N	2026-10-15 12:22:56.784705+00	1
1e00ba79-7e63-41fe-ad24-016666b10f09	3dc7d10d308db8101ff1b79a92aff63348f3a686736d4bed672c02c8e8ceb3cf	2026-10-15 12:22:58.560225+00	20260203120000_add_deprecated_verification_token_table	\N	\N	2026-10-15 12:22:57.404274+00	1
737ab5b5-6ef6-4f0b-86ac-75e8bd03d69b	1d364b454c528c4662780cc4a0ddb12f4c18e82b5eebc83a72fd4429ff367aa1	2026-10-15 12:22:58.736586+00	20260205091235_allow_team_guardrail_config	\N	\N	2026-10-15 12:22:58.604641+00	1
a26edf6c-2b5e-4a39-8d22-038e90288a55	f1f3c7982ff5ff7f55b064d247cc39ce39e882c7d02abf621669e1b76e437442	2026-10-15 12:22:58.935418+00	20260205144610_add_soft_budget_to_team_table	\N	\N	2026-10-15 12:22:58.781181+00	1
bc7d79c2-051b-4e35-ac76-a651e738ee51	bdb5f1a12ad5eb20c962d03bfd05d6aee6fce92cfd50972d61864856753b0e3a	2026-10-15 12:22:59.19001+00	20260207093506_add_available_on_public_internet_to_mcp_servers	\N	\N	2026-10-15 12:22:59.02401+00	1
b71e2060-63f4-468e-9a7e-c2b047648eff	f7c32024cf470b46700be73100dc1e08010942989e908ceb12a5b0e72f95fb5f	2026-10-15 12:22:59.44312+00	20260207110613_add_soft_budget_to_deleted_teams_table	\N	\N	2026-10-15 12:22:59.233387+00	1
89a659a8-83c0-48ee-868b-756312617f40	3cea96b5d541ed36ab8bd027ea3a05094ee235ae9867228aa2fb04c3723fb324	2026-10-15 12:23:00.149343+00	20260209085821_add_verificationtoken_indexes	\N	\N	2026-10-15 12:22:59.531672+00	1
b3b61b1d-97c8-4f95-8f0a-1c40dd5fdc4b	a782f25b1d9fef4048b24e768f076cabee428060151761cbb9331efa78686ee7	2026-10-15 12:23:00.326176+00	20260212103349_adjust_tags_policy_table	\N	\N	2026-10-15 12:23:00.193362+00	1
ceca0dbb-fd98-481c-8d2d-dc217d93ff31	c245f807fcfd72bf80d438f1459fa60c9d4fb445990b154b5ed1bb0fa9ba1872	2026-10-15 12:23:01.010861+00	20260212143306_add_access_group_table	\N	\N	2026-10-15 12:23:00.425736+00	1
b12560a7-a939-4f9d-88c9-d538f395466e	5ac7e8b6bfb25f1a6d931d545e32929108c76612e73eae2e806ea18058d42ecc	2026-10-15 12:23:01.994268+00	20260213105436_add_managed_vector_store_table	\N	\N	2026-10-15 12:23:01.089244+00	1
70d15d78-075c-4a13-9770-98ba8dfbbf2d	153e085303ec6c02df5d6fc44a152a853a33b498a252b3c8b1c48056a8da231a	2026-10-15 12:23:02.226195+00	20260213170952_access_group_change_to_model_name	\N	\N	2026-10-15 12:23:02.062088+00	1
b22c3a7c-1acf-43c5-93f2-11bb4f5fe62d	7269a6d0c0734aced27e3cbcc5841fce76f2f9990b2d44dbcba886f0188e7171	2026-10-15 12:23:02.469174+00	20260214094754_schema_sync	\N	\N	2026-10-15 12:23:02.304694+00	1
72beeb70-26b0-4d4f-b360-56ee4fbbcc65	ec5ae74d2da8fcc40a42d7f48b2e4ad951677f4e4988a5d52af3665ad54b5e72	2026-10-15 12:23:02.81309+00	20260214163027_add_pipeline_to_policy_table	\N	\N	2026-10-15 12:23:02.590909+00	1
276d82a6-4bd9-4241-8a04-9748ff9afae1	be60adf5a2b5cee92eed4e17e2d213d0a12c1debd55a637e7ba05e3a234bb2b3	2026-10-15 12:23:03.121215+00	20260214185341_object_permissions_for_end_users	\N	\N	2026-10-15 12:23:02.889349+00	1
b2b6306a-97a6-4eaa-b940-6b6dcc4b6349	7f63ab0118b1e6582eb284dd957c708ff77efe0463219f895a2dee48f0beb6e3	2026-10-15 12:23:03.365773+00	20260218231534_add_last_active_to_key_table	\N	\N	2026-10-15 12:23:03.223091+00	1
e2592b56-f8b2-4bf8-a3dc-78ca94cf8cbf	a8a34c4f3f2e5db16ee907152ebf836f5a63aea777798a66069c8af7997869a4	2026-10-15 12:23:03.541219+00	20260219105005_add_project_id_to_deleted_keys	\N	\N	2026-10-15 12:23:03.408727+00	1
ab61235a-e4d5-4808-989b-992174b99e14	ecbd073ba23472f98ede77177d4318abb9ae0958bae691ed3939dead91bd299e	2026-10-15 12:23:05.686543+00	20260219181415_baseline_diff	\N	\N	2026-10-15 12:23:03.5857+00	1
35181cf3-de02-4684-b81c-e921ab679c55	e49454e7f5be2ba0e46da7e5be61900942398f971dcfb0ab70ff4fcef9cfd50e	2026-10-15 12:23:05.863433+00	20260220124742_add_spec_path_to_mcp_servers	\N	\N	2026-10-15 12:23:05.730435+00	1
9d24ed95-714e-4550-b8e6-d41421d308b3	3f509af1ecb34b350a56f8e35ef47944541f487ddf5033e70f05c2f0ebcc0615	2026-10-15 12:23:07.290955+00	20260220153844_add_composite_index_aggregate_tables	\N	\N	2026-10-15 12:23:05.907998+00	1
837be305-255b-4189-a0e2-1b83510a2321	c6e0c6f91022ecb66af31eb3778913a2313b1b8270dd7f241681abf354ce306d	2026-10-15 12:23:07.665582+00	20260221000000_ensure_project_id_verification_token	\N	\N	2026-10-15 12:23:07.378988+00	1
080db408-21ab-4241-8c2f-bcc719ae4808	7f3f29b50badc248a70f5a4aaee3ed06d933e1ad8ebaef543338a6cb816faf4b	2026-10-15 12:23:08.617242+00	20260221183800_add_policy_versioning	\N	\N	2026-10-15 12:23:07.743213+00	1
fd1a1825-b5ea-47d3-9f71-56cd6b89bf5b	70826378aec43d18575c23e83417bc11455a267104eb0909918a96a24118ba55	2026-10-15 12:23:08.904539+00	20260222000000_add_batch_processed_to_managed_object_table	\N	\N	2026-10-15 12:23:08.694661+00	1
0a6706bc-c08a-4584-9ecf-946b4d44d511	bc0cb6ca3c8f432c0b32ad128fa3667ed991245b672e62e9fd18ca34552482ee	2026-10-15 12:23:09.226073+00	20260224201417_spend_logs_request_duration	\N	\N	2026-10-15 12:23:08.982223+00	1
dfff4298-e5ab-4080-b220-b64287a46661	c7d02b13901092b4f9bcc4eac1102f23ba8d639ed3fa9745277647df904afb92	2026-10-15 12:23:10.056722+00	20260224203854_add_agent_object_permissions_table	\N	\N	2026-10-15 12:23:09.292418+00	1
9a0a6d4f-2f3d-4505-8c35-66bdaf99fdc9	855545571013964f192ec7d066c001392d2778c47ad1306c974322cc4ad7482f	2026-10-15 12:23:10.211486+00	20260226000000_add_blocked_tools_to_object_permission	\N	\N	2026-10-15 12:23:10.101678+00	1
b5375e19-6f1a-4187-9020-63bdb051ec87	019ae3e4e71f35763d6d515e1d463d97e75b8c50e7637c842e4e16ce59009a4b	2026-10-15 12:23:10.742688+00	20260226120000_add_spend_log_tool_index	\N	\N	2026-10-15 12:23:10.256335+00	1
c9a33622-7d7a-4f92-ad81-42ebb69ed3ff	67af990c525e2160cbda0c759d6992ccbfc4b228313c2439b3b47f93c5c4c13c	2026-10-15 12:23:10.89743+00	20260226202727_add_agent_id_to_delete_keys	\N	\N	2026-10-15 12:23:10.786602+00	1
0cb68272-27dc-46c8-af66-b77b5a950bae	97f41d1817251781594a1dbf5d812f1a860ff21da79d11e914d5151179481fd4	2026-10-15 12:23:11.461645+00	20260228000000_add_claude_code_plugin_table	\N	\N	2026-10-15 12:23:10.94185+00	1
a24fb474-5e39-448c-b035-b176aaa07bbb	7ece8b0cdb67336e9914f87882bcc804ada60de54a715f10175a9450748d6cfa	2026-10-15 12:23:11.797167+00	20260228100000_add_spend_logs_composite_index	\N	\N	2026-10-15 12:23:11.539484+00	1
74145bc6-7069-4995-ad33-6cc240b4be56	e007fdb13fe6128d5ac59ae7e7c4b92b08a147a38a44ddcf518dbe94d3904726	2026-10-15 12:23:12.081439+00	20260228110000_mcp_default_public_internet_true	\N	\N	2026-10-15 12:23:11.882324+00	1
687009c3-d2d3-483c-b9bb-438904fd032b	3610ed4728cd666030881bc61380441901e65a0705296ed255a1bc5001bf6457	2026-10-15 12:23:12.524149+00	20260228170127_support_team_based_guardrails	\N	\N	2026-10-15 12:23:12.13921+00	1
18dae7ea-2d11-4afb-805e-555a99570536	e85f13e8222e6aa682cf1c8e8af45823bf480d85446893c71d77fbea18adcd61	2026-10-15 12:23:13.078488+00	20260303000000_update_tool_table_policies	\N	\N	2026-10-15 12:23:12.613945+00	1
9fbc9782-2748-4390-8058-ed0f191716db	cbdcbf988896f0ba08bc774f345f550ea3c784c4bc5eda872af093be346cc84d	2026-10-15 12:23:13.322063+00	20260304175016_add_spend_to_agent_table	\N	\N	2026-10-15 12:23:13.133773+00	1
11b1df42-f3a1-4a28-b951-4485284f2fab	225bc1c1da92e33d0088e7703fe786430da76cc631317eaef1d4aecc520f8262	2026-10-15 12:23:13.531958+00	20260305000000_add_agent_headers	\N	\N	2026-10-15 12:23:13.400579+00	1
103c203f-7ddf-4c7b-84ee-7e444e139d43	ebe9b00cdbe4225e49f9bba8d0dcf1e22dc7b43f63bb5ccebc8fdde76f227f14	2026-10-15 12:23:13.698498+00	20260305000000_add_rate_limits_to_agents	\N	\N	2026-10-15 12:23:13.576331+00	1
cd03d326-2021-42fd-95ad-dea91136f8ae	f4b1682d40d1999b98215a0677481980372e4cb5659d071e878a343a7a65944b	2026-10-15 12:23:13.886873+00	20260306175056_add_configs_override_table	\N	\N	2026-10-15 12:23:13.731446+00	1
6cb4d73c-2957-4033-aaf1-833fd191d924	1fac2f1e9d937b170c06b7828f3de1290d056287d81901b03c174d75bf1e0604	2026-10-15 12:23:15.168616+00	20260306233848_schema_sync	\N	\N	2026-10-15 12:23:13.940775+00	1
9129321f-12e0-401e-ac34-81239ca56292	69c77e41e45c3f24f50bfccc2801795aa9ecbdada2cc35263f1977a81457d55a	2026-10-15 12:23:15.41255+00	20260309000000_add_mcp_approval_status	\N	\N	2026-10-15 12:23:15.203314+00	1
14b74bab-60ee-454a-84b6-6c320bf77727	cbf048fe8db758b349f53a1d4e25107d354a41c3aa9080bb1d5a091343e125b0	2026-10-15 12:23:15.734901+00	20260309000001_add_mcp_source_url	\N	\N	2026-10-15 12:23:15.457678+00	1
534967a3-3c14-44b0-8fad-473cf40bf301	62bc045f03c1393c83743262d885693297f891b879bcbf11c749c588e005525b	2026-10-15 12:23:15.888591+00	20260312124619_schema_sync	\N	\N	2026-10-15 12:23:15.778525+00	1
054d6869-ab5c-4f95-9f42-b7f74dc8ab4c	6d2aa9c28c9c3de83bd5f6cee2bdc6a2b671f348ca8dee58dfc7ffd2abf831cb	2026-10-15 12:23:16.596882+00	20260318140652_add_index_to_team_table	\N	\N	2026-10-15 12:23:15.93373+00	1
faa6a90f-8f96-4f95-98e4-72c77cd7430d	552e04c0e6590ef1b2e9d0e1a181e3c98d83581ae57ab4e292aafa76a54af1fb	2026-10-15 12:23:16.818285+00	20260319000000_restore_mcp_approval_fields	\N	\N	2026-10-15 12:23:16.66584+00	1
e3d738aa-d41f-4da7-899d-fdfff827c837	4b151c1a923781877f3666157d5463a1e0c565dad6c20e73eb8840b76c5bf9a0	2026-10-15 12:23:17.361154+00	20260321000000_add_mcp_toolsets	\N	\N	2026-10-15 12:23:16.874263+00	1
e2c52f21-6859-4cb1-b783-da2de588a56e	b49bdecc8510bbe30eb3810761cbde182a37575cd012e38fff60829a3c32e8a7	2026-10-15 12:23:30.536364+00	20260418000000_add_adaptive_router_tables	\N	\N	2026-10-15 12:23:29.741291+00	1
ee04101f-4ccd-4c24-be67-95841e96a028	52db3f7f88c3073debc15024e2d3c448a294510531d5189a9fe7d6cbfc44756b	2026-10-15 12:23:17.871379+00	20260331000000_add_prompt_environment_and_created_by	\N	\N	2026-10-15 12:23:17.450565+00	1
c28a93eb-6397-41a7-b7e6-5ae54a4e58be	ef1161b00f477701b08b9868c8ca4b41266765a946c3adda8530d810db7bc7c5	2026-10-15 12:23:18.113874+00	20260401000000_add_budget_limits	\N	\N	2026-10-15 12:23:17.914411+00	1
c62e7a30-28d8-4a4c-afa4-4fe80b4e3a53	4872cb4220d148cc96b4a17e8673566891ebdd804a576112db705147bc9c1a2f	2026-10-15 12:23:18.379528+00	20260401000000_add_team_member_model_scope	\N	\N	2026-10-15 12:23:18.191323+00	1
652e9df2-a4c1-4eca-8109-531bb6b1789b	a39a409b748dc9c65ab7f182cc668d21c89a8489f1859899056fab60a7c8ba1e	2026-10-15 12:23:31.541923+00	20260421120000_add_memory_table	\N	\N	2026-10-15 12:23:30.580995+00	1
47fe0e37-957f-4f75-a4a6-12a23dd23ee1	076b759528c1065b535472c6694bbdeb7d6b0b5446f3df26ea68aac3294c49b1	2026-10-15 12:23:18.634388+00	20260414140000_add_mcp_server_instructions	\N	\N	2026-10-15 12:23:18.424185+00	1
fb6a94a8-f8fc-4fcb-b85d-2efd2f429ad5	e5dce697bc2b61744f058f64892ebd7ef4112a46fc82ba42cd6104785e977ccb	\N	20260415120000_health_check_latest_per_model_index	A migration failed to apply. New migrations cannot be applied before the error is recovered from. Read more about how to resolve migration issues in a production database: https://pris.ly/d/migrate-resolve\n\nMigration name: 20260415120000_health_check_latest_per_model_index\n\nDatabase error code: 40P01\n\nDatabase error:\nERROR: deadlock detected\nDETAIL: Process 130 waits for ShareLock on virtual transaction 10/16; blocked by process 259.\nProcess 259 waits for ExclusiveLock on advisory lock [16384,0,72707369,1]; blocked by process 130.\nHINT: See server log for query details.\n\nDbError { severity: "ERROR", parsed_severity: Some(Error), code: SqlState(E40P01), message: "deadlock detected", detail: Some("Process 130 waits for ShareLock on virtual transaction 10/16; blocked by process 259.\\nProcess 259 waits for ExclusiveLock on advisory lock [16384,0,72707369,1]; blocked by process 130."), hint: Some("See server log for query details."), position: None, where_: None, schema: None, table: None, column: None, datatype: None, constraint: None, file: Some("deadlock.c"), line: Some(1130), routine: Some("DeadLockReport") }\n\n   0: sql_schema_connector::apply_migration::apply_script\n           with migration_name="20260415120000_health_check_latest_per_model_index"\n             at schema-engine/connectors/sql-schema-connector/src/apply_migration.rs:106\n   1: schema_core::commands::apply_migrations::Applying migration\n           with migration_name="20260415120000_health_check_latest_per_model_index"\n             at schema-engine/core/src/commands/apply_migrations.rs:91\n   2: schema_core::state::ApplyMigrations\n             at schema-engine/core/src/state.rs:201	2026-10-15 12:23:20.637839+00	2026-10-15 12:23:18.713004+00	0
f7916369-2f49-411b-87cc-d765bb89a4cf	e5dce697bc2b61744f058f64892ebd7ef4112a46fc82ba42cd6104785e977ccb	2026-10-15 12:23:29.696547+00	20260415120000_health_check_latest_per_model_index	\N	\N	2026-10-15 12:23:29.609844+00	1
c66ea9e6-7997-4e1f-a21e-7f184e00852f	686be79c5c68c056c7473f27374767ae6c952fe09e95ea7b8dd13047a09fad8b	2026-10-15 12:23:31.818008+00	20260421135425_add_team_membership_total_spend	\N	\N	2026-10-15 12:23:31.641795+00	1
266d75a1-0b7e-469f-9e5d-a3378cebfc84	dab418bc243b4a928ca2fca2a49621900c1d2223fde0aa5c9c6027ca2d8b5558	2026-10-15 12:23:32.149562+00	20260429120000_search_tools_on_object_permission	\N	\N	2026-10-15 12:23:31.895919+00	1
82efd2f6-73a1-4b9d-bd6b-5f246ffec5ef	6293c4f78ea52d9e64503a0b284e9da960dd6351ffe2210b74ec5494607c6f67	2026-10-15 12:23:35.034645+00	20260429161855_workflow_runs_tables	\N	\N	2026-10-15 12:23:32.195058+00	1
68237465-fec8-4e92-983f-c85248e49e8a	70a413cf659a8263cc4cc3d90942fa13c11569f6a29dac63aabfe53791ea7f57	2026-10-15 12:23:35.698686+00	20260501195714_managed_resource_team_owner	\N	\N	2026-10-15 12:23:35.090742+00	1
69b4b8a3-1415-4a4e-bdc6-a0442401b2d6	8edde816aef67759bbdb455276a3aa02e15e2e96892d8623cdb58092d393992e	2026-10-15 12:23:36.087095+00	20260513120000_add_delegate_auth_to_upstream_to_mcp_servers	\N	\N	2026-10-15 12:23:35.779559+00	1
00c35ed3-56f1-4dc2-9947-3f18fe480d4e	6079a465b829311a62c9fccc9c15447754841e683b3862551819d02cc59868fc	2026-10-15 12:23:36.428529+00	20260514120000_add_blocked_to_proxy_model_table	\N	\N	2026-10-15 12:23:36.174286+00	1
8673fb9e-6b59-48b2-9654-5f6c160bae72	b1884c51b26eaf06412782635b88f7073efbf8a93c4a6b647eb1f504e53e7bc6	2026-10-15 12:23:37.733845+00	20260520120000_add_mcp_env_vars	\N	\N	2026-10-15 12:23:36.528045+00	1
7da63847-1c4f-4443-9879-f23efa39fc10	12fc51a97ad28eb8c2f69841ee25d30f3f394b73f689d99952adb5a8db2de224	2026-10-15 12:23:38.0432+00	20260526120000_add_oauth_passthrough_to_mcp_servers	\N	\N	2026-10-15 12:23:37.812254+00	1
c8220fca-8d45-4698-9c83-dd9ec4fe0031	37a30575e319fe6d071ae0169f920822af0cd1dc98bce17a60afa21548dd6aa0	2026-10-15 12:23:38.354219+00	20260604120000_add_oauth2_flow_to_mcp_servers	\N	\N	2026-10-15 12:23:38.117918+00	1
f73b866e-721e-4a97-bed5-a15edbf6342a	04ad0398ccf6dc0c03a1f1520f4461b7fe34347654f81d19a2a3bef8e8ef2e89	2026-10-15 12:23:38.862264+00	20260605182307_add_timeout_to_mcp_server_table	\N	\N	2026-10-15 12:23:38.453+00	1
8a4f1123-e58a-4691-b813-c9e583a414f2	58ba614cb29ed40b724f02a5657b1eb04294c528f55c889413fa1b4f8e1a0a2b	2026-10-15 12:23:39.16071+00	20260626120000_add_mcp_tool_search_enabled	\N	\N	2026-10-15 12:23:38.939015+00	1
44a99ca3-102e-4adf-8170-c8cf4e38f897	ab8e6e84af7b3080d559c5e2023752b7f1bd69c94111284fe1d878bcdf4458ea	2026-10-15 12:23:39.636329+00	20260629000000_add_max_concurrent_requests_to_mcp_server_table	\N	\N	2026-10-15 12:23:39.390433+00	1
34cba944-adb4-47c2-acbd-f628a6509e9f	ddc9a89115f25ec043b6dfd46eff43e37289db55ab3e82a74290660d308a0399	2026-10-15 12:23:39.924355+00	20260630120000_add_token_exchange_to_mcp_servers	\N	\N	2026-10-15 12:23:39.725086+00	1
4754061f-a285-4de8-899e-9a950f5cb7df	e505c9f94735b209b790293b0a02e14a9b7fd306d144c0d6138190874105e02e	2026-10-15 12:23:40.201049+00	20260630190000_add_budget_fallbacks_to_litellm_verification_token	\N	\N	2026-10-15 12:23:40.012699+00	1
10591ef5-aa2b-4710-882d-2b4dc7e0b72c	c17998f21e0122401c7f3e4d11f02b7c3924da6ae9a0f5a17bb4920d7b5b3ccc	2026-10-15 12:23:40.49937+00	20260703120000_add_token_exchange_profile_to_mcp_servers	\N	\N	2026-10-15 12:23:40.245742+00	1
25ab6be1-97ff-4215-80cc-86b79aeaa0d3	8071e33b4af00586d53adfecfac43a6ce3ece46aadabc306e43083c8c429faa4	2026-10-15 12:23:40.820431+00	20260710000000_add_dcr_bridge_to_mcp_server_table	\N	\N	2026-10-15 12:23:40.599712+00	1
0cfb066c-76da-467e-a87f-bc84062151a4	b8b667c881330111a4f034e20d489b962b2c7599ca8ebbd54cadfcb9e7446076	2026-10-15 12:23:41.008913+00	20260713010000_add_ptu_columns_to_daily_team_spend	\N	\N	2026-10-15 12:23:40.864459+00	1
a54cf08d-b1bd-4dbb-abcc-523660a31c7b	e8cf45e1f2aab2ddaad1d53cd67f518e08f803b409ccac210a9c3a3e8c6a03f5	2026-10-15 12:23:41.359007+00	20260713230852_add_key_type_to_litellm_verification_token	\N	\N	2026-10-15 12:23:41.064623+00	1
96c08015-0937-42b6-a87b-95faf8bc11c6	bb5a30704d0ff8a32635b757a34027d84170ec0ad114bcaf1ca71e771f57b19a	2026-10-15 12:23:41.672182+00	20260715000000_add_issuer_to_mcp_server_table	\N	\N	2026-10-15 12:23:41.439849+00	1
ef26f7fd-70e9-41a1-a8d0-2b2071cb1ffc	3bd9818383657f7399aa7e5b5acb8743f3d684063cad4e0f962927f8574eefe0	2026-10-15 12:23:42.060241+00	20260717000000_add_compression_saved_tokens	\N	\N	2026-10-15 12:23:41.751631+00	1
7a1ffb21-150b-4a51-8c18-ff0c082916cf	9d9b8d465b5c7974d73798f07b74496a5ff5a615e9fc646c8eac3651f50eb94b	2026-10-15 12:23:42.823198+00	20260717000000_add_mcp_server_oauth_client_table	\N	\N	2026-10-15 12:23:42.137813+00	1
a6c9f248-3a59-46f3-8596-93c242b11f47	a9d57b2cfb9e268734ed4d43786f3423f333c51d8f6f698ec4a3b1ffb77c446a	2026-10-15 12:23:43.133597+00	20260717000000_cascade_delete_jwt_key_mapping_on_token_delete	\N	\N	2026-10-15 12:23:42.912043+00	1
2a09a36d-129e-49e7-a5a6-ed879daa3cf2	09d40b5beacaf2c2bf1c73da2fe0e67e2812e3fd6ee1977c47ae9417eda0667d	2026-10-15 12:23:43.520933+00	20260718000000_add_savings_spend	\N	\N	2026-10-15 12:23:43.221978+00	1
0dab0a76-d46b-4e01-83a0-d0dce7e40f81	61df604554a40f55fd44a1f94d20b154eea3d10bc83a399d64ed42a784a37e71	2026-10-15 12:23:44.152758+00	20260721000000_add_sso_identity_assertion	\N	\N	2026-10-15 12:23:43.567209+00	1
03d47b3a-acbd-436d-baee-cfe9221c8128	3a73fe2955610df1fd635e2ab4ffb33004db5d0c03221eda799ac45455d7af09	2026-10-15 12:23:44.639717+00	20260724000000_add_spend_log_tool_index_start_time_idx	\N	\N	2026-10-15 12:23:44.233149+00	1
06b2005a-a875-4723-a0db-c84d248310c1	626702edb86035095d6ae9cd21ee218bc7ed98267c2472a9918b1f7057957ab2	2026-10-15 12:23:45.258647+00	20260725000000_add_daily_tool_spend	\N	\N	2026-10-15 12:23:44.705027+00	1
4e4c5ed5-8b8a-42c0-817a-5d596b60a3c3	c2b92f39fc51fc9a23ebc90eebc648e5cd1eaa70fcc92db7bb43cf1b6d9a2e7e	2026-10-15 12:23:45.546199+00	20260729000000_add_reload_tracking_to_litellm_config	\N	\N	2026-10-15 12:23:45.32487+00	1
bdfdb97b-3a00-4546-ae22-0246d92a38d2	dbfd2ddf670c8ee0d6016c38db9858334d2593f739e0778ccf60691e645819e1	2026-10-15 12:23:45.756648+00	20260730000000_add_api_key_and_request_tags_to_managed_object_table	\N	\N	2026-10-15 12:23:45.601072+00	1
38de5e8a-64ed-467d-9423-383699f9593f	7bb2048d3377d9a237a5650f757992aada6bc9d88a003b326d283397541f330e	2026-10-15 12:23:45.955803+00	20260731000000_add_autorouter_savings_spend	\N	\N	2026-10-15 12:23:45.811468+00	1
30ec5cee-6dd7-4e95-9ef4-3d048571888e	d052bf6f7fead1abbe9dce9b7adda7a6497acd685321f91b819ecd1ac34eb551	2026-10-15 12:23:46.8309+00	20260803000000_add_daily_gateway_requests	\N	\N	2026-10-15 12:23:46.001187+00	1
eb802642-4fd4-4227-80af-59d684528946	ea19ecfef5e181f8b4ac20d9e5baeb241c2d10a793de3c50cfc24b69ca600774	2026-10-15 12:23:47.472299+00	20260804162853_add_budget_window_spend_table	\N	\N	2026-10-15 12:23:46.918609+00	1
e7c26d65-f699-4405-aa81-ba8f8c7d5347	25607951a7a70e13670a7209c1b711cf22e758b441028b4ce6d9e76c662d184f	2026-10-15 12:23:48.025367+00	20260805000000_add_autorouter_session_rollup	\N	\N	2026-10-15 12:23:47.550558+00	1
0da9faed-ae6e-4293-8a81-808a08a6e81c	22e5b257dcd2d8695f9b76eddc5f6543a245fdcea14bf5ba6f0643eebb988a54	2026-10-15 12:23:48.357529+00	20260807000000_add_autorouter_session_tier_turns	\N	\N	2026-10-15 12:23:48.10326+00	1
7aca586b-2f7a-40ea-abab-69ba741ccbc5	420c8634a5febc76b118fcb9295b0dfd73579d58396ac85746f4098c46d34739	2026-10-15 12:23:48.579354+00	20260810000000_add_verificationtoken_settings_updated_at	\N	\N	2026-10-15 12:23:48.435147+00	1
aa8e22d6-2532-497c-aa3c-f8736729ba23	03f670e91b8586922d1a6e8460274697eb73bb365ecdf26eea0727b16b8ba05a	2026-10-15 12:23:49.886002+00	20260811172448_add_shadow_eval	\N	\N	2026-10-15 12:23:48.634532+00	1
6073356b-ea7f-45ef-b36b-06c48385f534	cca1fa5a90e74f31902714b7ef8c147712b6c889f82effb6491a226abbc34f9b	2026-10-15 12:23:50.218158+00	20260813180408_add_shadow_eval_direction	\N	\N	2026-10-15 12:23:49.93007+00	1
0101663a-6457-461f-bfe7-6647831ec23c	7b042b28a4b8bfa74ad9e439b2aca4c85ab6e0de707a5f115d8caae287aba059	2026-10-15 12:23:50.915734+00	20260814000000_add_proxy_worker_heartbeat	\N	\N	2026-10-15 12:23:50.306839+00	1
6a55502f-cf40-447e-be42-50355662423d	b979459e5949f3731ac4ec029665748e312f8420a6756c9775b99fcd9210cf7c	2026-10-15 12:23:51.192454+00	20260817000000_shadow_eval_multi_key	\N	\N	2026-10-15 12:23:50.970991+00	1
3735a62d-791d-4747-a188-9ff8ad688e60	c49f1741928eb7c91f6f1c65a8795dc34ed337f4bf287dacb394dbdb21da3d2e	2026-10-15 12:23:52.078148+00	20260817143646_add_daily_guardrail_usage_units	\N	\N	2026-10-15 12:23:51.303536+00	1
d5322431-e837-45a2-a50d-99804078de1a	43483d9059a5bb4c5d1909b66cf31a0bcfcb56ee8cee41759a2fe6cc7ec29f7a	2026-10-15 12:23:52.434292+00	20260818000000_add_spend_log_timestamps	\N	\N	2026-10-15 12:23:52.28832+00	1
db14555d-0ced-455c-afd1-0c211e77e0ea	eb7eab0f28f0195e29aa3b522dadd5f20cab937321b28f9414694c77ba7275d2	2026-10-15 12:23:52.809149+00	20260818224500_add_shadow_eval_stopped_by	\N	\N	2026-10-15 12:23:52.521326+00	1
430623e1-e7a6-44f6-b4ba-675d0fba7210	57b13e4db3145e309bc1de0f6227ca1ac996b770ed64a305e8d5d576339c6dce	2026-10-15 12:23:53.086121+00	20260819000000_shadow_eval_max_budget	\N	\N	2026-10-15 12:23:52.898709+00	1
557b793d-e89c-459a-a85a-8af639864692	2ae38bee90bda6ecc16d6cfc4cd6c33344b47557a4ed1b35eaabf58b02540ce0	2026-10-15 12:23:53.274039+00	20260823000000_add_spend_logs_api_key_starttime_index	\N	\N	2026-10-15 12:23:53.141268+00	1
c0d65f86-dc81-4b61-96f7-5b1cb3643d84	8657e0cd99f8ff8e69dba50decc602c0d11e98076f6a32a3cb5563c6ce114da7	2026-10-15 12:23:53.462381+00	20260824000000_add_gateway_injected_caching_savings_spend	\N	\N	2026-10-15 12:23:53.319074+00	1
c766230b-4bb9-4e34-a5b5-0b78d9f17355	57e6e28b853b51674dc0161a71cb1149f449086cd7ee787e5eb768283fed25a9	2026-10-15 12:23:54.005683+00	20260828000000_shadow_eval_cost_comparison	\N	\N	2026-10-15 12:23:53.517568+00	1
324d638a-fd5f-4dd5-a9d3-253c869e883e	d8003a7d0a4fdf580aaf1262408959882b205ee83a13bd131ca706fd3b3e1298	2026-10-15 12:23:54.868404+00	20260829000000_add_model_access_group_budget_table	\N	\N	2026-10-15 12:23:54.094282+00	1
0574d09c-6167-4c16-aef0-b822ae493a79	78357ae2db2ee3b5305d5630c0eae95af59ae2db07e5adf21b5fb4f37f334cd6	2026-10-15 12:23:55.269762+00	20260831000000_shadow_eval_typed_targets	\N	\N	2026-10-15 12:23:54.927765+00	1
39646898-4b2b-4af0-a639-127057aa5dfc	bcb344e885c0784de365a94646a21a5564942a90b55bcbcc9e3c492fb2b831b6	2026-10-15 12:23:55.457301+00	20260831120000_add_litellm_call_id_spend_logs	\N	\N	2026-10-15 12:23:55.313775+00	1
02594c49-e1fd-4018-9a5a-a56d0824c994	7166fd213126f8dcbd6d1ecdf0d2851cdd55abf5e518242f2f44bb6b100a872d	2026-10-15 12:23:55.611232+00	20260831120001_spend_logs_litellm_call_id_index	\N	\N	2026-10-15 12:23:55.502119+00	1
df3880b7-8ebc-4eef-8219-95289dffdf67	f6980539317506b5daa6746011743bf8f369a9f0d6a4469d696be46faae453f2	2026-10-15 12:23:55.809847+00	20260901000000_shadow_eval_multi_router	\N	\N	2026-10-15 12:23:55.655836+00	1
14db895f-4ed1-4c9b-a8ab-d3253ef14d99	7381f8ea473e50d0dcb67aff508a6fe70984da9ec3d821652db87afe39733106	2026-10-15 12:23:56.064107+00	20260901000001_add_guardrail_usage_units_cost	\N	\N	2026-10-15 12:23:55.865436+00	1
2b1a0f69-c512-41db-8b1d-15c30b053811	35fd128554221aa4409cc8405b990c70c37b7a291dd00f7ab766b0d5a52cc977	2026-10-15 12:23:56.494043+00	20260903230000_add_org_id_to_managed_object_table	\N	\N	2026-10-15 12:23:56.152849+00	1
78c35f2c-3b41-4f2c-b68a-344ec7b04c65	f58035b900234c4a2d93691cdeef0b033409eacfb8bebecac978c3b7b21084e5	2026-10-15 12:23:56.814292+00	20260904000000_shadow_eval_model_scope	\N	\N	2026-10-15 12:23:56.58274+00	1
c4e37e32-4437-4487-b3c5-bac8ef293393	f18e82c054d69d040e4eeb6b1a036638216117b5d2292cb7cc315f8ffc217da6	2026-10-15 12:23:57.101257+00	20260905120000_add_per_server_oauth_discovery_to_mcp_servers	\N	\N	2026-10-15 12:23:56.902725+00	1
bfa5d5d9-18b0-4ee5-ad3f-53b7eedfa3cc	af862ad1c02eb4467747610cec938d50549df28a9ad0810f0a8ddde3644f7c8f	2026-10-15 12:23:57.465438+00	20260907000000_add_autorouter_classifier_cost	\N	\N	2026-10-15 12:23:57.157864+00	1
c97da6ac-9667-4506-9f8c-0d01698cd083	cb6444896cbeb60aa289c10750c65eb5a7a2fc9baa2552394e047658cf03decf	2026-10-15 12:23:57.664275+00	20260910000000_add_autorouter_session_baseline_models	\N	\N	2026-10-15 12:23:57.510803+00	1
d7bb19a0-d5d1-4585-bc25-a805f3ece84f	8bb13d391be3872bc38b9455224292bd55f7179f4f4f9f2065659072d1e0e208	2026-10-15 12:23:57.862445+00	20260910000000_skills_on_object_permission	\N	\N	2026-10-15 12:23:57.720108+00	1
d18b01cd-391f-44a8-ba1e-01c44a7b5064	e65f7d0fa6d24cf46fc6596aed9371d7f49ff9d45670ac36b542d8395a84d57b	2026-10-15 12:23:58.160976+00	20260913000000_add_tpd_limit	\N	\N	2026-10-15 12:23:57.918473+00	1
67ed5af4-e70c-4414-8144-3fe4669d5eff	426f1b80ffe1319401bd994a9bdc061145a09fd080e9bf074bf8f22980a238ab	2026-10-15 12:23:58.492216+00	20260915000000_add_autorouter_savings_estimate_coverage	\N	\N	2026-10-15 12:23:58.271661+00	1
699adf00-07b3-4efd-a9e7-0b4728645144	83d716d3adf6eeee67eed7b037aa975b92317d38691dc6e0230616fcaeec3bda	2026-10-15 12:23:59.607485+00	20260915000000_add_daily_global_spend	\N	\N	2026-10-15 12:23:58.569671+00	1
68e25d4f-608b-43ec-a420-908540ae664e	b19733a85da03b52b6265d3196781e4e4131beb6ffc76942136cb361a1da67f3	2026-10-15 12:23:59.828196+00	20260915000000_add_daily_response_time	\N	\N	2026-10-15 12:23:59.685489+00	1
d232630b-dd6b-40dc-947e-70e915bc52d7	9a2954a7a631243ea15d7437b86bc199d424cccc9f596c3223b5a408259636c3	2026-10-15 12:24:00.336444+00	20260915000000_scope_jwt_key_mapping_by_issuer	\N	\N	2026-10-15 12:23:59.884699+00	1
3b40895d-0cb4-4ae5-a45e-2b2ffa2e77c9	181dc0a452fb062476fe77e18351f48e20c2b14f763d3b19dce3ccb81c962d3d	2026-10-15 12:24:02.404161+00	20260915010000_add_autorouter_baseline_state	\N	\N	2026-10-15 12:24:00.425217+00	1
c50c50d5-1c3e-4f00-b89e-5dcd89984933	a6c0cd6606339cc5267c21d202b6f6142bdb47806d17075f09fcbd15ad967b5d	2026-10-15 12:24:02.614399+00	20260916000000_add_key_total_spend	\N	\N	2026-10-15 12:24:02.458812+00	1
89197d7d-f9b0-41d1-8be5-b548bcc01171	d40a9042f649e10aea65d170104f2cf12dbcfa3a9c6324b3f5f73e578ca32429	2026-10-15 12:24:02.967536+00	20260917000000_add_agent_access_group_ids	\N	\N	2026-10-15 12:24:02.659461+00	1
4a0fa298-2fd7-4e65-b3b4-f428c0cdfc6d	5fd45400bee66355df8cc4dc7b839cdcbff2555de2e0a87f508051b3ef49463e	2026-10-15 12:24:03.244438+00	20260917000000_add_budget_temp_increase	\N	\N	2026-10-15 12:24:03.045243+00	1
001b8812-57e8-4ebd-87fc-1e6d68791c1a	9591135a8f8899d8129b100b287776fe0c52cbb0b89f0e05057716359b3d953f	2026-10-15 12:24:03.544686+00	20260917055603_add_policy_attachment_priority	\N	\N	2026-10-15 12:24:03.366171+00	1
ae763ed2-6cd9-487b-af62-a8317e97b237	d8c32459c92896d2e7ba57c7541da5449aa2c7124b02bb787bf3b221c3601849	2026-10-15 12:24:03.985548+00	20260918000000_add_managed_file_content_table	\N	\N	2026-10-15 12:24:03.6203+00	1
39266219-afec-459c-b932-33f4ebb5239f	d5227cb7dbe124069aef53dd1050ad50853eec3b134eec2fd16917b302d8fa22	2026-10-15 12:24:04.836092+00	20260919000000_add_autorouter_user_session_rollup	\N	\N	2026-10-15 12:24:04.028922+00	1
bb9bfea1-239e-40d5-ab7f-05b1c355a452	33259c7ebc3c2a2d7f2d81eef1e8f3fb94217facd882694bec2c30f9b7d851ef	2026-10-15 12:24:05.091208+00	20260920041500_add_policy_attachment_is_default	\N	\N	2026-10-15 12:24:04.925507+00	1
14d37a73-9171-4267-8cff-35a5c45cdbef	601287a72ed29f3813d97dd51a16a83407a585731788ab512fedf8a01f56a756	2026-10-15 12:24:05.496711+00	20260921000000_add_password_reset_columns	\N	\N	2026-10-15 12:24:05.134539+00	1
28af5899-0bcc-41be-bf66-a353b189ccac	4a9d6f79f0cfe0eef9b76d1dd4c676b93be64d5621fd9f4c11f5870385991bba	2026-10-15 12:24:07.646163+00	20260921190000_agent_identity	\N	\N	2026-10-15 12:24:05.57735+00	1
8b90b468-4089-4e65-b9f5-52c7bc1f3c0d	5202b1314da4432a30700c558b6ef3c234a3057376deca81f0dad00f4293838a	2026-10-15 12:24:07.945069+00	20260923000000_add_agent_kill_switch	\N	\N	2026-10-15 12:24:07.735191+00	1
666e3706-3570-46de-8be1-7c7866d4c2bb	23f89722e760e15fc22cf90caa439d7895cd60c32cc6add6b1ca449993f88562	2026-10-15 12:24:08.22216+00	20260925000000_add_mcp_pinned_tools	\N	\N	2026-10-15 12:24:08.011234+00	1
f429bea5-c585-4284-820b-579d3389ac25	2eb2711cabd6f75670849f40ee1d1f7f48d468f22d7871c69dbede02d60cb63d	2026-10-15 12:24:09.195402+00	20260928000000_add_daily_model_usage	\N	\N	2026-10-15 12:24:08.266477+00	1
9320878a-caeb-4b36-bf68-fbd78558b08c	c08a58b26e04b2a83bb4c58864e0a9608941c3561dc7dbfc9c12604336f392d9	2026-10-15 12:24:10.336056+00	20260930000000_agent_engine	\N	\N	2026-10-15 12:24:09.295137+00	1
278ecac4-93c6-4bd7-81a6-6687b0989c5d	200f7b134499282a235b0be261d520286066c5f7fa10bc461fd29c6d749a0b61	2026-10-15 12:24:11.054769+00	20261001000000_lens_run_history	\N	\N	2026-10-15 12:24:10.380745+00	1
13ea9403-5aaf-4081-876f-d8216c737e7e	ca2c6b8bda8b16381e9b707d43d914c800923c8b476b4da12d3ad0b4179a3603	2026-10-15 12:24:11.342017+00	20261001100000_rename_lens	\N	\N	2026-10-15 12:24:11.14359+00	1
\.


--
-- Name: LiteLLM_ModelTable_id_seq; Type: SEQUENCE SET; Schema: public; Owner: litellm
--

SELECT pg_catalog.setval('public."LiteLLM_ModelTable_id_seq"', 1, false);


--
-- Name: LiteLLM_AccessGroupTable LiteLLM_AccessGroupTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_AccessGroupTable"
    ADD CONSTRAINT "LiteLLM_AccessGroupTable_pkey" PRIMARY KEY (access_group_id);


--
-- Name: LiteLLM_AdaptiveRouterSession LiteLLM_AdaptiveRouterSession_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_AdaptiveRouterSession"
    ADD CONSTRAINT "LiteLLM_AdaptiveRouterSession_pkey" PRIMARY KEY (session_id, router_name, model_name);


--
-- Name: LiteLLM_AdaptiveRouterState LiteLLM_AdaptiveRouterState_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_AdaptiveRouterState"
    ADD CONSTRAINT "LiteLLM_AdaptiveRouterState_pkey" PRIMARY KEY (router_name, request_type, model_name);


--
-- Name: LiteLLM_AgentIdentity LiteLLM_AgentIdentity_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_AgentIdentity"
    ADD CONSTRAINT "LiteLLM_AgentIdentity_pkey" PRIMARY KEY (agent_id);


--
-- Name: LiteLLM_AgentsTable LiteLLM_AgentsTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_AgentsTable"
    ADD CONSTRAINT "LiteLLM_AgentsTable_pkey" PRIMARY KEY (agent_id);


--
-- Name: LiteLLM_AuditLog LiteLLM_AuditLog_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_AuditLog"
    ADD CONSTRAINT "LiteLLM_AuditLog_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_AutoRouterBaselineComparison LiteLLM_AutoRouterBaselineComparison_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_AutoRouterBaselineComparison"
    ADD CONSTRAINT "LiteLLM_AutoRouterBaselineComparison_pkey" PRIMARY KEY (scope);


--
-- Name: LiteLLM_AutoRouterBaselineObservation LiteLLM_AutoRouterBaselineObservation_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_AutoRouterBaselineObservation"
    ADD CONSTRAINT "LiteLLM_AutoRouterBaselineObservation_pkey" PRIMARY KEY (request_id);


--
-- Name: LiteLLM_AutoRouterSession LiteLLM_AutoRouterSession_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_AutoRouterSession"
    ADD CONSTRAINT "LiteLLM_AutoRouterSession_pkey" PRIMARY KEY (api_key, session_id, router_name);


--
-- Name: LiteLLM_AutoRouterUserSession LiteLLM_AutoRouterUserSession_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_AutoRouterUserSession"
    ADD CONSTRAINT "LiteLLM_AutoRouterUserSession_pkey" PRIMARY KEY (user_id, api_key, session_id, router_name);


--
-- Name: LiteLLM_BudgetTable LiteLLM_BudgetTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_BudgetTable"
    ADD CONSTRAINT "LiteLLM_BudgetTable_pkey" PRIMARY KEY (budget_id);


--
-- Name: LiteLLM_BudgetWindowSpend LiteLLM_BudgetWindowSpend_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_BudgetWindowSpend"
    ADD CONSTRAINT "LiteLLM_BudgetWindowSpend_pkey" PRIMARY KEY (entity_type, entity_id, window_duration);


--
-- Name: LiteLLM_CacheConfig LiteLLM_CacheConfig_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_CacheConfig"
    ADD CONSTRAINT "LiteLLM_CacheConfig_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_ClaudeCodePluginTable LiteLLM_ClaudeCodePluginTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ClaudeCodePluginTable"
    ADD CONSTRAINT "LiteLLM_ClaudeCodePluginTable_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_ConfigOverrides LiteLLM_ConfigOverrides_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ConfigOverrides"
    ADD CONSTRAINT "LiteLLM_ConfigOverrides_pkey" PRIMARY KEY (config_type);


--
-- Name: LiteLLM_Config LiteLLM_Config_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_Config"
    ADD CONSTRAINT "LiteLLM_Config_pkey" PRIMARY KEY (param_name);


--
-- Name: LiteLLM_CredentialsTable LiteLLM_CredentialsTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_CredentialsTable"
    ADD CONSTRAINT "LiteLLM_CredentialsTable_pkey" PRIMARY KEY (credential_id);


--
-- Name: LiteLLM_CronJob LiteLLM_CronJob_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_CronJob"
    ADD CONSTRAINT "LiteLLM_CronJob_pkey" PRIMARY KEY (cronjob_id);


--
-- Name: LiteLLM_DailyAgentSpend LiteLLM_DailyAgentSpend_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_DailyAgentSpend"
    ADD CONSTRAINT "LiteLLM_DailyAgentSpend_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_DailyEndUserSpend LiteLLM_DailyEndUserSpend_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_DailyEndUserSpend"
    ADD CONSTRAINT "LiteLLM_DailyEndUserSpend_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_DailyGatewayRequests LiteLLM_DailyGatewayRequests_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_DailyGatewayRequests"
    ADD CONSTRAINT "LiteLLM_DailyGatewayRequests_pkey" PRIMARY KEY (date, category, route);


--
-- Name: LiteLLM_DailyGlobalSpend LiteLLM_DailyGlobalSpend_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_DailyGlobalSpend"
    ADD CONSTRAINT "LiteLLM_DailyGlobalSpend_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_DailyGuardrailMetrics LiteLLM_DailyGuardrailMetrics_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_DailyGuardrailMetrics"
    ADD CONSTRAINT "LiteLLM_DailyGuardrailMetrics_pkey" PRIMARY KEY (guardrail_id, date);


--
-- Name: LiteLLM_DailyGuardrailUsageUnits LiteLLM_DailyGuardrailUsageUnits_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_DailyGuardrailUsageUnits"
    ADD CONSTRAINT "LiteLLM_DailyGuardrailUsageUnits_pkey" PRIMARY KEY (guardrail_id, date, team_id, api_key, usage_unit);


--
-- Name: LiteLLM_DailyModelUsage LiteLLM_DailyModelUsage_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_DailyModelUsage"
    ADD CONSTRAINT "LiteLLM_DailyModelUsage_pkey" PRIMARY KEY (date, model_group, model, custom_llm_provider, task_type);


--
-- Name: LiteLLM_DailyOrganizationSpend LiteLLM_DailyOrganizationSpend_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_DailyOrganizationSpend"
    ADD CONSTRAINT "LiteLLM_DailyOrganizationSpend_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_DailyPolicyMetrics LiteLLM_DailyPolicyMetrics_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_DailyPolicyMetrics"
    ADD CONSTRAINT "LiteLLM_DailyPolicyMetrics_pkey" PRIMARY KEY (policy_id, date);


--
-- Name: LiteLLM_DailyTagSpend LiteLLM_DailyTagSpend_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_DailyTagSpend"
    ADD CONSTRAINT "LiteLLM_DailyTagSpend_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_DailyTeamSpend LiteLLM_DailyTeamSpend_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_DailyTeamSpend"
    ADD CONSTRAINT "LiteLLM_DailyTeamSpend_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_DailyToolSpend LiteLLM_DailyToolSpend_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_DailyToolSpend"
    ADD CONSTRAINT "LiteLLM_DailyToolSpend_pkey" PRIMARY KEY (date, tool_name);


--
-- Name: LiteLLM_DailyUserSpend LiteLLM_DailyUserSpend_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_DailyUserSpend"
    ADD CONSTRAINT "LiteLLM_DailyUserSpend_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_DeletedTeamTable LiteLLM_DeletedTeamTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_DeletedTeamTable"
    ADD CONSTRAINT "LiteLLM_DeletedTeamTable_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_DeletedVerificationToken LiteLLM_DeletedVerificationToken_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_DeletedVerificationToken"
    ADD CONSTRAINT "LiteLLM_DeletedVerificationToken_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_DeprecatedVerificationToken LiteLLM_DeprecatedVerificationToken_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_DeprecatedVerificationToken"
    ADD CONSTRAINT "LiteLLM_DeprecatedVerificationToken_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_EndUserTable LiteLLM_EndUserTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_EndUserTable"
    ADD CONSTRAINT "LiteLLM_EndUserTable_pkey" PRIMARY KEY (user_id);


--
-- Name: LiteLLM_ErrorLogs LiteLLM_ErrorLogs_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ErrorLogs"
    ADD CONSTRAINT "LiteLLM_ErrorLogs_pkey" PRIMARY KEY (request_id);


--
-- Name: LiteLLM_GuardrailsTable LiteLLM_GuardrailsTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_GuardrailsTable"
    ADD CONSTRAINT "LiteLLM_GuardrailsTable_pkey" PRIMARY KEY (guardrail_id);


--
-- Name: LiteLLM_HealthCheckTable LiteLLM_HealthCheckTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_HealthCheckTable"
    ADD CONSTRAINT "LiteLLM_HealthCheckTable_pkey" PRIMARY KEY (health_check_id);


--
-- Name: LiteLLM_InvitationLink LiteLLM_InvitationLink_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_InvitationLink"
    ADD CONSTRAINT "LiteLLM_InvitationLink_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_JWTKeyMapping LiteLLM_JWTKeyMapping_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_JWTKeyMapping"
    ADD CONSTRAINT "LiteLLM_JWTKeyMapping_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_LensRun LiteLLM_LensRun_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_LensRun"
    ADD CONSTRAINT "LiteLLM_LensRun_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_LensWorker LiteLLM_LensWorker_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_LensWorker"
    ADD CONSTRAINT "LiteLLM_LensWorker_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_LensWorker LiteLLM_LensWorker_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_LensWorker"
    ADD CONSTRAINT "LiteLLM_LensWorker_token_hash_key" UNIQUE (token_hash);


--
-- Name: LiteLLM_Lens LiteLLM_Lens_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_Lens"
    ADD CONSTRAINT "LiteLLM_Lens_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_MCPServerOAuthClient LiteLLM_MCPServerOAuthClient_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_MCPServerOAuthClient"
    ADD CONSTRAINT "LiteLLM_MCPServerOAuthClient_pkey" PRIMARY KEY (server_id);


--
-- Name: LiteLLM_MCPServerTable LiteLLM_MCPServerTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_MCPServerTable"
    ADD CONSTRAINT "LiteLLM_MCPServerTable_pkey" PRIMARY KEY (server_id);


--
-- Name: LiteLLM_MCPToolsetTable LiteLLM_MCPToolsetTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_MCPToolsetTable"
    ADD CONSTRAINT "LiteLLM_MCPToolsetTable_pkey" PRIMARY KEY (toolset_id);


--
-- Name: LiteLLM_MCPUserCredentials LiteLLM_MCPUserCredentials_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_MCPUserCredentials"
    ADD CONSTRAINT "LiteLLM_MCPUserCredentials_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_MCPUserEnvVars LiteLLM_MCPUserEnvVars_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_MCPUserEnvVars"
    ADD CONSTRAINT "LiteLLM_MCPUserEnvVars_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_ManagedFileContentTable LiteLLM_ManagedFileContentTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ManagedFileContentTable"
    ADD CONSTRAINT "LiteLLM_ManagedFileContentTable_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_ManagedFileTable LiteLLM_ManagedFileTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ManagedFileTable"
    ADD CONSTRAINT "LiteLLM_ManagedFileTable_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_ManagedObjectTable LiteLLM_ManagedObjectTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ManagedObjectTable"
    ADD CONSTRAINT "LiteLLM_ManagedObjectTable_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_ManagedVectorStoreIndexTable LiteLLM_ManagedVectorStoreIndexTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ManagedVectorStoreIndexTable"
    ADD CONSTRAINT "LiteLLM_ManagedVectorStoreIndexTable_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_ManagedVectorStoreTable LiteLLM_ManagedVectorStoreTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ManagedVectorStoreTable"
    ADD CONSTRAINT "LiteLLM_ManagedVectorStoreTable_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_ManagedVectorStoresTable LiteLLM_ManagedVectorStoresTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ManagedVectorStoresTable"
    ADD CONSTRAINT "LiteLLM_ManagedVectorStoresTable_pkey" PRIMARY KEY (vector_store_id);


--
-- Name: LiteLLM_MemoryTable LiteLLM_MemoryTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_MemoryTable"
    ADD CONSTRAINT "LiteLLM_MemoryTable_pkey" PRIMARY KEY (memory_id);


--
-- Name: LiteLLM_ModelAccessGroupBudgetTable LiteLLM_ModelAccessGroupBudgetTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ModelAccessGroupBudgetTable"
    ADD CONSTRAINT "LiteLLM_ModelAccessGroupBudgetTable_pkey" PRIMARY KEY (access_group_name);


--
-- Name: LiteLLM_ModelTable LiteLLM_ModelTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ModelTable"
    ADD CONSTRAINT "LiteLLM_ModelTable_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_ObjectPermissionTable LiteLLM_ObjectPermissionTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ObjectPermissionTable"
    ADD CONSTRAINT "LiteLLM_ObjectPermissionTable_pkey" PRIMARY KEY (object_permission_id);


--
-- Name: LiteLLM_OrganizationMembership LiteLLM_OrganizationMembership_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_OrganizationMembership"
    ADD CONSTRAINT "LiteLLM_OrganizationMembership_pkey" PRIMARY KEY (user_id, organization_id);


--
-- Name: LiteLLM_OrganizationTable LiteLLM_OrganizationTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_OrganizationTable"
    ADD CONSTRAINT "LiteLLM_OrganizationTable_pkey" PRIMARY KEY (organization_id);


--
-- Name: LiteLLM_PolicyAttachmentTable LiteLLM_PolicyAttachmentTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_PolicyAttachmentTable"
    ADD CONSTRAINT "LiteLLM_PolicyAttachmentTable_pkey" PRIMARY KEY (attachment_id);


--
-- Name: LiteLLM_PolicyTable LiteLLM_PolicyTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_PolicyTable"
    ADD CONSTRAINT "LiteLLM_PolicyTable_pkey" PRIMARY KEY (policy_id);


--
-- Name: LiteLLM_ProjectTable LiteLLM_ProjectTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ProjectTable"
    ADD CONSTRAINT "LiteLLM_ProjectTable_pkey" PRIMARY KEY (project_id);


--
-- Name: LiteLLM_PromptTable LiteLLM_PromptTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_PromptTable"
    ADD CONSTRAINT "LiteLLM_PromptTable_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_ProxyModelTable LiteLLM_ProxyModelTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ProxyModelTable"
    ADD CONSTRAINT "LiteLLM_ProxyModelTable_pkey" PRIMARY KEY (model_id);


--
-- Name: LiteLLM_ProxyWorkerHeartbeat LiteLLM_ProxyWorkerHeartbeat_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ProxyWorkerHeartbeat"
    ADD CONSTRAINT "LiteLLM_ProxyWorkerHeartbeat_pkey" PRIMARY KEY (worker_id);


--
-- Name: LiteLLM_RetiredAgentIdentity LiteLLM_RetiredAgentIdentity_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_RetiredAgentIdentity"
    ADD CONSTRAINT "LiteLLM_RetiredAgentIdentity_pkey" PRIMARY KEY (binding_id);


--
-- Name: LiteLLM_RetiredAgent LiteLLM_RetiredAgent_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_RetiredAgent"
    ADD CONSTRAINT "LiteLLM_RetiredAgent_pkey" PRIMARY KEY (original_agent_id);


--
-- Name: LiteLLM_SSOConfig LiteLLM_SSOConfig_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_SSOConfig"
    ADD CONSTRAINT "LiteLLM_SSOConfig_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_SSOIdentityAssertion LiteLLM_SSOIdentityAssertion_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_SSOIdentityAssertion"
    ADD CONSTRAINT "LiteLLM_SSOIdentityAssertion_pkey" PRIMARY KEY (user_id);


--
-- Name: LiteLLM_SearchToolsTable LiteLLM_SearchToolsTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_SearchToolsTable"
    ADD CONSTRAINT "LiteLLM_SearchToolsTable_pkey" PRIMARY KEY (search_tool_id);


--
-- Name: LiteLLM_ShadowEvalAttempt LiteLLM_ShadowEvalAttempt_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ShadowEvalAttempt"
    ADD CONSTRAINT "LiteLLM_ShadowEvalAttempt_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_ShadowEvalFunnel LiteLLM_ShadowEvalFunnel_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ShadowEvalFunnel"
    ADD CONSTRAINT "LiteLLM_ShadowEvalFunnel_pkey" PRIMARY KEY (job_id);


--
-- Name: LiteLLM_ShadowEvalJob LiteLLM_ShadowEvalJob_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ShadowEvalJob"
    ADD CONSTRAINT "LiteLLM_ShadowEvalJob_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_SkillsTable LiteLLM_SkillsTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_SkillsTable"
    ADD CONSTRAINT "LiteLLM_SkillsTable_pkey" PRIMARY KEY (skill_id);


--
-- Name: LiteLLM_SpendLogGuardrailIndex LiteLLM_SpendLogGuardrailIndex_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_SpendLogGuardrailIndex"
    ADD CONSTRAINT "LiteLLM_SpendLogGuardrailIndex_pkey" PRIMARY KEY (request_id, guardrail_id);


--
-- Name: LiteLLM_SpendLogToolIndex LiteLLM_SpendLogToolIndex_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_SpendLogToolIndex"
    ADD CONSTRAINT "LiteLLM_SpendLogToolIndex_pkey" PRIMARY KEY (request_id, tool_name);


--
-- Name: LiteLLM_SpendLogs LiteLLM_SpendLogs_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_SpendLogs"
    ADD CONSTRAINT "LiteLLM_SpendLogs_pkey" PRIMARY KEY (request_id);


--
-- Name: LiteLLM_TagTable LiteLLM_TagTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_TagTable"
    ADD CONSTRAINT "LiteLLM_TagTable_pkey" PRIMARY KEY (tag_name);


--
-- Name: LiteLLM_TeamMembership LiteLLM_TeamMembership_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_TeamMembership"
    ADD CONSTRAINT "LiteLLM_TeamMembership_pkey" PRIMARY KEY (user_id, team_id);


--
-- Name: LiteLLM_TeamTable LiteLLM_TeamTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_TeamTable"
    ADD CONSTRAINT "LiteLLM_TeamTable_pkey" PRIMARY KEY (team_id);


--
-- Name: LiteLLM_ToolTable LiteLLM_ToolTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ToolTable"
    ADD CONSTRAINT "LiteLLM_ToolTable_pkey" PRIMARY KEY (tool_id);


--
-- Name: LiteLLM_UISettings LiteLLM_UISettings_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_UISettings"
    ADD CONSTRAINT "LiteLLM_UISettings_pkey" PRIMARY KEY (id);


--
-- Name: LiteLLM_UserNotifications LiteLLM_UserNotifications_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_UserNotifications"
    ADD CONSTRAINT "LiteLLM_UserNotifications_pkey" PRIMARY KEY (request_id);


--
-- Name: LiteLLM_UserTable LiteLLM_UserTable_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_UserTable"
    ADD CONSTRAINT "LiteLLM_UserTable_pkey" PRIMARY KEY (user_id);


--
-- Name: LiteLLM_VerificationToken LiteLLM_VerificationToken_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_VerificationToken"
    ADD CONSTRAINT "LiteLLM_VerificationToken_pkey" PRIMARY KEY (token);


--
-- Name: LiteLLM_VerifiedSubject LiteLLM_VerifiedSubject_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_VerifiedSubject"
    ADD CONSTRAINT "LiteLLM_VerifiedSubject_pkey" PRIMARY KEY (subject_id);


--
-- Name: LiteLLM_WorkflowEvent LiteLLM_WorkflowEvent_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_WorkflowEvent"
    ADD CONSTRAINT "LiteLLM_WorkflowEvent_pkey" PRIMARY KEY (event_id);


--
-- Name: LiteLLM_WorkflowMessage LiteLLM_WorkflowMessage_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_WorkflowMessage"
    ADD CONSTRAINT "LiteLLM_WorkflowMessage_pkey" PRIMARY KEY (message_id);


--
-- Name: LiteLLM_WorkflowRun LiteLLM_WorkflowRun_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_WorkflowRun"
    ADD CONSTRAINT "LiteLLM_WorkflowRun_pkey" PRIMARY KEY (run_id);


--
-- Name: _prisma_migrations _prisma_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public._prisma_migrations
    ADD CONSTRAINT _prisma_migrations_pkey PRIMARY KEY (id);


--
-- Name: LiteLLM_AccessGroupTable_access_group_name_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_AccessGroupTable_access_group_name_key" ON public."LiteLLM_AccessGroupTable" USING btree (access_group_name);


--
-- Name: LiteLLM_AgentIdentity_issuer_service_principal_id_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_AgentIdentity_issuer_service_principal_id_key" ON public."LiteLLM_AgentIdentity" USING btree (issuer, service_principal_id);


--
-- Name: LiteLLM_AgentIdentity_provider_tenant_id_client_id_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_AgentIdentity_provider_tenant_id_client_id_key" ON public."LiteLLM_AgentIdentity" USING btree (provider, tenant_id, client_id);


--
-- Name: LiteLLM_AgentsTable_agent_name_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_AgentsTable_agent_name_key" ON public."LiteLLM_AgentsTable" USING btree (agent_name);


--
-- Name: LiteLLM_ClaudeCodePluginTable_name_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_ClaudeCodePluginTable_name_key" ON public."LiteLLM_ClaudeCodePluginTable" USING btree (name);


--
-- Name: LiteLLM_CredentialsTable_credential_name_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_CredentialsTable_credential_name_key" ON public."LiteLLM_CredentialsTable" USING btree (credential_name);


--
-- Name: LiteLLM_DailyAgentSpend_agent_id_date_api_key_model_custom__key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_DailyAgentSpend_agent_id_date_api_key_model_custom__key" ON public."LiteLLM_DailyAgentSpend" USING btree (agent_id, date, api_key, model, custom_llm_provider, mcp_namespaced_tool_name, endpoint);


--
-- Name: LiteLLM_DailyAgentSpend_agent_id_date_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyAgentSpend_agent_id_date_idx" ON public."LiteLLM_DailyAgentSpend" USING btree (agent_id, date);


--
-- Name: LiteLLM_DailyAgentSpend_api_key_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyAgentSpend_api_key_idx" ON public."LiteLLM_DailyAgentSpend" USING btree (api_key);


--
-- Name: LiteLLM_DailyAgentSpend_date_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyAgentSpend_date_idx" ON public."LiteLLM_DailyAgentSpend" USING btree (date);


--
-- Name: LiteLLM_DailyAgentSpend_endpoint_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyAgentSpend_endpoint_idx" ON public."LiteLLM_DailyAgentSpend" USING btree (endpoint);


--
-- Name: LiteLLM_DailyAgentSpend_mcp_namespaced_tool_name_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyAgentSpend_mcp_namespaced_tool_name_idx" ON public."LiteLLM_DailyAgentSpend" USING btree (mcp_namespaced_tool_name);


--
-- Name: LiteLLM_DailyAgentSpend_model_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyAgentSpend_model_idx" ON public."LiteLLM_DailyAgentSpend" USING btree (model);


--
-- Name: LiteLLM_DailyEndUserSpend_api_key_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyEndUserSpend_api_key_idx" ON public."LiteLLM_DailyEndUserSpend" USING btree (api_key);


--
-- Name: LiteLLM_DailyEndUserSpend_date_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyEndUserSpend_date_idx" ON public."LiteLLM_DailyEndUserSpend" USING btree (date);


--
-- Name: LiteLLM_DailyEndUserSpend_end_user_id_date_api_key_model_cu_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_DailyEndUserSpend_end_user_id_date_api_key_model_cu_key" ON public."LiteLLM_DailyEndUserSpend" USING btree (end_user_id, date, api_key, model, custom_llm_provider, mcp_namespaced_tool_name, endpoint);


--
-- Name: LiteLLM_DailyEndUserSpend_end_user_id_date_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyEndUserSpend_end_user_id_date_idx" ON public."LiteLLM_DailyEndUserSpend" USING btree (end_user_id, date);


--
-- Name: LiteLLM_DailyEndUserSpend_endpoint_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyEndUserSpend_endpoint_idx" ON public."LiteLLM_DailyEndUserSpend" USING btree (endpoint);


--
-- Name: LiteLLM_DailyEndUserSpend_mcp_namespaced_tool_name_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyEndUserSpend_mcp_namespaced_tool_name_idx" ON public."LiteLLM_DailyEndUserSpend" USING btree (mcp_namespaced_tool_name);


--
-- Name: LiteLLM_DailyEndUserSpend_model_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyEndUserSpend_model_idx" ON public."LiteLLM_DailyEndUserSpend" USING btree (model);


--
-- Name: LiteLLM_DailyGatewayRequests_date_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyGatewayRequests_date_idx" ON public."LiteLLM_DailyGatewayRequests" USING btree (date);


--
-- Name: LiteLLM_DailyGlobalSpend_date_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyGlobalSpend_date_idx" ON public."LiteLLM_DailyGlobalSpend" USING btree (date);


--
-- Name: LiteLLM_DailyGlobalSpend_date_model_model_group_custom_llm__key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_DailyGlobalSpend_date_model_model_group_custom_llm__key" ON public."LiteLLM_DailyGlobalSpend" USING btree (date, model, model_group, custom_llm_provider, mcp_namespaced_tool_name, endpoint);


--
-- Name: LiteLLM_DailyGuardrailMetrics_date_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyGuardrailMetrics_date_idx" ON public."LiteLLM_DailyGuardrailMetrics" USING btree (date);


--
-- Name: LiteLLM_DailyGuardrailMetrics_guardrail_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyGuardrailMetrics_guardrail_id_idx" ON public."LiteLLM_DailyGuardrailMetrics" USING btree (guardrail_id);


--
-- Name: LiteLLM_DailyGuardrailUsageUnits_date_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyGuardrailUsageUnits_date_idx" ON public."LiteLLM_DailyGuardrailUsageUnits" USING btree (date);


--
-- Name: LiteLLM_DailyModelUsage_date_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyModelUsage_date_idx" ON public."LiteLLM_DailyModelUsage" USING btree (date);


--
-- Name: LiteLLM_DailyModelUsage_model_group_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyModelUsage_model_group_idx" ON public."LiteLLM_DailyModelUsage" USING btree (model_group);


--
-- Name: LiteLLM_DailyOrganizationSpend_api_key_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyOrganizationSpend_api_key_idx" ON public."LiteLLM_DailyOrganizationSpend" USING btree (api_key);


--
-- Name: LiteLLM_DailyOrganizationSpend_date_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyOrganizationSpend_date_idx" ON public."LiteLLM_DailyOrganizationSpend" USING btree (date);


--
-- Name: LiteLLM_DailyOrganizationSpend_endpoint_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyOrganizationSpend_endpoint_idx" ON public."LiteLLM_DailyOrganizationSpend" USING btree (endpoint);


--
-- Name: LiteLLM_DailyOrganizationSpend_mcp_namespaced_tool_name_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyOrganizationSpend_mcp_namespaced_tool_name_idx" ON public."LiteLLM_DailyOrganizationSpend" USING btree (mcp_namespaced_tool_name);


--
-- Name: LiteLLM_DailyOrganizationSpend_model_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyOrganizationSpend_model_idx" ON public."LiteLLM_DailyOrganizationSpend" USING btree (model);


--
-- Name: LiteLLM_DailyOrganizationSpend_organization_id_date_api_key_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_DailyOrganizationSpend_organization_id_date_api_key_key" ON public."LiteLLM_DailyOrganizationSpend" USING btree (organization_id, date, api_key, model, custom_llm_provider, mcp_namespaced_tool_name, endpoint);


--
-- Name: LiteLLM_DailyOrganizationSpend_organization_id_date_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyOrganizationSpend_organization_id_date_idx" ON public."LiteLLM_DailyOrganizationSpend" USING btree (organization_id, date);


--
-- Name: LiteLLM_DailyPolicyMetrics_date_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyPolicyMetrics_date_idx" ON public."LiteLLM_DailyPolicyMetrics" USING btree (date);


--
-- Name: LiteLLM_DailyPolicyMetrics_policy_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyPolicyMetrics_policy_id_idx" ON public."LiteLLM_DailyPolicyMetrics" USING btree (policy_id);


--
-- Name: LiteLLM_DailyTagSpend_api_key_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyTagSpend_api_key_idx" ON public."LiteLLM_DailyTagSpend" USING btree (api_key);


--
-- Name: LiteLLM_DailyTagSpend_date_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyTagSpend_date_idx" ON public."LiteLLM_DailyTagSpend" USING btree (date);


--
-- Name: LiteLLM_DailyTagSpend_endpoint_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyTagSpend_endpoint_idx" ON public."LiteLLM_DailyTagSpend" USING btree (endpoint);


--
-- Name: LiteLLM_DailyTagSpend_mcp_namespaced_tool_name_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyTagSpend_mcp_namespaced_tool_name_idx" ON public."LiteLLM_DailyTagSpend" USING btree (mcp_namespaced_tool_name);


--
-- Name: LiteLLM_DailyTagSpend_model_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyTagSpend_model_idx" ON public."LiteLLM_DailyTagSpend" USING btree (model);


--
-- Name: LiteLLM_DailyTagSpend_tag_date_api_key_model_custom_llm_pro_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_DailyTagSpend_tag_date_api_key_model_custom_llm_pro_key" ON public."LiteLLM_DailyTagSpend" USING btree (tag, date, api_key, model, custom_llm_provider, mcp_namespaced_tool_name, endpoint);


--
-- Name: LiteLLM_DailyTagSpend_tag_date_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyTagSpend_tag_date_idx" ON public."LiteLLM_DailyTagSpend" USING btree (tag, date);


--
-- Name: LiteLLM_DailyTeamSpend_api_key_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyTeamSpend_api_key_idx" ON public."LiteLLM_DailyTeamSpend" USING btree (api_key);


--
-- Name: LiteLLM_DailyTeamSpend_date_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyTeamSpend_date_idx" ON public."LiteLLM_DailyTeamSpend" USING btree (date);


--
-- Name: LiteLLM_DailyTeamSpend_endpoint_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyTeamSpend_endpoint_idx" ON public."LiteLLM_DailyTeamSpend" USING btree (endpoint);


--
-- Name: LiteLLM_DailyTeamSpend_mcp_namespaced_tool_name_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyTeamSpend_mcp_namespaced_tool_name_idx" ON public."LiteLLM_DailyTeamSpend" USING btree (mcp_namespaced_tool_name);


--
-- Name: LiteLLM_DailyTeamSpend_model_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyTeamSpend_model_idx" ON public."LiteLLM_DailyTeamSpend" USING btree (model);


--
-- Name: LiteLLM_DailyTeamSpend_team_id_date_api_key_model_custom_ll_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_DailyTeamSpend_team_id_date_api_key_model_custom_ll_key" ON public."LiteLLM_DailyTeamSpend" USING btree (team_id, date, api_key, model, custom_llm_provider, mcp_namespaced_tool_name, endpoint);


--
-- Name: LiteLLM_DailyTeamSpend_team_id_date_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyTeamSpend_team_id_date_idx" ON public."LiteLLM_DailyTeamSpend" USING btree (team_id, date);


--
-- Name: LiteLLM_DailyUserSpend_api_key_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyUserSpend_api_key_idx" ON public."LiteLLM_DailyUserSpend" USING btree (api_key);


--
-- Name: LiteLLM_DailyUserSpend_date_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyUserSpend_date_idx" ON public."LiteLLM_DailyUserSpend" USING btree (date);


--
-- Name: LiteLLM_DailyUserSpend_endpoint_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyUserSpend_endpoint_idx" ON public."LiteLLM_DailyUserSpend" USING btree (endpoint);


--
-- Name: LiteLLM_DailyUserSpend_mcp_namespaced_tool_name_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyUserSpend_mcp_namespaced_tool_name_idx" ON public."LiteLLM_DailyUserSpend" USING btree (mcp_namespaced_tool_name);


--
-- Name: LiteLLM_DailyUserSpend_model_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyUserSpend_model_idx" ON public."LiteLLM_DailyUserSpend" USING btree (model);


--
-- Name: LiteLLM_DailyUserSpend_user_id_date_api_key_model_custom_ll_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_DailyUserSpend_user_id_date_api_key_model_custom_ll_key" ON public."LiteLLM_DailyUserSpend" USING btree (user_id, date, api_key, model, custom_llm_provider, mcp_namespaced_tool_name, endpoint);


--
-- Name: LiteLLM_DailyUserSpend_user_id_date_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DailyUserSpend_user_id_date_idx" ON public."LiteLLM_DailyUserSpend" USING btree (user_id, date);


--
-- Name: LiteLLM_DeletedTeamTable_created_at_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DeletedTeamTable_created_at_idx" ON public."LiteLLM_DeletedTeamTable" USING btree (created_at);


--
-- Name: LiteLLM_DeletedTeamTable_deleted_at_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DeletedTeamTable_deleted_at_idx" ON public."LiteLLM_DeletedTeamTable" USING btree (deleted_at);


--
-- Name: LiteLLM_DeletedTeamTable_organization_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DeletedTeamTable_organization_id_idx" ON public."LiteLLM_DeletedTeamTable" USING btree (organization_id);


--
-- Name: LiteLLM_DeletedTeamTable_team_alias_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DeletedTeamTable_team_alias_idx" ON public."LiteLLM_DeletedTeamTable" USING btree (team_alias);


--
-- Name: LiteLLM_DeletedTeamTable_team_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DeletedTeamTable_team_id_idx" ON public."LiteLLM_DeletedTeamTable" USING btree (team_id);


--
-- Name: LiteLLM_DeletedVerificationToken_created_at_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DeletedVerificationToken_created_at_idx" ON public."LiteLLM_DeletedVerificationToken" USING btree (created_at);


--
-- Name: LiteLLM_DeletedVerificationToken_deleted_at_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DeletedVerificationToken_deleted_at_idx" ON public."LiteLLM_DeletedVerificationToken" USING btree (deleted_at);


--
-- Name: LiteLLM_DeletedVerificationToken_key_alias_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DeletedVerificationToken_key_alias_idx" ON public."LiteLLM_DeletedVerificationToken" USING btree (key_alias);


--
-- Name: LiteLLM_DeletedVerificationToken_organization_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DeletedVerificationToken_organization_id_idx" ON public."LiteLLM_DeletedVerificationToken" USING btree (organization_id);


--
-- Name: LiteLLM_DeletedVerificationToken_team_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DeletedVerificationToken_team_id_idx" ON public."LiteLLM_DeletedVerificationToken" USING btree (team_id);


--
-- Name: LiteLLM_DeletedVerificationToken_token_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DeletedVerificationToken_token_idx" ON public."LiteLLM_DeletedVerificationToken" USING btree (token);


--
-- Name: LiteLLM_DeletedVerificationToken_user_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DeletedVerificationToken_user_id_idx" ON public."LiteLLM_DeletedVerificationToken" USING btree (user_id);


--
-- Name: LiteLLM_DeprecatedVerificationToken_revoke_at_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DeprecatedVerificationToken_revoke_at_idx" ON public."LiteLLM_DeprecatedVerificationToken" USING btree (revoke_at);


--
-- Name: LiteLLM_DeprecatedVerificationToken_token_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_DeprecatedVerificationToken_token_key" ON public."LiteLLM_DeprecatedVerificationToken" USING btree (token);


--
-- Name: LiteLLM_DeprecatedVerificationToken_token_revoke_at_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_DeprecatedVerificationToken_token_revoke_at_idx" ON public."LiteLLM_DeprecatedVerificationToken" USING btree (token, revoke_at);


--
-- Name: LiteLLM_GuardrailsTable_guardrail_name_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_GuardrailsTable_guardrail_name_key" ON public."LiteLLM_GuardrailsTable" USING btree (guardrail_name);


--
-- Name: LiteLLM_GuardrailsTable_status_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_GuardrailsTable_status_idx" ON public."LiteLLM_GuardrailsTable" USING btree (status);


--
-- Name: LiteLLM_HealthCheckTable_checked_at_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_HealthCheckTable_checked_at_idx" ON public."LiteLLM_HealthCheckTable" USING btree (checked_at);


--
-- Name: LiteLLM_HealthCheckTable_model_id_model_name_checked_at_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_HealthCheckTable_model_id_model_name_checked_at_idx" ON public."LiteLLM_HealthCheckTable" USING btree (model_id, model_name, checked_at DESC);


--
-- Name: LiteLLM_HealthCheckTable_model_name_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_HealthCheckTable_model_name_idx" ON public."LiteLLM_HealthCheckTable" USING btree (model_name);


--
-- Name: LiteLLM_HealthCheckTable_status_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_HealthCheckTable_status_idx" ON public."LiteLLM_HealthCheckTable" USING btree (status);


--
-- Name: LiteLLM_JWTKeyMapping_jwt_issuer_jwt_claim_name_jwt_claim_v_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_JWTKeyMapping_jwt_issuer_jwt_claim_name_jwt_claim_v_idx" ON public."LiteLLM_JWTKeyMapping" USING btree (jwt_issuer, jwt_claim_name, jwt_claim_value, is_active);


--
-- Name: LiteLLM_JWTKeyMapping_jwt_issuer_jwt_claim_name_jwt_claim_v_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_JWTKeyMapping_jwt_issuer_jwt_claim_name_jwt_claim_v_key" ON public."LiteLLM_JWTKeyMapping" USING btree (jwt_issuer, jwt_claim_name, jwt_claim_value);


--
-- Name: LiteLLM_LensRun_lens_id_created_at_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_LensRun_lens_id_created_at_idx" ON public."LiteLLM_LensRun" USING btree (lens_id, created_at);


--
-- Name: LiteLLM_MCPServerTable_approval_status_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_MCPServerTable_approval_status_idx" ON public."LiteLLM_MCPServerTable" USING btree (approval_status);


--
-- Name: LiteLLM_MCPToolsetTable_toolset_name_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_MCPToolsetTable_toolset_name_key" ON public."LiteLLM_MCPToolsetTable" USING btree (toolset_name);


--
-- Name: LiteLLM_MCPUserCredentials_user_id_server_id_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_MCPUserCredentials_user_id_server_id_key" ON public."LiteLLM_MCPUserCredentials" USING btree (user_id, server_id);


--
-- Name: LiteLLM_MCPUserEnvVars_server_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_MCPUserEnvVars_server_id_idx" ON public."LiteLLM_MCPUserEnvVars" USING btree (server_id);


--
-- Name: LiteLLM_MCPUserEnvVars_user_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_MCPUserEnvVars_user_id_idx" ON public."LiteLLM_MCPUserEnvVars" USING btree (user_id);


--
-- Name: LiteLLM_MCPUserEnvVars_user_id_server_id_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_MCPUserEnvVars_user_id_server_id_key" ON public."LiteLLM_MCPUserEnvVars" USING btree (user_id, server_id);


--
-- Name: LiteLLM_ManagedFileTable_team_id_created_at_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_ManagedFileTable_team_id_created_at_idx" ON public."LiteLLM_ManagedFileTable" USING btree (team_id, created_at DESC);


--
-- Name: LiteLLM_ManagedFileTable_unified_file_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_ManagedFileTable_unified_file_id_idx" ON public."LiteLLM_ManagedFileTable" USING btree (unified_file_id);


--
-- Name: LiteLLM_ManagedFileTable_unified_file_id_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_ManagedFileTable_unified_file_id_key" ON public."LiteLLM_ManagedFileTable" USING btree (unified_file_id);


--
-- Name: LiteLLM_ManagedObjectTable_model_object_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_ManagedObjectTable_model_object_id_idx" ON public."LiteLLM_ManagedObjectTable" USING btree (model_object_id);


--
-- Name: LiteLLM_ManagedObjectTable_model_object_id_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_ManagedObjectTable_model_object_id_key" ON public."LiteLLM_ManagedObjectTable" USING btree (model_object_id);


--
-- Name: LiteLLM_ManagedObjectTable_team_id_created_at_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_ManagedObjectTable_team_id_created_at_idx" ON public."LiteLLM_ManagedObjectTable" USING btree (team_id, created_at DESC);


--
-- Name: LiteLLM_ManagedObjectTable_unified_object_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_ManagedObjectTable_unified_object_id_idx" ON public."LiteLLM_ManagedObjectTable" USING btree (unified_object_id);


--
-- Name: LiteLLM_ManagedObjectTable_unified_object_id_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_ManagedObjectTable_unified_object_id_key" ON public."LiteLLM_ManagedObjectTable" USING btree (unified_object_id);


--
-- Name: LiteLLM_ManagedVectorStoreIndexTable_index_name_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_ManagedVectorStoreIndexTable_index_name_key" ON public."LiteLLM_ManagedVectorStoreIndexTable" USING btree (index_name);


--
-- Name: LiteLLM_ManagedVectorStoreTable_team_id_created_at_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_ManagedVectorStoreTable_team_id_created_at_idx" ON public."LiteLLM_ManagedVectorStoreTable" USING btree (team_id, created_at DESC);


--
-- Name: LiteLLM_ManagedVectorStoreTable_unified_resource_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_ManagedVectorStoreTable_unified_resource_id_idx" ON public."LiteLLM_ManagedVectorStoreTable" USING btree (unified_resource_id);


--
-- Name: LiteLLM_ManagedVectorStoreTable_unified_resource_id_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_ManagedVectorStoreTable_unified_resource_id_key" ON public."LiteLLM_ManagedVectorStoreTable" USING btree (unified_resource_id);


--
-- Name: LiteLLM_ManagedVectorStoresTable_team_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_ManagedVectorStoresTable_team_id_idx" ON public."LiteLLM_ManagedVectorStoresTable" USING btree (team_id);


--
-- Name: LiteLLM_ManagedVectorStoresTable_user_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_ManagedVectorStoresTable_user_id_idx" ON public."LiteLLM_ManagedVectorStoresTable" USING btree (user_id);


--
-- Name: LiteLLM_MemoryTable_key_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_MemoryTable_key_key" ON public."LiteLLM_MemoryTable" USING btree (key);


--
-- Name: LiteLLM_MemoryTable_team_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_MemoryTable_team_id_idx" ON public."LiteLLM_MemoryTable" USING btree (team_id);


--
-- Name: LiteLLM_MemoryTable_user_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_MemoryTable_user_id_idx" ON public."LiteLLM_MemoryTable" USING btree (user_id);


--
-- Name: LiteLLM_OrganizationMembership_user_id_organization_id_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_OrganizationMembership_user_id_organization_id_key" ON public."LiteLLM_OrganizationMembership" USING btree (user_id, organization_id);


--
-- Name: LiteLLM_PolicyTable_policy_name_version_number_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_PolicyTable_policy_name_version_number_key" ON public."LiteLLM_PolicyTable" USING btree (policy_name, version_number);


--
-- Name: LiteLLM_PolicyTable_policy_name_version_status_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_PolicyTable_policy_name_version_status_idx" ON public."LiteLLM_PolicyTable" USING btree (policy_name, version_status);


--
-- Name: LiteLLM_PromptTable_prompt_id_environment_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_PromptTable_prompt_id_environment_idx" ON public."LiteLLM_PromptTable" USING btree (prompt_id, environment);


--
-- Name: LiteLLM_PromptTable_prompt_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_PromptTable_prompt_id_idx" ON public."LiteLLM_PromptTable" USING btree (prompt_id);


--
-- Name: LiteLLM_PromptTable_prompt_id_version_environment_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_PromptTable_prompt_id_version_environment_key" ON public."LiteLLM_PromptTable" USING btree (prompt_id, version, environment);


--
-- Name: LiteLLM_RetiredAgentIdentity_provider_tenant_id_client_id_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_RetiredAgentIdentity_provider_tenant_id_client_id_key" ON public."LiteLLM_RetiredAgentIdentity" USING btree (provider, tenant_id, client_id);


--
-- Name: LiteLLM_SearchToolsTable_search_tool_name_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_SearchToolsTable_search_tool_name_key" ON public."LiteLLM_SearchToolsTable" USING btree (search_tool_name);


--
-- Name: LiteLLM_ShadowEvalAttempt_job_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_ShadowEvalAttempt_job_id_idx" ON public."LiteLLM_ShadowEvalAttempt" USING btree (job_id);


--
-- Name: LiteLLM_ShadowEvalJob_created_at_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_ShadowEvalJob_created_at_idx" ON public."LiteLLM_ShadowEvalJob" USING btree (created_at);


--
-- Name: LiteLLM_ShadowEvalJob_group_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_ShadowEvalJob_group_id_idx" ON public."LiteLLM_ShadowEvalJob" USING btree (group_id);


--
-- Name: LiteLLM_ShadowEvalJob_one_active_per_target_direction; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_ShadowEvalJob_one_active_per_target_direction" ON public."LiteLLM_ShadowEvalJob" USING btree (target_type, target_id, direction) WHERE (stopped_at IS NULL);


--
-- Name: LiteLLM_ShadowEvalJob_target_type_target_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_ShadowEvalJob_target_type_target_id_idx" ON public."LiteLLM_ShadowEvalJob" USING btree (target_type, target_id);


--
-- Name: LiteLLM_SpendLogGuardrailIndex_guardrail_id_start_time_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_SpendLogGuardrailIndex_guardrail_id_start_time_idx" ON public."LiteLLM_SpendLogGuardrailIndex" USING btree (guardrail_id, start_time);


--
-- Name: LiteLLM_SpendLogGuardrailIndex_policy_id_start_time_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_SpendLogGuardrailIndex_policy_id_start_time_idx" ON public."LiteLLM_SpendLogGuardrailIndex" USING btree (policy_id, start_time);


--
-- Name: LiteLLM_SpendLogToolIndex_start_time_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_SpendLogToolIndex_start_time_idx" ON public."LiteLLM_SpendLogToolIndex" USING btree (start_time);


--
-- Name: LiteLLM_SpendLogToolIndex_tool_name_start_time_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_SpendLogToolIndex_tool_name_start_time_idx" ON public."LiteLLM_SpendLogToolIndex" USING btree (tool_name, start_time);


--
-- Name: LiteLLM_SpendLogs_api_key_startTime_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_SpendLogs_api_key_startTime_idx" ON public."LiteLLM_SpendLogs" USING btree (api_key, "startTime");


--
-- Name: LiteLLM_SpendLogs_end_user_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_SpendLogs_end_user_idx" ON public."LiteLLM_SpendLogs" USING btree (end_user);


--
-- Name: LiteLLM_SpendLogs_litellm_call_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_SpendLogs_litellm_call_id_idx" ON public."LiteLLM_SpendLogs" USING btree (litellm_call_id);


--
-- Name: LiteLLM_SpendLogs_session_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_SpendLogs_session_id_idx" ON public."LiteLLM_SpendLogs" USING btree (session_id);


--
-- Name: LiteLLM_SpendLogs_startTime_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_SpendLogs_startTime_idx" ON public."LiteLLM_SpendLogs" USING btree ("startTime");


--
-- Name: LiteLLM_SpendLogs_startTime_request_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_SpendLogs_startTime_request_id_idx" ON public."LiteLLM_SpendLogs" USING btree ("startTime", request_id);


--
-- Name: LiteLLM_TeamTable_created_at_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_TeamTable_created_at_idx" ON public."LiteLLM_TeamTable" USING btree (created_at);


--
-- Name: LiteLLM_TeamTable_model_id_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_TeamTable_model_id_key" ON public."LiteLLM_TeamTable" USING btree (model_id);


--
-- Name: LiteLLM_TeamTable_organization_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_TeamTable_organization_id_idx" ON public."LiteLLM_TeamTable" USING btree (organization_id);


--
-- Name: LiteLLM_TeamTable_team_alias_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_TeamTable_team_alias_idx" ON public."LiteLLM_TeamTable" USING btree (team_alias);


--
-- Name: LiteLLM_ToolTable_input_policy_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_ToolTable_input_policy_idx" ON public."LiteLLM_ToolTable" USING btree (input_policy);


--
-- Name: LiteLLM_ToolTable_output_policy_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_ToolTable_output_policy_idx" ON public."LiteLLM_ToolTable" USING btree (output_policy);


--
-- Name: LiteLLM_ToolTable_team_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_ToolTable_team_id_idx" ON public."LiteLLM_ToolTable" USING btree (team_id);


--
-- Name: LiteLLM_ToolTable_tool_name_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_ToolTable_tool_name_key" ON public."LiteLLM_ToolTable" USING btree (tool_name);


--
-- Name: LiteLLM_UserTable_sso_user_id_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_UserTable_sso_user_id_key" ON public."LiteLLM_UserTable" USING btree (sso_user_id);


--
-- Name: LiteLLM_UserTable_user_email_lower_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_UserTable_user_email_lower_idx" ON public."LiteLLM_UserTable" USING btree (lower(user_email));


--
-- Name: LiteLLM_VerificationToken_budget_reset_at_expires_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_VerificationToken_budget_reset_at_expires_idx" ON public."LiteLLM_VerificationToken" USING btree (budget_reset_at, expires);


--
-- Name: LiteLLM_VerificationToken_team_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_VerificationToken_team_id_idx" ON public."LiteLLM_VerificationToken" USING btree (team_id);


--
-- Name: LiteLLM_VerificationToken_user_id_team_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_VerificationToken_user_id_team_id_idx" ON public."LiteLLM_VerificationToken" USING btree (user_id, team_id);


--
-- Name: LiteLLM_VerifiedSubject_issuer_tenant_id_oid_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_VerifiedSubject_issuer_tenant_id_oid_key" ON public."LiteLLM_VerifiedSubject" USING btree (issuer, tenant_id, oid);


--
-- Name: LiteLLM_VerifiedSubject_user_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_VerifiedSubject_user_id_idx" ON public."LiteLLM_VerifiedSubject" USING btree (user_id);


--
-- Name: LiteLLM_WorkflowEvent_run_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_WorkflowEvent_run_id_idx" ON public."LiteLLM_WorkflowEvent" USING btree (run_id);


--
-- Name: LiteLLM_WorkflowEvent_run_id_sequence_number_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_WorkflowEvent_run_id_sequence_number_key" ON public."LiteLLM_WorkflowEvent" USING btree (run_id, sequence_number);


--
-- Name: LiteLLM_WorkflowMessage_run_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_WorkflowMessage_run_id_idx" ON public."LiteLLM_WorkflowMessage" USING btree (run_id);


--
-- Name: LiteLLM_WorkflowMessage_run_id_sequence_number_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_WorkflowMessage_run_id_sequence_number_key" ON public."LiteLLM_WorkflowMessage" USING btree (run_id, sequence_number);


--
-- Name: LiteLLM_WorkflowRun_created_at_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_WorkflowRun_created_at_idx" ON public."LiteLLM_WorkflowRun" USING btree (created_at);


--
-- Name: LiteLLM_WorkflowRun_created_by_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_WorkflowRun_created_by_idx" ON public."LiteLLM_WorkflowRun" USING btree (created_by);


--
-- Name: LiteLLM_WorkflowRun_session_id_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_WorkflowRun_session_id_idx" ON public."LiteLLM_WorkflowRun" USING btree (session_id);


--
-- Name: LiteLLM_WorkflowRun_session_id_key; Type: INDEX; Schema: public; Owner: litellm
--

CREATE UNIQUE INDEX "LiteLLM_WorkflowRun_session_id_key" ON public."LiteLLM_WorkflowRun" USING btree (session_id);


--
-- Name: LiteLLM_WorkflowRun_workflow_type_status_idx; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX "LiteLLM_WorkflowRun_workflow_type_status_idx" ON public."LiteLLM_WorkflowRun" USING btree (workflow_type, status);


--
-- Name: idx_adaptive_router_session_activity; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX idx_adaptive_router_session_activity ON public."LiteLLM_AdaptiveRouterSession" USING btree (last_activity_at);


--
-- Name: idx_autorouter_baseline_dirty; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX idx_autorouter_baseline_dirty ON public."LiteLLM_AutoRouterBaselineComparison" USING btree (attempted_at, updated_at, scope) WHERE ((NOT retired) AND (revision <> published_revision));


--
-- Name: idx_autorouter_baseline_event_order; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX idx_autorouter_baseline_event_order ON public."LiteLLM_AutoRouterBaselineObservation" USING btree (scope, started_at, request_id);


--
-- Name: idx_autorouter_baseline_event_revision; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX idx_autorouter_baseline_event_revision ON public."LiteLLM_AutoRouterBaselineObservation" USING btree (scope, revision, started_at);


--
-- Name: idx_autorouter_baseline_scope; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX idx_autorouter_baseline_scope ON public."LiteLLM_AutoRouterBaselineComparison" USING btree (api_key, session_id, router_name);


--
-- Name: idx_autorouter_baseline_updated; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX idx_autorouter_baseline_updated ON public."LiteLLM_AutoRouterBaselineComparison" USING btree (updated_at);


--
-- Name: idx_autorouter_session_last_turn; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX idx_autorouter_session_last_turn ON public."LiteLLM_AutoRouterSession" USING btree (last_turn_at);


--
-- Name: idx_autorouter_user_session_last_turn; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX idx_autorouter_user_session_last_turn ON public."LiteLLM_AutoRouterUserSession" USING btree (last_turn_at);


--
-- Name: idx_autorouter_user_session_user_last_turn; Type: INDEX; Schema: public; Owner: litellm
--

CREATE INDEX idx_autorouter_user_session_user_last_turn ON public."LiteLLM_AutoRouterUserSession" USING btree (user_id, last_turn_at);


--
-- Name: LiteLLM_AgentIdentity LiteLLM_AgentIdentity_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_AgentIdentity"
    ADD CONSTRAINT "LiteLLM_AgentIdentity_agent_id_fkey" FOREIGN KEY (agent_id) REFERENCES public."LiteLLM_AgentsTable"(agent_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: LiteLLM_AgentsTable LiteLLM_AgentsTable_object_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_AgentsTable"
    ADD CONSTRAINT "LiteLLM_AgentsTable_object_permission_id_fkey" FOREIGN KEY (object_permission_id) REFERENCES public."LiteLLM_ObjectPermissionTable"(object_permission_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: LiteLLM_EndUserTable LiteLLM_EndUserTable_budget_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_EndUserTable"
    ADD CONSTRAINT "LiteLLM_EndUserTable_budget_id_fkey" FOREIGN KEY (budget_id) REFERENCES public."LiteLLM_BudgetTable"(budget_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: LiteLLM_EndUserTable LiteLLM_EndUserTable_object_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_EndUserTable"
    ADD CONSTRAINT "LiteLLM_EndUserTable_object_permission_id_fkey" FOREIGN KEY (object_permission_id) REFERENCES public."LiteLLM_ObjectPermissionTable"(object_permission_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: LiteLLM_InvitationLink LiteLLM_InvitationLink_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_InvitationLink"
    ADD CONSTRAINT "LiteLLM_InvitationLink_created_by_fkey" FOREIGN KEY (created_by) REFERENCES public."LiteLLM_UserTable"(user_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: LiteLLM_InvitationLink LiteLLM_InvitationLink_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_InvitationLink"
    ADD CONSTRAINT "LiteLLM_InvitationLink_updated_by_fkey" FOREIGN KEY (updated_by) REFERENCES public."LiteLLM_UserTable"(user_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: LiteLLM_InvitationLink LiteLLM_InvitationLink_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_InvitationLink"
    ADD CONSTRAINT "LiteLLM_InvitationLink_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public."LiteLLM_UserTable"(user_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: LiteLLM_JWTKeyMapping LiteLLM_JWTKeyMapping_token_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_JWTKeyMapping"
    ADD CONSTRAINT "LiteLLM_JWTKeyMapping_token_fkey" FOREIGN KEY (token) REFERENCES public."LiteLLM_VerificationToken"(token) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: LiteLLM_ModelAccessGroupBudgetTable LiteLLM_ModelAccessGroupBudgetTable_budget_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ModelAccessGroupBudgetTable"
    ADD CONSTRAINT "LiteLLM_ModelAccessGroupBudgetTable_budget_id_fkey" FOREIGN KEY (budget_id) REFERENCES public."LiteLLM_BudgetTable"(budget_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: LiteLLM_OrganizationMembership LiteLLM_OrganizationMembership_budget_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_OrganizationMembership"
    ADD CONSTRAINT "LiteLLM_OrganizationMembership_budget_id_fkey" FOREIGN KEY (budget_id) REFERENCES public."LiteLLM_BudgetTable"(budget_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: LiteLLM_OrganizationMembership LiteLLM_OrganizationMembership_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_OrganizationMembership"
    ADD CONSTRAINT "LiteLLM_OrganizationMembership_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public."LiteLLM_OrganizationTable"(organization_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: LiteLLM_OrganizationMembership LiteLLM_OrganizationMembership_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_OrganizationMembership"
    ADD CONSTRAINT "LiteLLM_OrganizationMembership_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public."LiteLLM_UserTable"(user_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: LiteLLM_OrganizationTable LiteLLM_OrganizationTable_budget_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_OrganizationTable"
    ADD CONSTRAINT "LiteLLM_OrganizationTable_budget_id_fkey" FOREIGN KEY (budget_id) REFERENCES public."LiteLLM_BudgetTable"(budget_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: LiteLLM_OrganizationTable LiteLLM_OrganizationTable_object_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_OrganizationTable"
    ADD CONSTRAINT "LiteLLM_OrganizationTable_object_permission_id_fkey" FOREIGN KEY (object_permission_id) REFERENCES public."LiteLLM_ObjectPermissionTable"(object_permission_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: LiteLLM_ProjectTable LiteLLM_ProjectTable_budget_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ProjectTable"
    ADD CONSTRAINT "LiteLLM_ProjectTable_budget_id_fkey" FOREIGN KEY (budget_id) REFERENCES public."LiteLLM_BudgetTable"(budget_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: LiteLLM_ProjectTable LiteLLM_ProjectTable_object_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ProjectTable"
    ADD CONSTRAINT "LiteLLM_ProjectTable_object_permission_id_fkey" FOREIGN KEY (object_permission_id) REFERENCES public."LiteLLM_ObjectPermissionTable"(object_permission_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: LiteLLM_ProjectTable LiteLLM_ProjectTable_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_ProjectTable"
    ADD CONSTRAINT "LiteLLM_ProjectTable_team_id_fkey" FOREIGN KEY (team_id) REFERENCES public."LiteLLM_TeamTable"(team_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: LiteLLM_RetiredAgentIdentity LiteLLM_RetiredAgentIdentity_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_RetiredAgentIdentity"
    ADD CONSTRAINT "LiteLLM_RetiredAgentIdentity_agent_id_fkey" FOREIGN KEY (agent_id) REFERENCES public."LiteLLM_AgentsTable"(agent_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: LiteLLM_TagTable LiteLLM_TagTable_budget_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_TagTable"
    ADD CONSTRAINT "LiteLLM_TagTable_budget_id_fkey" FOREIGN KEY (budget_id) REFERENCES public."LiteLLM_BudgetTable"(budget_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: LiteLLM_TeamMembership LiteLLM_TeamMembership_budget_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_TeamMembership"
    ADD CONSTRAINT "LiteLLM_TeamMembership_budget_id_fkey" FOREIGN KEY (budget_id) REFERENCES public."LiteLLM_BudgetTable"(budget_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: LiteLLM_TeamTable LiteLLM_TeamTable_model_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_TeamTable"
    ADD CONSTRAINT "LiteLLM_TeamTable_model_id_fkey" FOREIGN KEY (model_id) REFERENCES public."LiteLLM_ModelTable"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: LiteLLM_TeamTable LiteLLM_TeamTable_object_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_TeamTable"
    ADD CONSTRAINT "LiteLLM_TeamTable_object_permission_id_fkey" FOREIGN KEY (object_permission_id) REFERENCES public."LiteLLM_ObjectPermissionTable"(object_permission_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: LiteLLM_TeamTable LiteLLM_TeamTable_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_TeamTable"
    ADD CONSTRAINT "LiteLLM_TeamTable_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public."LiteLLM_OrganizationTable"(organization_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: LiteLLM_UserTable LiteLLM_UserTable_object_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_UserTable"
    ADD CONSTRAINT "LiteLLM_UserTable_object_permission_id_fkey" FOREIGN KEY (object_permission_id) REFERENCES public."LiteLLM_ObjectPermissionTable"(object_permission_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: LiteLLM_UserTable LiteLLM_UserTable_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_UserTable"
    ADD CONSTRAINT "LiteLLM_UserTable_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public."LiteLLM_OrganizationTable"(organization_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: LiteLLM_VerificationToken LiteLLM_VerificationToken_budget_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_VerificationToken"
    ADD CONSTRAINT "LiteLLM_VerificationToken_budget_id_fkey" FOREIGN KEY (budget_id) REFERENCES public."LiteLLM_BudgetTable"(budget_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: LiteLLM_VerificationToken LiteLLM_VerificationToken_object_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_VerificationToken"
    ADD CONSTRAINT "LiteLLM_VerificationToken_object_permission_id_fkey" FOREIGN KEY (object_permission_id) REFERENCES public."LiteLLM_ObjectPermissionTable"(object_permission_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: LiteLLM_VerificationToken LiteLLM_VerificationToken_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_VerificationToken"
    ADD CONSTRAINT "LiteLLM_VerificationToken_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public."LiteLLM_OrganizationTable"(organization_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: LiteLLM_VerificationToken LiteLLM_VerificationToken_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_VerificationToken"
    ADD CONSTRAINT "LiteLLM_VerificationToken_project_id_fkey" FOREIGN KEY (project_id) REFERENCES public."LiteLLM_ProjectTable"(project_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: LiteLLM_VerifiedSubject LiteLLM_VerifiedSubject_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_VerifiedSubject"
    ADD CONSTRAINT "LiteLLM_VerifiedSubject_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public."LiteLLM_UserTable"(user_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: LiteLLM_WorkflowEvent LiteLLM_WorkflowEvent_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_WorkflowEvent"
    ADD CONSTRAINT "LiteLLM_WorkflowEvent_run_id_fkey" FOREIGN KEY (run_id) REFERENCES public."LiteLLM_WorkflowRun"(run_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: LiteLLM_WorkflowMessage LiteLLM_WorkflowMessage_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: litellm
--

ALTER TABLE ONLY public."LiteLLM_WorkflowMessage"
    ADD CONSTRAINT "LiteLLM_WorkflowMessage_run_id_fkey" FOREIGN KEY (run_id) REFERENCES public."LiteLLM_WorkflowRun"(run_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

\unrestrict GGrmIiveQagJSX1rGjFJv6PNW8Pc7ibD22afze12DGDpW1RHWSDXAvBIhInqY9L

