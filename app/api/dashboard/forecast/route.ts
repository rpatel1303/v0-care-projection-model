import { NextResponse } from "next/server"
import { createServerClient } from "@/lib/supabase/server"

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const region = searchParams.get("region") || "all"
  const network = searchParams.get("network") || "all"
  const planType = searchParams.get("planType") || "all"
  const episodeId = searchParams.get("episodeId") || "TKA"

  try {
    const supabase = await createServerClient()

    // Get member IDs that match the filters
    let memberQuery = supabase.from("member").select("member_id")

    if (region !== "all") {
      memberQuery = memberQuery.eq("region", region)
    }
    if (network !== "all") {
      memberQuery = memberQuery.eq("network_tier", network)
    }
    if (planType !== "all") {
      memberQuery = memberQuery.eq("plan_type", planType)
    }

    const { data: members } = await memberQuery

    if (!members || members.length === 0) {
      return NextResponse.json([])
    }

    const memberIds = members.map((m) => m.member_id)

    // Get actual volumes from clinical_outcome_event (claims)
    const { data: outcomes } = await supabase
      .from("clinical_outcome_event")
      .select("procedure_date, episode_id")
      .eq("episode_id", episodeId)
      .in("member_id", memberIds)
      .gte("procedure_date", new Date(Date.now() - 180 * 24 * 60 * 60 * 1000).toISOString()) // Last 6 months

    // Get predictions for future volumes
    const { data: predictions } = await supabase
      .from("prediction_result")
      .select("predicted_event_date, probability_score, episode_id")
      .eq("episode_id", episodeId)
      .in("member_id", memberIds)
      .gte("probability_score", 0.5)
      .gte("predicted_event_date", new Date().toISOString())
      .lte("predicted_event_date", new Date(Date.now() + 150 * 24 * 60 * 60 * 1000).toISOString()) // Next 5 months

    // Aggregate by month
    const monthlyData: Record<string, { actual: number; predicted: number }> = {}

    // Generate last 6 months + next 5 months
    const months = []
    for (let i = -5; i <= 5; i++) {
      const date = new Date()
      date.setMonth(date.getMonth() + i)
      const monthKey = date.toLocaleDateString("en-US", { month: "short", year: "numeric" })
      months.push(monthKey)
      monthlyData[monthKey] = { actual: 0, predicted: 0 }
    }

    // Count actual outcomes by month
    outcomes?.forEach((outcome) => {
      const date = new Date(outcome.procedure_date)
      const monthKey = date.toLocaleDateString("en-US", { month: "short", year: "numeric" })
      if (monthlyData[monthKey]) {
        monthlyData[monthKey].actual++
      }
    })

    // Count predictions by month
    predictions?.forEach((pred) => {
      const date = new Date(pred.predicted_event_date)
      const monthKey = date.toLocaleDateString("en-US", { month: "short", year: "numeric" })
      if (monthlyData[monthKey]) {
        monthlyData[monthKey].predicted++
      }
    })

    // Format response with confidence intervals (±20% for simplicity)
    const forecast = months.map((month) => {
      const data = monthlyData[month]
      const isPast = new Date(month) < new Date()

      return {
        month,
        actual: isPast ? data.actual : 0,
        predicted: data.predicted || data.actual,
        lower: Math.floor((data.predicted || data.actual) * 0.8),
        upper: Math.ceil((data.predicted || data.actual) * 1.2),
      }
    })

    return NextResponse.json(forecast)
  } catch (error) {
    console.error("[v0] Forecast API error:", error)
    return NextResponse.json([])
  }
}
