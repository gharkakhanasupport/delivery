# GKK Delivery App - Edge Functions Deployment Guide

This guide explains how to deploy and configure the Edge Functions for multi-database synchronization.

## Prerequisites

1. **Supabase CLI installed**
   ```bash
   npm install -g supabase
   ```

2. **Logged in to Supabase**
   ```bash
   supabase login
   ```

3. **Project linked**
   ```bash
   cd gkk-delivery
   supabase link --project-ref YOUR_PROJECT_REF
   ```

## Edge Functions Overview

| Function | Purpose | Trigger |
|----------|---------|---------|
| `receive-order-sync` | Receives orders from User/Admin DB | Webhook from User DB |
| `sync-delivery-status` | Syncs status updates to User/Admin DB | Webhook on `delivery_orders` |
| `broadcast-location` | Broadcasts location to User DB | Called from app |

## Step 1: Run Database Migration

Run the SQL migration to create the `delivery_orders` table:

```bash
# Option 1: Via Supabase Dashboard
# Go to SQL Editor > New Query > Paste content from:
# supabase/migrations/001_delivery_orders_sync.sql

# Option 2: Via CLI
supabase db push
```

## Step 2: Set Required Secrets

Before deploying, configure the secrets for other database connections:

```bash
# User DB credentials (get from Team Aditya)
supabase secrets set USER_DB_URL=https://USER_PROJECT_REF.supabase.co
supabase secrets set USER_DB_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Admin DB credentials (get from Team Aditya)
supabase secrets set ADMIN_DB_URL=https://ADMIN_PROJECT_REF.supabase.co
supabase secrets set ADMIN_DB_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

> ⚠️ **IMPORTANT**: Get the `SERVICE_ROLE_KEY` (not the anon key) from Aditya's Supabase projects.

## Step 3: Deploy Edge Functions

```bash
# Deploy all functions
supabase functions deploy receive-order-sync
supabase functions deploy sync-delivery-status
supabase functions deploy broadcast-location

# Or deploy all at once
supabase functions deploy
```

## Step 4: Configure Database Webhooks

In your Supabase Dashboard:

### Webhook 1: Sync status updates to User/Admin DB

1. Go to **Database** → **Webhooks**
2. Click **Create a new webhook**
3. Configure:
   - **Name**: `sync_delivery_status`
   - **Table**: `delivery_orders`
   - **Events**: `UPDATE`
   - **Webhook URL**: `https://YOUR_PROJECT.supabase.co/functions/v1/sync-delivery-status`
   - **HTTP Headers**: 
     ```
     Authorization: Bearer YOUR_ANON_KEY
     ```

### Webhook 2: Location broadcast (optional)

Only needed if you want automatic location sync. Otherwise, call the function directly from the app.

## Step 5: Share Your Endpoint with Team Aditya

Give Aditya this URL so User DB can sync orders to you:

```
https://YOUR_PROJECT_REF.supabase.co/functions/v1/receive-order-sync
```

He needs to add this as a webhook in User DB to trigger on:
- `orders` table → `UPDATE` (when status becomes `ready_for_pickup`)

## Testing

### Test receive-order-sync

```bash
curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/receive-order-sync' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "type": "INSERT",
    "record": {
      "id": "test-uuid-123",
      "order_number": "GKK-TEST-001",
      "user_name": "Test Customer",
      "user_phone": "9876543210",
      "kitchen_name": "Test Kitchen",
      "status": "ready_for_pickup",
      "pickup_address": {"address": "123 Kitchen St", "lat": 12.9716, "lng": 77.5946},
      "delivery_address": {"address": "456 Customer Ave", "lat": 12.9616, "lng": 77.5846},
      "items": [{"name": "Test Item", "qty": 1, "price": 100}],
      "delivery_fee": 40
    },
    "source_db": "user_db"
  }'
```

### Verify data in database

```sql
SELECT * FROM delivery_orders WHERE order_number = 'GKK-TEST-001';
```

## Troubleshooting

### Function not receiving data?
- Check webhook is created and active
- Verify Authorization header has correct key
- Check function logs: `supabase functions list` then view logs in Dashboard

### Sync failing?
- Verify secrets are set correctly: `supabase secrets list`
- Check target DB URL and SERVICE_KEY are valid
- Look at function logs for specific errors

### RLS blocking inserts?
- Edge Functions use `SUPABASE_SERVICE_ROLE_KEY` which bypasses RLS
- Make sure you're using the service role key in secrets

## File Structure

```
gkk-delivery/
├── supabase/
│   ├── config.toml                 # Supabase configuration
│   ├── functions/
│   │   ├── receive-order-sync/     # Receives synced orders
│   │   │   └── index.ts
│   │   ├── sync-delivery-status/   # Sends status updates
│   │   │   └── index.ts
│   │   └── broadcast-location/     # Location broadcasting
│   │       └── index.ts
│   └── migrations/
│       └── 001_delivery_orders_sync.sql
└── lib/
    ├── models/
    │   └── order.dart              # Updated with sync support
    └── services/
        └── order_service.dart      # Updated with sync methods
```

## Next Steps

1. ✅ Run the SQL migration
2. ✅ Set the secrets
3. ✅ Deploy functions
4. ✅ Create webhooks
5. ✅ Share endpoint with Team Aditya
6. ⏳ Test end-to-end sync flow
