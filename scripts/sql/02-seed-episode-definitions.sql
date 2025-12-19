-- Seed Episode of Care Definitions
-- These represent the major high-cost procedures we want to predict

INSERT INTO episode_definition (episode_id, episode_name, episode_category, display_order, is_active) VALUES
  ('TKA', 'Total Knee Replacement', 'Orthopedic', 1, TRUE),
  ('THA', 'Total Hip Replacement', 'Orthopedic', 2, TRUE),
  ('SPINAL_FUSION', 'Spinal Fusion Surgery', 'Orthopedic', 3, TRUE),
  ('CABG', 'Coronary Artery Bypass Graft', 'Cardiac', 4, TRUE),
  ('PCI', 'Percutaneous Coronary Intervention', 'Cardiac', 5, TRUE),
  ('BARIATRIC', 'Bariatric Surgery', 'Bariatric', 6, TRUE),
  ('COLORECTAL', 'Colorectal Surgery', 'Oncology', 7, TRUE),
  ('MASTECTOMY', 'Mastectomy', 'Oncology', 8, TRUE)
ON CONFLICT (episode_id) DO NOTHING;

-- Map CPT procedure codes to episodes
INSERT INTO episode_procedure_map (episode_id, procedure_code, code_type, is_primary) VALUES
  -- Total Knee Replacement
  ('TKA', '27447', 'CPT', TRUE),
  ('TKA', '27446', 'CPT', FALSE),
  
  -- Total Hip Replacement
  ('THA', '27130', 'CPT', TRUE),
  ('THA', '27132', 'CPT', FALSE),
  
  -- Spinal Fusion
  ('SPINAL_FUSION', '22612', 'CPT', TRUE),
  ('SPINAL_FUSION', '22614', 'CPT', FALSE),
  ('SPINAL_FUSION', '22630', 'CPT', FALSE),
  
  -- CABG
  ('CABG', '33533', 'CPT', TRUE),
  ('CABG', '33534', 'CPT', FALSE),
  ('CABG', '33535', 'CPT', FALSE),
  
  -- PCI
  ('PCI', '92928', 'CPT', TRUE),
  ('PCI', '92929', 'CPT', FALSE),
  
  -- Bariatric
  ('BARIATRIC', '43644', 'CPT', TRUE),
  ('BARIATRIC', '43645', 'CPT', FALSE),
  
  -- Colorectal
  ('COLORECTAL', '44204', 'CPT', TRUE),
  ('COLORECTAL', '44205', 'CPT', FALSE),
  
  -- Mastectomy
  ('MASTECTOMY', '19303', 'CPT', TRUE),
  ('MASTECTOMY', '19304', 'CPT', FALSE)
ON CONFLICT (episode_id, procedure_code, code_type) DO NOTHING;

-- Map ICD-10 diagnosis codes to episodes
INSERT INTO episode_diagnosis_map (episode_id, diagnosis_code, code_type, is_primary) VALUES
  -- Total Knee Replacement
  ('TKA', 'M17.11', 'ICD10', TRUE),  -- Unilateral primary osteoarthritis, right knee
  ('TKA', 'M17.12', 'ICD10', TRUE),  -- Unilateral primary osteoarthritis, left knee
  ('TKA', 'M17.0', 'ICD10', FALSE),  -- Bilateral primary osteoarthritis of knee
  
  -- Total Hip Replacement
  ('THA', 'M16.11', 'ICD10', TRUE),  -- Unilateral primary osteoarthritis, right hip
  ('THA', 'M16.12', 'ICD10', TRUE),  -- Unilateral primary osteoarthritis, left hip
  ('THA', 'M16.0', 'ICD10', FALSE),  -- Bilateral primary osteoarthritis of hip
  
  -- Spinal Fusion
  ('SPINAL_FUSION', 'M51.26', 'ICD10', TRUE),  -- Intervertebral disc disorder
  ('SPINAL_FUSION', 'M47.26', 'ICD10', FALSE), -- Spondylosis
  
  -- CABG
  ('CABG', 'I25.10', 'ICD10', TRUE),  -- Atherosclerotic heart disease
  ('CABG', 'I21.3', 'ICD10', FALSE),  -- ST elevation myocardial infarction
  
  -- PCI
  ('PCI', 'I25.10', 'ICD10', TRUE),
  ('PCI', 'I20.0', 'ICD10', FALSE),   -- Unstable angina
  
  -- Bariatric
  ('BARIATRIC', 'E66.01', 'ICD10', TRUE),  -- Morbid obesity
  ('BARIATRIC', 'E11.9', 'ICD10', FALSE),  -- Type 2 diabetes
  
  -- Colorectal
  ('COLORECTAL', 'C18.9', 'ICD10', TRUE),  -- Malignant neoplasm of colon
  ('COLORECTAL', 'C20', 'ICD10', FALSE),   -- Malignant neoplasm of rectum
  
  -- Mastectomy
  ('MASTECTOMY', 'C50.911', 'ICD10', TRUE),  -- Malignant neoplasm of breast
  ('MASTECTOMY', 'Z85.3', 'ICD10', FALSE)    -- Personal history of breast cancer
ON CONFLICT (episode_id, diagnosis_code, code_type) DO NOTHING;
