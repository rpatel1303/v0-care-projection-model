"""
Parser for 270/271 EDI Eligibility Inquiry/Response transactions
"""

import re
from datetime import datetime
from typing import List, Dict

def parse_270_271(file_path: str) -> List[Dict]:
    """
    Parse 270/271 EDI file and return list of eligibility inquiry events
    
    Args:
        file_path: Path to EDI file containing 270/271 transactions
        
    Returns:
        List of dictionaries with parsed eligibility data
    """
    inquiries = []
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Split into individual transactions (ST...SE)
    transactions = re.findall(r'ST\*270.*?SE\*\d+\*\d+~', content, re.DOTALL)
    
    for transaction in transactions:
        inquiry = parse_single_270_271(transaction)
        if inquiry:
            inquiries.append(inquiry)
    
    return inquiries

def parse_single_270_271(transaction: str) -> Dict:
    """Parse a single 270/271 transaction"""
    
    segments = transaction.split('~')
    
    inquiry = {
        'inquiry_ts': None,
        'source_channel': 'edi_gateway',
        'payer_id': None,
        'member_id': None,
        'provider_npi': None,
        'service_type_codes': [],
        'place_of_service': None,
        'network_indicator': 'unknown',
        'coverage_status': 'unknown',
        'raw_270_ref': transaction
    }
    
    for segment in segments:
        fields = segment.split('*')
        
        if not fields:
            continue
            
        segment_id = fields[0]
        
        # BHT - Beginning of Hierarchical Transaction
        if segment_id == 'BHT':
            if len(fields) >= 5:
                # BHT*0022*13*REF123*20241201*1045
                date_str = fields[4] if len(fields) > 4 else ''
                time_str = fields[5] if len(fields) > 5 else '0000'
                inquiry['inquiry_ts'] = parse_edi_datetime(date_str, time_str)
        
        # NM1 - Individual/Organization Name
        elif segment_id == 'NM1':
            if len(fields) >= 3:
                entity_type = fields[1]
                
                # NM1*IL*1*DOE*JOHN****MI*M00001
                if entity_type == 'IL':  # Insured/Member
                    if len(fields) >= 9:
                        inquiry['member_id'] = fields[9]
                
                # NM1*1P*2*ORTHO CLINIC****XX*1234567890
                elif entity_type in ['1P', '2B']:  # Provider
                    if len(fields) >= 9:
                        inquiry['provider_npi'] = fields[9]
                
                # NM1*PR*2*AETNA****PI*PAYER001
                elif entity_type == 'PR':  # Payer
                    if len(fields) >= 9:
                        inquiry['payer_id'] = fields[9]
        
        # DTP - Date/Time Period  
        elif segment_id == 'DTP':
            if len(fields) >= 3:
                date_qualifier = fields[1]
                if date_qualifier == '291':  # Service date
                    inquiry['inquiry_ts'] = inquiry['inquiry_ts'] or parse_edi_date(fields[3])
        
        # EQ - Eligibility/Benefit Inquiry
        elif segment_id == 'EQ':
            if len(fields) >= 2:
                service_type = fields[1]
                inquiry['service_type_codes'].append(service_type)
        
        # EB - Eligibility/Benefit Information (from 271 response)
        elif segment_id == 'EB':
            if len(fields) >= 2:
                eligibility_code = fields[1]
                if eligibility_code in ['1', 'A', 'B', 'C']:
                    inquiry['coverage_status'] = 'active'
                elif eligibility_code in ['I', 'T']:
                    inquiry['coverage_status'] = 'inactive'
                
                # Network status
                if len(fields) >= 13:
                    network_indicator = fields[12]
                    if network_indicator == 'Y':
                        inquiry['network_indicator'] = 'in'
                    elif network_indicator == 'N':
                        inquiry['network_indicator'] = 'out'
    
    return inquiry if inquiry['member_id'] else None

def parse_edi_datetime(date_str: str, time_str: str) -> str:
    """Convert EDI date/time to ISO format"""
    try:
        # Date: YYYYMMDD or YYMMDD
        if len(date_str) == 8:
            dt = datetime.strptime(date_str, '%Y%m%d')
        elif len(date_str) == 6:
            dt = datetime.strptime(date_str, '%y%m%d')
        else:
            return None
        
        # Time: HHMM
        if time_str and len(time_str) >= 4:
            hour = int(time_str[:2])
            minute = int(time_str[2:4])
            dt = dt.replace(hour=hour, minute=minute)
        
        return dt.isoformat()
    except:
        return None

def parse_edi_date(date_str: str) -> str:
    """Convert EDI date to ISO format"""
    return parse_edi_datetime(date_str, '0000')
