# API Audit Report - Mock Data Review

**Date:** December 19, 2024
**Status:** All APIs currently using mock data

## Summary

All dashboard APIs are currently returning hardcoded mock data instead of querying Supabase. The `episodeId` and filter parameters are being accepted but not applied to actual database queries.

## API Endpoints Status

### ✅ Partially Working (Accept episodeId but return mock data)

| Endpoint | Episode Filter | Other Filters | Mock Data | Notes |
|----------|---------------|---------------|-----------|-------|
| `/api/dashboard/summary` | ✅ Yes | ✅ Yes (region, network, planType) | ❌ Hardcoded | Returns episode-specific metrics but from hardcoded object |
| `/api/dashboard/forecast` | ✅ Yes | ✅ Yes (region, network, planType) | ❌ Hardcoded | Returns episode-specific forecast data but from hardcoded arrays |
| `/api/dashboard/cost-projection` | ✅ Yes | ❌ No | ❌ Hardcoded | Returns episode-specific cost data but from hardcoded arrays |

### ❌ Not Working (Missing episodeId parameter)

| Endpoint | Episode Filter | Other Filters | Mock Data | Issues |
|----------|---------------|---------------|-----------|--------|
| `/api/dashboard/members` | ❌ No | ❌ No | ❌ Hardcoded | Does not accept or use episodeId parameter |
| `/api/dashboard/signals` | ❌ No | ❌ No | ❌ Hardcoded | Does not accept or use episodeId parameter |

## Required Changes

### Priority 1: Add Episode Filtering

**Members API (`/api/dashboard/members/route.ts`)**
- Add `episodeId` query parameter
- Filter members by episode: `WHERE prediction_result.episode_id = ?`
- Return different high-risk members for each episode

**Signals API (`/api/dashboard/signals/route.ts`)**
- Add `episodeId` query parameter  
- Filter intent signals by episode: `WHERE clinical_intent_event.episode_id = ?`
- Return episode-specific signal counts and timeline

### Priority 2: Connect to Supabase

All APIs need to:
1. Import `createServerClient` from `lib/supabase/server`
2. Replace hardcoded mock data with SQL queries
3. Apply filters to WHERE clauses
4. Return actual data from database

### Priority 3: Implement Filters

All APIs accept but don't use these filters:
- `region` - Geographic region filter
- `network` - Provider network filter
- `planType` - Plan type filter (HMO, PPO, etc.)

These need to be applied in SQL WHERE clauses.

## API Contract Specification

### Standard Query Parameters

All dashboard APIs should accept:

```typescript
interface DashboardAPIParams {
  episodeId: string;      // Required - episode to analyze
  region?: string;        // Optional - filter by region ('all' = no filter)
  network?: string;       // Optional - filter by network ('all' = no filter)
  planType?: string;      // Optional - filter by plan type ('all' = no filter)
  timeHorizon?: string;   // Optional - forecast horizon in days (default: 90)
}
```

### Response Contracts

**Summary API Response:**
```typescript
{
  predictedVolume: {
    next30Days: number,
    next60Days: number,
    next90Days: number,
    next180Days: number,
    totalYear: number
  },
  projectedCosts: {
    next30Days: number,
    next60Days: number,
    next90Days: number,
    next180Days: number,
    totalYear: number
  },
  intentSignals: {
    eligibilityQueries: number,
    priorAuths: number,
    referrals: number,
    total: number
  },
  highRiskMembers: number,
  avgLeadTime: number,
  modelAccuracy: number,
  comparison: {
    volumeChange: number,    // % change from previous period
    costChange: number,       // % change from previous period
    signalsChange: number     // % change from previous period
  }
}
```

**Forecast API Response:**
```typescript
Array<{
  month: string,        // e.g., "Jan 2025"
  actual: number,       // Actual procedures (0 if future)
  predicted: number,    // Predicted procedures
  lower: number,        // Confidence interval lower bound
  upper: number         // Confidence interval upper bound
}>
```

**Cost Projection API Response:**
```typescript
Array<{
  quarter: string,      // e.g., "Q1 2025"
  actual: number,       // Actual cost (0 if future)
  projected: number,    // Projected cost
  breakdown?: {         // Optional detailed breakdown
    next30: number,
    next60: number,
    next90: number
  }
}>
```

**Members API Response:**
```typescript
Array<{
  memberId: string,
  name: string,
  age: number,
  gender: string,
  probability: number,         // 0.0 - 1.0
  predictedDate: string,       // ISO date
  riskTier: string,           // 'very_high' | 'high' | 'medium' | 'low'
  signals: Array<{
    type: string,             // 'pa' | 'elig' | 'referral' | 'rx'
    date: string,             // ISO date
    details: string,
    strength: number          // 0.0 - 1.0
  }>,
  diagnosis: string[],
  provider: string,
  estimatedCost: number,
  planId: string,
  daysUntilProcedure: number
}>
```

**Signals API Response:**
```typescript
{
  byType: Array<{
    type: string,
    count: number,
    change: number            // % change from previous period
  }>,
  timeline: Array<{
    week: string,
    elig: number,
    pa: number,
    referral: number
  }>
}
```

## Recommended Implementation Order

1. **Members API** - Add episodeId filtering (highest priority, most visible issue)
2. **Signals API** - Add episodeId filtering  
3. **All APIs** - Connect to Supabase and replace mock data
4. **All APIs** - Implement region/network/planType filters

## SQL Query Templates

### Members Query
```sql
SELECT 
  pr.member_id,
  m.first_name || ' ' || SUBSTRING(m.last_name, 1, 1) || '.' as name,
  EXTRACT(YEAR FROM AGE(m.date_of_birth)) as age,
  m.gender,
  pr.probability,
  pr.predicted_service_date,
  pr.risk_tier,
  pr.estimated_cost,
  m.plan_id
FROM prediction_result pr
JOIN member m ON pr.member_id = m.member_id
WHERE pr.episode_id = $1
  AND pr.risk_tier IN ('very_high', 'high')
  AND ($2 = 'all' OR m.geographic_region = $2)
  AND ($3 = 'all' OR m.network = $3)
  AND ($4 = 'all' OR m.plan_type = $4)
ORDER BY pr.probability DESC
LIMIT 10;
```

### Signals Query
```sql
SELECT 
  cie.signal_type,
  COUNT(*) as count
FROM clinical_intent_event cie
WHERE cie.episode_id = $1
  AND cie.intent_ts >= NOW() - INTERVAL '30 days'
GROUP BY cie.signal_type;
```

## Next Steps

1. Review and approve this audit
2. Implement Priority 1 fixes (episode filtering)
3. Create Supabase connection utilities
4. Migrate each API one at a time from mock → Supabase
5. Add comprehensive error handling
6. Add caching layer for performance
