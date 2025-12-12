"use client"

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"

export function SignalTimeline() {
  const timelineEvents = [
    {
      date: "Oct 15, 2024",
      member: "M000847 - Sarah Johnson",
      signal: "Eligibility Query",
      details: "Provider checked coverage for orthopedic consultation",
      weight: 0.4,
    },
    {
      date: "Oct 22, 2024",
      member: "M000847 - Sarah Johnson",
      signal: "Referral Created",
      details: "PCP referred to Dr. Anderson (Orthopedic Surgery)",
      weight: 0.7,
    },
    {
      date: "Oct 28, 2024",
      member: "M000847 - Sarah Johnson",
      signal: "MRI Prior Auth",
      details: "PA request approved for knee MRI imaging",
      weight: 0.6,
    },
    {
      date: "Nov 5, 2024",
      member: "M000847 - Sarah Johnson",
      signal: "Rx Benefit Check",
      details: "Pharmacy benefit verification for pain management",
      weight: 0.3,
    },
    {
      date: "Nov 10, 2024",
      member: "M000847 - Sarah Johnson",
      signal: "TKA Prior Auth",
      details: "PA submitted for total knee arthroplasty (CPT 27447)",
      weight: 0.9,
    },
  ]

  return (
    <Card>
      <CardHeader>
        <CardTitle>Signal Timeline Example</CardTitle>
        <CardDescription>Intent-to-event pathway for member M000847 (89% probability score)</CardDescription>
      </CardHeader>
      <CardContent>
        <div className="relative space-y-4 pl-6">
          <div className="absolute left-[11px] top-2 h-[calc(100%-2rem)] w-px bg-border" />
          {timelineEvents.map((event, index) => (
            <div key={index} className="relative">
              <div className="absolute -left-6 top-1 h-3 w-3 rounded-full border-2 border-primary bg-background" />
              <div className="space-y-1 rounded-lg border border-border p-3">
                <div className="flex items-center justify-between">
                  <span className="text-sm font-medium">{event.signal}</span>
                  <Badge variant="outline" className="text-xs">
                    Weight: {event.weight}
                  </Badge>
                </div>
                <p className="text-sm text-muted-foreground">{event.details}</p>
                <div className="flex items-center gap-2 text-xs text-muted-foreground">
                  <span>{event.date}</span>
                  <span>•</span>
                  <span>{event.member}</span>
                </div>
              </div>
            </div>
          ))}
        </div>
        <div className="mt-6 rounded-lg border border-primary/20 bg-primary/5 p-4">
          <p className="text-sm text-foreground">
            <span className="font-medium">Prediction:</span> Based on signal accumulation (cumulative weight: 2.9),
            member has 89% probability of TKA procedure within 30-45 days. Recommended actions: care navigation, prehab
            enrollment, site-of-care optimization.
          </p>
        </div>
      </CardContent>
    </Card>
  )
}
