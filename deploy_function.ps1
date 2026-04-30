$ErrorActionPreference = "Stop"

Write-Host "Deploying sync-delivery-status Edge Function..." -ForegroundColor Cyan

supabase functions deploy sync-delivery-status --project-ref miqoctpjqcdvjimzlwls --no-verify-jwt

Write-Host "Function deployed successfully!" -ForegroundColor Green
