-- Service Category Code Mappings
-- Starting with TKA (Total Knee Arthroplasty) as MVP

-- TKA CPT Codes
INSERT INTO service_category_code_map (service_category, code_system, code, weight_hint, effective_date) VALUES
('ortho_knee', 'CPT', '27447', 1.0, '2020-01-01'), -- Total knee arthroplasty
('ortho_knee', 'CPT', '27446', 0.9, '2020-01-01'), -- Partial knee arthroplasty
('ortho_knee', 'CPT', '27486', 0.95, '2020-01-01'), -- Revision of total knee arthroplasty
('ortho_knee', 'CPT', '27487', 0.95, '2020-01-01'); -- Revision of total knee replacement

-- TKA-related ICD-10 Diagnosis Codes
INSERT INTO service_category_code_map (service_category, code_system, code, weight_hint, effective_date) VALUES
('ortho_knee', 'ICD10', 'M17.0', 0.7, '2020-01-01'), -- Bilateral primary osteoarthritis of knee
('ortho_knee', 'ICD10', 'M17.11', 0.8, '2020-01-01'), -- Unilateral primary osteoarthritis, right knee
('ortho_knee', 'ICD10', 'M17.12', 0.8, '2020-01-01'), -- Unilateral primary osteoarthritis, left knee
('ortho_knee', 'ICD10', 'M17.2', 0.6, '2020-01-01'), -- Bilateral post-traumatic osteoarthritis of knee
('ortho_knee', 'ICD10', 'M17.30', 0.6, '2020-01-01'), -- Unilateral post-traumatic osteoarthritis of knee
('ortho_knee', 'ICD10', 'M23.50', 0.5, '2020-01-01'); -- Chronic instability of knee

-- X12 Service Type Codes related to orthopedic surgery
INSERT INTO service_category_code_map (service_category, code_system, code, weight_hint, effective_date) VALUES
('ortho_knee', 'X12_STC', '2', 0.4, '2020-01-01'), -- Surgical
('ortho_knee', 'X12_STC', 'BT', 0.3, '2020-01-01'), -- Orthopedic
('ortho_knee', 'X12_STC', 'AG', 0.5, '2020-01-01'); -- Physical Medicine
