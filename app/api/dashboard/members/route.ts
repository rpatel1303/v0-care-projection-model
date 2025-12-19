import { NextResponse } from "next/server"
import { createServerClient } from "@/lib/supabase/server"

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const episodeId = searchParams.get("episodeId") || "TKA"

  console.log("[v0] Members API - episodeId:", episodeId)

  try {
    const supabase = createServerClient()

    // Query prediction_result joined with member and clinical_intent_event
    const { data: predictions, error: predError } = await supabase
      .from("prediction_result")
      .select(`
        prediction_id,
        member_id,
        episode_id,
        predicted_event_date,
        probability_score,
        risk_tier,
        predicted_cost,
        member:member_id (
          member_id,
          first_name,
          last_name,
          date_of_birth,
          gender,
          plan_type
        )
      `)
      .eq("episode_id", episodeId)
      .in("risk_tier", ["very_high", "high"])
      .order("probability_score", { ascending: false })
      .limit(10)

    if (predError) {
      console.error("[v0] Members API - Prediction query error:", predError)
      return NextResponse.json([])
    }

    if (!predictions || predictions.length === 0) {
      console.log("[v0] Members API - No predictions found for episode:", episodeId)
      return NextResponse.json([])
    }

    console.log("[v0] Members API - Found predictions:", predictions.length)

    // Get clinical intent events for each member
    const memberIds = predictions.map((p: any) => p.member_id)
    const { data: intents, error: intentError } = await supabase
      .from("clinical_intent_event")
      .select("*")
      .in("member_id", memberIds)
      .eq("episode_id", episodeId)
      .order("event_date", { ascending: false })

    if (intentError) {
      console.error("[v0] Members API - Intent query error:", intentError)
    }

    // Transform data to match component expectations
    const members = predictions.map((pred: any) => {
      const member = pred.member
      const memberIntents = intents?.filter((i: any) => i.member_id === pred.member_id) || []

      // Calculate age from date_of_birth
      const dob = new Date(member.date_of_birth)
      const age = Math.floor((Date.now() - dob.getTime()) / (365.25 * 24 * 60 * 60 * 1000))

      // Calculate days until procedure
      const predDate = new Date(pred.predicted_event_date)
      const daysUntil = Math.ceil((predDate.getTime() - Date.now()) / (24 * 60 * 60 * 1000))

      // Transform intents to signals
      const signals = memberIntents.map((intent: any) => {
        const eventTypeMap: Record<string, string> = {
          Prior_Auth_Request: "pa",
          Eligibility_Inquiry: "elig",
          Referral: "referral",
          Rx_Benefit_Check: "rx",
        }

        return {
          type: eventTypeMap[intent.event_type] || "other",
          date: intent.event_date,
          details: `${intent.event_type}${intent.procedure_code ? " - CPT " + intent.procedure_code : ""}${intent.diagnosis_code ? " - " + intent.diagnosis_code : ""}`,
          strength: intent.signal_strength || 0.5,
        }
      })

      // Get unique diagnosis codes from intents
      const diagnosisCodes = [
        ...new Set(memberIntents.filter((i: any) => i.diagnosis_code).map((i: any) => i.diagnosis_code)),
      ]

      // Get provider NPI from most recent intent
      const providerNpi = memberIntents[0]?.provider_npi || "Unknown"

      return {
        memberId: member.member_id,
        name: `${member.first_name} ${member.last_name.charAt(0)}.`,
        age,
        gender: member.gender,
        probability: pred.probability_score,
        predictedDate: pred.predicted_event_date,
        riskTier: pred.risk_tier,
        signals,
        diagnosis: diagnosisCodes,
        provider: `Provider (NPI: ${providerNpi})`,
        estimatedCost: pred.predicted_cost,
        planId: member.plan_type,
        daysUntilProcedure: daysUntil,
      }
    })

    console.log("[v0] Members API - Returning members:", members.length)
    return NextResponse.json(members)
  } catch (error) {
    console.error("[v0] Members API - Unexpected error:", error)
    return NextResponse.json([])
  }
}
