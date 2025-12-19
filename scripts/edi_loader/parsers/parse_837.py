"""
Parser for 837 EDI Healthcare Claims (Institutional and Professional)
"""

import re
from datetime import datetime
from typing import List, Dict, Tuple

def parse_837(file_path: str) -> Tuple[List[Dict], List[Dict]]:
    """
    Parse 837I/837P EDI file and return claims headers and lines
    
    Args:
        file_path: Path to EDI file containing 837 transactions
        
    Returns:
        Tuple of (claim_headers, claim_lines)
    """
    headers = []
    lines = []
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Split into individual claims
    claims = re.findall(r'CLM\*.*?(?=CLM\*|SE\*)', content, re.DOTALL)
    
    for claim_text in claims:
        header, claim_lines = parse_single_claim(claim_text)
        if header:
            headers.append(header)
            lines.extend(claim_lines)
    
    return headers, lines

def parse_single_claim(claim_text: str) -> Tuple[Dict, List[Dict]]:
    """Parse a single claim and its lines"""
    
    segments = claim_text.split('~')
    
    header = {
        'claim_id': None,
        'member_id': None,
        'claim_type': 'institutional',
        'from_date': None,
        'thru_date': None,
        'received_ts': None,
        'claim_status': 'paid',
        'billing_provider_npi': None,
        'rendering_provider_npi': None,
        'facility_npi': None,
        'place_of_service': None,
        'bill_type': None,
        'total_billed_amt': 0,
        'total_allowed_amt': 0,
        'total_paid_amt': 0,
        'line_of_business': 'Commercial',
        'plan_id': None
    }
    
    lines = []
    line_num = 0
    current_line = None
    
    for segment in segments:
        fields = segment.split('*')
        
        if not fields:
            continue
            
        segment_id = fields[0]
        
        # CLM - Claim Information
        if segment_id == 'CLM':
            if len(fields) >= 3:
                header['claim_id'] = fields[1]
                header['total_billed_amt'] = float(fields[2]) if fields[2] else 0
        
        # DTP - Claim Dates
        elif segment_id == 'DTP':
            if len(fields) >= 3:
                date_qualifier = fields[1]
                date_value = fields[3]
                
                if date_qualifier == '434':  # Statement from date
                    header['from_date'] = parse_edi_date(date_value)
                elif date_qualifier == '435':  # Statement through date
                    header['thru_date'] = parse_edi_date(date_value)
                elif date_qualifier == '050':  # Received date
                    header['received_ts'] = parse_edi_datetime(date_value, '0000')
        
        # NM1 - Entity Names
        elif segment_id == 'NM1':
            if len(fields) >= 3:
                entity_type = fields[1]
                
                if entity_type == 'IL':  # Member
                    if len(fields) >= 9:
                        header['member_id'] = fields[9]
                
                elif entity_type == '85':  # Billing provider
                    if len(fields) >= 9:
                        header['billing_provider_npi'] = fields[9]
                
                elif entity_type in ['82', '71']:  # Rendering provider
                    if len(fields) >= 9:
                        header['rendering_provider_npi'] = fields[9]
                
                elif entity_type == '77':  # Service facility
                    if len(fields) >= 9:
                        header['facility_npi'] = fields[9]
        
        # SV1 - Professional Service Line (837P)
        elif segment_id == 'SV1':
            line_num += 1
            current_line = {
                'claim_id': header['claim_id'],
                'line_num': line_num,
                'service_date': header['from_date'],
                'procedure_code': None,
                'modifier1': None,
                'units': 1,
                'billed_amt': 0,
                'allowed_amt': 0,
                'paid_amt': 0,
                'line_status': 'paid'
            }
            
            if len(fields) >= 2:
                proc_info = fields[1]
                if ':' in proc_info:
                    parts = proc_info.split(':')
                    current_line['procedure_code'] = parts[1] if len(parts) > 1 else None
                    if len(parts) > 2:
                        current_line['modifier1'] = parts[2]
            
            if len(fields) >= 3:
                current_line['billed_amt'] = float(fields[2]) if fields[2] else 0
            
            if len(fields) >= 5:
                current_line['units'] = int(fields[5]) if fields[5] else 1
            
            lines.append(current_line)
        
        # SV2 - Institutional Service Line (837I)
        elif segment_id == 'SV2':
            line_num += 1
            current_line = {
                'claim_id': header['claim_id'],
                'line_num': line_num,
                'service_date': header['from_date'],
                'procedure_code': None,
                'revenue_code': None,
                'units': 1,
                'billed_amt': 0,
                'allowed_amt': 0,
                'paid_amt': 0,
                'line_status': 'paid'
            }
            
            if len(fields) >= 2:
                rev_code = fields[1]
                if ':' in rev_code:
                    current_line['revenue_code'] = rev_code.split(':')[1]
            
            if len(fields) >= 3:
                proc_code = fields[2]
                if ':' in proc_code:
                    current_line['procedure_code'] = proc_code.split(':')[1]
            
            if len(fields) >= 4:
                current_line['billed_amt'] = float(fields[3]) if fields[3] else 0
            
            if len(fields) >= 5:
                current_line['units'] = float(fields[5]) if fields[5] else 1
            
            lines.append(current_line)
        
        # DTP on service line
        elif segment_id == 'DTP' and current_line:
            if len(fields) >= 3:
                date_qualifier = fields[1]
                if date_qualifier == '472':  # Service date
                    current_line['service_date'] = parse_edi_date(fields[3])
    
    # Calculate totals
    header['total_paid_amt'] = sum(line['paid_amt'] for line in lines)
    header['total_allowed_amt'] = sum(line['allowed_amt'] for line in lines)
    
    return (header, lines) if header['claim_id'] and header['member_id'] else (None, [])

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
        # Handle date ranges (e.g., "20241201-20241205")
        if '-' in date_str:
            date_str = date_str.split('-')[0]
        
        if len(date_str) == 8:
            return datetime.strptime(date_str, '%Y%m%d').date().isoformat()
        elif len(date_str) == 6:
            return datetime.strptime(date_str, '%y%m%d').date().isoformat()
    except:
        return None
