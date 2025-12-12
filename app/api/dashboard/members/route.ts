import { NextResponse } from "next/server"

// Based on prediction_result joined with member and clinical_intent_event
export async function GET() {
  // SQL would be:
  // SELECT p.*, m.date_of_birth, m.gender,
  //        COUNT(cie.intent_event_id) as signal_count,
  //        MAX(cie.intent_ts) as last_signal_date
  // FROM prediction_result p
  // JOIN member m ON p.member_id = m.member_id
  // LEFT JOIN clinical_intent_event cie ON p.member_id = cie.member_id
  // WHERE p.risk_tier IN ('very_high', 'high')
  // GROUP BY p.prediction_id, m.member_id

  const members = [
    {
      memberId: "M00002",
      name: "John D.",
      age: 62,
      gender: "M",
      probability: 0.95,
      predictedDate: "2025-01-10",
      riskTier: "very_high",
      signals: [
        { type: "pa", date: "2024-10-25", details: "PA Approved - CPT 27447", strength: 0.95 },
        { type: "elig", date: "2024-10-20", details: "Eligibility Check - Orthopedic Surgery", strength: 0.35 },
      ],
      diagnosis: ["M17.12 - Left knee OA", "M17.0 - Bilateral knee OA"],
      provider: "Dr. Smith (NPI: 1234567890)",
      estimatedCost: 38000,
      planId: "PLAN001",
      daysUntilProcedure: 40,
    },
    {
      memberId: "M00004",
      name: "Robert M.",
      age: 64,
      gender: "M",
      probability: 0.93,
      predictedDate: "2025-02-05",
      riskTier: "very_high",
      signals: [
        { type: "pa", date: "2024-11-18", details: "PA Approved (Expedited) - CPT 27447", strength: 0.93 },
        { type: "elig", date: "2024-11-15", details: "Eligibility Check - Surgery, Ortho, PT", strength: 0.4 },
      ],
      diagnosis: ["M17.12 - Left knee OA"],
      provider: "Dr. Smith (NPI: 1234567890)",
      estimatedCost: 38000,
      planId: "PLAN001",
      daysUntilProcedure: 66,
    },
    {
      memberId: "M00001",
      name: "Patricia K.",
      age: 66,
      gender: "F",
      probability: 0.92,
      predictedDate: "2024-12-15",
      riskTier: "very_high",
      signals: [
        { type: "pa", date: "2024-10-18", details: "PA Approved - CPT 27447", strength: 0.92 },
        { type: "elig", date: "2024-10-15", details: "Eligibility Check - Surgical, Orthopedic", strength: 0.35 },
      ],
      diagnosis: ["M17.11 - Right knee OA"],
      provider: "Dr. Smith (NPI: 1234567890)",
      estimatedCost: 38000,
      planId: "PLAN001",
      daysUntilProcedure: 14,
    },
    {
      memberId: "M00003",
      name: "Linda R.",
      age: 69,
      gender: "F",
      probability: 0.9,
      predictedDate: "2025-01-20",
      riskTier: "very_high",
      signals: [
        { type: "pa", date: "2024-11-05", details: "PA Approved - CPT 27447", strength: 0.9 },
        { type: "elig", date: "2024-11-02", details: "Eligibility Check - Surgical", strength: 0.3 },
      ],
      diagnosis: ["M17.11 - Right knee OA"],
      provider: "Dr. Johnson (NPI: 9876543210)",
      estimatedCost: 35500,
      planId: "PLAN002",
      daysUntilProcedure: 50,
    },
    {
      memberId: "M00005",
      name: "Susan W.",
      age: 61,
      gender: "F",
      probability: 0.75,
      predictedDate: "2025-02-15",
      riskTier: "high",
      signals: [
        { type: "pa", date: "2024-11-22", details: "PA Pended - CPT 27447", strength: 0.75 },
        { type: "elig", date: "2024-11-20", details: "Eligibility Check - Surgical", strength: 0.3 },
      ],
      diagnosis: ["M17.0 - Bilateral knee OA"],
      provider: "Dr. Johnson (NPI: 9876543210)",
      estimatedCost: 35500,
      planId: "PLAN002",
      daysUntilProcedure: 76,
    },
  ]

  return NextResponse.json(members)
}
