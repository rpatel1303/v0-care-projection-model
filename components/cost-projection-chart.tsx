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
  filters: {
    region: string
    network: string
    planType: string
  }
}

export function CostProjectionChart({ filters }: CostProjectionChartProps) {
  const [data, setData] = useState<CostData[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const params = new URLSearchParams(filters)
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
  }, [filters])

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
        <CardTitle>Cost Exposure by Quarter</CardTitle>
        <CardDescription>Actual vs projected knee replacement costs in millions (USD)</CardDescription>
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
            <Bar dataKey="projected" fill="hsl(var(--chart-3))" name="Projected Cost" radius={[4, 4, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  )
}
