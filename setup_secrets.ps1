$ErrorActionPreference = "Stop"

Write-Host "Setting Supabase Secrets for Delivery Project (miqoctpjqcdvjimzlwls)..." -ForegroundColor Cyan

supabase secrets set --project-ref miqoctpjqcdvjimzlwls `
  USER_DB_URL="https://mwnpwuxrbaousgwgoyco.supabase.co" `
  USER_DB_SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13bnB3dXhyYmFvdXNnd2dveWNvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2Nzk4NTYzNiwiZXhwIjoyMDgzNTYxNjM2fQ.fyLds3C75939r99mRBhT_YLctX8KkC2imYFGnHRSjzc" `
  ADMIN_DB_URL="https://jqqzkazdjmiieyidnldm.supabase.co" `
  ADMIN_DB_SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpxcXprYXpkam1paWV5aWRubGRtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NzcyMjEwOCwiZXhwIjoyMDgzMjk4MTA4fQ.aK2Xp8TkCPoCnldyID-77hLdCyX910yT19JHZAAYcaQ"

Write-Host "Secrets set successfully!" -ForegroundColor Green
