-- Load sample member data and generate predictions and intent signals
-- This script populates the database with realistic sample data for testing

-- Insert members (manually from members.json for v0 compatibility)
INSERT INTO member (member_id, first_name, last_name, date_of_birth, gender, plan_type, network, geographic_region, enrollment_date, enrollment_status, risk_score, hcc_score, created_at, updated_at) VALUES
('M00001', 'John', 'Smith', '1958-03-15', 'M', 'PPO', 'Northeast Network', 'New York', '2023-01-01', 'active', 7.2, 2.3, NOW(), NOW()),
('M00002', 'Maria', 'Garcia', '1965-07-22', 'F', 'HMO', 'Metro Network', 'New Jersey', '2022-06-15', 'active', 8.5, 3.1, NOW(), NOW()),
('M00003', 'Robert', 'Johnson', '1962-11-08', 'M', 'PPO', 'Regional Network', 'Connecticut', '2023-03-20', 'active', 6.8, 2.0, NOW(), NOW()),
('M00004', 'Jennifer', 'Lee', '1970-05-14', 'F', 'EPO', 'Northeast Network', 'New York', '2023-09-01', 'active', 7.9, 2.7, NOW(), NOW()),
('M00005', 'William', 'Brown', '1960-09-30', 'M', 'HMO', 'Metro Network', 'New Jersey', '2022-11-10', 'active', 8.1, 2.9, NOW(), NOW()),
('M00006', 'Patricia', 'Martinez', '1968-12-03', 'F', 'PPO', 'Regional Network', 'Connecticut', '2023-04-15', 'active', 7.5, 2.4, NOW(), NOW()),
('M00007', 'Michael', 'Davis', '1955-04-18', 'M', 'HMO', 'Northeast Network', 'New York', '2021-01-01', 'active', 5.2, 1.5, NOW(), NOW()),
('M00008', 'Linda', 'Wilson', '1957-08-25', 'F', 'PPO', 'Metro Network', 'New Jersey', '2020-07-15', 'active', 6.0, 1.8, NOW(), NOW()),
('M00009', 'David', 'Anderson', '1963-02-11', 'M', 'EPO', 'Regional Network', 'Connecticut', '2023-05-20', 'active', 7.0, 2.2, NOW(), NOW()),
('M00010', 'Barbara', 'Taylor', '1966-10-19', 'F', 'HMO', 'Northeast Network', 'New York', '2022-08-10', 'active', 7.7, 2.6, NOW(), NOW())
ON CONFLICT (member_id) DO NOTHING;

-- Fixed column names to match schema: intent_event_id, event_type, event_source_id, diagnosis_code, procedure_code
-- Generate clinical intent events (simulating EDI 270, 278, prior auths)
INSERT INTO clinical_intent_event (intent_event_id, member_id, episode_id, event_date, event_type, event_source_id, procedure_code, diagnosis_code, provider_npi, signal_strength, created_at) VALUES
-- TKA intent signals from eligibility checks and prior auths
('EVT001', 'M00001', 'TKA', CURRENT_DATE - INTERVAL '45 days', 'Eligibility_Inquiry', 'EDI-270-001', NULL, 'M17.11', 'NPI1234567890', 0.65, NOW()),
('EVT002', 'M00001', 'TKA', CURRENT_DATE - INTERVAL '30 days', 'Prior_Auth_Request', 'EDI-278-001', '27447', 'M17.11', 'NPI1234567890', 0.85, NOW()),
('EVT003', 'M00002', 'TKA', CURRENT_DATE - INTERVAL '60 days', 'Eligibility_Inquiry', 'EDI-270-002', NULL, 'M17.0', 'NPI2345678901', 0.70, NOW()),
('EVT004', 'M00002', 'TKA', CURRENT_DATE - INTERVAL '40 days', 'Referral', 'EDI-278-002', NULL, 'M17.0', 'NPI2345678901', 0.75, NOW()),
('EVT005', 'M00003', 'TKA', CURRENT_DATE - INTERVAL '20 days', 'Eligibility_Inquiry', 'EDI-270-003', NULL, 'M17.12', 'NPI3456789012', 0.60, NOW()),
('EVT006', 'M00004', 'TKA', CURRENT_DATE - INTERVAL '15 days', 'Prior_Auth_Request', 'EDI-278-003', '27447', 'M17.11', 'NPI4567890123', 0.90, NOW()),
('EVT007', 'M00005', 'TKA', CURRENT_DATE - INTERVAL '35 days', 'Eligibility_Inquiry', 'EDI-270-004', NULL, 'M17.0', 'NPI5678901234', 0.68, NOW()),
('EVT008', 'M00006', 'TKA', CURRENT_DATE - INTERVAL '25 days', 'Referral', 'EDI-278-004', NULL, 'M17.12', 'NPI6789012345', 0.72, NOW()),
('EVT009', 'M00007', 'TKA', CURRENT_DATE - INTERVAL '50 days', 'Eligibility_Inquiry', 'EDI-270-005', NULL, 'M17.11', 'NPI7890123456', 0.58, NOW()),
('EVT010', 'M00008', 'TKA', CURRENT_DATE - INTERVAL '28 days', 'Referral', 'EDI-278-005', NULL, 'M17.12', 'NPI8901234567', 0.70, NOW()),
('EVT011', 'M00009', 'TKA', CURRENT_DATE - INTERVAL '12 days', 'Prior_Auth_Request', 'EDI-278-006', '27447', 'M17.0', 'NPI9012345678', 0.88, NOW()),
('EVT012', 'M00010', 'TKA', CURRENT_DATE - INTERVAL '42 days', 'Eligibility_Inquiry', 'EDI-270-006', NULL, 'M17.11', 'NPI0123456789', 0.63, NOW()),
-- Adding Bariatric Surgery and Spine Fusion intent signals
('EVT016', 'M00003', 'BARIATRIC', CURRENT_DATE - INTERVAL '28 days', 'Eligibility_Inquiry', 'EDI-270-008', NULL, 'E66.01', 'NPI3456789012', 0.65, NOW()),
('EVT017', 'M00003', 'BARIATRIC', CURRENT_DATE - INTERVAL '15 days', 'Prior_Auth_Request', 'EDI-278-009', '43644', 'E66.01', 'NPI3456789012', 0.83, NOW()),
('EVT018', 'M00006', 'BARIATRIC', CURRENT_DATE - INTERVAL '42 days', 'Eligibility_Inquiry', 'EDI-270-009', NULL, 'E66.01', 'NPI6789012345', 0.62, NOW()),
('EVT019', 'M00007', 'SPINAL_FUSION', CURRENT_DATE - INTERVAL '35 days', 'Prior_Auth_Request', 'EDI-278-010', '22612', 'M51.26', 'NPI7890123456', 0.78, NOW()),
('EVT020', 'M00008', 'SPINAL_FUSION', CURRENT_DATE - INTERVAL '20 days', 'Referral', 'EDI-278-011', NULL, 'M51.26', 'NPI8901234567', 0.70, NOW())
ON CONFLICT (intent_event_id) DO NOTHING;

-- Generate predictions for TKA episode (next 90 days forecast)
-- Predictions based on clinical intent signal strength
-- Removed features_used column and added risk_tier and predicted_cost to match schema
INSERT INTO prediction_result (prediction_id, member_id, episode_id, prediction_date, predicted_event_date, probability_score, risk_tier, predicted_cost, confidence_interval_low, confidence_interval_high, model_version, created_at) VALUES
('PRED001', 'M00001', 'TKA', CURRENT_DATE, CURRENT_DATE + INTERVAL '30 days', 0.87, 'very_high', 32000.00, 28000.00, 36000.00, '1.0.0', NOW()),
('PRED002', 'M00002', 'TKA', CURRENT_DATE, CURRENT_DATE + INTERVAL '45 days', 0.82, 'high', 31500.00, 27500.00, 35500.00, '1.0.0', NOW()),
('PRED003', 'M00003', 'TKA', CURRENT_DATE, CURRENT_DATE + INTERVAL '60 days', 0.65, 'medium', 30000.00, 26000.00, 34000.00, '1.0.0', NOW()),
('PRED004', 'M00004', 'TKA', CURRENT_DATE, CURRENT_DATE + INTERVAL '20 days', 0.91, 'very_high', 33000.00, 29000.00, 37000.00, '1.0.0', NOW()),
('PRED005', 'M00005', 'TKA', CURRENT_DATE, CURRENT_DATE + INTERVAL '40 days', 0.78, 'high', 31000.00, 27000.00, 35000.00, '1.0.0', NOW()),
('PRED006', 'M00006', 'TKA', CURRENT_DATE, CURRENT_DATE + INTERVAL '35 days', 0.73, 'high', 30500.00, 26500.00, 34500.00, '1.0.0', NOW()),
('PRED007', 'M00007', 'TKA', CURRENT_DATE, CURRENT_DATE + INTERVAL '70 days', 0.58, 'medium', 29500.00, 25500.00, 33500.00, '1.0.0', NOW()),
('PRED008', 'M00008', 'TKA', CURRENT_DATE, CURRENT_DATE + INTERVAL '50 days', 0.68, 'medium', 30000.00, 26000.00, 34000.00, '1.0.0', NOW()),
('PRED009', 'M00009', 'TKA', CURRENT_DATE, CURRENT_DATE + INTERVAL '18 days', 0.89, 'very_high', 32500.00, 28500.00, 36500.00, '1.0.0', NOW()),
('PRED010', 'M00010', 'TKA', CURRENT_DATE, CURRENT_DATE + INTERVAL '55 days', 0.71, 'high', 30500.00, 26500.00, 34500.00, '1.0.0', NOW()),
-- Adding Bariatric Surgery and Spine Fusion predictions
('PRED014', 'M00003', 'BARIATRIC', CURRENT_DATE, CURRENT_DATE + INTERVAL '35 days', 0.81, 'very_high', 22000.00, 18000.00, 26000.00, '1.0.0', NOW()),
('PRED015', 'M00006', 'BARIATRIC', CURRENT_DATE, CURRENT_DATE + INTERVAL '55 days', 0.72, 'high', 21500.00, 17500.00, 25500.00, '1.0.0', NOW()),
('PRED016', 'M00007', 'SPINAL_FUSION', CURRENT_DATE, CURRENT_DATE + INTERVAL '45 days', 0.76, 'high', 48000.00, 42000.00, 54000.00, '1.0.0', NOW()),
('PRED017', 'M00008', 'SPINAL_FUSION', CURRENT_DATE, CURRENT_DATE + INTERVAL '38 days', 0.68, 'medium', 47000.00, 41000.00, 53000.00, '1.0.0', NOW())
ON CONFLICT (prediction_id) DO NOTHING;
