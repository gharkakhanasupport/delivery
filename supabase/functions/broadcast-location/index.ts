// ================================================================
// BROADCAST LOCATION - Edge Function for Delivery DB
// This function broadcasts delivery partner location to User DB
// for real-time tracking in the User App
// Deploy: supabase functions deploy broadcast-location
// ================================================================

// @ts-ignore - Deno imports
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
// @ts-ignore - Deno imports
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

declare const Deno: {
    env: {
        get(key: string): string | undefined;
    };
};

serve(async (req: Request) => {
    if (req.method === 'OPTIONS') {
        return new Response(null, { headers: corsHeaders })
    }

    try {
        const { order_id, partner_id, latitude, longitude, heading, speed } = await req.json()

        // Validate required fields
        if (!order_id || !latitude || !longitude) {
            return new Response(
                JSON.stringify({
                    success: false,
                    error: 'Missing required fields: order_id, latitude, longitude'
                }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        console.log(`[broadcast-location] Order: ${order_id}, Lat: ${latitude}, Lng: ${longitude}`)

        // Update local delivery_orders table
        const localClient = createClient(
            Deno.env.get('SUPABASE_URL')!,
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        )

        const locationData = {
            lat: latitude,
            lng: longitude,
            heading: heading || null,
            speed: speed || null,
            updated_at: new Date().toISOString(),
        }

        // Update current_location in local delivery_orders
        await localClient
            .from('delivery_orders')
            .update({ current_location: locationData })
            .eq('id', order_id)

        // Store in location history
        if (partner_id) {
            await localClient.from('location_history').insert({
                partner_id,
                order_id,
                latitude,
                longitude,
                heading,
                speed,
            })
        }

        // Broadcast to User DB for customer tracking
        const userDbUrl = Deno.env.get('USER_DB_URL')
        const userDbKey = Deno.env.get('USER_DB_SERVICE_KEY')

        if (userDbUrl && userDbKey) {
            const userClient = createClient(userDbUrl, userDbKey)

            await userClient
                .from('orders')
                .update({
                    current_location: locationData,
                    // This triggers Supabase Realtime for customer app
                })
                .eq('id', order_id)

            console.log('[broadcast-location] Location broadcasted to User DB')
        }

        return new Response(
            JSON.stringify({
                success: true,
                message: 'Location broadcasted successfully'
            }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error: unknown) {
        const errorMessage = error instanceof Error ? error.message : 'Unknown error'
        console.error('[broadcast-location] Error:', errorMessage)
        return new Response(
            JSON.stringify({ success: false, error: errorMessage }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
