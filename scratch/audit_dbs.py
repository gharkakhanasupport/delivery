import requests
import os

DB_NAMES = ['AGENT', 'USER', 'KITCHEN', 'ADMIN']
# AGENT use SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY
# Others use USER_DB_URL, etc.

CONFIGS = [
    {
        'name': 'AGENT',
        'url': 'https://uinictqyoycnwrnggznz.supabase.co',
        'key': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVpbmljdHF5b3ljbndybmdnem56Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTkwMDE3NywiZXhwIjoyMDkxNDc2MTc3fQ.xAjt2itGTh59fQbPcOo1ykO1Kh1g6TfjXXWAIJMoBVU'
    },
    {
        'name': 'USER',
        'url': 'https://mwnpwuxrbaousgwgoyco.supabase.co',
        'key': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13bnB3dXhyYmFvdXNnd2dveWNvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2Nzk4NTYzNiwiZXhwIjoyMDgzNTYxNjM2fQ.fyLds3C75939r99mRBhT_YLctX8KkC2imYFGnHRSjzc'
    },
    {
        'name': 'KITCHEN',
        'url': 'https://yvbjnuobnxekgibfqsmq.supabase.co',
        'key': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl2YmpudW9ibnhla2dpYmZxc21xIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTM5NjU3MiwiZXhwIjoyMDkwOTcyNTcyfQ.hSn6Z9Ct1kv6UqoFeTeaMhktKLs_6kns1AEaVN-T9hA'
    },
    {
        'name': 'ADMIN',
        'url': 'https://jqqzkazdjmiieyidnldm.supabase.co',
        'key': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpxcXprYXpkam1paWV5aWRubGRtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NzcyMjEwOCwiZXhwIjoyMDgzMjk4MTA4fQ.aK2Xp8TkCPoCnldyID-77hLdCyX910yT19JHZAAYcaQ'
    }
]

def check_db(config):
    print(f"\n--- Checking {config['name']} DB ---")
    headers = {
        'apikey': config['key'],
        'Authorization': f"Bearer {config['key']}"
    }
    
    # Check tables
    try:
        r = requests.get(f"{config['url']}/rest/v1/?select=*", headers=headers, timeout=10)
        if r.status_code == 200:
            tables = r.json()
            for t in tables:
                print(f"Table: {t['name']}")
        else:
            print(f"Error fetching tables: {r.status_code} {r.text}")
    except Exception as e:
        print(f"Connection error: {e}")

    # Specific column check for wallet/balance
    query = "select=table_name,column_name,data_type&table_name=in.(profiles,users,orders,kitchens,agent_wallets,wallet_transactions)"
    try:
        r = requests.get(f"{config['url']}/rest/v1/rpc/get_schema_info", headers=headers, timeout=10)
        # If rpc doesn't exist, we can't easily get columns via REST, but we can try information_schema if enabled
        # But usually we can just query a row and check keys
        print("Checking key tables columns...")
        for table in ['profiles', 'users', 'orders', 'kitchens', 'agent_wallets', 'wallet_transactions', 'delivery_orders']:
            r = requests.get(f"{config['url']}/rest/v1/{table}?limit=1", headers=headers, timeout=10)
            if r.status_code == 200 and r.json():
                print(f"Columns for {table}: {list(r.json()[0].keys())}")
            elif r.status_code == 200:
                print(f"Table {table} is empty.")
            else:
                # Table might not exist
                pass
    except Exception as e:
        print(f"Error checking columns: {e}")

for cfg in CONFIGS:
    check_db(cfg)
