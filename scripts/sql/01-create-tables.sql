-- Clinical Forecasting Engine - Database Schema
-- Based on healthcare domain specifications

-- 1. Eligibility Inquiry Events (270/271 EDI transactions)
CREATE TABLE IF NOT EXISTS eligibility_inquiry_event (
    elig_event_id SERIAL PRIMARY KEY,
    inquiry_ts TIMESTAMP NOT NULL,
    source_channel VARCHAR(50) CHECK (source_channel IN ('portal', 'api', 'clearinghouse', 'batch')),
    payer_id VARCHAR(50) NOT NULL,
    member_id VARCHAR(50) NOT NULL,
    subscriber_id VARCHAR(50),
    provider_npi VARCHAR(10) NOT NULL,
    provider_tin VARCHAR(20),
    provider_taxonomy VARCHAR(50),
    service_type_codes TEXT[], -- Array of X12 EB segment service type codes
    place_of_service VARCHAR(2),
    network_indicator VARCHAR(20) CHECK (network_indicator IN ('in', 'out', 'unknown')),
    plan_id VARCHAR(50),
    product_id VARCHAR(50),
    group_id VARCHAR(50),
    coverage_status VARCHAR(20) CHECK (coverage_status IN ('active', 'inactive', 'unknown')),
    benefit_snapshot_json JSONB,
    response_code VARCHAR(50),
    trace_id VARCHAR(100),
    edi_control_number VARCHAR(50),
    raw_270_ref TEXT,
    raw_271_ref TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_member_inquiry (member_id, inquiry_ts),
    INDEX idx_provider (provider_npi),
    INDEX idx_inquiry_ts (inquiry_ts)
);

-- 2. Prior Authorization Requests (PA/UM)
CREATE TABLE IF NOT EXISTS prior_auth_request (
    pa_id SERIAL PRIMARY KEY,
    request_ts TIMESTAMP NOT NULL,
    decision_ts TIMESTAMP,
    status VARCHAR(20) CHECK (status IN ('requested', 'pended', 'approved', 'denied', 'withdrawn')),
    decision_code VARCHAR(50),
    denial_reason_code VARCHAR(50),
    member_id VARCHAR(50) NOT NULL,
    requesting_provider_npi VARCHAR(10) NOT NULL,
    servicing_provider_npi VARCHAR(10),
    facility_npi VARCHAR(10),
    service_from_date DATE,
    service_to_date DATE,
    place_of_service VARCHAR(2),
    diagnosis_codes TEXT[], -- ICD-10 codes
    procedure_codes TEXT[], -- CPT/HCPCS codes
    drg_code VARCHAR(10),
    units_requested INT,
    clinical_type VARCHAR(50) CHECK (clinical_type IN ('inpatient', 'outpatient', 'DME', 'imaging', 'surgery')),
    line_of_business VARCHAR(20) CHECK (line_of_business IN ('MA', 'Medicaid', 'Commercial')),
    plan_id VARCHAR(50),
    product_id VARCHAR(50),
    urgency VARCHAR(20) CHECK (urgency IN ('standard', 'expedited')),
    referral_required_flag BOOLEAN,
    case_mgr_id VARCHAR(50),
    queue VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_member_pa (member_id, request_ts),
    INDEX idx_status (status),
    INDEX idx_procedure_codes USING GIN (procedure_codes),
    INDEX idx_service_dates (service_from_date, service_to_date)
);

-- 3. Claim Header
CREATE TABLE IF NOT EXISTS claim_header (
    claim_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL,
    claim_type VARCHAR(20) CHECK (claim_type IN ('professional', 'institutional', 'dental', 'pharm')),
    from_date DATE NOT NULL,
    thru_date DATE,
    received_ts TIMESTAMP,
    adjudicated_ts TIMESTAMP,
    paid_date DATE,
    claim_status VARCHAR(20) CHECK (claim_status IN ('paid', 'denied', 'void', 'adjusted')),
    billing_provider_npi VARCHAR(10),
    rendering_provider_npi VARCHAR(10),
    facility_npi VARCHAR(10),
    place_of_service VARCHAR(2),
    bill_type VARCHAR(4),
    total_billed_amt DECIMAL(12,2),
    total_allowed_amt DECIMAL(12,2),
    total_paid_amt DECIMAL(12,2),
    line_of_business VARCHAR(20),
    plan_id VARCHAR(50),
    product_id VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_member_claim (member_id, from_date),
    INDEX idx_claim_status (claim_status),
    INDEX idx_adjudicated (adjudicated_ts)
);

-- 4. Claim Lines
CREATE TABLE IF NOT EXISTS claim_line (
    claim_line_id SERIAL PRIMARY KEY,
    claim_id VARCHAR(50) NOT NULL REFERENCES claim_header(claim_id),
    line_num INT NOT NULL,
    service_date DATE NOT NULL,
    procedure_code VARCHAR(10) NOT NULL,
    modifier1 VARCHAR(2),
    modifier2 VARCHAR(2),
    modifier3 VARCHAR(2),
    modifier4 VARCHAR(2),
    revenue_code VARCHAR(4),
    diagnosis_pointers VARCHAR(20),
    units INT,
    billed_amt DECIMAL(10,2),
    allowed_amt DECIMAL(10,2),
    paid_amt DECIMAL(10,2),
    line_status VARCHAR(20) CHECK (line_status IN ('paid', 'denied')),
    denial_code VARCHAR(10),
    edit_code VARCHAR(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (claim_id, line_num),
    INDEX idx_procedure_code (procedure_code),
    INDEX idx_service_date (service_date),
    INDEX idx_claim_line (claim_id)
);

-- 5. Clinical Intent Event (Canonical unified layer)
CREATE TABLE IF NOT EXISTS clinical_intent_event (
    intent_event_id SERIAL PRIMARY KEY,
    intent_ts TIMESTAMP NOT NULL,
    member_id VARCHAR(50) NOT NULL,
    provider_npi VARCHAR(10),
    signal_type VARCHAR(20) CHECK (signal_type IN ('elig', 'pa', 'referral', 'rtbc', 'um_attach')),
    service_category VARCHAR(50), -- e.g., 'ortho_knee', 'imaging_mri', 'cardio_stress'
    codes TEXT[], -- CPT/HCPCS/ICD/service-type codes
    signal_strength DECIMAL(3,2) CHECK (signal_strength BETWEEN 0 AND 1),
    source_system VARCHAR(50),
    source_record_id VARCHAR(100), -- Reference to original record (elig_event_id, pa_id, etc.)
    metadata_json JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_member_intent (member_id, intent_ts),
    INDEX idx_signal_type (signal_type),
    INDEX idx_service_category (service_category),
    INDEX idx_codes USING GIN (codes)
);

-- 6. Clinical Outcome Event (Ground truth from claims)
CREATE TABLE IF NOT EXISTS clinical_outcome_event (
    outcome_event_id SERIAL PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL,
    event_type VARCHAR(50) NOT NULL, -- e.g., 'tka', 'hip', 'mri', 'admit', 'infusion'
    event_date DATE NOT NULL, -- Anchor date (earliest qualifying service_date)
    confirming_claim_id VARCHAR(50) REFERENCES claim_header(claim_id),
    confirming_codes TEXT[], -- Codes that confirmed this event
    allowed_amt DECIMAL(10,2),
    place_of_service VARCHAR(2),
    provider_npi VARCHAR(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_member_outcome (member_id, event_date),
    INDEX idx_event_type (event_type),
    INDEX idx_confirming_claim (confirming_claim_id)
);

-- 7. Service Category Code Map (for mapping codes to categories)
CREATE TABLE IF NOT EXISTS service_category_code_map (
    map_id SERIAL PRIMARY KEY,
    service_category VARCHAR(50) NOT NULL,
    code_system VARCHAR(20) CHECK (code_system IN ('CPT', 'HCPCS', 'ICD10', 'X12_STC')),
    code VARCHAR(20) NOT NULL,
    weight_hint DECIMAL(3,2), -- Optional weighting for signal strength
    effective_date DATE,
    end_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (service_category, code_system, code),
    INDEX idx_category (service_category),
    INDEX idx_code (code_system, code)
);

-- 8. Member Demographics (reference table)
CREATE TABLE IF NOT EXISTS member (
    member_id VARCHAR(50) PRIMARY KEY,
    date_of_birth DATE,
    gender VARCHAR(1),
    plan_id VARCHAR(50),
    product_id VARCHAR(50),
    line_of_business VARCHAR(20),
    effective_date DATE,
    termination_date DATE,
    risk_score DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_plan (plan_id),
    INDEX idx_lob (line_of_business)
);

-- 9. Prediction Results (model output)
CREATE TABLE IF NOT EXISTS prediction_result (
    prediction_id SERIAL PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    prediction_date DATE NOT NULL,
    predicted_event_date DATE,
    probability DECIMAL(5,4) CHECK (probability BETWEEN 0 AND 1),
    risk_tier VARCHAR(20) CHECK (risk_tier IN ('very_high', 'high', 'medium', 'low')),
    contributing_signals JSONB, -- Details about which signals contributed
    model_version VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_member_prediction (member_id, prediction_date),
    INDEX idx_risk_tier (risk_tier),
    INDEX idx_event_type_pred (event_type)
);
