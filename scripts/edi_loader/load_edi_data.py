"""
EDI Data Loader - Main orchestrator for loading EDI transactions

Processes EDI files in the correct sequence to maintain referential integrity:
1. Members (from proprietary system JSON export)
2. Eligibility Inquiries (270/271)
3. Prior Authorizations (278)
4. Claims (837I/837P)
"""

import os
import sys
import json
from datetime import datetime
from typing import List, Dict

# Add parent directory to path for imports
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from parsers import parse_270_271, parse_278, parse_837

# Database connection (mock for now - replace with actual DB connection)
class DatabaseConnection:
    """Mock database connection - replace with psycopg2 or SQLAlchemy"""
    
    def __init__(self):
        self.host = os.getenv('DB_HOST', 'localhost')
        self.database = os.getenv('DB_NAME', 'clinical_forecasting')
        self.user = os.getenv('DB_USER', 'postgres')
        self.password = os.getenv('DB_PASSWORD', '')
    
    def execute_function(self, function_name: str, data: List[Dict]) -> int:
        """Execute PostgreSQL function with JSON data"""
        print(f"[Mock] Calling {function_name} with {len(data)} records")
        return len(data)
    
    def execute_query(self, query: str, params: tuple = None):
        """Execute SQL query"""
        print(f"[Mock] Executing query: {query[:100]}...")
        return None

class EDIDataLoader:
    """Main EDI data loading orchestrator"""
    
    def __init__(self):
        self.db = DatabaseConnection()
        self.stats = {
            'members': 0,
            'eligibility': 0,
            'prior_auth': 0,
            'claims': 0,
            'errors': []
        }
    
    def load_members(self, file_path: str) -> int:
        """Load member demographics from JSON export (from proprietary enrollment system)"""
        print(f"\n[1/4] Loading members from JSON: {file_path}")
        
        try:
            # Parse JSON file
            with open(file_path, 'r') as f:
                members = json.load(f)
            
            if not members:
                print("⚠ No members found in JSON file")
                return 0
            
            # Bulk insert members
            count = self.db.execute_function('load_members_batch', members)
            self.stats['members'] = count
            print(f"✓ Loaded {count} members from JSON")
            return count
            
        except Exception as e:
            error = f"Error loading members from JSON: {str(e)}"
            print(f"✗ {error}")
            self.stats['errors'].append(error)
            return 0
    
    def load_eligibility_data(self, file_path: str) -> int:
        """Load 270/271 eligibility inquiry data"""
        print(f"\n[2/4] Loading eligibility data from {file_path}")
        
        try:
            inquiries = parse_270_271(file_path)
            count = self.db.execute_function('load_270_271_batch', inquiries)
            self.stats['eligibility'] = count
            print(f"✓ Loaded {count} eligibility inquiries")
            return count
            
        except Exception as e:
            error = f"Error loading eligibility data: {str(e)}"
            print(f"✗ {error}")
            self.stats['errors'].append(error)
            return 0
    
    def load_prior_auth_data(self, file_path: str) -> int:
        """Load 278 prior authorization data"""
        print(f"\n[3/4] Loading prior authorization data from {file_path}")
        
        try:
            prior_auths = parse_278(file_path)
            count = self.db.execute_function('load_278_batch', prior_auths)
            self.stats['prior_auth'] = count
            print(f"✓ Loaded {count} prior authorizations")
            return count
            
        except Exception as e:
            error = f"Error loading prior auth data: {str(e)}"
            print(f"✗ {error}")
            self.stats['errors'].append(error)
            return 0
    
    def load_claims_data(self, file_path: str) -> int:
        """Load 837 claims data"""
        print(f"\n[4/4] Loading claims data from {file_path}")
        
        try:
            headers, lines = parse_837(file_path)
            
            # Load headers first
            header_count = self.db.execute_function('load_837_headers_batch', headers)
            
            # Then load lines
            line_count = self.db.execute_function('load_837_lines_batch', lines)
            
            self.stats['claims'] = header_count
            print(f"✓ Loaded {header_count} claims with {line_count} lines")
            return header_count
            
        except Exception as e:
            error = f"Error loading claims data: {str(e)}"
            print(f"✗ {error}")
            self.stats['errors'].append(error)
            return 0
    
    def load_all(self, sample_data_dir: str = '../../sample-data'):
        """Load all EDI data in correct sequence"""
        print("=" * 60)
        print("EDI Data Loader - Clinical Forecasting Engine")
        print("=" * 60)
        print(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        # Load in sequence to maintain referential integrity
        self.load_members(os.path.join(sample_data_dir, 'members.json'))
        self.load_eligibility_data(os.path.join(sample_data_dir, '270-eligibility-requests.edi'))
        self.load_prior_auth_data(os.path.join(sample_data_dir, '278-prior-auth-requests.edi'))
        self.load_claims_data(os.path.join(sample_data_dir, '837I-institutional-claims.edi'))
        
        # Print summary
        print("\n" + "=" * 60)
        print("LOAD SUMMARY")
        print("=" * 60)
        print(f"Members:              {self.stats['members']:>6}")
        print(f"Eligibility Inquiries: {self.stats['eligibility']:>6}")
        print(f"Prior Authorizations:  {self.stats['prior_auth']:>6}")
        print(f"Claims:                {self.stats['claims']:>6}")
        
        if self.stats['errors']:
            print(f"\nErrors: {len(self.stats['errors'])}")
            for error in self.stats['errors']:
                print(f"  - {error}")
        else:
            print("\n✓ All data loaded successfully!")
        
        print(f"\nCompleted: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("=" * 60)

def main():
    """Main entry point"""
    loader = EDIDataLoader()
    loader.load_all()

if __name__ == '__main__':
    main()
