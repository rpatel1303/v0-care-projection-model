"use client"

import { useState, useEffect } from "react"
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Activity, Calendar } from "lucide-react"
import { ExecutiveDashboard } from "@/components/executive-dashboard"
import { ClinicalOpsDashboard } from "@/components/clinical-ops-dashboard"
import { IntentSignalsOverview } from "@/components/intent-signals-overview"

interface Episode {
  id: string
  name: string
  category: string
  avgCost: number
  avgLeadTime: number
  color: string
}

export default function ClinicalForecastingEngine() {
  const [activeView, setActiveView] = useState<"executive" | "clinical">("executive")
  const [selectedEpisode, setSelectedEpisode] = useState<string>("TKA")
  const [episodes, setEpisodes] = useState<Episode[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetch("/api/episodes")
      .then((res) => res.json())
      .then((data) => {
        setEpisodes(data)
        setLoading(false)
      })
      .catch((err) => {
        console.error("[v0] Failed to fetch episodes:", err)
        setLoading(false)
      })
  }, [])

  const currentEpisode = episodes.find((e) => e.id === selectedEpisode)

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-border bg-card">
        <div className="container mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-primary">
                <Activity className="h-6 w-6 text-primary-foreground" />
              </div>
              <div>
                <h1 className="text-xl font-semibold text-foreground">Clinical Forecasting Engine</h1>
                <p className="text-sm text-muted-foreground">Pre-Claim Intent Signal Analytics</p>
              </div>
            </div>
            <div className="flex items-center gap-4">
              <div className="min-w-[280px]">
                <Select value={selectedEpisode} onValueChange={setSelectedEpisode} disabled={loading}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select episode of care..." />
                  </SelectTrigger>
                  <SelectContent>
                    {episodes.map((episode) => (
                      <SelectItem key={episode.id} value={episode.id}>
                        <div className="flex items-center gap-2">
                          <div className="h-2 w-2 rounded-full" style={{ backgroundColor: episode.color }} />
                          <span className="font-medium">{episode.name}</span>
                          <span className="text-xs text-muted-foreground">({episode.category})</span>
                        </div>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <Badge variant="outline" className="gap-1">
                <div className="h-2 w-2 rounded-full bg-green-500" />
                Live Data
              </Badge>
              <Button variant="outline" size="sm">
                <Calendar className="mr-2 h-4 w-4" />
                Last 90 Days
              </Button>
            </div>
          </div>
          {currentEpisode && (
            <div className="mt-3 flex items-center gap-6 text-sm text-muted-foreground">
              <div className="flex items-center gap-2">
                <span className="font-medium">Category:</span>
                <Badge variant="secondary">{currentEpisode.category}</Badge>
              </div>
              <div className="flex items-center gap-2">
                <span className="font-medium">Avg Cost:</span>
                <span>${currentEpisode.avgCost.toLocaleString()}</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="font-medium">Avg Lead Time:</span>
                <span>{currentEpisode.avgLeadTime} days</span>
              </div>
            </div>
          )}
        </div>
      </header>

      {/* Navigation Tabs */}
      <div className="border-b border-border bg-card">
        <div className="container mx-auto px-6">
          <Tabs value={activeView} onValueChange={(v) => setActiveView(v as any)} className="w-full">
            <TabsList className="grid w-full max-w-md grid-cols-2">
              <TabsTrigger value="executive">Executive View</TabsTrigger>
              <TabsTrigger value="clinical">Clinical Operations</TabsTrigger>
            </TabsList>
          </Tabs>
        </div>
      </div>

      {/* Main Content */}
      <main className="container mx-auto px-6 py-8">
        {activeView === "executive" ? (
          <ExecutiveDashboard episodeId={selectedEpisode} />
        ) : (
          <ClinicalOpsDashboard episodeId={selectedEpisode} />
        )}

        {/* Intent Signals Overview - Shown on both views */}
        <IntentSignalsOverview episodeId={selectedEpisode} />
      </main>
    </div>
  )
}
