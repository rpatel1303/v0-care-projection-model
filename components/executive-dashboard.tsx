"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { TrendingUp, TrendingDown, DollarSign, Users, AlertCircle, ArrowUpRight, Filter } from "lucide-react"
import { TKAVolumeChart } from "@/components/tka-volume-chart"
import { CostProjectionChart } from "@/components/cost-projection-chart"

interface DashboardSummary {
  predictedVolume: {
    next30Days: number
    next60Days: number
    next90Days: number
    next180Days: number
    totalYear: number
  }
  projectedCosts: {
    next30Days: number
    next60Days: number
    next90Days: number
    next180Days: number
    totalYear: number
  }
  intentSignals: {
    eligibilityQueries: number
    priorAuths: number
    referrals: number
    total: number
  }
  highRiskMembers: number
  avgLeadTime: number
  modelAccuracy: number
  comparison: {
    volumeChange: number
    costChange: number
    signalsChange: number
  }
}

interface ExecutiveDashboardProps {
  episodeId: string
}

export function ExecutiveDashboard({ episodeId }: ExecutiveDashboardProps) {
  const [summary, setSummary] = useState<DashboardSummary | null>(null)
  const [loading, setLoading] = useState(true)

  const [timeHorizon, setTimeHorizon] = useState<"30" | "60" | "90" | "180">("90")
  const [region, setRegion] = useState<string>("all")
  const [network, setNetwork] = useState<string>("all")
  const [planType, setPlanType] = useState<string>("all")

  useEffect(() => {
    const params = new URLSearchParams({
      episodeId,
      timeHorizon,
      region,
      network,
      planType,
    })

    fetch(`/api/dashboard/summary?${params}`)
      .then((res) => res.json())
      .then((data) => {
        if (data.error || !data.predictedVolume) {
          console.error("[v0] Invalid summary data received:", data)
          // Fall back to empty state
          setSummary(null)
        } else {
          setSummary(data)
        }
        setLoading(false)
      })
      .catch((err) => {
        console.error("[v0] Failed to fetch dashboard summary:", err)
        setSummary(null)
        setLoading(false)
      })
  }, [episodeId, timeHorizon, region, network, planType])

  if (loading) {
    return (
      <div className="space-y-6">
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
          {[1, 2, 3, 4].map((i) => (
            <Card key={i}>
              <CardHeader className="pb-2">
                <div className="h-4 w-24 animate-pulse bg-muted rounded" />
              </CardHeader>
              <CardContent>
                <div className="h-8 w-16 animate-pulse bg-muted rounded" />
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    )
  }

  if (!summary) {
    return (
      <div className="space-y-6">
        <Card>
          <CardHeader>
            <CardTitle>Unable to Load Dashboard</CardTitle>
            <CardDescription>
              There was an error loading dashboard data. Please check that Supabase is properly configured and the
              database has been seeded.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="text-sm text-muted-foreground">
              <p>Troubleshooting steps:</p>
              <ul className="mt-2 list-disc list-inside space-y-1">
                <li>Verify Supabase environment variables are set</li>
                <li>
                  Run SQL scripts in order: 00-consolidated-schema.sql → 02-seed-episode-definitions.sql →
                  03-seed-code-mappings.sql
                </li>
                <li>Check browser console and server logs for specific errors</li>
              </ul>
            </div>
          </CardContent>
        </Card>
      </div>
    )
  }

  const getMetrics = () => {
    const key = `next${timeHorizon}Days` as keyof typeof summary.predictedVolume
    return {
      volume: summary.predictedVolume[key],
      cost: summary.projectedCosts[key],
    }
  }

  const metrics = getMetrics()

  const getEpisodeName = () => {
    const episodeNames: Record<string, string> = {
      TKA: "Knee Replacement",
      THA: "Hip Replacement",
      SPINAL_FUSION: "Spinal Fusion",
      CABG: "Coronary Artery Bypass Graft",
      PCI: "Coronary Intervention",
      BARIATRIC: "Bariatric Surgery",
      COLORECTAL: "Colorectal Surgery",
      MASTECTOMY: "Mastectomy",
    }
    return episodeNames[episodeId] || "Episode"
  }

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between">
            <div>
              <CardTitle className="text-lg">{getEpisodeName()} Forecasting</CardTitle>
              <CardDescription>Clinical utilization prediction based on pre-claim intent signals</CardDescription>
            </div>
            <Badge variant="outline" className="gap-1">
              <Filter className="h-3 w-3" />
              Filters Active
            </Badge>
          </div>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-4">
            <div className="space-y-2">
              <label className="text-sm font-medium">Time Horizon</label>
              <Select value={timeHorizon} onValueChange={(v) => setTimeHorizon(v as any)}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="30">Next 30 Days</SelectItem>
                  <SelectItem value="60">Next 60 Days</SelectItem>
                  <SelectItem value="90">Next 90 Days</SelectItem>
                  <SelectItem value="180">Next 180 Days</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium">Geographic Region</label>
              <Select value={region} onValueChange={setRegion}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Regions</SelectItem>
                  <SelectItem value="northeast">Northeast</SelectItem>
                  <SelectItem value="southeast">Southeast</SelectItem>
                  <SelectItem value="midwest">Midwest</SelectItem>
                  <SelectItem value="southwest">Southwest</SelectItem>
                  <SelectItem value="west">West</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium">Provider Network</label>
              <Select value={network} onValueChange={setNetwork}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Networks</SelectItem>
                  <SelectItem value="tier1">Tier 1 - Preferred</SelectItem>
                  <SelectItem value="tier2">Tier 2 - Standard</SelectItem>
                  <SelectItem value="tier3">Tier 3 - Out-of-Network</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium">Plan Type</label>
              <Select value={planType} onValueChange={setPlanType}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Plans</SelectItem>
                  <SelectItem value="hmo">HMO</SelectItem>
                  <SelectItem value="ppo">PPO</SelectItem>
                  <SelectItem value="epo">EPO</SelectItem>
                  <SelectItem value="pos">POS</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Key Metrics */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Predicted Volume</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{metrics.volume}</div>
            <p className="text-xs text-muted-foreground">Next {timeHorizon} days</p>
            <div className="mt-2 flex items-center gap-1 text-xs">
              {summary.comparison.volumeChange >= 0 ? (
                <TrendingUp className="h-3 w-3 text-green-600" />
              ) : (
                <TrendingDown className="h-3 w-3 text-red-600" />
              )}
              <span className={summary.comparison.volumeChange >= 0 ? "text-green-600" : "text-red-600"}>
                {summary.comparison.volumeChange > 0 ? "+" : ""}
                {summary.comparison.volumeChange}% vs. last period
              </span>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Projected Cost</CardTitle>
            <DollarSign className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">${(metrics.cost / 1000000).toFixed(1)}M</div>
            <p className="text-xs text-muted-foreground">Expected exposure ({timeHorizon}d)</p>
            <div className="mt-2 flex items-center gap-1 text-xs">
              {summary.comparison.costChange >= 0 ? (
                <ArrowUpRight className="h-3 w-3 text-orange-600" />
              ) : (
                <TrendingDown className="h-3 w-3 text-green-600" />
              )}
              <span className={summary.comparison.costChange >= 0 ? "text-orange-600" : "text-green-600"}>
                {summary.comparison.costChange > 0 ? "+" : ""}
                {summary.comparison.costChange}% vs. last period
              </span>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Model Accuracy</CardTitle>
            <AlertCircle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{Math.round(summary.modelAccuracy * 100)}%</div>
            <p className="text-xs text-muted-foreground">Precision rate</p>
            <div className="mt-2 flex items-center gap-1 text-xs">
              <Badge variant="secondary" className="text-xs">
                {summary.avgLeadTime}-day avg lead time
              </Badge>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Intent Signals</CardTitle>
            <TrendingUp className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{summary.intentSignals.total.toLocaleString()}</div>
            <p className="text-xs text-muted-foreground">This period</p>
            <div className="mt-2 flex items-center gap-1 text-xs">
              {summary.comparison.signalsChange >= 0 ? (
                <TrendingUp className="h-3 w-3 text-blue-600" />
              ) : (
                <TrendingDown className="h-3 w-3 text-muted-foreground" />
              )}
              <span className={summary.comparison.signalsChange >= 0 ? "text-blue-600" : "text-muted-foreground"}>
                {summary.comparison.signalsChange > 0 ? "+" : ""}
                {summary.comparison.signalsChange}% vs. last period
              </span>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Charts */}
      <div className="grid gap-6 lg:grid-cols-2">
        <TKAVolumeChart episodeId={episodeId} filters={{ region, network, planType }} />
        <CostProjectionChart episodeId={episodeId} filters={{ region, network, planType }} />
      </div>

      {/* High Risk Members Summary */}
      <Card>
        <CardHeader>
          <CardTitle>High-Risk Member Summary</CardTitle>
          <CardDescription>
            Members with very high probability (90%+) of {getEpisodeName().toLowerCase()} procedure in next{" "}
            {timeHorizon} days
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div className="space-y-1">
                <p className="text-2xl font-bold">{summary.highRiskMembers}</p>
                <p className="text-sm text-muted-foreground">Members requiring immediate outreach</p>
              </div>
              <div className="text-right">
                <p className="text-lg font-semibold text-green-600">
                  ${((summary.highRiskMembers * 38000) / 1000000).toFixed(1)}M
                </p>
                <p className="text-sm text-muted-foreground">Estimated cost impact</p>
              </div>
            </div>
            <div className="grid gap-4 md:grid-cols-3">
              <div className="rounded-lg border border-border p-3">
                <p className="text-sm text-muted-foreground">Care Navigation Ready</p>
                <p className="mt-1 text-xl font-bold">{Math.round(summary.highRiskMembers * 0.65)}</p>
              </div>
              <div className="rounded-lg border border-border p-3">
                <p className="text-sm text-muted-foreground">Prehab Eligible</p>
                <p className="mt-1 text-xl font-bold">{Math.round(summary.highRiskMembers * 0.45)}</p>
              </div>
              <div className="rounded-lg border border-border p-3">
                <p className="text-sm text-muted-foreground">Site-of-Care Review</p>
                <p className="mt-1 text-xl font-bold">{Math.round(summary.highRiskMembers * 0.55)}</p>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
