# Episode Classification API

## Overview

The Episode Classification API is a dedicated service that maps clinical codes (CPT, ICD-10, NDC, etc.) to episodes of care. This API is used for:

1. **Clinical Forecasting** - Identify intent signals and predict upcoming procedures
2. **Care Navigation** - Help members shop for procedures and get cost estimates
3. **Claims Processing** - Automatically classify claims to episode bundles
4. **Prior Authorization** - Route PA requests based on episode type

## Architecture

### Database-Driven Rules
All code mappings are stored in the `episode_code_mapping` table, not hardcoded. This allows:
- Client-specific customization
- Real-time rule updates without deployment
- Version control and audit trails
- A/B testing different rule sets

### Scale Considerations
- **Composite indexes** on (code_type, code_value, client_id) for O(log n) lookups
- **Caching ready** - Results can be cached in Redis for sub-10ms response
- **Batch support** - Can process 100+ claims per request (future)
- **Query optimization** - Single database query fetches all matches

## API Endpoint

```
POST /api/rules/classify-episode
```

### Request Body

```json
{
  "diagnosis_codes": ["M17.11", "M17.12"],
  "procedure_codes": ["27447"],
  "ndc_codes": [],
  "revenue_codes": [],
  "context": {
    "member_id": "M00001",
    "service_date": "2024-12-20",
    "provider_specialty": "Orthopedic Surgery",
    "client_id": "default"
  }
}
```

### Response

```json
{
  "episode_id": "TKA",
  "episode_name": "Total Knee Replacement",
  "confidence_score": 95,
  "matched_codes": [
    {
      "code_type": "CPT",
      "code_value": "27447",
      "signal_strength": 90.0,
      "is_primary": true
    },
    {
      "code_type": "ICD10",
      "code_value": "M17.11",
      "signal_strength": 60.0,
      "is_primary": false
    }
  ],
  "reasoning": [
    "Matched 2 code(s) to Total Knee Replacement",
    "1 primary code match(es) found",
    "Procedure code(s): 27447",
    "Diagnosis code(s): M17.11"
  ]
}
```

## Classification Logic

### Scoring Algorithm

1. **Base Signal Strength** - Each code has a signal_strength (0-100)
2. **Primary Code Boost** - Primary codes get 1.5x multiplier
3. **Procedure Code Boost** - CPT codes get additional 1.3x multiplier
4. **Normalization** - Score divided by sqrt(match_count) to avoid over-counting
5. **Confidence** - Final score converted to 0-100 confidence percentage

### Example Scoring

```
CPT 27447 (primary): 90 × 1.5 × 1.3 = 175.5
ICD10 M17.11: 60 × 1.0 = 60.0
Total: 235.5
Normalized: 235.5 / sqrt(2) = 166.5
Confidence: min(100, 166.5 / 2) = 83%
```

## Use Cases

### 1. Clinical Forecasting (Current)
```typescript
// Classify prior auth request
const result = await fetch('/api/rules/classify-episode', {
  method: 'POST',
  body: JSON.stringify({
    procedure_codes: ['27447'],
    diagnosis_codes: ['M17.11'],
    context: { member_id: 'M00001' }
  })
})
```

### 2. Care Navigation (Future)
```typescript
// Member shops for knee replacement
const result = await fetch('/api/rules/classify-episode', {
  method: 'POST',
  body: JSON.stringify({
    procedure_codes: ['27447'],
    context: { 
      member_id: 'M00001',
      estimate_type: 'cost_transparency'
    }
  })
})

// Use episode_id to fetch:
// - Network providers
// - Cost estimates (low/avg/high)
// - Quality ratings
// - Bundle pricing
```

### 3. Claims Auto-Adjudication (Future)
```typescript
// Classify incoming claim to episode bundle
const result = await fetch('/api/rules/classify-episode', {
  method: 'POST',
  body: JSON.stringify({
    procedure_codes: claim.procedures,
    diagnosis_codes: claim.diagnoses,
    context: { 
      member_id: claim.member_id,
      service_date: claim.service_date
    }
  })
})

// Apply episode-based pricing rules
if (result.episode_id === 'TKA') {
  applyBundlePayment(claim, result.episode_id)
}
```

## Admin UI

A simple admin interface allows managing code mappings without code deployment:

- View all episode-to-code mappings
- Add/edit/remove code mappings
- Set signal strength and primary flags
- Preview classification results
- Export/import rule sets for clients

## Performance at Scale

### 5M Lives Considerations

**Single Classification:**
- Database query: ~5-10ms (with indexes)
- Scoring logic: ~1-2ms
- Total: **< 15ms per request**

**With Caching (Redis):**
- Cache hit: ~1-2ms
- Cache miss: 15ms (then cached)
- Cache TTL: 1 hour (rules don't change often)
- **99% of requests: < 5ms**

**Batch Processing:**
- 100 claims per request
- Single DB query with IN clause
- Score all episodes in memory
- Total: **< 50ms for 100 classifications**

### Scaling Strategy

1. **Phase 1 (Now):** Direct Supabase queries
2. **Phase 2 (10K+ req/day):** Add Redis caching layer
3. **Phase 3 (100K+ req/day):** Read replicas + connection pooling
4. **Phase 4 (1M+ req/day):** Event-driven async processing (Vercel Queues)

## Future Enhancements

- **ML-based classification** - Train model on historical data
- **Multi-episode detection** - Return top 3 matches with probabilities
- **Temporal rules** - Different mappings based on service date
- **Regional variations** - State-specific episode definitions
- **Provider specialty weighting** - Boost confidence based on provider type
