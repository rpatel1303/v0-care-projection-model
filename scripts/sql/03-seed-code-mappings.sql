-- Seed code mappings from episode_procedure_map and episode_diagnosis_map
-- Migrate existing hardcoded logic to database-driven rules

-- Seed CPT procedure codes for Knee Replacement (TKA)
INSERT INTO episode_code_mapping (episode_id, code_type, code_value, code_description, is_primary, signal_strength, client_id) VALUES
  ('TKA', 'CPT', '27447', 'Total knee arthroplasty', true, 95.0, 'default'),
  ('TKA', 'CPT', '27446', 'Total knee arthroplasty with tibial insert', true, 95.0, 'default'),
  ('TKA', 'CPT', '27486', 'Revision of total knee arthroplasty', false, 70.0, 'default'),
  ('TKA', 'CPT', '27487', 'Revision of total knee arthroplasty with insert', false, 70.0, 'default')
ON CONFLICT (episode_id, code_type, code_value, client_id) DO NOTHING;

-- Seed ICD-10 diagnosis codes for Knee Replacement (TKA)
INSERT INTO episode_code_mapping (episode_id, code_type, code_value, code_description, is_primary, signal_strength, client_id) VALUES
  ('TKA', 'ICD10', 'M17.11', 'Unilateral primary osteoarthritis, right knee', false, 70.0, 'default'),
  ('TKA', 'ICD10', 'M17.12', 'Unilateral primary osteoarthritis, left knee', false, 70.0, 'default'),
  ('TKA', 'ICD10', 'M17.0', 'Bilateral primary osteoarthritis of knee', false, 75.0, 'default'),
  ('TKA', 'ICD10', 'M17.2', 'Bilateral post-traumatic osteoarthritis of knee', false, 65.0, 'default'),
  ('TKA', 'ICD10', 'M17.30', 'Unilateral post-traumatic osteoarthritis, unspecified knee', false, 60.0, 'default')
ON CONFLICT (episode_id, code_type, code_value, client_id) DO NOTHING;

-- Seed NDC drug class mappings for Rx benefit checks
INSERT INTO episode_code_mapping (episode_id, code_type, code_value, code_description, is_primary, signal_strength, client_id) VALUES
  ('TKA', 'NDC', 'NSAID', 'Non-steroidal anti-inflammatory drugs', false, 50.0, 'default'),
  ('TKA', 'NDC', 'Opioid', 'Opioid pain medications', false, 75.0, 'default'),
  ('TKA', 'NDC', 'Viscosupplement', 'Hyaluronic acid knee injections', false, 85.0, 'default')
ON CONFLICT (episode_id, code_type, code_value, client_id) DO NOTHING;

-- Add drug class mappings for Rx benefit checks
INSERT INTO episode_code_mapping (episode_id, code_type, code_value, code_description, is_primary, signal_strength, client_id) VALUES
  ('CABG', 'NDC', 'Anticoagulant', 'Blood thinning medications', false, 60.0, 'default'),
  ('CABG', 'NDC', 'Antiplatelet', 'Antiplatelet medications', false, 60.0, 'default')
ON CONFLICT (episode_id, code_type, code_value, client_id) DO NOTHING;
