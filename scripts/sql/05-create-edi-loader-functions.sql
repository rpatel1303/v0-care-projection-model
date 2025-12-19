-- EDI Data Loader Functions
-- These PostgreSQL functions parse and load EDI transaction data

-- Function to load 270/271 eligibility inquiry data
CREATE OR REPLACE FUNCTION load_270_eligibility(
  p_member_id VARCHAR,
  p_inquiry_date TIMESTAMP,
  p_service_type_code VARCHAR,
  p_procedure_code VARCHAR,
  p_diagnosis_code VARCHAR,
  p_provider_npi VARCHAR,
  p_eligibility_status VARCHAR,
  p_coverage_status VARCHAR,
  p_raw_edi TEXT
) RETURNS VARCHAR AS $$
DECLARE
  v_event_id VARCHAR(50);
BEGIN
  v_event_id := 'ELG-' || p_member_id || '-' || TO_CHAR(p_inquiry_date, 'YYYYMMDDHH24MISS');
  
  INSERT INTO eligibility_inquiry_event (
    event_id,
    member_id,
    inquiry_date,
    service_type_code,
    procedure_code,
    diagnosis_code,
    provider_npi,
    eligibility_status,
    coverage_status,
    raw_edi_data
  ) VALUES (
    v_event_id,
    p_member_id,
    p_inquiry_date,
    p_service_type_code,
    p_procedure_code,
    p_diagnosis_code,
    p_provider_npi,
    p_eligibility_status,
    p_coverage_status,
    p_raw_edi
  ) ON CONFLICT (event_id) DO NOTHING;
  
  RETURN v_event_id;
END;
$$ LANGUAGE plpgsql;

-- Function to load 278 prior authorization data
CREATE OR REPLACE FUNCTION load_278_prior_auth(
  p_member_id VARCHAR,
  p_request_date TIMESTAMP,
  p_auth_status VARCHAR,
  p_procedure_code VARCHAR,
  p_diagnosis_code VARCHAR,
  p_requesting_provider_npi VARCHAR,
  p_servicing_provider_npi VARCHAR,
  p_requested_service_date DATE,
  p_raw_edi TEXT
) RETURNS VARCHAR AS $$
DECLARE
  v_auth_id VARCHAR(50);
BEGIN
  v_auth_id := 'PA-' || p_member_id || '-' || TO_CHAR(p_request_date, 'YYYYMMDDHH24MISS');
  
  INSERT INTO prior_auth_request (
    auth_id,
    member_id,
    request_date,
    auth_status,
    procedure_code,
    diagnosis_code,
    requesting_provider_npi,
    servicing_provider_npi,
    requested_service_date,
    raw_edi_data
  ) VALUES (
    v_auth_id,
    p_member_id,
    p_request_date,
    p_auth_status,
    p_procedure_code,
    p_diagnosis_code,
    p_requesting_provider_npi,
    p_servicing_provider_npi,
    p_requested_service_date,
    p_raw_edi
  ) ON CONFLICT (auth_id) DO NOTHING;
  
  RETURN v_auth_id;
END;
$$ LANGUAGE plpgsql;

-- Function to load 837 claim header
CREATE OR REPLACE FUNCTION load_837_claim_header(
  p_claim_id VARCHAR,
  p_member_id VARCHAR,
  p_claim_type VARCHAR,
  p_service_from_date DATE,
  p_service_to_date DATE,
  p_billing_provider_npi VARCHAR,
  p_facility_npi VARCHAR,
  p_total_charge_amount NUMERIC,
  p_raw_edi TEXT
) RETURNS VARCHAR AS $$
BEGIN
  INSERT INTO claim_header (
    claim_id,
    member_id,
    claim_type,
    claim_status,
    service_from_date,
    service_to_date,
    billing_provider_npi,
    facility_npi,
    total_charge_amount,
    raw_edi_data
  ) VALUES (
    p_claim_id,
    p_member_id,
    p_claim_type,
    'Submitted',
    p_service_from_date,
    p_service_to_date,
    p_billing_provider_npi,
    p_facility_npi,
    p_total_charge_amount,
    p_raw_edi
  ) ON CONFLICT (claim_id) DO NOTHING;
  
  RETURN p_claim_id;
END;
$$ LANGUAGE plpgsql;

-- Function to load 837 claim line
CREATE OR REPLACE FUNCTION load_837_claim_line(
  p_claim_id VARCHAR,
  p_line_number INTEGER,
  p_procedure_code VARCHAR,
  p_diagnosis_code VARCHAR,
  p_service_date DATE,
  p_charge_amount NUMERIC
) RETURNS VARCHAR AS $$
DECLARE
  v_line_id VARCHAR(50);
BEGIN
  v_line_id := p_claim_id || '-LINE-' || p_line_number;
  
  INSERT INTO claim_line (
    line_id,
    claim_id,
    line_number,
    procedure_code,
    diagnosis_code,
    service_date,
    charge_amount
  ) VALUES (
    v_line_id,
    p_claim_id,
    p_line_number,
    p_procedure_code,
    p_diagnosis_code,
    p_service_date,
    p_charge_amount
  ) ON CONFLICT (line_id) DO NOTHING;
  
  RETURN v_line_id;
END;
$$ LANGUAGE plpgsql;

-- Function to create clinical intent events from eligibility and PA data
CREATE OR REPLACE FUNCTION create_clinical_intent_events() RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER := 0;
BEGIN
  -- Create intent events from eligibility inquiries
  INSERT INTO clinical_intent_event (
    intent_event_id,
    member_id,
    episode_id,
    event_date,
    event_type,
    event_source_id,
    procedure_code,
    diagnosis_code,
    provider_npi,
    signal_strength
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
  );
  
  GET DIAGNOSTICS v_count = ROW_COUNT;
  
  -- Create intent events from prior auth requests
  INSERT INTO clinical_intent_event (
    intent_event_id,
    member_id,
    episode_id,
    event_date,
    event_type,
    event_source_id,
    procedure_code,
    diagnosis_code,
    provider_npi,
    signal_strength
  )
  SELECT 
    'INT-PA-' || pa.auth_id,
    pa.member_id,
    epm.episode_id,
    pa.request_date,
    'Prior_Auth_Request',
    pa.auth_id,
    pa.procedure_code,
    pa.diagnosis_code,
    pa.requesting_provider_npi,
    CASE 
      WHEN pa.auth_status = 'Approved' THEN 90.0
      WHEN pa.auth_status = 'Pended' THEN 70.0
      WHEN pa.auth_status = 'Requested' THEN 85.0
      ELSE 50.0
    END
  FROM prior_auth_request pa
  JOIN episode_procedure_map epm ON pa.procedure_code = epm.procedure_code
  WHERE NOT EXISTS (
    SELECT 1 FROM clinical_intent_event ci 
    WHERE ci.event_source_id = pa.auth_id
  );
  
  GET DIAGNOSTICS v_count = v_count + ROW_COUNT;
  
  RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Function to create clinical outcome events from claims
CREATE OR REPLACE FUNCTION create_clinical_outcome_events() RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER := 0;
BEGIN
  INSERT INTO clinical_outcome_event (
    outcome_event_id,
    member_id,
    episode_id,
    claim_id,
    procedure_date,
    procedure_code,
    diagnosis_code,
    provider_npi,
    facility_npi,
    total_cost
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
  );
  
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$ LANGUAGE plpgsql;
