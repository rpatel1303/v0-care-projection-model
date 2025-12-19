import { NextResponse } from "next/server"

// This would query the episode_definition table in production
export async function GET() {
  const episodes = [
    {
      id: "TKA",
      name: "Total Knee Replacement",
      category: "Orthopedic",
      avgCost: 38000,
      avgLeadTime: 45,
      color: "#3b82f6",
    },
    {
      id: "THA",
      name: "Total Hip Replacement",
      category: "Orthopedic",
      avgCost: 42000,
      avgLeadTime: 42,
      color: "#8b5cf6",
    },
    {
      id: "SPINE_FUSION",
      name: "Spinal Fusion",
      category: "Orthopedic",
      avgCost: 65000,
      avgLeadTime: 38,
      color: "#ec4899",
    },
    {
      id: "CABG",
      name: "Coronary Artery Bypass Graft",
      category: "Cardiac",
      avgCost: 85000,
      avgLeadTime: 21,
      color: "#ef4444",
    },
    {
      id: "PCI",
      name: "Percutaneous Coronary Intervention",
      category: "Cardiac",
      avgCost: 48000,
      avgLeadTime: 14,
      color: "#f97316",
    },
    {
      id: "BARIATRIC",
      name: "Bariatric Surgery",
      category: "General Surgery",
      avgCost: 28000,
      avgLeadTime: 90,
      color: "#10b981",
    },
    {
      id: "COLORECTAL",
      name: "Colorectal Surgery",
      category: "Oncology",
      avgCost: 45000,
      avgLeadTime: 30,
      color: "#14b8a6",
    },
    {
      id: "MASTECTOMY",
      name: "Mastectomy",
      category: "Oncology",
      avgCost: 38000,
      avgLeadTime: 28,
      color: "#06b6d4",
    },
  ]

  return NextResponse.json(episodes)
}
