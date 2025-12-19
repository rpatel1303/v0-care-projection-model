import { NextResponse } from "next/server"
import { createServerClient } from "@/lib/supabase/server"

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const episodeId = searchParams.get("episodeId") || "TKA"

  console.log("[v0] Cost projection API called with episodeId:", episodeId)

  try {
    const supabase = await createServerClient()

    // Get episode average cost
    const { data: episodeDef, error: episodeDefError } = await supabase
      .from("episode_definition")
      .select("average_cost")
      .eq("episode_id", episodeId)
      .maybeSingle()

    console.log("[v0] Episode definition for cost projection:", { episodeId, episodeDef, error: episodeDefError })

    const avgCost = episodeDef?.average_cost || 30000

    // Get historical costs from clinical_outcome_event + claim_line
    const threeMonthsAgo = new Date()
    threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3)

    const { data: outcomes } = await supabase
      .from("clinical_outcome_event")
      .select("procedure_date, outcome_event_id")
      .eq("episode_id", episodeId)
      .gte("procedure_date", threeMonthsAgo.toISOString())

    // Get predictions for future quarters
    const { data: predictions } = await supabase
      .from("prediction_result")
      .select("predicted_event_date, predicted_cost")
      .eq("episode_id", episodeId)
      .gte("probability_score", 0.5)
      .gte("predicted_event_date", new Date().toISOString())

    // Aggregate by quarter
    const quarterlyData: Record<string, { actual: number; projected: number; count: number }> = {}

    // Generate quarters (Q3 2024 through Q2 2025)
    const quarters = ["Q3 2024", "Q4 2024", "Q1 2025", "Q2 2025"]
    quarters.forEach((q) => {
      quarterlyData[q] = { actual: 0, projected: 0, count: 0 }
    })

    // Aggregate actual costs by quarter
    outcomes?.forEach((outcome) => {
      const date = new Date(outcome.procedure_date)
      const quarter = `Q${Math.floor(date.getMonth() / 3) + 1} ${date.getFullYear()}`
      if (quarterlyData[quarter]) {
        quarterlyData[quarter].actual += avgCost / 1000000 // Convert to millions
      }
    })

    // Aggregate predicted costs by quarter
    predictions?.forEach((pred) => {
      const date = new Date(pred.predicted_event_date)
      const quarter = `Q${Math.floor(date.getMonth() / 3) + 1} ${date.getFullYear()}`
      if (quarterlyData[quarter]) {
        const cost = pred.predicted_cost || avgCost
        quarterlyData[quarter].projected += cost / 1000000 // Convert to millions
        quarterlyData[quarter].count++
      }
    })

    // Format response
    const costData = quarters.map((quarter) => {
      const data = quarterlyData[quarter]
      const isPast = new Date() > new Date(quarter.split(" ")[1] + "-" + Number.parseInt(quarter.split("Q")[1]) * 3)

      return {
        quarter,
        actual: isPast ? Number(data.actual.toFixed(2)) : 0,
        projected: Number(data.projected.toFixed(2)),
        breakdown:
          quarter === "Q4 2024"
            ? {
                next30: Number((data.projected * 0.267).toFixed(3)),
                next60: Number((data.projected * 0.356).toFixed(3)),
                next90: Number((data.projected * 0.377).toFixed(3)),
              }
            : {},
      }
    })

    return NextResponse.json(costData)
  } catch (error) {
    console.error("[v0] Cost projection API error:", error)
    return NextResponse.json([])
  }
}
