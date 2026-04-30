import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function isUUID(str: string) {
  const regexExp = /^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$/gi;
  return regexExp.test(str);
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const userDbUrl = Deno.env.get('USER_DB_URL')
    const userDbKey = Deno.env.get('USER_DB_SERVICE_KEY')
    const kitchenDbUrl = Deno.env.get('KITCHEN_DB_URL')
    const kitchenDbKey = Deno.env.get('KITCHEN_DB_SERVICE_KEY')

    if (!userDbUrl || !userDbKey || !kitchenDbUrl || !kitchenDbKey) {
      throw new Error('Server configuration error: Target DB credentials missing')
    }

    const userClient = createClient(userDbUrl, userDbKey)
    const kitchenClient = createClient(kitchenDbUrl, kitchenDbKey)

    // 1. Fetch active orders from User DB
    const { data: orders, error: orderError } = await userClient
      .from('orders')
      .select('*')
      .in('status', ['pending', 'confirmed', 'preparing', 'ready', 'ready_for_pickup'])
      .order('created_at', { ascending: false })
      .limit(30)

    if (orderError) throw orderError
    if (!orders || orders.length === 0) {
        return new Response(JSON.stringify([]), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })
    }

    // 2. Fetch Kitchens
    const cookIds = [...new Set(orders.map((o: any) => o.cook_id).filter(Boolean))]
    let kitchens: any[] = []
    if (cookIds.length > 0) {
        const { data: kitchenData } = await kitchenClient
            .from('kitchens')
            .select('cook_id, kitchen_name, phone, location')
            .in('cook_id', cookIds)
        if (kitchenData) kitchens = kitchenData
    }

    // 3. Fetch Saved Addresses (delivery coordinates)
    const addressIds = [...new Set(orders.map((o: any) => o.delivery_address).filter((addr: any) => addr && isUUID(addr)))]
    let addresses: any[] = []
    if (addressIds.length > 0) {
        const { data: addressData } = await userClient
            .from('saved_addresses')
            .select('id, latitude, longitude, full_address, street_address, area, city')
            .in('id', addressIds)
        if (addressData) addresses = addressData
    }

    // 4. Merge everything
    const enrichedOrders = orders.map((order: any) => {
        const kitchen = kitchens.find((k: any) => k.cook_id === order.cook_id)
        
        let resolvedAddress = null
        if (order.delivery_address && isUUID(order.delivery_address)) {
            resolvedAddress = addresses.find((a: any) => a.id === order.delivery_address)
        }

        return {
            ...order,
            kitchen_details: kitchen || null,
            resolved_delivery_address: resolvedAddress || null
        }
    })

    return new Response(JSON.stringify(enrichedOrders), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    const err = error as Error
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
