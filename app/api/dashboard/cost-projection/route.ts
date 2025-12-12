import { NextResponse } from "next/server"

// Based on prediction_result aggregated with estimated costs
export async function GET() {
  // This would calculate:
  // - Historical: SUM(claim_line.allowed_amt) grouped by quarter from clinical_outcome_event
  // - Projected: COUNT(predictions) * avg_cost grouped by predicted quarter
  const costData = [
    { quarter: "Q3 2024", actual: 5.8, projected: 0 },
    { quarter: "Q4 2024", actual: 0, projected: 1.71, breakdown: { next30: 0.456, next60: 0.608, next90: 0.646 } },
    { quarter: "Q1 2025", actual: 0, projected: 3.51, breakdown: {} },
    { quarter: "Q2 2025", actual: 0, projected: 2.42, breakdown: {} },
  ]

  return NextResponse.json(costData)
}
