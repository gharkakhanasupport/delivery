const SUPABASE_URL = "https://uinictqyoycnwrnggznz.supabase.co";
const SUPABASE_SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVpbmljdHF5b3ljbndybmdnem56Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTkwMDE3NywiZXhwIjoyMDkxNDc2MTc3fQ.xAjt2itGTh59fQbPcOo1ykO1Kh1g6TfjXXWAIJMoBVU";

async function debugCreateUser() {
  const url = `${SUPABASE_URL}/auth/v1/admin/users`;
  console.log('Sending request to:', url);
  
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'apikey': SUPABASE_SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      email: "debug_agent_" + Date.now() + "@example.com",
      password: "password123",
      email_confirm: true
    })
  });

  const text = await res.text();
  console.log("Status:", res.status);
  console.log("Response:", text);
}

debugCreateUser();
