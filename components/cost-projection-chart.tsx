"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from "recharts"

interface CostData {
  quarter: string
  actual: number
  projected: number
}

interface CostProjectionChartProps {
  episodeId: string
  filters: {
    region: string
    network: string
    planType: string
  }
}

const getEpisodeName = (episodeId: string): string => {
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
  return episodeNames[episodeId] || `Episode ${episodeId}`
}

export function CostProjectionChart({ episodeId, filters }: CostProjectionChartProps) {
  const [data, setData] = useState<CostData[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const params = new URLSearchParams({ ...filters, episodeId })
    fetch(`/api/dashboard/cost-projection?${params}`)
      .then((res) => res.json())
      .then((costData) => {
        setData(costData)
        setLoading(false)
      })
      .catch((err) => {
        console.error("[v0] Failed to fetch cost projection:", err)
        setLoading(false)
      })
  }, [filters, episodeId])

  if (loading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Cost Exposure by Quarter</CardTitle>
          <CardDescription>Loading cost data...</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="h-[300px] animate-pulse rounded-lg bg-muted" />
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{getEpisodeName(episodeId)} Cost Exposure by Quarter</CardTitle>
        <CardDescription>Actual vs projected costs in millions (USD)</CardDescription>
      </CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={300}>
          <BarChart data={data}>
            <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
            <XAxis dataKey="quarter" className="text-xs" tick={{ fill: "hsl(var(--muted-foreground))" }} />
            <YAxis className="text-xs" tick={{ fill: "hsl(var(--muted-foreground))" }} />
            <Tooltip
              contentStyle={{
                backgroundColor: "hsl(var(--card))",
                border: "1px solid hsl(var(--border))",
                borderRadius: "0.5rem",
              }}
              formatter={(value) => `$${value}M`}
            />
            <Legend />
            <Bar dataKey="actual" fill="hsl(var(--chart-2))" name="Actual Cost" radius={[4, 4, 0, 0]} />
            <Bar dataKey="projected" fill="#005F6C" name="Projected Cost" radius={[4, 4, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  )
}
