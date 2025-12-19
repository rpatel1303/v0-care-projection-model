# 278 EDI Transaction: Referral vs Prior Authorization Specification

## Overview

The **X12 278 Health Care Services Review** transaction serves as the container for **BOTH referrals AND prior authorizations**. The distinction between these two use cases is determined by specific data elements within the transaction, NOT by using different transaction sets.

This document provides authoritative guidance on how to properly distinguish referrals from prior authorizations based on X12 standards and real-world payer implementation patterns.

---

## Key Distinction: Same Envelope, Different Content

```
278 Transaction
├── Referral Request (consultation, specialist visit)
└── Prior Authorization Request (procedure, high-cost service)
```

**Both use:**
- Same EDI transaction set (278)
- Same segment structure
- Same data elements

**Differ by:**
- Service Type Codes
- Procedure code presence/detail
- Certification type
- Provider relationships

---

## Service Type Codes (UM01)

The **UM segment** (Health Care Services Review Information) contains the critical `UM01` element that identifies the type of service being requested.

### Referral Service Type Codes

Based on X12 standards and industry practice, referrals typically use:

| Code | Description | Usage Context |
|------|-------------|---------------|
| **3** | **Consultation** | Most common for referrals - specialist evaluation |
| **BY** | **Physician Visit - Sick** | PCP referring for specialist sick visit |
| **BZ** | **Physician Visit - Well** | Referral for wellness/preventive visit |
| **1** | **Medical Care** | General medical referral (less specific) |

### Prior Authorization Service Type Codes

Prior authorizations typically use procedure-specific codes:

| Code | Description | Usage Context |
|------|-------------|---------------|
| **2** | **Surgical** | Surgical procedures requiring PA |
| **4** | **Diagnostic X-Ray** | Imaging procedures |
| **5** | **Diagnostic Lab** | Lab services |
| **6** | **Radiation Therapy** | Oncology treatments |
| **11-18** | **DME (various)** | Durable medical equipment |
| **42** | **Home Health Care** | Home health services |
| **47** | **Hospitalization** | Inpatient admissions |
| **54** | **Long Term Care** | LTC facility admissions |
| **62** | **MRI Scan** | Advanced imaging |
| **70** | **Transplants** | Organ transplants |
| **BK** | **Orthopedic** | Orthopedic procedures (e.g., knee replacement) |
| **BL** | **Cardiac** | Cardiac procedures (e.g., CABG, PCI) |

---

## Certification Type Qualifier (UM02)

The `UM02` element specifies the type of certification/review being requested:

### Referral Values
- **I** = Initial (most common for referrals - first time referral)
- **R** = Renewal (extending existing referral)

### Prior Authorization Values
- **I** = Initial (first PA request for this service)
- **R** = Renewal/Extension (extending approved PA)
- **S** = Revised (changing previously approved PA)

---

## Procedure Code Presence

### Referrals
**Characteristics:**
- **Minimal or NO CPT codes** in SV1/SV2 segments
- May include evaluation/management codes (99201-99215)
- Focus on "see specialist" not "perform procedure"
- Often just diagnosis codes in HI segment

**Example:**
```
UM*HS*I*3::::3*RQ~  (Service Type 3 = Consultation)
HI*BK:M17.11~       (Diagnosis: Knee osteoarthritis)
[NO SV1 segment or generic E/M code]
```

### Prior Authorizations
**Characteristics:**
- **Specific CPT/HCPCS codes** required
- Detailed procedure information
- May include multiple procedure codes
- Often includes facility/place of service details

**Example:**
```
UM*HS*I*BK::::BK*RQ~  (Service Type BK = Orthopedic)
HI*BK:M17.11~         (Diagnosis)
SV1*HC:27447*5400*UN*1**1~  (CPT 27447 = Total Knee Replacement, $5,400)
```

---

## Provider Relationships

### Referrals
**2010EA Loop (Patient Event Provider) contains:**
- **Referring Provider** (NM101 = RF)
- **Referred-to Provider** (NM101 = SJ or DN)
- Provider specialty codes indicating consulting physician
- Minimal clinical detail

**Example:**
```
NM1*RF*1*SMITH*JOHN****XX*1234567890~  (Referring PCP)
NM1*SJ*1*ROBERTS*DAVID****XX*9876543210~  (Referred-to Orthopedic Surgeon)
REF*1G*BK~  (Specialty: Orthopedic)
```

### Prior Authorizations
**2010EA Loop contains:**
- **Servicing Provider** (NM101 = SJ)
- **Facility** (NM101 = 77 for service location)
- Detailed provider taxonomy
- May include rendering, billing, and facility providers

---

## Typical Payer Routing Logic

Real-world payers use decision trees to route 278 transactions:

```
Inbound 278 Transaction
│
├── If UM01 in [3, BY, BZ] AND minimal CPT detail
│   └── Route to → Referral Management System
│
├── If UM01 in [2, 4-8, BK, BL] OR specific CPT/HCPCS present
│   └── Route to → Utilization Management / Prior Auth System
│
└── If ambiguous
    └── Apply plan-specific business rules
```

---

## Sample 278 Referral Transaction

### Real-World Referral Request

```
ST*278*0001*005010X217~
BHT*0007*13*REF001*20241215*1023~
HL*1**20*1~
NM1*X3*2*NORTHEAST HEALTH PLAN*****PI*NEHP001~
HL*2*1*21*1~
NM1*1P*1*SMITH*JOHN****XX*1234567890~  (Requesting PCP)
HL*3*2*22*0~
NM1*IL*1*JOHNSON*MARY****MI*M00001~  (Member)
HL*4*3*EV*1~
UM*HS*I*3::::3*RQ~  ← Service Type 3 = Consultation
HI*BK:M17.11~  ← Diagnosis: Knee OA
DTP*472*RD8*20250101-20250430~  ← Date range for referral
HL*5*4*SS*0~
NM1*SJ*1*ROBERTS*DAVID****XX*9876543210~  ← Referred-to Specialist
REF*1G*BK~  ← Specialty: Orthopedic
SE*24*0001~
```

**Key Indicators of Referral:**
✓ Service Type = 3 (Consultation)  
✓ No CPT codes  
✓ Referred-to provider (SJ) specified  
✓ Date range for validity  

---

## Sample 278 Prior Authorization Transaction

### Real-World PA Request for Total Knee Replacement

```
ST*278*0002*005010X217~
BHT*0007*13*PA001*20241215*1045~
HL*1**20*1~
NM1*X3*2*NORTHEAST HEALTH PLAN*****PI*NEHP001~
HL*2*1*21*1~
NM1*1P*1*ROBERTS*DAVID****XX*9876543210~  (Servicing Provider)
HL*3*2*22*0~
NM1*IL*1*JOHNSON*MARY****MI*M00001~  (Member)
HL*4*3*EV*1~
UM*HS*I*BK::::BK*RQ~  ← Service Type BK = Orthopedic
HI*BK:M17.11~  ← Primary Diagnosis
DTP*472*D8*20250115~  ← Proposed service date
HL*5*4*SS*0~
SV1*HC:27447*5400*UN*1**1~  ← CPT 27447 = TKA, $5,400
HSD*VS*30~  ← Visit count
SE*22*0002~
```

**Key Indicators of Prior Auth:**
✓ Service Type = BK (Orthopedic procedure)  
✓ Specific CPT code (27447)  
✓ Cost estimate  
✓ Specific service date  

---

## Implementation Guidance for Clinical Forecasting Engine

### Referral Classification Logic

```python
def is_referral(transaction_278):
    """
    Classify 278 transaction as referral vs prior auth
    """
    service_type = transaction_278.UM01
    has_cpt = bool(transaction_278.SV1 or transaction_278.SV2)
    has_referred_to_provider = transaction_278.has_provider_type('SJ')
    
    # Referral indicators
    referral_service_types = ['3', 'BY', 'BZ', '1']
    
    if service_type in referral_service_types and not has_cpt:
        return 'REFERRAL'
    elif service_type not in referral_service_types and has_cpt:
        return 'PRIOR_AUTH'
    else:
        # Ambiguous - use secondary rules
        if has_referred_to_provider and not has_cpt:
            return 'REFERRAL'
        else:
            return 'PRIOR_AUTH'
```

### Intent Signal Strength

**For Forecasting Model:**

| Signal Type | Service Type | Signal Strength | Reasoning |
|-------------|--------------|-----------------|-----------|
| Referral to Orthopedic Surgeon | 3, BY | Medium (0.6) | Indicates evaluation for potential surgery |
| PA Request for TKA | BK | Very High (0.95) | Strong intent, procedure identified |
| Eligibility Check for Orthopedic | N/A | Low (0.3) | Early stage inquiry |
| Rx Benefit Check for NSAIDs | N/A | Medium (0.5) | Conservative treatment before surgery |

---

## Sources

- **X12 005010X217 Implementation Guide** - Official 278 Transaction Set
- **CMS esMD X12N 278 Companion Guide** - Medicare implementation
- **X12 External Code Lists** - Service Type Codes (x12.org)
- **HL7 Terminology** - Healthcare Service Type Code System
- **Real-world payer implementations** - Based on industry patterns

---

## Related Documents

- `sample-data/278-referral-requests.edi` - Sample referral transactions
- `sample-data/278-prior-auth-requests.edi` - Sample PA transactions  
- `scripts/edi_loader/parsers/parse_278.py` - Parser implementation
- `docs/edi-integration-architecture.md` - Full EDI integration guide

---

*Last Updated: December 2024*
*Version: 1.0*
