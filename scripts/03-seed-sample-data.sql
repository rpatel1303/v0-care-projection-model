-- Sample Data for Clinical Forecasting Engine Demo
-- This creates realistic test data for the prototype

-- Members
INSERT INTO member (member_id, date_of_birth, gender, plan_id, product_id, line_of_business, effective_date, risk_score) VALUES
('M00001', '1958-03-15', 'F', 'PLAN001', 'PROD_MA', 'MA', '2024-01-01', 1.45),
('M00002', '1962-07-22', 'M', 'PLAN001', 'PROD_MA', 'MA', '2024-01-01', 2.18),
('M00003', '1955-11-08', 'F', 'PLAN002', 'PROD_COM', 'Commercial', '2024-01-01', 0.98),
('M00004', '1960-05-30', 'M', 'PLAN001', 'PROD_MA', 'MA', '2024-01-01', 1.67),
('M00005', '1963-09-12', 'F', 'PLAN002', 'PROD_COM', 'Commercial', '2024-01-01', 1.22),
('M00006', '1959-02-28', 'M', 'PLAN001', 'PROD_MA', 'MA', '2024-01-01', 1.89),
('M00007', '1961-12-05', 'F', 'PLAN003', 'PROD_MCD', 'Medicaid', '2024-01-01', 2.45),
('M00008', '1957-08-19', 'M', 'PLAN002', 'PROD_COM', 'Commercial', '2024-01-01', 1.34);

-- Eligibility Inquiry Events (270/271)
INSERT INTO eligibility_inquiry_event (inquiry_ts, source_channel, payer_id, member_id, provider_npi, service_type_codes, place_of_service, coverage_status, plan_id, product_id) VALUES
('2024-10-15 09:23:00', 'portal', 'PAYER01', 'M00001', '1234567890', ARRAY['2', 'BT'], '21', 'active', 'PLAN001', 'PROD_MA'),
('2024-10-20 14:45:00', 'api', 'PAYER01', 'M00002', '1234567890', ARRAY['2', 'BT'], '21', 'active', 'PLAN001', 'PROD_MA'),
('2024-11-02 11:12:00', 'portal', 'PAYER02', 'M00003', '9876543210', ARRAY['2'], '21', 'active', 'PLAN002', 'PROD_COM'),
('2024-11-15 16:30:00', 'api', 'PAYER01', 'M00004', '1234567890', ARRAY['2', 'BT', 'AG'], '21', 'active', 'PLAN001', 'PROD_MA'),
('2024-11-20 10:05:00', 'clearinghouse', 'PAYER02', 'M00005', '9876543210', ARRAY['2'], '21', 'active', 'PLAN002', 'PROD_COM');

-- Prior Authorization Requests
INSERT INTO prior_auth_request (request_ts, decision_ts, status, member_id, requesting_provider_npi, servicing_provider_npi, service_from_date, service_to_date, place_of_service, diagnosis_codes, procedure_codes, clinical_type, line_of_business, plan_id, urgency) VALUES
('2024-10-18 10:00:00', '2024-10-19 15:30:00', 'approved', 'M00001', '1234567890', '1234567890', '2024-12-15', '2024-12-15', '21', ARRAY['M17.11'], ARRAY['27447'], 'surgery', 'MA', 'PLAN001', 'standard'),
('2024-10-25 09:15:00', '2024-10-26 14:20:00', 'approved', 'M00002', '1234567890', '1234567890', '2025-01-10', '2025-01-10', '21', ARRAY['M17.12', 'M17.0'], ARRAY['27447'], 'surgery', 'MA', 'PLAN001', 'standard'),
('2024-11-05 13:45:00', '2024-11-06 16:00:00', 'approved', 'M00003', '9876543210', '9876543210', '2025-01-20', '2025-01-20', '21', ARRAY['M17.11'], ARRAY['27447'], 'surgery', 'Commercial', 'PLAN002', 'standard'),
('2024-11-18 08:30:00', '2024-11-19 11:45:00', 'approved', 'M00004', '1234567890', '1234567890', '2025-02-05', '2025-02-05', '21', ARRAY['M17.12'], ARRAY['27447'], 'surgery', 'MA', 'PLAN001', 'expedited'),
('2024-11-22 14:20:00', NULL, 'pended', 'M00005', '9876543210', '9876543210', '2025-02-15', '2025-02-15', '21', ARRAY['M17.0'], ARRAY['27447'], 'surgery', 'Commercial', 'PLAN002', 'standard'),
('2024-11-28 10:10:00', NULL, 'requested', 'M00006', '1234567890', '1234567890', '2025-03-01', '2025-03-01', '21', ARRAY['M17.11'], ARRAY['27447'], 'surgery', 'MA', 'PLAN001', 'standard');

-- Historical Claims (for training/validation)
INSERT INTO claim_header (claim_id, member_id, claim_type, from_date, thru_date, received_ts, adjudicated_ts, paid_date, claim_status, rendering_provider_npi, place_of_service, total_billed_amt, total_allowed_amt, total_paid_amt, line_of_business, plan_id) VALUES
('CLM2024001', 'M00007', 'institutional', '2024-09-15', '2024-09-15', '2024-09-20 10:00:00', '2024-09-25 14:30:00', '2024-10-05', 'paid', '1234567890', '21', 45000.00, 38000.00, 38000.00, 'Medicaid', 'PLAN003'),
('CLM2024002', 'M00008', 'institutional', '2024-10-08', '2024-10-08', '2024-10-12 09:15:00', '2024-10-18 11:20:00', '2024-10-28', 'paid', '9876543210', '21', 42000.00, 35500.00, 35500.00, 'Commercial', 'PLAN002');

INSERT INTO claim_line (claim_id, line_num, service_date, procedure_code, units, billed_amt, allowed_amt, paid_amt, line_status) VALUES
('CLM2024001', 1, '2024-09-15', '27447', 1, 45000.00, 38000.00, 38000.00, 'paid'),
('CLM2024002', 1, '2024-10-08', '27447', 1, 42000.00, 35500.00, 35500.00, 'paid');

-- Clinical Intent Events (derived from eligibility + PA)
INSERT INTO clinical_intent_event (intent_ts, member_id, provider_npi, signal_type, service_category, codes, signal_strength, source_system, source_record_id) VALUES
('2024-10-15 09:23:00', 'M00001', '1234567890', 'elig', 'ortho_knee', ARRAY['2', 'BT'], 0.35, 'edi_gateway', '1'),
('2024-10-18 10:00:00', 'M00001', '1234567890', 'pa', 'ortho_knee', ARRAY['27447', 'M17.11'], 0.92, 'pa_system', '1'),
('2024-10-20 14:45:00', 'M00002', '1234567890', 'elig', 'ortho_knee', ARRAY['2', 'BT'], 0.35, 'edi_gateway', '2'),
('2024-10-25 09:15:00', 'M00002', '1234567890', 'pa', 'ortho_knee', ARRAY['27447', 'M17.12'], 0.95, 'pa_system', '2'),
('2024-11-02 11:12:00', 'M00003', '9876543210', 'elig', 'ortho_knee', ARRAY['2'], 0.30, 'edi_gateway', '3'),
('2024-11-05 13:45:00', 'M00003', '9876543210', 'pa', 'ortho_knee', ARRAY['27447', 'M17.11'], 0.90, 'pa_system', '3'),
('2024-11-15 16:30:00', 'M00004', '1234567890', 'elig', 'ortho_knee', ARRAY['2', 'BT', 'AG'], 0.40, 'edi_gateway', '4'),
('2024-11-18 08:30:00', 'M00004', '1234567890', 'pa', 'ortho_knee', ARRAY['27447', 'M17.12'], 0.93, 'pa_system', '4'),
('2024-11-20 10:05:00', 'M00005', '9876543210', 'elig', 'ortho_knee', ARRAY['2'], 0.30, 'edi_gateway', '5'),
('2024-11-22 14:20:00', 'M00005', '9876543210', 'pa', 'ortho_knee', ARRAY['27447', 'M17.0'], 0.75, 'pa_system', '5'),
('2024-11-28 10:10:00', 'M00006', '1234567890', 'elig', 'ortho_knee', ARRAY['2', 'BT'], 0.35, 'edi_gateway', '6');

-- Clinical Outcome Events (ground truth from historical claims)
INSERT INTO clinical_outcome_event (member_id, event_type, event_date, confirming_claim_id, confirming_codes, allowed_amt, provider_npi) VALUES
('M00007', 'tka', '2024-09-15', 'CLM2024001', ARRAY['27447'], 38000.00, '1234567890'),
('M00008', 'tka', '2024-10-08', 'CLM2024002', ARRAY['27447'], 35500.00, '9876543210');

-- Prediction Results (model output for dashboard)
INSERT INTO prediction_result (member_id, event_type, prediction_date, predicted_event_date, probability, risk_tier, model_version, contributing_signals) VALUES
('M00001', 'tka', '2024-12-01', '2024-12-15', 0.9200, 'very_high', 'v1.0', '{"pa_approved": true, "elig_query": true, "days_to_event": 14}'),
('M00002', 'tka', '2024-12-01', '2025-01-10', 0.9500, 'very_high', 'v1.0', '{"pa_approved": true, "elig_query": true, "bilateral_dx": true}'),
('M00003', 'tka', '2024-12-01', '2025-01-20', 0.9000, 'very_high', 'v1.0', '{"pa_approved": true, "elig_query": true}'),
('M00004', 'tka', '2024-12-01', '2025-02-05', 0.9300, 'very_high', 'v1.0', '{"pa_approved": true, "expedited": true}'),
('M00005', 'tka', '2024-12-01', '2025-02-15', 0.7500, 'high', 'v1.0', '{"pa_pended": true, "elig_query": true}'),
('M00006', 'tka', '2024-12-01', '2025-03-01', 0.6800, 'high', 'v1.0', '{"pa_requested": true, "elig_query": false}');
