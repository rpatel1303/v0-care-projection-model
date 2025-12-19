#!/usr/bin/env python3
"""
EDI Loader for Clinical Forecasting Engine
Parses EDI files and loads data into Supabase

Usage:
  python load_to_supabase.py
"""

import os
import sys
sys.path.insert(0, os.path.dirname(__file__))

import json
import re
from datetime import datetime, timedelta
import random
from parsers import parse_270_271, parse_278, parse_837, parse_rx_benefit

try:
    from supabase import create_client, Client
except ImportError:
    print("Error: supabase-py library not installed")
    print("Install it with: pip install supabase")
    sys.exit(1)

# ============================================================================
# PARSER FUNCTIONS (Inlined for v0 compatibility)
# ============================================================================

def parse_edi_datetime(date_str: str, time_str: str) -> str:
    """Convert EDI date/time to ISO format"""
    try:
        if len(date_str) == 8:
            dt = datetime.strptime(date_str, '%Y%m%d')
        elif len(date_str) == 6:
            dt = datetime.strptime(date_str, '%y%m%d')
        else:
            return None
        
        if time_str and len(time_str) >= 4:
            hour = int(time_str[:2])
            minute = int(time_str[2:4])
            dt = dt.replace(hour=hour, minute=minute)
        
        return dt.isoformat()
    except:
        return None

def parse_edi_date(date_str: str) -> str:
    """Convert EDI date to ISO format"""
    try:
        if '-' in date_str:
            date_str = date_str.split('-')[0]
        
        if len(date_str) == 8:
            return datetime.strptime(date_str, '%Y%m%d').date().isoformat()
        elif len(date_str) == 6:
            return datetime.strptime(date_str, '%y%m%d').date().isoformat()
    except:
        return None

def parse_270_271(file_path: str):
    """Parse 270/271 EDI eligibility inquiries"""
    inquiries = []
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    transactions = re.findall(r'ST\*270.*?SE\*\d+\*\d+~', content, re.DOTALL)
    
    for transaction in transactions:
        segments = transaction.split('~')
        
        inquiry = {
            'inquiry_date': None,
            'member_id': None,
            'provider_npi': None,
            'service_type_codes': [],
            'coverage_status': 'unknown'
        }
        
        for segment in segments:
            fields = segment.split('*')
            if not fields:
                continue
                
            segment_id = fields[0]
            
            if segment_id == 'BHT' and len(fields) >= 5:
                date_str = fields[4]
                time_str = fields[5] if len(fields) > 5 else '0000'
                inquiry['inquiry_date'] = parse_edi_datetime(date_str, time_str)
            
            elif segment_id == 'NM1' and len(fields) >= 3:
                entity_type = fields[1]
                if entity_type == 'IL' and len(fields) >= 9:
                    inquiry['member_id'] = fields[9]
                elif entity_type in ['1P', '2B'] and len(fields) >= 9:
                    inquiry['provider_npi'] = fields[9]
            
            elif segment_id == 'EQ' and len(fields) >= 2:
                inquiry['service_type_codes'].append(fields[1])
        
        if inquiry['member_id']:
            inquiries.append(inquiry)
    
    return inquiries

def parse_278(file_path: str):
    """Parse 278 EDI prior authorization requests"""
    prior_auths = []
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    transactions = re.findall(r'ST\*278.*?SE\*\d+\*\d+~', content, re.DOTALL)
    
    for transaction in transactions:
        segments = transaction.split('~')
        
        pa = {
            'auth_number': None,
            'request_date': None,
            'member_id': None,
            'requesting_provider_npi': None,
            'procedure_codes': [],
            'diagnosis_codes': [],
            'request_category': 'HS',  # Health Services Review
            'status': 'pending'
        }
        
        for segment in segments:
            fields = segment.split('*')
            if not fields:
                continue
                
            segment_id = fields[0]
            
            if segment_id == 'BHT' and len(fields) >= 4:
                pa['auth_number'] = fields[3]
                if len(fields) >= 5:
                    date_str = fields[4]
                    time_str = fields[5] if len(fields) > 5 else '0000'
                    pa['request_date'] = parse_edi_datetime(date_str, time_str)
            
            elif segment_id == 'UM' and len(fields) >= 2:
                pa['request_category'] = fields[1]  # AR=Referral, HS=Prior Auth
            
            elif segment_id == 'NM1' and len(fields) >= 3:
                entity_type = fields[1]
                if entity_type == 'IL' and len(fields) >= 9:
                    pa['member_id'] = fields[9]
                elif entity_type == '1P' and len(fields) >= 9:
                    pa['requesting_provider_npi'] = fields[9]
            
            elif segment_id == 'HI':
                for i in range(1, len(fields)):
                    if ':' in fields[i]:
                        code = fields[i].split(':')[1]
                        pa['diagnosis_codes'].append(code)
            
            elif segment_id == 'SV2' and len(fields) >= 2:
                if ':' in fields[1]:
                    proc_code = fields[1].split(':')[1]
                    pa['procedure_codes'].append(proc_code)
        
        if pa['member_id'] and pa['auth_number']:
            prior_auths.append(pa)
    
    return prior_auths

def parse_837(file_path: str):
    """Parse 837 EDI claims"""
    headers = []
    lines = []
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    claims = re.findall(r'CLM\*.*?(?=CLM\*|SE\*)', content, re.DOTALL)
    
    for claim_text in claims:
        segments = claim_text.split('~')
        
        header = {
            'claim_id': None,
            'member_id': None,
            'claim_type': 'institutional',
            'service_from_date': None,
            'service_to_date': None,
            'billing_provider_npi': None,
            'total_billed': 0,
            'total_paid': 0
        }
        
        line_num = 0
        
        for segment in segments:
            fields = segment.split('*')
            if not fields:
                continue
                
            segment_id = fields[0]
            
            if segment_id == 'CLM' and len(fields) >= 3:
                header['claim_id'] = fields[1]
                header['total_billed'] = float(fields[2]) if fields[2] else 0
            
            elif segment_id == 'DTP' and len(fields) >= 3:
                date_qualifier = fields[1]
                if date_qualifier == '434':
                    header['service_from_date'] = parse_edi_date(fields[3])
                elif date_qualifier == '435':
                    header['service_to_date'] = parse_edi_date(fields[3])
            
            elif segment_id == 'NM1' and len(fields) >= 3:
                entity_type = fields[1]
                if entity_type == 'IL' and len(fields) >= 9:
                    header['member_id'] = fields[9]
                elif entity_type == '85' and len(fields) >= 9:
                    header['billing_provider_npi'] = fields[9]
            
            elif segment_id in ['SV1', 'SV2']:
                line_num += 1
                line = {
                    'claim_id': header['claim_id'],
                    'line_number': line_num,
                    'procedure_code': None,
                    'service_date': header['service_from_date'],
                    'billed_amount': 0
                }
                
                if segment_id == 'SV1' and len(fields) >= 2:
                    if ':' in fields[1]:
                        line['procedure_code'] = fields[1].split(':')[1]
                    if len(fields) >= 3:
                        line['billed_amount'] = float(fields[2]) if fields[2] else 0
                
                elif segment_id == 'SV2' and len(fields) >= 3:
                    if ':' in fields[2]:
                        line['procedure_code'] = fields[2].split(':')[1]
                    if len(fields) >= 4:
                        line['billed_amount'] = float(fields[3]) if fields[3] else 0
                
                lines.append(line)
        
        if header['claim_id'] and header['member_id']:
            headers.append(header)
    
    return {'headers': headers, 'lines': lines}

def parse_rx_benefit(file_path: str):
    """Parse Rx benefit inquiry JSON"""
    with open(file_path, 'r') as f:
        data = json.load(f)
    return data.get('inquiries', [])

# ============================================================================
# DATA LOADING FUNCTIONS
# ============================================================================

def get_supabase_client() -> Client:
    """Initialize Supabase client"""
    url = os.environ.get("CFE_PUBLIC_SUPABASE_URL") or os.environ.get("SUPABASE_URL") or os.environ.get("NEXT_PUBLIC_SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("CFE_PUBLIC_SUPABASE_ANON_KEY") or os.environ.get("SUPABASE_ANON_KEY")
    
    if not url or not key:
        raise ValueError("Missing Supabase credentials. Set CFE_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables")
    
    return create_client(url, key)

def load_members(supabase: Client):
    """Load member data from JSON file"""
    print("\n[1/7] Loading member demographics...")
    
    with open('sample-data/members.json') as f:
        members_data = json.load(f)
    
    members = []
    chronic_conditions = []
    
    for member in members_data:
        # Prepare member record
        member_record = {
            'member_id': member['member_id'],
            'first_name': member['first_name'],
            'last_name': member['last_name'],
            'date_of_birth': member['date_of_birth'],
            'gender': member['gender'],
            'address_street': member.get('address', {}).get('street'),
            'address_city': member.get('address', {}).get('city'),
            'address_state': member.get('address', {}).get('state'),
            'address_zip': member.get('address', {}).get('zip_code'),
            'phone': member.get('phone'),
            'email': member.get('email'),
            'plan_type': member['plan_type'],
            'network': member['network'],
            'geographic_region': member['geographic_region'],
            'enrollment_date': member['enrollment_date'],
            'enrollment_status': member['enrollment_status'],
            'termination_date': member.get('termination_date'),
            'pcp_npi': member.get('primary_care_provider', {}).get('npi'),
            'pcp_name': member.get('primary_care_provider', {}).get('name'),
            'pcp_specialty': member.get('primary_care_provider', {}).get('specialty'),
            'risk_score': member.get('risk_score'),
            'hcc_score': member.get('hcc_score')
        }
        members.append(member_record)
        
        # Prepare chronic conditions
        for condition in member.get('chronic_conditions', []):
            chronic_conditions.append({
                'member_id': member['member_id'],
                'icd10_code': condition['icd10_code'],
                'description': condition['description'],
                'diagnosis_date': condition['diagnosis_date']
            })
    
    # Insert members
    result = supabase.table('member').upsert(members).execute()
    print(f"  ✓ Loaded {len(members)} members")
    
    # Insert chronic conditions
    if chronic_conditions:
        result = supabase.table('member_chronic_condition').upsert(chronic_conditions).execute()
        print(f"  ✓ Loaded {len(chronic_conditions)} chronic conditions")

def load_eligibility_inquiries(supabase: Client):
    """Parse 270/271 EDI files and load eligibility inquiries"""
    print("\n[2/7] Loading eligibility inquiries (270/271)...")
    
    file_path = 'sample-data/270-eligibility-requests.edi'
    if not os.path.exists(file_path):
        print(f"  ⚠ File not found: {file_path}, skipping...")
        return
    
    inquiries = parse_270_271(file_path)
    
    if inquiries:
        result = supabase.table('eligibility_inquiry_event').upsert(inquiries).execute()
        print(f"  ✓ Loaded {len(inquiries)} eligibility inquiries")

def load_prior_auths(supabase: Client):
    """Parse 278 EDI files and load prior authorization requests"""
    print("\n[3/7] Loading prior authorizations (278)...")
    
    file_path = 'sample-data/278-prior-auth-requests.edi'
    if not os.path.exists(file_path):
        print(f"  ⚠ File not found: {file_path}, skipping...")
        return
    
    prior_auths = parse_278(file_path)
    
    if prior_auths:
        result = supabase.table('prior_auth_request').upsert(prior_auths).execute()
        print(f"  ✓ Loaded {len(prior_auths)} prior authorization requests")

def load_rx_benefit_inquiries(supabase: Client):
    """Parse Rx benefit inquiry JSON and load pharmacy benefit checks"""
    print("\n[4/7] Loading Rx benefit inquiries...")
    
    file_path = 'sample-data/rx-benefit-inquiries.json'
    if not os.path.exists(file_path):
        print(f"  ⚠ File not found: {file_path}, skipping...")
        return
    
    inquiries = parse_rx_benefit(file_path)
    
    if inquiries:
        result = supabase.table('rx_benefit_inquiry').upsert(inquiries).execute()
        print(f"  ✓ Loaded {len(inquiries)} Rx benefit inquiries")

def load_claims(supabase: Client):
    """Parse 837 EDI files and load claims"""
    print("\n[5/7] Loading claims (837)...")
    
    file_path = 'sample-data/837I-institutional-claims.edi'
    if not os.path.exists(file_path):
        print(f"  ⚠ File not found: {file_path}, skipping...")
        return
    
    claims_data = parse_837(file_path)
    
    if claims_data:
        headers = claims_data['headers']
        lines = claims_data['lines']
        
        result = supabase.table('claim_header').upsert(headers).execute()
        print(f"  ✓ Loaded {len(headers)} claim headers")
        
        if lines:
            result = supabase.table('claim_line').upsert(lines).execute()
            print(f"  ✓ Loaded {len(lines)} claim lines")

def generate_intent_events(supabase: Client):
    """Generate clinical intent events from eligibility and PA data"""
    print("\n[6/7] Generating clinical intent events...")
    
    # Fetch eligibility inquiries
    elig_result = supabase.table('eligibility_inquiry_event').select('*').execute()
    eligibility_inquiries = elig_result.data or []
    
    # Fetch prior auths
    pa_result = supabase.table('prior_auth_request').select('*').execute()
    prior_auths = pa_result.data or []
    
    # Fetch referrals (278 transactions with referral type)
    referral_result = supabase.table('prior_auth_request').select('*').eq('request_category', 'AR').execute()
    referrals = referral_result.data or []
    
    intent_events = []
    
    # Create intent events from eligibility inquiries
    for elig in eligibility_inquiries:
        intent_events.append({
            'member_id': elig.get('member_id'),
            'episode_id': elig.get('episode_id', 'TKA'),  # Default to TKA for demo
            'event_type': 'eligibility_check',
            'event_date': elig.get('inquiry_date'),
            'source_transaction': 'eligibility_270',
            'signal_strength': 0.3,
            'metadata': {'transaction_id': elig.get('transaction_id')}
        })
    
    # Create intent events from prior auths
    for pa in prior_auths:
        if pa.get('request_category') != 'AR':  # Exclude referrals
            intent_events.append({
                'member_id': pa.get('member_id'),
                'episode_id': pa.get('episode_id', 'TKA'),
                'event_type': 'prior_auth',
                'event_date': pa.get('request_date'),
                'source_transaction': 'prior_auth_278',
                'signal_strength': 0.7,
                'metadata': {'auth_number': pa.get('auth_number')}
            })
    
    # Create intent events from referrals
    for ref in referrals:
        intent_events.append({
            'member_id': ref.get('member_id'),
            'episode_id': ref.get('episode_id', 'TKA'),
            'event_type': 'referral',
            'event_date': ref.get('request_date'),
            'source_transaction': 'referral_278',
            'signal_strength': 0.5,
            'metadata': {'auth_number': ref.get('auth_number')}
        })
    
    if intent_events:
        result = supabase.table('clinical_intent_event').upsert(intent_events).execute()
        print(f"  ✓ Generated {len(intent_events)} clinical intent events")
    else:
        print("  ⚠ No intent events generated (no source data found)")

def generate_predictions(supabase: Client):
    """Generate prediction results based on intent signals and member risk scores"""
    print("\n[7/7] Generating prediction results...")
    
    # Fetch members with TKA-related chronic conditions
    members_result = supabase.table('member_chronic_condition').select('member_id, icd10_code, diagnosis_date').in_('icd10_code', ['M17.11', 'M17.12', 'M17.0']).execute()
    tka_members = members_result.data or []
    
    # Fetch intent events for these members
    member_ids = list(set([m['member_id'] for m in tka_members]))
    
    predictions = []
    
    for member_data in tka_members:
        member_id = member_data['member_id']
        
        # Fetch intent signals for this member
        signals_result = supabase.table('clinical_intent_event').select('*').eq('member_id', member_id).execute()
        signals = signals_result.data or []
        
        # Calculate probability based on signals
        signal_count = len(signals)
        base_probability = 0.5
        signal_boost = min(signal_count * 0.1, 0.4)
        probability_score = min(base_probability + signal_boost, 0.95)
        
        # Predict event date (30-120 days from now)
        days_ahead = random.randint(30, 120)
        predicted_date = (datetime.now() + timedelta(days=days_ahead)).strftime('%Y-%m-%d')
        
        predictions.append({
            'member_id': member_id,
            'episode_id': 'TKA',
            'prediction_date': datetime.now().strftime('%Y-%m-%d'),
            'predicted_event_date': predicted_date,
            'probability_score': round(probability_score, 2),
            'model_version': 'v1.0-rule-based',
            'confidence_interval_low': round(max(probability_score - 0.15, 0.0), 2),
            'confidence_interval_high': round(min(probability_score + 0.15, 1.0), 2),
            'feature_importance': {
                'chronic_condition': 0.6,
                'intent_signals': 0.3,
                'demographics': 0.1
            }
        })
    
    if predictions:
        result = supabase.table('prediction_result').upsert(predictions).execute()
        print(f"  ✓ Generated {len(predictions)} prediction results")
    else:
        print("  ⚠ No predictions generated (no eligible members found)")

def main():
    """Main execution"""
    print("="*60)
    print("Clinical Forecasting Engine - EDI Data Loader")
    print("="*60)
    
    # Load environment variables
    # Removed load_env_file() as it's no longer needed with the new env variable logic
    
    try:
        # Initialize Supabase client
        supabase = get_supabase_client()
        print("\n✓ Connected to Supabase")
        
        # Load data in sequence (maintains referential integrity)
        load_members(supabase)
        load_eligibility_inquiries(supabase)
        load_prior_auths(supabase)
        load_rx_benefit_inquiries(supabase)
        load_claims(supabase)
        generate_intent_events(supabase)
        generate_predictions(supabase)
        
        print("\n" + "="*60)
        print("✓ Data loading complete!")
        print("="*60)
        
    except Exception as e:
        print(f"\n✗ Error: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()
