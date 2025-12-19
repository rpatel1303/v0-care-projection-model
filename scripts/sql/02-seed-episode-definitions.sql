-- Seed Episode of Care Definitions
-- These represent the major high-cost procedures we want to predict

-- Updated to match actual episode_definition table columns
INSERT INTO episode_definition (
  episode_id, 
  episode_name, 
  episode_category, 
  description,
  average_cost,
  typical_los_days
) VALUES
  ('TKA', 'Total Knee Replacement', 'Orthopedic', 'Surgical replacement of knee joint with prosthetic implant', 35000.00, 3),
  ('THA', 'Total Hip Replacement', 'Orthopedic', 'Surgical replacement of hip joint with prosthetic implant', 38000.00, 3),
  ('SPINAL_FUSION', 'Spinal Fusion Surgery', 'Orthopedic', 'Fusion of vertebrae to treat chronic back pain or instability', 85000.00, 4),
  ('CABG', 'Coronary Artery Bypass Graft', 'Cardiac', 'Open heart surgery to bypass blocked coronary arteries', 125000.00, 7),
  ('PCI', 'Percutaneous Coronary Intervention', 'Cardiac', 'Minimally invasive procedure to open blocked coronary arteries', 45000.00, 1),
  ('BARIATRIC', 'Bariatric Surgery', 'Bariatric', 'Weight loss surgery including gastric bypass or sleeve gastrectomy', 28000.00, 2),
  ('COLORECTAL', 'Colorectal Surgery', 'Oncology', 'Surgical removal of part of colon or rectum', 55000.00, 5),
  ('MASTECTOMY', 'Mastectomy', 'Oncology', 'Surgical removal of breast tissue', 42000.00, 2)
ON CONFLICT (episode_id) DO NOTHING;
