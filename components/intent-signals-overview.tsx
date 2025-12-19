"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Activity, FileText, Users, Pill } from "lucide-react"

interface SignalData {
  byType: Array<{ type: string; count: number; change: number }>
  timeline: Array<{ week: string; elig: number; pa: number; referral: number }>
}

export function IntentSignalsOverview({ episodeId }: { episodeId: string }) {
  const [signals, setSignals] = useState<SignalData | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetch(`/api/dashboard/signals?episodeId=${episodeId}`)
      .then((res) => res.json())
      .then((data) => {
        setSignals(data)
        setLoading(false)
      })
      .catch((err) => {
        console.error("[v0] Failed to fetch signal data:", err)
        setLoading(false)
      })
  }, [episodeId])

  return (
    <Card className="mt-6">
      <CardHeader>
        <CardTitle>Intent Signal Architecture</CardTitle>
        <CardDescription>
          Pre-claim signals from clinical_intent_event table used to predict upcoming procedures
        </CardDescription>
      </CardHeader>
      <CardContent>
        {loading || !signals ? (
          <div className="h-48 animate-pulse rounded-lg bg-muted" />
        ) : (
          <>
            <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
              <div className="space-y-3">
                <div className="flex items-center gap-2">
                  <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary/10">
                    <Activity className="h-4 w-4 text-primary" />
                  </div>
                  <div>
                    <div className="font-medium">Eligibility (270/271)</div>
                    <Badge variant="outline" className="mt-1 text-xs">
                      Weight: 0.35
                    </Badge>
                  </div>
                </div>
                <p className="text-sm text-muted-foreground">
                  Member or provider checking coverage for procedure services via EDI gateway
                </p>
                <div className="text-sm">
                  <span className="font-medium">{signals.byType[1]?.count.toLocaleString()}</span>
                  <span className="text-muted-foreground"> signals this period</span>
                  {signals.byType[1]?.change !== 0 && (
                    <span className={`ml-2 ${signals.byType[1].change > 0 ? "text-green-600" : "text-red-600"}`}>
                      {signals.byType[1].change > 0 ? "+" : ""}
                      {signals.byType[1].change}%
                    </span>
                  )}
                </div>
              </div>

              <div className="space-y-3">
                <div className="flex items-center gap-2">
                  <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary/10">
                    <FileText className="h-4 w-4 text-primary" />
                  </div>
                  <div>
                    <div className="font-medium">Prior Auth (278)</div>
                    <Badge variant="outline" className="mt-1 text-xs">
                      Weight: 0.90
                    </Badge>
                  </div>
                </div>
                <p className="text-sm text-muted-foreground">
                  Direct PA request for procedure with specific CPT codes from UM system
                </p>
                <div className="text-sm">
                  <span className="font-medium">{signals.byType[0]?.count.toLocaleString()}</span>
                  <span className="text-muted-foreground"> requests this period</span>
                  {signals.byType[0]?.change !== 0 && (
                    <span className={`ml-2 ${signals.byType[0].change > 0 ? "text-green-600" : "text-red-600"}`}>
                      {signals.byType[0].change > 0 ? "+" : ""}
                      {signals.byType[0].change}%
                    </span>
                  )}
                </div>
              </div>

              <div className="space-y-3">
                <div className="flex items-center gap-2">
                  <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary/10">
                    <Users className="h-4 w-4 text-primary" />
                  </div>
                  <div>
                    <div className="font-medium">Referrals (HL7/FHIR)</div>
                    <Badge variant="outline" className="mt-1 text-xs">
                      Weight: 0.70
                    </Badge>
                  </div>
                </div>
                <p className="text-sm text-muted-foreground">
                  PCP to orthopedic surgeon referral for knee evaluation via EMR integration
                </p>
                <div className="text-sm">
                  <span className="font-medium">{signals.byType[2]?.count.toLocaleString()}</span>
                  <span className="text-muted-foreground"> referrals this period</span>
                  {signals.byType[2]?.change !== 0 && (
                    <span className={`ml-2 ${signals.byType[2].change > 0 ? "text-green-600" : "text-red-600"}`}>
                      {signals.byType[2].change > 0 ? "+" : ""}
                      {signals.byType[2].change}%
                    </span>
                  )}
                </div>
              </div>

              <div className="space-y-3">
                <div className="flex items-center gap-2">
                  <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary/10">
                    <Pill className="h-4 w-4 text-primary" />
                  </div>
                  <div>
                    <div className="font-medium">Rx Benefit Check</div>
                    <Badge variant="outline" className="mt-1 text-xs">
                      Weight: 0.30
                    </Badge>
                  </div>
                </div>
                <p className="text-sm text-muted-foreground">
                  Real-time pharmacy check for pain medication or post-op drug coverage
                </p>
                <div className="text-sm">
                  <span className="font-medium">
                    {signals.byType.find((s) => s.type.includes("Pended"))?.count.toLocaleString()}
                  </span>
                  <span className="text-muted-foreground"> checks this period</span>
                </div>
              </div>
            </div>

            <div className="mt-6 rounded-lg bg-muted/50 p-4">
              <h4 className="mb-2 font-medium">Prediction Model Logic</h4>
              <p className="text-sm text-muted-foreground">
                Member probability score = Σ (signal_weight × time_decay × frequency). Signal data is aggregated from
                eligibility_inquiry_event and prior_auth_request tables into clinical_intent_event. Scores above 0.65
                are flagged for care management intervention. Model uses gradient boosted trees with 30-90 day
                prediction window, validated against clinical_outcome_event ground truth.
              </p>
            </div>
          </>
        )}
      </CardContent>
    </Card>
  )
}
