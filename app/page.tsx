"use client"

import { useState } from "react"
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Activity, Calendar } from "lucide-react"
import { ExecutiveDashboard } from "@/components/executive-dashboard"
import { ClinicalOpsDashboard } from "@/components/clinical-ops-dashboard"
import { IntentSignalsOverview } from "@/components/intent-signals-overview"

export default function ClinicalForecastingEngine() {
  const [activeView, setActiveView] = useState<"executive" | "clinical">("executive")

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
        {activeView === "executive" ? <ExecutiveDashboard /> : <ClinicalOpsDashboard />}

        {/* Intent Signals Overview - Shown on both views */}
        <IntentSignalsOverview />
      </main>
    </div>
  )
}
