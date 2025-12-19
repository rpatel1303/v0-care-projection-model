-- Clinical Forecasting Engine - Unified PostgreSQL/Supabase Schema
-- This consolidates all tables needed for the application
-- Run this FIRST before any other scripts

-- Drop existing tables if they exist (for clean reinstall)
DROP TABLE IF EXISTS prediction_result CASCADE;
DROP TABLE IF EXISTS clinical_outcome_event CASCADE;
DROP TABLE IF EXISTS clinical_intent_event CASCADE;
DROP TABLE IF EXISTS claim_line CASCADE;
DROP TABLE IF EXISTS claim_header CASCADE;
DROP TABLE IF EXISTS rx_benefit_inquiry CASCADE;
DROP TABLE IF EXISTS prior_auth_request CASCADE;
DROP TABLE IF EXISTS eligibility_inquiry_event CASCADE;
DROP TABLE IF EXISTS member_chronic_condition CASCADE;
DROP TABLE IF EXISTS episode_diagnosis_map CASCADE;
DROP TABLE IF EXISTS episode_procedure_map CASCADE;
DROP TABLE IF EXISTS episode_definition CASCADE;
DROP TABLE IF EXISTS member CASCADE;
DROP TABLE IF EXISTS episode_code_mapping CASCADE;

-- 1. Episode definitions (types of care episodes we can predict)
CREATE TABLE episode_definition (
  episode_id TEXT PRIMARY KEY,
  episode_name TEXT NOT NULL,
  episode_category TEXT NOT NULL,
  description TEXT,
  average_cost DECIMAL(12,2),
  typical_los_days INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Procedure code mappings (CPT codes that identify episodes)
CREATE TABLE episode_procedure_map (
  id SERIAL PRIMARY KEY,
  episode_id TEXT REFERENCES episode_definition(episode_id),
  procedure_code TEXT NOT NULL,
  procedure_description TEXT,
  is_primary BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(episode_id, procedure_code)
);

-- 3. Diagnosis code mappings (ICD-10 codes associated with episodes)
CREATE TABLE episode_diagnosis_map (
  id SERIAL PRIMARY KEY,
  episode_id TEXT REFERENCES episode_definition(episode_id),
  diagnosis_code TEXT NOT NULL,
  diagnosis_description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(episode_id, diagnosis_code)
);

-- 4. Member demographics (from proprietary enrollment system)
CREATE TABLE member (
  member_id TEXT PRIMARY KEY,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  date_of_birth DATE NOT NULL,
  gender TEXT CHECK (gender IN ('M', 'F', 'U')),
  address_street TEXT,
  address_city TEXT,
  address_state TEXT,
  address_zip TEXT,
  phone TEXT,
  email TEXT,
  plan_type TEXT,
  network TEXT,
  geographic_region TEXT,
  enrollment_date DATE,
  enrollment_status TEXT CHECK (enrollment_status IN ('active', 'termed', 'suspended')),
  termination_date DATE,
  pcp_npi TEXT,
  pcp_name TEXT,
  pcp_specialty TEXT,
  risk_score DECIMAL(5,2),
  hcc_score DECIMAL(8,2),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Chronic conditions
CREATE TABLE member_chronic_condition (
  id SERIAL PRIMARY KEY,
  member_id TEXT REFERENCES member(member_id) ON DELETE CASCADE,
  icd10_code TEXT NOT NULL,
  description TEXT,
  diagnosis_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Eligibility inquiry events (270/271 transactions)
CREATE TABLE eligibility_inquiry_event (
  event_id TEXT PRIMARY KEY,
  member_id TEXT REFERENCES member(member_id),
  inquiry_date TIMESTAMPTZ NOT NULL,
  service_type_code TEXT,
  procedure_code TEXT,
  diagnosis_code TEXT,
  provider_npi TEXT,
  eligibility_status TEXT,
  coverage_status TEXT,
  raw_edi_data TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Prior authorization requests AND referrals (both use 278 EDI)
-- Added request_type, servicing_provider_npi, referred_provider_name, referred_provider_specialty to support referrals
CREATE TABLE prior_auth_request (
  auth_id TEXT PRIMARY KEY,
  member_id TEXT REFERENCES member(member_id),
  request_date TIMESTAMPTZ NOT NULL,
  request_type TEXT CHECK (request_type IN ('prior_authorization', 'referral')),
  service_type_code TEXT,
  auth_status TEXT CHECK (auth_status IN ('requested', 'approved', 'denied', 'pended')),
  procedure_code TEXT,
  diagnosis_code TEXT,
  requesting_provider_npi TEXT,
  servicing_provider_npi TEXT,
  referred_provider_name TEXT,
  referred_provider_specialty TEXT,
  requested_service_date DATE,
  raw_edi_data TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Added new table for Rx benefit inquiries
-- 8. Rx (pharmacy) benefit inquiry events
CREATE TABLE rx_benefit_inquiry (
  inquiry_id TEXT PRIMARY KEY,
  member_id TEXT REFERENCES member(member_id),
  inquiry_date TIMESTAMPTZ NOT NULL,
  ndc_code TEXT,
  drug_name TEXT,
  drug_class TEXT,
  prescriber_npi TEXT,
  pharmacy_npi TEXT,
  days_supply INTEGER,
  quantity DECIMAL(10,2),
  coverage_status TEXT,
  copay_amount DECIMAL(8,2),
  indication TEXT,
  raw_transaction_data TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Moved claim_header BEFORE claim_line to fix foreign key reference
-- 9. Claim header (837 transactions)
CREATE TABLE claim_header (
  claim_id TEXT PRIMARY KEY,
  member_id TEXT REFERENCES member(member_id),
  claim_type TEXT CHECK (claim_type IN ('Institutional', 'Professional')),
  claim_status TEXT CHECK (claim_status IN ('Submitted', 'Adjudicated', 'Paid', 'Denied')),
  service_from_date DATE NOT NULL,
  service_to_date DATE,
  billing_provider_npi TEXT,
  rendering_provider_npi TEXT,
  facility_npi TEXT,
  total_charge_amount DECIMAL(12,2),
  paid_amount DECIMAL(12,2),
  raw_edi_data TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. Claim line items
CREATE TABLE claim_line (
  line_id TEXT PRIMARY KEY,
  claim_id TEXT REFERENCES claim_header(claim_id) ON DELETE CASCADE,
  line_number INTEGER NOT NULL,
  procedure_code TEXT NOT NULL,
  diagnosis_code TEXT,
  service_date DATE NOT NULL,
  charge_amount DECIMAL(12,2),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (claim_id, line_number)
);

-- 11. Clinical intent events (unified view of eligibility + PA + Rx + Referrals)
CREATE TABLE clinical_intent_event (
  intent_event_id TEXT PRIMARY KEY,
  member_id TEXT REFERENCES member(member_id),
  episode_id TEXT REFERENCES episode_definition(episode_id),
  event_date TIMESTAMPTZ NOT NULL,
  event_type TEXT CHECK (event_type IN ('Eligibility_Inquiry', 'Prior_Auth_Request', 'Rx_Benefit_Check', 'Referral')),
  event_source_id TEXT,
  procedure_code TEXT,
  diagnosis_code TEXT,
  provider_npi TEXT,
  signal_strength DECIMAL(5,2),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 12. Clinical outcome events (actual procedures performed)
CREATE TABLE clinical_outcome_event (
  outcome_event_id TEXT PRIMARY KEY,
  member_id TEXT REFERENCES member(member_id),
  episode_id TEXT REFERENCES episode_definition(episode_id),
  claim_id TEXT REFERENCES claim_header(claim_id),
  procedure_date DATE NOT NULL,
  procedure_code TEXT NOT NULL,
  diagnosis_code TEXT,
  provider_npi TEXT,
  facility_npi TEXT,
  total_cost DECIMAL(12,2),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 13. Prediction results (ML model output)
CREATE TABLE prediction_result (
  prediction_id TEXT PRIMARY KEY,
  member_id TEXT REFERENCES member(member_id),
  episode_id TEXT REFERENCES episode_definition(episode_id),
  prediction_date TIMESTAMPTZ NOT NULL,
  predicted_event_date DATE,
  probability_score DECIMAL(5,4),
  risk_tier TEXT CHECK (risk_tier IN ('very_high', 'high', 'medium', 'low')),
  predicted_cost DECIMAL(12,2),
  confidence_interval_low DECIMAL(12,2),
  confidence_interval_high DECIMAL(12,2),
  model_version TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Adding episode_code_mapping table for database-driven rules
-- This table replaces hardcoded logic and supports multi-client customization
CREATE TABLE episode_code_mapping (
  id SERIAL PRIMARY KEY,
  episode_id TEXT REFERENCES episode_definition(episode_id),
  code_type TEXT NOT NULL CHECK (code_type IN ('CPT', 'ICD10', 'ICD9', 'NDC', 'HCPCS', 'DRG', 'Revenue')),
  code_value TEXT NOT NULL,
  code_description TEXT,
  is_primary BOOLEAN DEFAULT false,
  signal_strength DECIMAL(5,2) DEFAULT 50.0 CHECK (signal_strength >= 0 AND signal_strength <= 100),
  effective_date DATE DEFAULT CURRENT_DATE,
  expiration_date DATE,
  client_id TEXT DEFAULT 'default',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(episode_id, code_type, code_value, client_id)
);

-- Create indexes for performance
CREATE INDEX idx_member_enrollment_status ON member(enrollment_status);
CREATE INDEX idx_member_region ON member(geographic_region);
CREATE INDEX idx_member_network ON member(network);
CREATE INDEX idx_member_plan ON member(plan_type);

CREATE INDEX idx_eligibility_member_date ON eligibility_inquiry_event(member_id, inquiry_date);
CREATE INDEX idx_eligibility_procedure ON eligibility_inquiry_event(procedure_code);

CREATE INDEX idx_prior_auth_member_date ON prior_auth_request(member_id, request_date);
CREATE INDEX idx_prior_auth_procedure ON prior_auth_request(procedure_code);
CREATE INDEX idx_prior_auth_status ON prior_auth_request(auth_status);
CREATE INDEX idx_prior_auth_request_type ON prior_auth_request(request_type);

CREATE INDEX idx_rx_benefit_member_date ON rx_benefit_inquiry(member_id, inquiry_date);
CREATE INDEX idx_rx_benefit_ndc ON rx_benefit_inquiry(ndc_code);
CREATE INDEX idx_rx_benefit_drug_class ON rx_benefit_inquiry(drug_class);

CREATE INDEX idx_claim_member_date ON claim_header(member_id, service_from_date);
CREATE INDEX idx_claim_status ON claim_header(claim_status);

CREATE INDEX idx_claim_line_procedure ON claim_line(procedure_code);
CREATE INDEX idx_claim_line_date ON claim_line(service_date);

CREATE INDEX idx_intent_member_episode ON clinical_intent_event(member_id, episode_id);
CREATE INDEX idx_intent_event_type ON clinical_intent_event(event_type);

CREATE INDEX idx_outcome_member_episode ON clinical_outcome_event(member_id, episode_id);
CREATE INDEX idx_outcome_date ON clinical_outcome_event(procedure_date);

CREATE INDEX idx_prediction_member_episode ON prediction_result(member_id, episode_id);
CREATE INDEX idx_prediction_date ON prediction_result(predicted_event_date);
CREATE INDEX idx_prediction_risk_tier ON prediction_result(risk_tier);

-- Creating composite index for fast lookups at scale
CREATE INDEX idx_code_mapping_lookup ON episode_code_mapping(code_type, code_value, client_id);
CREATE INDEX idx_code_mapping_episode ON episode_code_mapping(episode_id, is_primary);
CREATE INDEX idx_code_mapping_expiration ON episode_code_mapping(expiration_date) WHERE expiration_date IS NOT NULL;

-- EDI Loader Functions (consolidated)
CREATE OR REPLACE FUNCTION load_270_eligibility(
  p_member_id TEXT,
  p_inquiry_date TIMESTAMPTZ,
  p_service_type_code TEXT,
  p_procedure_code TEXT,
  p_diagnosis_code TEXT,
  p_provider_npi TEXT,
  p_eligibility_status TEXT,
  p_coverage_status TEXT,
  p_raw_edi TEXT
) RETURNS TEXT AS $$
DECLARE
  v_event_id TEXT;
BEGIN
  v_event_id := 'ELG-' || p_member_id || '-' || TO_CHAR(p_inquiry_date, 'YYYYMMDDHH24MISS');
  
  INSERT INTO eligibility_inquiry_event (
    event_id, member_id, inquiry_date, service_type_code, procedure_code,
    diagnosis_code, provider_npi, eligibility_status, coverage_status, raw_edi_data
  ) VALUES (
    v_event_id, p_member_id, p_inquiry_date, p_service_type_code, p_procedure_code,
    p_diagnosis_code, p_provider_npi, p_eligibility_status, p_coverage_status, p_raw_edi
  ) ON CONFLICT (event_id) DO NOTHING;
  
  RETURN v_event_id;
END;
$$ LANGUAGE plpgsql;

-- Updated function to support request_type parameter for referrals
CREATE OR REPLACE FUNCTION load_278_prior_auth(
  p_member_id TEXT,
  p_request_date TIMESTAMPTZ,
  p_request_type TEXT,
  p_service_type_code TEXT,
  p_auth_status TEXT,
  p_procedure_code TEXT,
  p_diagnosis_code TEXT,
  p_requesting_provider_npi TEXT,
  p_servicing_provider_npi TEXT,
  p_referred_provider_name TEXT,
  p_referred_provider_specialty TEXT,
  p_requested_service_date DATE,
  p_raw_edi TEXT
) RETURNS TEXT AS $$
DECLARE
  v_auth_id TEXT;
BEGIN
  v_auth_id := CASE 
    WHEN p_request_type = 'referral' THEN 'REF-'
    ELSE 'PA-'
  END || p_member_id || '-' || TO_CHAR(p_request_date, 'YYYYMMDDHH24MISS');
  
  INSERT INTO prior_auth_request (
    auth_id, member_id, request_date, request_type, service_type_code, auth_status, 
    procedure_code, diagnosis_code, requesting_provider_npi, servicing_provider_npi,
    referred_provider_name, referred_provider_specialty, requested_service_date, raw_edi_data
  ) VALUES (
    v_auth_id, p_member_id, p_request_date, p_request_type, p_service_type_code, p_auth_status, 
    p_procedure_code, p_diagnosis_code, p_requesting_provider_npi, p_servicing_provider_npi,
    p_referred_provider_name, p_referred_provider_specialty, p_requested_service_date, p_raw_edi
  ) ON CONFLICT (auth_id) DO NOTHING;
  
  RETURN v_auth_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION load_837_claim_header(
  p_claim_id TEXT,
  p_member_id TEXT,
  p_claim_type TEXT,
  p_service_from_date DATE,
  p_service_to_date DATE,
  p_billing_provider_npi TEXT,
  p_facility_npi TEXT,
  p_total_charge_amount DECIMAL,
  p_raw_edi TEXT
) RETURNS TEXT AS $$
BEGIN
  INSERT INTO claim_header (
    claim_id, member_id, claim_type, claim_status, service_from_date,
    service_to_date, billing_provider_npi, facility_npi, total_charge_amount, raw_edi_data
  ) VALUES (
    p_claim_id, p_member_id, p_claim_type, 'Submitted', p_service_from_date,
    p_service_to_date, p_billing_provider_npi, p_facility_npi, p_total_charge_amount, p_raw_edi
  ) ON CONFLICT (claim_id) DO NOTHING;
  
  RETURN p_claim_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION load_837_claim_line(
  p_claim_id TEXT,
  p_line_number INTEGER,
  p_procedure_code TEXT,
  p_diagnosis_code TEXT,
  p_service_date DATE,
  p_charge_amount DECIMAL
) RETURNS TEXT AS $$
DECLARE
  v_line_id TEXT;
BEGIN
  v_line_id := p_claim_id || '-LINE-' || p_line_number;
  
  INSERT INTO claim_line (
    line_id, claim_id, line_number, procedure_code, diagnosis_code,
    service_date, charge_amount
  ) VALUES (
    v_line_id, p_claim_id, p_line_number, p_procedure_code, p_diagnosis_code,
    p_service_date, p_charge_amount
  ) ON CONFLICT (claim_id, line_number) DO NOTHING;
  
  RETURN v_line_id;
END;
$$ LANGUAGE plpgsql;

-- Added Rx benefit inquiry loader function
CREATE OR REPLACE FUNCTION load_rx_benefit_inquiry(
  p_member_id TEXT,
  p_inquiry_date TIMESTAMPTZ,
  p_ndc_code TEXT,
  p_drug_name TEXT,
  p_drug_class TEXT,
  p_prescriber_npi TEXT,
  p_pharmacy_npi TEXT,
  p_days_supply INTEGER,
  p_quantity DECIMAL,
  p_coverage_status TEXT,
  p_copay_amount DECIMAL,
  p_indication TEXT,
  p_raw_transaction TEXT
) RETURNS TEXT AS $$
DECLARE
  v_inquiry_id TEXT;
BEGIN
  v_inquiry_id := 'RX-' || p_member_id || '-' || TO_CHAR(p_inquiry_date, 'YYYYMMDDHH24MISS');
  
  INSERT INTO rx_benefit_inquiry (
    inquiry_id, member_id, inquiry_date, ndc_code, drug_name, drug_class,
    prescriber_npi, pharmacy_npi, days_supply, quantity, coverage_status,
    copay_amount, indication, raw_transaction_data
  ) VALUES (
    v_inquiry_id, p_member_id, p_inquiry_date, p_ndc_code, p_drug_name, p_drug_class,
    p_prescriber_npi, p_pharmacy_npi, p_days_supply, p_quantity, p_coverage_status,
    p_copay_amount, p_indication, p_raw_transaction
  ) ON CONFLICT (inquiry_id) DO NOTHING;
  
  RETURN v_inquiry_id;
END;
$$ LANGUAGE plpgsql;

-- Function to create clinical intent events from eligibility, PA, Rx, and Referrals
CREATE OR REPLACE FUNCTION create_clinical_intent_events() RETURNS INTEGER AS $$
DECLARE
  v_elig_count INTEGER;
  v_pa_count INTEGER;
  v_rx_count INTEGER;
BEGIN
  -- Create intent events from eligibility inquiries
  WITH inserted AS (
    INSERT INTO clinical_intent_event (
      intent_event_id, member_id, episode_id, event_date, event_type,
      event_source_id, procedure_code, diagnosis_code, provider_npi, signal_strength
    )
    SELECT 
      'INT-ELG-' || e.event_id,
      e.member_id,
      epm.episode_id,
      e.inquiry_date,
      'Eligibility_Inquiry',
      e.event_id,
      e.procedure_code,
      e.diagnosis_code,
      e.provider_npi,
      CASE 
        WHEN e.coverage_status = 'Covered' THEN 60.0
        WHEN e.coverage_status = 'Prior Auth Required' THEN 75.0
        ELSE 40.0
      END
    FROM eligibility_inquiry_event e
    JOIN episode_procedure_map epm ON e.procedure_code = epm.procedure_code
    WHERE NOT EXISTS (
      SELECT 1 FROM clinical_intent_event ci 
      WHERE ci.event_source_id = e.event_id
    )
    RETURNING 1
  )
  SELECT COUNT(*) INTO v_elig_count FROM inserted;
  
  -- Create intent events from prior auth requests AND referrals
  WITH inserted AS (
    INSERT INTO clinical_intent_event (
      intent_event_id, member_id, episode_id, event_date, event_type,
      event_source_id, procedure_code, diagnosis_code, provider_npi, signal_strength
    )
    SELECT 
      CASE 
        WHEN pa.request_type = 'referral' THEN 'INT-REF-'
        ELSE 'INT-PA-'
      END || pa.auth_id,
      pa.member_id,
      epm.episode_id,
      pa.request_date,
      CASE 
        WHEN pa.request_type = 'referral' THEN 'Referral'
        ELSE 'Prior_Auth_Request'
      END,
      pa.auth_id,
      pa.procedure_code,
      pa.diagnosis_code,
      pa.requesting_provider_npi,
      CASE 
        -- Referrals have lower signal strength than PA
        WHEN pa.request_type = 'referral' AND pa.referred_provider_specialty IN ('Orthopedic Surgery', 'Pain Management') THEN 70.0
        WHEN pa.request_type = 'referral' THEN 55.0
        -- Prior auths have higher signal strength
        WHEN pa.auth_status = 'approved' THEN 90.0
        WHEN pa.auth_status = 'pended' THEN 70.0
        WHEN pa.auth_status = 'requested' THEN 85.0
        ELSE 50.0
      END
    FROM prior_auth_request pa
    LEFT JOIN episode_procedure_map epm ON pa.procedure_code = epm.procedure_code
    WHERE NOT EXISTS (
      SELECT 1 FROM clinical_intent_event ci 
      WHERE ci.event_source_id = pa.auth_id
    )
    -- For referrals without procedure codes, try to map via diagnosis
    AND (epm.episode_id IS NOT NULL OR pa.request_type = 'referral')
    RETURNING 1
  )
  SELECT COUNT(*) INTO v_pa_count FROM inserted;
  
  -- Create intent events from Rx benefit checks
  -- Map drugs to episodes based on indication
  WITH inserted AS (
    INSERT INTO clinical_intent_event (
      intent_event_id, member_id, episode_id, event_date, event_type,
      event_source_id, procedure_code, diagnosis_code, provider_npi, signal_strength
    )
    SELECT 
      'INT-RX-' || rx.inquiry_id,
      rx.member_id,
      CASE 
        WHEN rx.drug_class IN ('NSAID', 'Opioid', 'Viscosupplement') THEN 'TKA'
        WHEN rx.drug_class IN ('Anticoagulant', 'Antiplatelet') THEN 'CABG'
        WHEN rx.drug_class IN ('Chemotherapy', 'Antiemetic') THEN 'COLORECTAL_SURGERY'
        ELSE NULL
      END,
      rx.inquiry_date,
      'Rx_Benefit_Check',
      rx.inquiry_id,
      NULL,
      NULL,
      rx.prescriber_npi,
      CASE 
        WHEN rx.drug_class IN ('Viscosupplement', 'Opioid') THEN 80.0
        WHEN rx.drug_class = 'NSAID' THEN 50.0
        ELSE 40.0
      END
    FROM rx_benefit_inquiry rx
    WHERE NOT EXISTS (
      SELECT 1 FROM clinical_intent_event ci 
      WHERE ci.event_source_id = rx.inquiry_id
    )
    AND CASE 
      WHEN rx.drug_class IN ('NSAID', 'Opioid', 'Viscosupplement') THEN 'TKA'
      WHEN rx.drug_class IN ('Anticoagulant', 'Antiplatelet') THEN 'CABG'
      WHEN rx.drug_class IN ('Chemotherapy', 'Antiemetic') THEN 'COLORECTAL_SURGERY'
      ELSE NULL
    END IS NOT NULL
    RETURNING 1
  )
  SELECT COUNT(*) INTO v_rx_count FROM inserted;
  
  RETURN v_elig_count + v_pa_count + v_rx_count;
END;
$$ LANGUAGE plpgsql;

-- Function to create clinical outcome events from claims
CREATE OR REPLACE FUNCTION create_clinical_outcome_events() RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  WITH inserted AS (
    INSERT INTO clinical_outcome_event (
      outcome_event_id, member_id, episode_id, claim_id, procedure_date,
      procedure_code, diagnosis_code, provider_npi, facility_npi, total_cost
    )
    SELECT 
      'OUT-' || cl.line_id,
      ch.member_id,
      epm.episode_id,
      ch.claim_id,
      cl.service_date,
      cl.procedure_code,
      cl.diagnosis_code,
      ch.rendering_provider_npi,
      ch.facility_npi,
      cl.charge_amount
    FROM claim_line cl
    JOIN claim_header ch ON cl.claim_id = ch.claim_id
    JOIN episode_procedure_map epm ON cl.procedure_code = epm.procedure_code
    WHERE NOT EXISTS (
      SELECT 1 FROM clinical_outcome_event co 
      WHERE co.claim_id = ch.claim_id AND co.procedure_code = cl.procedure_code
    )
    RETURNING 1
  )
  SELECT COUNT(*) INTO v_count FROM inserted;
  
  RETURN v_count;
END;
$$ LANGUAGE plpgsql;
