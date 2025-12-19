-- Multi-Episode Clinical Forecasting Engine - Complete Database Schema
-- This schema supports multiple episodes of care (TKA, THA, Spinal Fusion, etc.)
-- and ingests data from EDI 837, 270/271, and 278 transactions

-- ============================================
-- CORE REFERENCE TABLES
-- ============================================

-- Episode of Care Definitions
CREATE TABLE IF NOT EXISTS episode_definition (
  episode_id VARCHAR(50) PRIMARY KEY,
  episode_name VARCHAR(200) NOT NULL,
  episode_category VARCHAR(100) NOT NULL, -- 'Orthopedic', 'Cardiac', 'Oncology', etc.
  display_order INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Episode-to-Procedure Code Mapping
CREATE TABLE IF NOT EXISTS episode_procedure_map (
  episode_id VARCHAR(50) REFERENCES episode_definition(episode_id),
  procedure_code VARCHAR(10) NOT NULL,
  code_type VARCHAR(10) NOT NULL DEFAULT 'CPT', -- 'CPT', 'HCPCS', 'ICD10-PCS'
  is_primary BOOLEAN DEFAULT TRUE,
  PRIMARY KEY (episode_id, procedure_code, code_type)
);

-- Episode-to-Diagnosis Code Mapping  
CREATE TABLE IF NOT EXISTS episode_diagnosis_map (
  episode_id VARCHAR(50) REFERENCES episode_definition(episode_id),
  diagnosis_code VARCHAR(10) NOT NULL,
  code_type VARCHAR(10) NOT NULL DEFAULT 'ICD10', -- 'ICD10', 'ICD9'
  is_primary BOOLEAN DEFAULT TRUE,
  PRIMARY KEY (episode_id, diagnosis_code, code_type)
);

-- ============================================
-- MEMBER/PATIENT DATA
-- ============================================

CREATE TABLE IF NOT EXISTS member (
  member_id VARCHAR(50) PRIMARY KEY,
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  date_of_birth DATE,
  gender VARCHAR(10),
  address_line1 VARCHAR(200),
  address_city VARCHAR(100),
  address_state VARCHAR(2),
  address_zip VARCHAR(10),
  plan_type VARCHAR(50),
  network_type VARCHAR(50),
  pcp_provider_npi VARCHAR(10),
  risk_score NUMERIC(5,2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_member_state ON member(address_state);
CREATE INDEX idx_member_plan ON member(plan_type);
CREATE INDEX idx_member_network ON member(network_type);

-- ============================================
-- EDI TRANSACTION TABLES
-- ============================================

-- 270/271 Eligibility Inquiry Events
CREATE TABLE IF NOT EXISTS eligibility_inquiry_event (
  event_id VARCHAR(50) PRIMARY KEY,
  member_id VARCHAR(50) REFERENCES member(member_id),
  inquiry_date TIMESTAMP NOT NULL,
  service_type_code VARCHAR(10), -- '30' for Medical Care, '35' for Dental Care, etc.
  service_type_description VARCHAR(200),
  procedure_code VARCHAR(10),
  diagnosis_code VARCHAR(10),
  provider_npi VARCHAR(10),
  provider_name VARCHAR(200),
  eligibility_status VARCHAR(50), -- 'Active', 'Inactive', 'Unknown'
  coverage_status VARCHAR(50), -- 'Covered', 'Not Covered', 'Prior Auth Required'
  deductible_remaining NUMERIC(10,2),
  oop_max_remaining NUMERIC(10,2),
  raw_edi_data TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_eligibility_member ON eligibility_inquiry_event(member_id);
CREATE INDEX idx_eligibility_date ON eligibility_inquiry_event(inquiry_date);
CREATE INDEX idx_eligibility_procedure ON eligibility_inquiry_event(procedure_code);

-- 278 Prior Authorization Request Events
CREATE TABLE IF NOT EXISTS prior_auth_request (
  auth_id VARCHAR(50) PRIMARY KEY,
  member_id VARCHAR(50) REFERENCES member(member_id),
  request_date TIMESTAMP NOT NULL,
  auth_status VARCHAR(50), -- 'Requested', 'Approved', 'Denied', 'Pended'
  procedure_code VARCHAR(10),
  procedure_description VARCHAR(500),
  diagnosis_code VARCHAR(10),
  diagnosis_description VARCHAR(500),
  requesting_provider_npi VARCHAR(10),
  requesting_provider_name VARCHAR(200),
  servicing_provider_npi VARCHAR(10),
  servicing_provider_name VARCHAR(200),
  requested_service_date DATE,
  approved_units INTEGER,
  denial_reason VARCHAR(500),
  raw_edi_data TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_pa_member ON prior_auth_request(member_id);
CREATE INDEX idx_pa_date ON prior_auth_request(request_date);
CREATE INDEX idx_pa_status ON prior_auth_request(auth_status);
CREATE INDEX idx_pa_procedure ON prior_auth_request(procedure_code);

-- 837 Claim Header (Institutional and Professional)
CREATE TABLE IF NOT EXISTS claim_header (
  claim_id VARCHAR(50) PRIMARY KEY,
  member_id VARCHAR(50) REFERENCES member(member_id),
  claim_type VARCHAR(10), -- '837I' for Institutional, '837P' for Professional
  claim_status VARCHAR(50), -- 'Submitted', 'Paid', 'Denied', 'Adjusted'
  service_from_date DATE NOT NULL,
  service_to_date DATE NOT NULL,
  admission_date DATE,
  discharge_date DATE,
  bill_type VARCHAR(10), -- For institutional claims (e.g., '131' for inpatient)
  admission_type VARCHAR(10),
  discharge_status VARCHAR(10),
  billing_provider_npi VARCHAR(10),
  billing_provider_name VARCHAR(200),
  rendering_provider_npi VARCHAR(10),
  rendering_provider_name VARCHAR(200),
  facility_npi VARCHAR(10),
  facility_name VARCHAR(200),
  total_charge_amount NUMERIC(12,2),
  total_paid_amount NUMERIC(12,2),
  patient_responsibility NUMERIC(12,2),
  raw_edi_data TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_claim_member ON claim_header(member_id);
CREATE INDEX idx_claim_service_date ON claim_header(service_from_date);
CREATE INDEX idx_claim_type ON claim_header(claim_type);

-- 837 Claim Line Detail
CREATE TABLE IF NOT EXISTS claim_line (
  line_id VARCHAR(50) PRIMARY KEY,
  claim_id VARCHAR(50) REFERENCES claim_header(claim_id),
  line_number INTEGER NOT NULL,
  procedure_code VARCHAR(10) NOT NULL,
  procedure_description VARCHAR(500),
  modifier_1 VARCHAR(5),
  modifier_2 VARCHAR(5),
  modifier_3 VARCHAR(5),
  modifier_4 VARCHAR(5),
  diagnosis_code VARCHAR(10),
  revenue_code VARCHAR(10),
  service_date DATE,
  service_units NUMERIC(10,2),
  charge_amount NUMERIC(12,2),
  paid_amount NUMERIC(12,2),
  allowed_amount NUMERIC(12,2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_line_claim ON claim_line(claim_id);
CREATE INDEX idx_line_procedure ON claim_line(procedure_code);

-- ============================================
-- ANALYTICAL/INTENT LAYER
-- ============================================

-- Clinical Intent Event (Unified layer combining eligibility + PA signals)
CREATE TABLE IF NOT EXISTS clinical_intent_event (
  intent_event_id VARCHAR(50) PRIMARY KEY,
  member_id VARCHAR(50) REFERENCES member(member_id),
  episode_id VARCHAR(50) REFERENCES episode_definition(episode_id),
  event_date TIMESTAMP NOT NULL,
  event_type VARCHAR(50) NOT NULL, -- 'Eligibility_Inquiry', 'Prior_Auth_Request', 'Referral'
  event_source_id VARCHAR(50), -- Reference to source event (eligibility_inquiry_event.event_id or prior_auth_request.auth_id)
  procedure_code VARCHAR(10),
  diagnosis_code VARCHAR(10),
  provider_npi VARCHAR(10),
  signal_strength NUMERIC(5,2), -- 0-100 score indicating strength of intent signal
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_intent_member ON clinical_intent_event(member_id);
CREATE INDEX idx_intent_episode ON clinical_intent_event(episode_id);
CREATE INDEX idx_intent_date ON clinical_intent_event(event_date);
CREATE INDEX idx_intent_type ON clinical_intent_event(event_type);

-- Clinical Outcome Event (Actual procedures performed from claims)
CREATE TABLE IF NOT EXISTS clinical_outcome_event (
  outcome_event_id VARCHAR(50) PRIMARY KEY,
  member_id VARCHAR(50) REFERENCES member(member_id),
  episode_id VARCHAR(50) REFERENCES episode_definition(episode_id),
  claim_id VARCHAR(50) REFERENCES claim_header(claim_id),
  procedure_date DATE NOT NULL,
  procedure_code VARCHAR(10) NOT NULL,
  diagnosis_code VARCHAR(10),
  provider_npi VARCHAR(10),
  facility_npi VARCHAR(10),
  total_cost NUMERIC(12,2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_outcome_member ON clinical_outcome_event(member_id);
CREATE INDEX idx_outcome_episode ON clinical_outcome_event(episode_id);
CREATE INDEX idx_outcome_date ON clinical_outcome_event(procedure_date);

-- ============================================
-- PREDICTION/ML LAYER
-- ============================================

-- Prediction Results (Output from ML model)
CREATE TABLE IF NOT EXISTS prediction_result (
  prediction_id VARCHAR(50) PRIMARY KEY,
  member_id VARCHAR(50) REFERENCES member(member_id),
  episode_id VARCHAR(50) REFERENCES episode_definition(episode_id),
  prediction_date TIMESTAMP NOT NULL,
  predicted_procedure_date DATE,
  prediction_probability NUMERIC(5,4), -- 0.0000 to 1.0000
  prediction_confidence VARCHAR(20), -- 'Very High', 'High', 'Medium', 'Low'
  risk_tier VARCHAR(20), -- 'very_high', 'high', 'moderate', 'low'
  predicted_cost NUMERIC(12,2),
  days_to_procedure INTEGER,
  model_version VARCHAR(50),
  features_used JSONB, -- Store feature values used for prediction
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_prediction_member ON prediction_result(member_id);
CREATE INDEX idx_prediction_episode ON prediction_result(episode_id);
CREATE INDEX idx_prediction_date ON prediction_result(prediction_date);
CREATE INDEX idx_prediction_probability ON prediction_result(prediction_probability DESC);
CREATE INDEX idx_prediction_risk_tier ON prediction_result(risk_tier);

-- Model Performance Metrics (Track model accuracy over time)
CREATE TABLE IF NOT EXISTS model_performance_metric (
  metric_id VARCHAR(50) PRIMARY KEY,
  model_version VARCHAR(50) NOT NULL,
  episode_id VARCHAR(50) REFERENCES episode_definition(episode_id),
  evaluation_date DATE NOT NULL,
  precision_score NUMERIC(5,4),
  recall_score NUMERIC(5,4),
  f1_score NUMERIC(5,4),
  auc_roc NUMERIC(5,4),
  total_predictions INTEGER,
  true_positives INTEGER,
  false_positives INTEGER,
  true_negatives INTEGER,
  false_negatives INTEGER,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_model_version ON model_performance_metric(model_version);
CREATE INDEX idx_model_episode ON model_performance_metric(episode_id);
