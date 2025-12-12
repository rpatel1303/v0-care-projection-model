"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { ChevronDown } from "lucide-react"

interface Signal {
  type: string
  date: string
  details: string
  strength: number
}

interface Member {
  memberId: string
  name: string
  age: number
  gender: string
  probability: number
  predictedDate: string
  riskTier: string
  signals: Signal[]
  diagnosis: string[]
  provider: string
  estimatedCost: number
  planId: string
  daysUntilProcedure: number
}

export function HighRiskMembers() {
  const [members, setMembers] = useState<Member[]>([])
  const [loading, setLoading] = useState(true)
  const [expandedMember, setExpandedMember] = useState<string | null>(null)

  useEffect(() => {
    fetch("/api/dashboard/members")
      .then((res) => res.json())
      .then((data) => {
        setMembers(data)
        setLoading(false)
      })
      .catch((err) => {
        console.error("[v0] Failed to fetch high-risk members:", err)
        setLoading(false)
      })
  }, [])

  if (loading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>High-Probability Knee Replacement Candidates</CardTitle>
          <CardDescription>Loading member data...</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-24 animate-pulse rounded-lg bg-muted" />
            ))}
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>High-Probability Knee Replacement Candidates</CardTitle>
        <CardDescription>
          {members.length} members with strongest intent signals (from prediction_result + clinical_intent_event)
        </CardDescription>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          {members.map((member) => (
            <div key={member.memberId} className="rounded-lg border border-border">
              <div className="flex items-center justify-between p-4">
                <div className="flex-1 space-y-2">
                  <div className="flex items-center gap-3">
                    <span className="font-medium">{member.name}</span>
                    <Badge variant="outline" className="text-xs">
                      {member.age}y {member.gender}
                    </Badge>
                    <Badge variant="outline" className="text-xs">
                      {member.memberId}
                    </Badge>
                    <Badge variant={member.riskTier === "very_high" ? "destructive" : "default"} className="text-xs">
                      {member.riskTier.replace("_", " ").toUpperCase()}
                    </Badge>
                  </div>
                  <div className="flex items-center gap-4 text-sm text-muted-foreground">
                    <span>{member.provider}</span>
                    <span>•</span>
                    <span>Expected: {new Date(member.predictedDate).toLocaleDateString()}</span>
                    <span>•</span>
                    <span>{member.daysUntilProcedure} days out</span>
                    <span>•</span>
                    <span className="font-medium text-foreground">${member.estimatedCost.toLocaleString()}</span>
                  </div>
                  <div className="flex flex-wrap gap-1">
                    {member.diagnosis.map((dx, idx) => (
                      <Badge key={idx} variant="secondary" className="text-xs">
                        {dx}
                      </Badge>
                    ))}
                  </div>
                </div>
                <div className="ml-4 flex items-center gap-6">
                  <div className="text-center">
                    <div className="text-2xl font-bold text-primary">{Math.round(member.probability * 100)}%</div>
                    <div className="text-xs text-muted-foreground">Probability</div>
                  </div>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setExpandedMember(expandedMember === member.memberId ? null : member.memberId)}
                  >
                    <ChevronDown
                      className={`mr-2 h-4 w-4 transition-transform ${
                        expandedMember === member.memberId ? "rotate-180" : ""
                      }`}
                    />
                    Signals
                  </Button>
                </div>
              </div>

              {expandedMember === member.memberId && (
                <div className="border-t border-border bg-muted/30 p-4">
                  <h4 className="mb-3 text-sm font-medium">Intent Signal Timeline</h4>
                  <div className="space-y-2">
                    {member.signals.map((signal, idx) => (
                      <div key={idx} className="flex items-center justify-between rounded-lg bg-card p-3">
                        <div className="flex items-center gap-3">
                          <Badge variant={signal.type === "pa" ? "default" : "secondary"} className="uppercase">
                            {signal.type}
                          </Badge>
                          <span className="text-sm">{signal.details}</span>
                        </div>
                        <div className="flex items-center gap-4">
                          <span className="text-xs text-muted-foreground">
                            {new Date(signal.date).toLocaleDateString()}
                          </span>
                          <Badge variant="outline" className="text-xs">
                            Strength: {signal.strength.toFixed(2)}
                          </Badge>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  )
}
