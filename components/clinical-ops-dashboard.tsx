"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { CheckCircle, ArrowRight, DollarSign, Activity } from "lucide-react"
import { HighRiskMembers } from "@/components/high-risk-members"
import { SignalTimeline } from "@/components/signal-timeline"

interface ClinicalMetrics {
  careNavigationReady: number
  siteOfCareSavings: number
  prehabCandidates: number
}

export function ClinicalOpsDashboard({ episodeId }: { episodeId: string }) {
  const [metrics, setMetrics] = useState<ClinicalMetrics | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    console.log("[v0] Fetching clinical ops metrics for episode:", episodeId)
    fetch(`/api/dashboard/summary?episodeId=${episodeId}`)
      .then((res) => res.json())
      .then((data) => {
        console.log("[v0] Clinical ops summary received:", data)
        // Calculate metrics from summary data
        const highRisk = data.highRiskMembers || 0
        setMetrics({
          careNavigationReady: Math.round(highRisk * 0.65),
          siteOfCareSavings: Math.round((highRisk * 38000 * 0.15) / 1000) / 1000, // 15% savings potential in millions
          prehabCandidates: Math.round(highRisk * 0.45),
        })
        setLoading(false)
      })
      .catch((err) => {
        console.error("[v0] Failed to fetch clinical ops metrics:", err)
        setLoading(false)
      })
  }, [episodeId])

  if (loading) {
    return (
      <div className="space-y-6">
        <div className="grid gap-6 md:grid-cols-3">
          {[1, 2, 3].map((i) => (
            <Card key={i}>
              <CardHeader className="pb-2">
                <div className="h-4 w-32 animate-pulse rounded bg-muted" />
              </CardHeader>
              <CardContent>
                <div className="h-8 w-16 animate-pulse rounded bg-muted" />
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Clinical Action Cards */}
      <div className="grid gap-6 md:grid-cols-3">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Care Navigation Ready</CardTitle>
            <CheckCircle className="h-4 w-4 text-green-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{metrics?.careNavigationReady || 0}</div>
            <p className="text-xs text-muted-foreground">Members for outreach</p>
            <Button variant="link" size="sm" className="mt-2 h-auto p-0 text-xs">
              View list <ArrowRight className="ml-1 h-3 w-3" />
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Site-of-Care Opportunities</CardTitle>
            <DollarSign className="h-4 w-4 text-blue-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">${metrics?.siteOfCareSavings.toFixed(1) || "0.0"}M</div>
            <p className="text-xs text-muted-foreground">Potential savings</p>
            <Button variant="link" size="sm" className="mt-2 h-auto p-0 text-xs">
              Review cases <ArrowRight className="ml-1 h-3 w-3" />
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Prehab Candidates</CardTitle>
            <Activity className="h-4 w-4 text-purple-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{metrics?.prehabCandidates || 0}</div>
            <p className="text-xs text-muted-foreground">Pre-surgical optimization</p>
            <Button variant="link" size="sm" className="mt-2 h-auto p-0 text-xs">
              Start program <ArrowRight className="ml-1 h-3 w-3" />
            </Button>
          </CardContent>
        </Card>
      </div>

      {/* High Risk Members Table */}
      <HighRiskMembers episodeId={episodeId} />

      {/* Signal Timeline */}
      <SignalTimeline episodeId={episodeId} />
    </div>
  )
}
