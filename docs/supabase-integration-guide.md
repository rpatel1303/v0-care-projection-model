# Supabase Integration Guide

## Overview
This guide explains how to integrate the Clinical Forecasting Engine with Supabase for production-ready data storage and real-time capabilities.

## Why Supabase?
- **PostgreSQL-based**: Full SQL support with our existing schema
- **Real-time subscriptions**: Live updates when new signals or predictions arrive
- **Row Level Security (RLS)**: Secure multi-tenant data access
- **Built-in Auth**: User authentication for dashboard access
- **REST & GraphQL APIs**: Auto-generated APIs for all tables
- **Edge Functions**: Serverless functions for ETL and ML scoring

## Setup Steps

### 1. Create Supabase Project
1. Go to [supabase.com](https://supabase.com)
2. Create a new project
3. Save your project URL and anon key
4. Note your database connection string

### 2. Environment Variables
Add to your Vercel project:
```bash
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
DATABASE_URL=postgresql://postgres:[password]@db.[project].supabase.co:5432/postgres
```

### 3. Run Schema Migration
Execute the SQL scripts in Supabase SQL Editor:
1. Run `scripts/01-create-tables.sql`
2. Run `scripts/02-seed-service-category-map.sql`
3. Run `scripts/03-seed-sample-data.sql`
4. Run `scripts/04-seed-expanded-sample-data.sql`

### 4. Set Up Row Level Security (RLS)

```sql
-- Enable RLS on all tables
ALTER TABLE member ENABLE ROW LEVEL SECURITY;
ALTER TABLE eligibility_inquiry_event ENABLE ROW LEVEL SECURITY;
ALTER TABLE prior_auth_request ENABLE ROW LEVEL SECURITY;
ALTER TABLE claim_header ENABLE ROW LEVEL SECURITY;
ALTER TABLE claim_line ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical_intent_event ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical_outcome_event ENABLE ROW LEVEL SECURITY;
ALTER TABLE prediction_result ENABLE ROW LEVEL SECURITY;

-- Create policies for authenticated users
-- Example: Users can only see their organization's data
CREATE POLICY "Users see own org data" ON member
  FOR SELECT
  USING (auth.jwt() ->> 'org_id' = plan_id);

-- Service role can see all
CREATE POLICY "Service role full access" ON member
  FOR ALL
  USING (auth.role() = 'service_role');

-- Repeat for other tables...
```

### 5. Create Supabase Client

```typescript
// lib/supabase.ts
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

// For server-side operations with elevated privileges
export const supabaseAdmin = createClient(
  supabaseUrl,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
)
```

### 6. Update API Routes to Use Supabase

```typescript
// app/api/dashboard/summary/route.ts
import { supabaseAdmin } from '@/lib/supabase'

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const period = searchParams.get('period') || '90'
  const region = searchParams.get('region')
  const network = searchParams.get('network')
  const planType = searchParams.get('planType')

  // Build query with filters
  let query = supabaseAdmin
    .from('prediction_result')
    .select('*, member(*)')
    .eq('event_type', 'tka')
    .gte('probability', 0.70)

  if (region) {
    query = query.eq('member.state', region)
  }

  const { data, error } = await query

  if (error) {
    return Response.json({ error: error.message }, { status: 500 })
  }

  // Process and return summary metrics
  const summary = {
    totalPredictions: data.length,
    highRisk: data.filter(p => p.probability >= 0.90).length,
    estimatedCost: data.reduce((sum, p) => sum + 35000, 0),
    // ... more calculations
  }

  return Response.json(summary)
}
```

### 7. Real-Time Updates (Optional)

```typescript
// components/executive-dashboard.tsx
import { supabase } from '@/lib/supabase'
import { useEffect } from 'react'

export function ExecutiveDashboard() {
  const [predictions, setPredictions] = useState([])

  useEffect(() => {
    // Subscribe to new predictions
    const subscription = supabase
      .channel('predictions')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'prediction_result'
        },
        (payload) => {
          console.log('[v0] New prediction received:', payload)
          // Update state with new prediction
          setPredictions(prev => [...prev, payload.new])
        }
      )
      .subscribe()

    return () => {
      subscription.unsubscribe()
    }
  }, [])

  // ... rest of component
}
```

## Data Flow with Supabase

```
Source Systems (EDI Gateway, PA System, Claims)
              ↓
    Supabase Edge Functions (ETL)
              ↓
    Supabase PostgreSQL Tables
              ↓
    Real-time Subscriptions
              ↓
    Next.js Dashboard Components
```

## ETL Pipeline with Edge Functions

Create Edge Functions for data ingestion:

```typescript
// supabase/functions/ingest-270-271/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  const { transaction } = await req.json()

  // Parse 270/271 EDI transaction
  const eligibilityEvent = parseEDI270(transaction)

  // Insert into database
  const { data, error } = await supabase
    .from('eligibility_inquiry_event')
    .insert(eligibilityEvent)
    .select()

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500
    })
  }

  // Create clinical intent event
  const intentEvent = {
    intent_ts: new Date().toISOString(),
    member_id: eligibilityEvent.member_id,
    provider_npi: eligibilityEvent.provider_npi,
    signal_type: 'elig',
    service_category: 'ortho_knee',
    codes: eligibilityEvent.service_type_codes,
    signal_strength: calculateSignalStrength(eligibilityEvent),
    source_system: 'edi_gateway',
    source_record_id: data[0].inquiry_id
  }

  await supabase.from('clinical_intent_event').insert(intentEvent)

  return new Response(JSON.stringify({ success: true, data }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

## Best Practices

1. **Use Service Role for API Routes**: Server-side operations need elevated privileges
2. **Enable RLS for Multi-Tenancy**: If multiple payers/organizations use the system
3. **Index Heavily Queried Fields**: Add indexes for filters (state, network, plan_id)
4. **Use Views for Complex Queries**: Create database views for dashboard metrics
5. **Implement Caching**: Use Redis or Supabase caching for frequently accessed data
6. **Monitor Performance**: Use Supabase's built-in monitoring and logging

## Migration from Mock Data

Current API routes return mock data. To migrate:
1. Replace mock data responses with Supabase queries
2. Update TypeScript interfaces to match database schema
3. Test each endpoint with real data
4. Deploy incrementally (one endpoint at a time)

## Next Steps
1. Set up Supabase project
2. Run schema migrations
3. Update one API route as proof of concept
4. Test with dashboard
5. Migrate remaining routes
6. Add authentication
7. Implement real-time features
