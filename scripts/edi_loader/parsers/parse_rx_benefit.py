"""
Rx Benefit Inquiry Parser
Parses pharmacy benefit check data (NCPDP format or JSON for prototype)
"""

import json
from datetime import datetime
from typing import List, Dict, Any

class ParseRxBenefit:
    """Parser for Rx benefit inquiry transactions"""
    
    def __init__(self, file_path: str):
        self.file_path = file_path
        self.inquiries = []
    
    def parse(self) -> List[Dict[str, Any]]:
        """
        Parse Rx benefit inquiry file
        For prototype, expects JSON format
        Production would parse NCPDP D.0 format
        """
        with open(self.file_path, 'r') as f:
            data = json.load(f)
        
        for inquiry in data:
            parsed = self._parse_inquiry(inquiry)
            if parsed:
                self.inquiries.append(parsed)
        
        return self.inquiries
    
    def _parse_inquiry(self, inquiry: Dict) -> Dict[str, Any]:
        """Parse individual Rx benefit inquiry"""
        return {
            'inquiry_id': inquiry['inquiry_id'],
            'member_id': inquiry['member_id'],
            'inquiry_date': inquiry['inquiry_date'],
            'ndc_code': inquiry['ndc_code'],
            'drug_name': inquiry['drug_name'],
            'drug_class': inquiry['drug_class'],
            'prescriber_npi': inquiry['prescriber_npi'],
            'pharmacy_npi': inquiry['pharmacy_npi'],
            'days_supply': inquiry['days_supply'],
            'quantity': inquiry['quantity'],
            'coverage_status': inquiry['coverage_status'],
            'copay_amount': inquiry['copay_amount'],
            'indication': inquiry['indication'],
            'raw_transaction_data': inquiry.get('raw_transaction_data', '')
        }
