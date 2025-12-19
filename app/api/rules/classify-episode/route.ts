import { type NextRequest, NextResponse } from "next/server"
import { createServerClient } from "@/lib/supabase/server"

export const runtime = "nodejs"

interface ClassificationRequest {
  diagnosis_codes?: string[]
  procedure_codes?: string[]
  ndc_codes?: string[]
  revenue_codes?: string[]
  context?: {
    member_id?: string
    service_date?: string
    provider_specialty?: string
    client_id?: string
  }
}

interface ClassificationResult {
  episode_id: string | null
  episode_name: string | null
  confidence_score: number
  matched_codes: Array<{
    code_type: string
    code_value: string
    signal_strength: number
    is_primary: boolean
  }>
  reasoning: string[]
}

export async function POST(request: NextRequest) {
  try {
    const supabase = await createServerClient()
    const body: ClassificationRequest = await request.json()

    const { diagnosis_codes = [], procedure_codes = [], ndc_codes = [], revenue_codes = [], context = {} } = body

    const client_id = context.client_id || "default"

    // Collect all codes to check
    const code_checks = [
      ...procedure_codes.map((code) => ({ type: "CPT", value: code })),
      ...diagnosis_codes.map((code) => ({ type: "ICD10", value: code })),
      ...ndc_codes.map((code) => ({ type: "NDC", value: code })),
      ...revenue_codes.map((code) => ({ type: "Revenue", value: code })),
    ]

    if (code_checks.length === 0) {
      return NextResponse.json({
        episode_id: null,
        episode_name: null,
        confidence_score: 0,
        matched_codes: [],
        reasoning: ["No codes provided for classification"],
      })
    }

    // Query all potential matches in one database call
    const { data: matches, error } = await supabase
      .from("episode_code_mapping")
      .select(`
        id,
        episode_id,
        code_type,
        code_value,
        code_description,
        is_primary,
        signal_strength,
        episode_definition!inner(episode_id, episode_name, episode_category)
      `)
      .in("code_type", [...new Set(code_checks.map((c) => c.type))])
      .in("code_value", [...new Set(code_checks.map((c) => c.value))])
      .eq("client_id", client_id)
      .or(`expiration_date.is.null,expiration_date.gt.${new Date().toISOString().split("T")[0]}`)

    if (error) {
      console.error("[v0] Classification error:", error)
      return NextResponse.json({ error: "Failed to classify episode" }, { status: 500 })
    }

    if (!matches || matches.length === 0) {
      return NextResponse.json({
        episode_id: null,
        episode_name: null,
        confidence_score: 0,
        matched_codes: [],
        reasoning: ["No matching episodes found for provided codes"],
      })
    }

    // Score each episode based on matched codes
    const episode_scores: Map<
      string,
      {
        score: number
        primary_matches: number
        total_matches: number
        matched_codes: Array<any>
        episode_name: string
      }
    > = new Map()

    for (const match of matches) {
      const episode_id = match.episode_id

      if (!episode_scores.has(episode_id)) {
        episode_scores.set(episode_id, {
          score: 0,
          primary_matches: 0,
          total_matches: 0,
          matched_codes: [],
          episode_name: (match.episode_definition as any).episode_name,
        })
      }

      const episode_data = episode_scores.get(episode_id)!

      // Calculate score contribution
      let score_contribution = match.signal_strength || 50

      // Boost for primary codes
      if (match.is_primary) {
        score_contribution *= 1.5
        episode_data.primary_matches += 1
      }

      // Boost for procedure codes (strongest signal)
      if (match.code_type === "CPT") {
        score_contribution *= 1.3
      }

      episode_data.score += score_contribution
      episode_data.total_matches += 1
      episode_data.matched_codes.push({
        code_type: match.code_type,
        code_value: match.code_value,
        signal_strength: match.signal_strength,
        is_primary: match.is_primary,
      })
    }

    // Find best match
    let best_episode: string | null = null
    let best_score = 0
    let best_data: any = null

    for (const [episode_id, data] of episode_scores.entries()) {
      // Normalize score by number of matches (avoid over-counting)
      const normalized_score = data.score / Math.sqrt(data.total_matches)

      if (normalized_score > best_score) {
        best_score = normalized_score
        best_episode = episode_id
        best_data = data
      }
    }

    if (!best_episode || !best_data) {
      return NextResponse.json({
        episode_id: null,
        episode_name: null,
        confidence_score: 0,
        matched_codes: [],
        reasoning: ["No confident episode match found"],
      })
    }

    // Calculate confidence (0-100 scale)
    const confidence_score = Math.min(100, best_score / 2)

    // Build reasoning
    const reasoning: string[] = []
    reasoning.push(`Matched ${best_data.total_matches} code(s) to ${best_data.episode_name}`)

    if (best_data.primary_matches > 0) {
      reasoning.push(`${best_data.primary_matches} primary code match(es) found`)
    }

    const proc_matches = best_data.matched_codes.filter((c: any) => c.code_type === "CPT")
    if (proc_matches.length > 0) {
      reasoning.push(`Procedure code(s): ${proc_matches.map((c: any) => c.code_value).join(", ")}`)
    }

    const diag_matches = best_data.matched_codes.filter((c: any) => c.code_type === "ICD10")
    if (diag_matches.length > 0) {
      reasoning.push(`Diagnosis code(s): ${diag_matches.map((c: any) => c.code_value).join(", ")}`)
    }

    const result: ClassificationResult = {
      episode_id: best_episode,
      episode_name: best_data.episode_name,
      confidence_score: Math.round(confidence_score),
      matched_codes: best_data.matched_codes,
      reasoning,
    }

    return NextResponse.json(result)
  } catch (error) {
    console.error("[v0] Classification exception:", error)
    return NextResponse.json({ error: "Internal server error" }, { status: 500 })
  }
}
