"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import {
  ComposedChart,
  Bar,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
  ReferenceLine,
} from "recharts"

interface ForecastData {
  month: string
  actual: number
  predicted: number
  lower: number
  upper: number
}

interface TKAVolumeChartProps {
  filters: {
    region: string
    network: string
    planType: string
  }
}

export function TKAVolumeChart({ filters }: TKAVolumeChartProps) {
  const [data, setData] = useState<ForecastData[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const params = new URLSearchParams(filters)
    fetch(`/api/dashboard/forecast?${params}`)
      .then((res) => res.json())
      .then((forecast: ForecastData[]) => {
        const chartData = forecast.map((item) => ({
          month: item.month,
          actual: item.actual > 0 ? item.actual : null,
          predicted: item.predicted > 0 ? item.predicted : null,
          confidenceLower: item.lower,
          confidenceUpper: item.upper,
          confidenceRange: item.upper - item.lower,
        }))
        setData(chartData)
        setLoading(false)
      })
      .catch((err) => {
        console.error("[v0] Failed to fetch forecast data:", err)
        setLoading(false)
      })
  }, [filters])

  if (loading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Knee Replacement Volume Forecast</CardTitle>
          <CardDescription>Loading forecast data...</CardDescription>
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
        <CardTitle>Knee Replacement Volume Forecast</CardTitle>
        <CardDescription>
          Historical claims (claim_line + clinical_outcome_event) vs predicted volume (prediction_result)
        </CardDescription>
      </CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={300}>
          <ComposedChart data={data}>
            <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
            <XAxis dataKey="month" className="text-xs" tick={{ fill: "hsl(var(--muted-foreground))" }} />
            <YAxis
              className="text-xs"
              tick={{ fill: "hsl(var(--muted-foreground))" }}
              label={{
                value: "Procedure Volume",
                angle: -90,
                position: "insideLeft",
                style: { fill: "hsl(var(--muted-foreground))" },
              }}
            />
            <Tooltip
              contentStyle={{
                backgroundColor: "hsl(var(--card))",
                border: "1px solid hsl(var(--border))",
                borderRadius: "0.5rem",
              }}
              labelStyle={{ color: "hsl(var(--foreground))" }}
            />
            <Legend />
            <ReferenceLine
              x="Nov 2024"
              stroke="hsl(var(--muted-foreground))"
              strokeDasharray="3 3"
              label={{ value: "Current", position: "top", fill: "hsl(var(--muted-foreground))" }}
            />

            {/* Confidence range area */}
            <Area
              type="monotone"
              dataKey="confidenceRange"
              stroke="none"
              fill="hsl(var(--chart-3))"
              fillOpacity={0.15}
              name="Confidence Range"
              stackId="1"
            />

            {/* Actual claims bars */}
            <Bar dataKey="actual" fill="hsl(var(--chart-2))" name="Actual Claims" radius={[4, 4, 0, 0]} />

            {/* Predicted volume area */}
            <Area
              type="monotone"
              dataKey="predicted"
              stroke="hsl(var(--chart-1))"
              strokeWidth={3}
              fill="hsl(var(--chart-1))"
              fillOpacity={0.2}
              name="Predicted Volume"
              dot={{ r: 5, fill: "hsl(var(--chart-1))" }}
            />
          </ComposedChart>
        </ResponsiveContainer>
        <div className="mt-4 flex items-center justify-center gap-6 text-xs text-muted-foreground">
          <div className="flex items-center gap-2">
            <div className="h-3 w-3 rounded bg-[hsl(var(--chart-2))]" />
            <span>Actual (from claims)</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="h-3 w-3 rounded bg-[hsl(var(--chart-1))]" />
            <span>Predicted (from intent signals)</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="h-3 w-3 rounded bg-[hsl(var(--chart-3))] opacity-50" />
            <span>Confidence interval</span>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}
