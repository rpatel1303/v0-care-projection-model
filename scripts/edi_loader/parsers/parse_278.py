"""
Parser for 278 EDI Prior Authorization Request/Response transactions
"""

import re
from datetime import datetime
from typing import List, Dict

def parse_278(file_path: str) -> List[Dict]:
    """
    Parse 278 EDI file and return list of prior authorization events
    
    Args:
        file_path: Path to EDI file containing 278 transactions
        
    Returns:
        List of dictionaries with parsed PA data
    """
    prior_auths = []
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Split into individual transactions
    transactions = re.findall(r'ST\*278.*?SE\*\d+\*\d+~', content, re.DOTALL)
    
    for transaction in transactions:
        pa = parse_single_278(transaction)
        if pa:
            prior_auths.append(pa)
    
    return prior_auths

def parse_single_278(transaction: str) -> Dict:
    """Parse a single 278 transaction"""
    
    segments = transaction.split('~')
    
    pa = {
        'pa_id': None,
        'request_ts': None,
        'decision_ts': None,
        'status': 'requested',
        'member_id': None,
        'requesting_provider_npi': None,
        'servicing_provider_npi': None,
        'service_from_date': None,
        'service_to_date': None,
        'place_of_service': None,
        'diagnosis_codes': [],
        'procedure_codes': [],
        'clinical_type': None,
        'line_of_business': 'Commercial',
        'plan_id': None,
        'urgency': 'standard'
    }
    
    for segment in segments:
        fields = segment.split('*')
        
        if not fields:
            continue
            
        segment_id = fields[0]
        
        # BHT - Beginning of Hierarchical Transaction
        if segment_id == 'BHT':
            if len(fields) >= 4:
                pa['pa_id'] = fields[3]  # Reference number
                if len(fields) >= 5:
                    date_str = fields[4]
                    time_str = fields[5] if len(fields) > 5 else '0000'
                    pa['request_ts'] = parse_edi_datetime(date_str, time_str)
        
        # NM1 - Name segments
        elif segment_id == 'NM1':
            if len(fields) >= 3:
                entity_type = fields[1]
                
                if entity_type == 'IL':  # Member
                    if len(fields) >= 9:
                        pa['member_id'] = fields[9]
                
                elif entity_type == '1P':  # Requesting provider
                    if len(fields) >= 9:
                        pa['requesting_provider_npi'] = fields[9]
                
                elif entity_type == 'SJ':  # Servicing provider  
                    if len(fields) >= 9:
                        pa['servicing_provider_npi'] = fields[9]
        
        # DTP - Dates
        elif segment_id == 'DTP':
            if len(fields) >= 3:
                date_qualifier = fields[1]
                date_value = fields[3]
                
                if date_qualifier == '472':  # Service date
                    pa['service_from_date'] = parse_edi_date(date_value)
                    pa['service_to_date'] = pa['service_from_date']
                
                elif date_qualifier == 'AAH':  # Decision date
                    pa['decision_ts'] = parse_edi_datetime(date_value, '0000')
        
        # HI - Health Care Diagnosis Code
        elif segment_id == 'HI':
            for i in range(1, len(fields)):
                code_info = fields[i]
                if ':' in code_info:
                    code = code_info.split(':')[1]
                    pa['diagnosis_codes'].append(code)
        
        # SV2 - Institutional Service Line
        elif segment_id == 'SV2':
            if len(fields) >= 2:
                revenue_code = fields[1]
                if ':' in revenue_code:
                    proc_code = revenue_code.split(':')[1]
                    pa['procedure_codes'].append(proc_code)
        
        # HSD - Health Care Services Delivery
        elif segment_id == 'HSD':
            if len(fields) >= 2:
                unit_type = fields[1]
                if unit_type == 'VS':  # Visit
                    pa['clinical_type'] = 'outpatient'
                elif unit_type == 'DY':  # Days
                    pa['clinical_type'] = 'inpatient'
        
        # HCR - Health Care Services Review Information (Response)
        elif segment_id == 'HCR':
            if len(fields) >= 2:
                action_code = fields[1]
                if action_code == 'A1':
                    pa['status'] = 'approved'
                elif action_code == 'A2':
                    pa['status'] = 'pended'
                elif action_code == 'A3':
                    pa['status'] = 'denied'
    
    # Set servicing provider to requesting if not specified
    if not pa['servicing_provider_npi']:
        pa['servicing_provider_npi'] = pa['requesting_provider_npi']
    
    return pa if pa['member_id'] and pa['pa_id'] else None

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
        if len(date_str) == 8:
            return datetime.strptime(date_str, '%Y%m%d').date().isoformat()
        elif len(date_str) == 6:
            return datetime.strptime(date_str, '%y%m%d').date().isoformat()
    except:
        return None
