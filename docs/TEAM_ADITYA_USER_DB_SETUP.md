# Team Aditya - User DB Setup Guide

> **For:** Aditya Vaiya (User App Database)  
> **From:** Debraj (Delivery App Database)  
> **Purpose:** Sync orders to Delivery DB when ready for pickup

---

## Overview

When an order status changes to `ready_for_pickup`, the User DB needs to send order data to the Delivery DB so delivery partners can see and accept orders.

**Delivery App Endpoint:**
```
https://miqoctpjqcdvjimzlwls.supabase.co/functions/v1/receive-order-sync
```

---

## Step 1: Add Sync Columns to Orders Table

Run this SQL in your **User DB** → SQL Editor:

```sql
-- Add columns for sync tracking (if not exists)
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS last_synced_from VARCHAR(50) DEFAULT 'user_db',
ADD COLUMN IF NOT EXISTS delivery_partner_id UUID,
ADD COLUMN IF NOT EXISTS current_location JSONB;

-- Add index for sync queries
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_synced ON public.orders(last_synced_at);
```

---

## Step 2: Create the Sync Edge Function

Create a new Edge Function in your User DB project:

### File: `supabase/functions/sync-order-to-delivery/index.ts`

```typescript
// @ts-ignore
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
// @ts-ignore
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

declare const Deno: { env: { get(key: string): string | undefined } };

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    const { type, record, old_record } = await req.json()
    
    console.log(`[sync-order-to-delivery] Event: ${type}, Status: ${record?.status}`)

    // Only sync when status becomes 'ready_for_pickup'
    if (record?.status !== 'ready_for_pickup') {
      return new Response(
        JSON.stringify({ success: true, message: 'Not ready for pickup, skipping' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Skip if already synced for this status
    if (type === 'UPDATE' && old_record?.status === 'ready_for_pickup') {
      return new Response(
        JSON.stringify({ success: true, message: 'Already synced' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Delivery DB endpoint
    const deliveryUrl = 'https://miqoctpjqcdvjimzlwls.supabase.co/functions/v1/receive-order-sync'
    
    // Get Delivery DB anon key (you'll set this as a secret)
    const deliveryKey = Deno.env.get('DELIVERY_DB_ANON_KEY')
    
    if (!deliveryKey) {
      throw new Error('DELIVERY_DB_ANON_KEY not set')
    }

    // Send order to Delivery DB
    const response = await fetch(deliveryUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${deliveryKey}`,
      },
      body: JSON.stringify({
        type: 'INSERT',
        record: {
          id: record.id,
          order_number: record.order_number,
          user_id: record.user_id,
          user_name: record.customer_name || record.user_name,
          user_phone: record.customer_phone || record.user_phone,
          kitchen_id: record.kitchen_id,
          kitchen_name: record.restaurant_name || record.kitchen_name,
          kitchen_phone: record.restaurant_phone,
          status: record.status,
          pickup_address: {
            address: record.restaurant_address,
            lat: record.restaurant_latitude,
            lng: record.restaurant_longitude,
          },
          delivery_address: {
            address: record.delivery_address,
            lat: record.delivery_latitude,
            lng: record.delivery_longitude,
          },
          items: record.items || record.order_items,
          total_amount: record.total_amount,
          delivery_fee: record.delivery_fee,
          created_at: record.created_at,
          ready_at: new Date().toISOString(),
        },
        source_db: 'user_db',
      }),
    })

    const result = await response.json()
    
    if (!response.ok) {
      console.error('[sync-order-to-delivery] Failed:', result)
      throw new Error(result.error || 'Sync failed')
    }

    console.log('[sync-order-to-delivery] Success:', result)

    // Update local order with sync timestamp
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    await supabase
      .from('orders')
      .update({ 
        last_synced_at: new Date().toISOString(),
        last_synced_from: 'user_db'
      })
      .eq('id', record.id)

    return new Response(
      JSON.stringify({ success: true, message: 'Order synced to Delivery DB' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : 'Unknown error'
    console.error('[sync-order-to-delivery] Error:', msg)
    return new Response(
      JSON.stringify({ success: false, error: msg }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

---

## Step 3: Deploy the Function

```bash
cd your-user-app-project
supabase login
supabase link --project-ref mwnpwuxrbaousgwgoyco
supabase functions deploy sync-order-to-delivery
```

---

## Step 4: Set the Secret

Set the Delivery DB anon key:

```bash
supabase secrets set DELIVERY_DB_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1pcW9jdHBqcWNkdmppbXpsd2xzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgyNDU2MjEsImV4cCI6MjA4MzgyMTYyMX0.arTYWehG-ZGytYlMPJ81ZbYBpBh-Id-QtAftYcwuIEA
```

---

## Step 5: Create Database Webhook

1. Go to **Supabase Dashboard** → Your User Project
2. Navigate to **Database** → **Webhooks**
3. Click **Create a new webhook**
4. Configure:

| Field | Value |
|-------|-------|
| Name | `sync_order_to_delivery` |
| Table | `orders` |
| Events | ✅ UPDATE |
| Type | HTTP Request |
| Method | POST |
| URL | `https://mwnpwuxrbaousgwgoyco.supabase.co/functions/v1/sync-order-to-delivery` |

5. Add HTTP Header:
   - Key: `Authorization`
   - Value: `Bearer YOUR_ANON_KEY`

6. Click **Create webhook**

---

## Step 6: Test the Integration

1. Create a test order in User App
2. Update order status to `ready_for_pickup`:

```sql
UPDATE orders SET status = 'ready_for_pickup' WHERE id = 'your-test-order-id';
```

3. Check Delivery DB for the synced order:
   - Go to Delivery DB Dashboard → Table Editor → `delivery_orders`
   - The order should appear

---

## Troubleshooting

### Check Function Logs
```bash
supabase functions logs sync-order-to-delivery
```

### Verify Webhook is Working
1. Go to Database → Webhooks
2. Check the "Last triggered" timestamp
3. Look for any error messages

### Common Issues

| Issue | Solution |
|-------|----------|
| "DELIVERY_DB_ANON_KEY not set" | Run `supabase secrets set DELIVERY_DB_ANON_KEY=...` |
| "Sync failed" | Check if Delivery DB Edge Function is deployed |
| Order not appearing | Verify order status is exactly `ready_for_pickup` |

---

## Summary

✅ Add sync columns to `orders` table  
✅ Create `sync-order-to-delivery` Edge Function  
✅ Deploy function  
✅ Set `DELIVERY_DB_ANON_KEY` secret  
✅ Create webhook on `orders` table UPDATE  
✅ Test the flow  

---

**Questions?** Contact Debraj
