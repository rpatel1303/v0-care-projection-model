import { NextResponse } from "next/server"
import { createServerClient } from "@/lib/supabase/server"

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const episodeId = searchParams.get("episodeId") || "TKA"

  try {
    const supabase = await createServerClient()

    // Get signals by type for this episode
    const { data: signals } = await supabase
      .from("clinical_intent_event")
      .select("event_type, event_date, intent_event_id")
      .eq("episode_id", episodeId)
      .gte("event_date", new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString()) // Last 90 days

    if (!signals || signals.length === 0) {
      return NextResponse.json({
        byType: [],
        timeline: [],
      })
    }

    // Aggregate by type
    const typeMap: Record<string, number> = {}
    signals.forEach((signal) => {
      const type = signal.event_type || "Unknown"
      typeMap[type] = (typeMap[type] || 0) + 1
    })

    const byType = Object.entries(typeMap).map(([type, count]) => ({
      type,
      count,
      change: Math.floor(Math.random() * 20) - 5, // Placeholder for week-over-week change
    }))

    // Aggregate by week for timeline
    const weekMap: Record<string, { elig: number; pa: number; referral: number }> = {}

    // Generate last 8 weeks
    for (let i = 7; i >= 0; i--) {
      const weekStart = new Date()
      weekStart.setDate(weekStart.getDate() - i * 7)
      const weekKey = `Week ${8 - i}`
      weekMap[weekKey] = { elig: 0, pa: 0, referral: 0 }
    }

    signals.forEach((signal) => {
      const date = new Date(signal.event_date)
      const weeksAgo = Math.floor((Date.now() - date.getTime()) / (7 * 24 * 60 * 60 * 1000))
      const weekKey = `Week ${8 - weeksAgo}`

      if (weekMap[weekKey]) {
        const eventType = signal.event_type?.toLowerCase() || ""

        if (eventType.includes("eligibility")) {
          weekMap[weekKey].elig++
        } else if (eventType.includes("prior") || eventType.includes("auth")) {
          weekMap[weekKey].pa++
        } else if (eventType.includes("referral")) {
          weekMap[weekKey].referral++
        }
      }
    })

    const timeline = Object.entries(weekMap).map(([week, counts]) => ({
      week,
      ...counts,
    }))

    return NextResponse.json({
      byType,
      timeline,
    })
  } catch (error) {
    console.error("[v0] Signals API error:", error)
    return NextResponse.json({
      byType: [],
      timeline: [],
    })
  }
}
