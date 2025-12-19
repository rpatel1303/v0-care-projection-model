# Complete Mock Data Audit Report
**Generated**: 2024-12-19
**Status**: All APIs using hardcoded mock data

## Executive Summary

**Finding**: All 5 dashboard API endpoints accept `episodeId` and filter parameters correctly, but **NONE** query the actual Supabase database. They all return hardcoded mock data.

## Detailed Findings

### 1. `/api/dashboard/summary` ❌
**File**: `app/api/dashboard/summary/route.ts`
**Parameters Accepted**: ✅ episodeId, timeHorizon, region, network, planType
**Data Source**: ❌ Hardcoded `episodeMetrics` object (lines 12-136)
**Impact**: HIGH - Drives all metric cards (Predicted Volume, Projected Cost, Intent Signals, Model Accuracy)

### 2. `/api/dashboard/forecast` ❌
**File**: `app/api/dashboard/forecast/route.ts`
**Parameters Accepted**: ✅ episodeId, region, network, planType
**Data Source**: ❌ Hardcoded `forecastData` object (lines 13-54)
**Impact**: HIGH - Drives volume forecast chart (main visualization)

### 3. `/api/dashboard/cost-projection` ❌
**File**: `app/api/dashboard/cost-projection/route.ts`
**Parameters Accepted**: ✅ episodeId
**Data Source**: ❌ Hardcoded `costDataByEpisode` object (lines 12-31)
**Impact**: HIGH - Drives cost exposure chart

### 4. `/api/dashboard/members` ❌
**File**: `app/api/dashboard/members/route.ts`
**Parameters Accepted**: ✅ episodeId
**Data Source**: ❌ Hardcoded `membersByEpisode` object (lines 19-152)
**Impact**: MEDIUM - Drives high-risk members table

### 5. `/api/dashboard/signals` ❌
**File**: `app/api/dashboard/signals/route.ts`
**Parameters Accepted**: ✅ episodeId
**Data Source**: ❌ Hardcoded `signalsByEpisode` object (lines 14-69)
**Impact**: MEDIUM - Drives intent signals breakdown

## What's Working

✅ Episode selector passes episodeId to all components
✅ All APIs accept episodeId parameter
✅ All APIs have different hardcoded data per episode (TKA, THA, CABG, SPINE_FUSION)
✅ UI updates when switching episodes (because mock data differs per episode)
✅ Supabase integration is connected
✅ Database schema exists with proper tables

## What's NOT Working

❌ No API queries Supabase database
❌ Filters (region, network, planType) are accepted but ignored
❌ No connection between EDI data and dashboard
❌ Sample EDI files are loaded into Supabase but never queried
❌ Episode classification API exists but is not used by dashboard

## Root Cause

The application was built with a **functional prototype using mock data** to demonstrate the UX and filtering behavior. The database integration was added but never connected to the frontend APIs.

## Impact on 5M Lives Scale

This architecture will **NOT scale** because:
- No database queries = No real data processing
- No connection pooling considerations
- No query optimization
- No caching strategy
- No batch processing capabilities

## Remediation Plan

### Phase 1: Connect to Real Data (Priority 1)

Replace all hardcoded mock data with Supabase queries:

1. **Summary API** - Query aggregated metrics from database
2. **Forecast API** - Query claims and intent signals to generate forecast
3. **Cost Projection API** - Calculate costs from actual claims data
4. **Members API** - Query members with high intent scores
5. **Signals API** - Query and count actual intent signal events

### Phase 2: Implement Filters (Priority 2)

Apply region/network/planType filters to all SQL queries:

```sql
WHERE episode_id = $1 
  AND (region_code = $2 OR $2 = 'all')
  AND (network_tier = $3 OR $3 = 'all')
  AND (plan_type = $4 OR $4 = 'all')
```

### Phase 3: Performance Optimization (Priority 3)

- Add connection pooling (pgBouncer via Supabase)
- Implement Redis caching for frequently accessed data
- Create materialized views for aggregated metrics
- Add database indexes on filter columns

## Recommended Immediate Action

**Option A: Full Database Integration** (2-3 days)
- Replace all mock data with real Supabase queries
- Implement proper error handling
- Add loading states
- Most production-ready

**Option B: Hybrid Approach** (1 day)
- Keep mock data as fallback
- Add console warnings when using mock data
- Implement 1-2 APIs with real data as proof of concept
- Allows incremental migration

**Option C: Demo Mode Flag** (2 hours)
- Add `DEMO_MODE=true` environment variable
- If demo mode, use mock data
- If production mode, require Supabase connection
- Clear separation of concerns

## Recommendation

For a **5M lives production system**, I recommend **Option A: Full Database Integration**.

The current mock data approach is excellent for prototyping but must be replaced with real database queries before any production deployment.

---

## Next Steps

Would you like me to:

1. **Start implementing Option A** - Replace mock data with Supabase queries systematically
2. **Implement Option C first** - Add demo mode flag, then work on real data
3. **Create detailed SQL query templates** - Document exact queries needed for each API
4. **Build a data seeding script** - Generate realistic sample data in Supabase for testing

Let me know which path you'd like to take.
