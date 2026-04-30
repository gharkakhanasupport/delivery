const SUPABASE_URL = "https://uinictqyoycnwrnggznz.supabase.co";
const SUPABASE_SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVpbmljdHF5b3ljbndybmdnem56Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTkwMDE3NywiZXhwIjoyMDkxNDc2MTc3fQ.xAjt2itGTh59fQbPcOo1ykO1Kh1g6TfjXXWAIJMoBVU";

async function run() {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/delivery_profiles?select=*&limit=1`, {
    headers: {
      "apikey": SUPABASE_SERVICE_ROLE_KEY,
      "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`
    }
  });

  const data = await res.json();
  console.log("Current rows:", JSON.stringify(data, null, 2));
}

run();
