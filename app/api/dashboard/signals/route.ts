import { NextResponse } from "next/server"

// Based on clinical_intent_event aggregated by signal_type and time
export async function GET() {
  // SQL would aggregate clinical_intent_event by week/month
  const signals = {
    byType: [
      { type: "Prior Auth Approved", count: 156, change: 12 },
      { type: "Eligibility Query", count: 847, change: 23 },
      { type: "Referrals", count: 234, change: -5 },
      { type: "Prior Auth Pended", count: 89, change: 8 },
    ],
    timeline: [
      { week: "Week 1", elig: 45, pa: 12, referral: 8 },
      { week: "Week 2", elig: 52, pa: 15, referral: 9 },
      { week: "Week 3", elig: 48, pa: 13, referral: 7 },
      { week: "Week 4", elig: 56, pa: 18, referral: 11 },
      { week: "Week 5", elig: 61, pa: 20, referral: 10 },
      { week: "Week 6", elig: 58, pa: 16, referral: 9 },
      { week: "Week 7", elig: 63, pa: 22, referral: 12 },
      { week: "Week 8", elig: 67, pa: 19, referral: 11 },
    ],
  }

  return NextResponse.json(signals)
}
