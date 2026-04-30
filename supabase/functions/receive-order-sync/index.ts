// ================================================================
// RECEIVE ORDER SYNC - Edge Function for Delivery DB
// This function receives order data synced from User DB/Admin DB
// Includes automatic geocoding for addresses without coordinates
// Deploy: supabase functions deploy receive-order-sync
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

// Geocoding function using OpenStreetMap Nominatim API
async function geocodeAddress(address: string): Promise<{ lat: number; lng: number } | null> {
    if (!address || address.trim() === '') return null;

    try {
        const encodedAddress = encodeURIComponent(address);
        const url = `https://nominatim.openstreetmap.org/search?q=${encodedAddress}&format=json&limit=1&countrycodes=in`;

        const response = await fetch(url, {
            headers: {
                'User-Agent': 'GKK-Delivery-Sync/1.0',
                'Accept': 'application/json',
            },
        });

        if (response.ok) {
            const results = await response.json();
            if (results && results.length > 0) {
                const lat = parseFloat(results[0].lat);
                const lng = parseFloat(results[0].lon);
                console.log(`[geocode] "${address}" -> (${lat}, ${lng})`);
                return { lat, lng };
            }
        }

        console.log(`[geocode] No results for: "${address}"`);
        return null;
    } catch (error) {
        console.error(`[geocode] Error: ${error}`);
        return null;
    }
}

// Process address - geocode if coordinates missing
async function processAddress(
    addressData: any,
    fallbackAddress?: string
): Promise<{ address: string; lat: number; lng: number }> {
    // If already has valid coordinates
    if (addressData && typeof addressData === 'object') {
        if (addressData.lat && addressData.lng) {
            return {
                address: addressData.address || fallbackAddress || 'Unknown',
                lat: addressData.lat,
                lng: addressData.lng,
            };
        }
        // Has address but no coordinates - geocode it
        const addr = addressData.address || fallbackAddress || '';
        if (addr) {
            const coords = await geocodeAddress(addr);
            if (coords) {
                return { address: addr, ...coords };
            }
        }
    }

    // Fallback address string - geocode it
    if (fallbackAddress) {
        const coords = await geocodeAddress(fallbackAddress);
        if (coords) {
            return { address: fallbackAddress, ...coords };
        }
    }

    // Default fallback - Baruipur center
    return {
        address: fallbackAddress || 'Unknown location',
        lat: 22.36,
        lng: 88.43,
    };
}

serve(async (req: Request) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response(null, { headers: corsHeaders })
    }

    try {
        // Initialize Supabase client with service role
        const supabase = createClient(
            Deno.env.get('SUPABASE_URL')!,
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        )

        const { type, record, old_record, source_db } = await req.json()

        console.log(`[receive-order-sync] Event: ${type}, Source: ${source_db || 'unknown'}`)
        console.log(`[receive-order-sync] Order: ${record?.order_number || record?.id}`)

        // Only accept orders that are ready for delivery or later stages
        const trackableStatuses = [
            'pending', 'confirmed', 'preparing', 'ready_for_pickup',
            'picked_up', 'out_for_delivery', 'delivered'
        ]

        if (!trackableStatuses.includes(record.status)) {
            console.log(`[receive-order-sync] Skipping order with status: ${record.status}`)
            return new Response(
                JSON.stringify({
                    success: true,
                    message: 'Order status not trackable yet',
                    skipped: true
                }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Process addresses with automatic geocoding
        const pickupAddress = await processAddress(
            record.pickup_address,
            record.restaurant_address
        );

        const deliveryAddress = await processAddress(
            record.delivery_address,
            record.delivery_address_text || record.customer_address
        );

        // Transform the incoming order to match our delivery_orders schema
        const deliveryOrder = {
            id: record.id,
            order_number: record.order_number,

            // User/Customer info (from User DB)
            user_id: record.user_id,
            user_name: record.user_name || record.customer_name,
            user_phone: record.user_phone || record.customer_phone,

            // Kitchen/Restaurant info (from Cook DB or Admin DB)
            kitchen_id: record.kitchen_id,
            kitchen_name: record.kitchen_name || record.restaurant_name,
            kitchen_phone: record.kitchen_phone || record.restaurant_phone,

            // Status
            status: record.status,

            // Locations (with geocoded coordinates)
            pickup_address: pickupAddress,
            delivery_address: deliveryAddress,

            // Items for reference
            items: record.items || record.order_items,

            // Financial
            delivery_fee: record.delivery_fee,
            total_amount: record.total_amount || record.order_total,
            agent_earnings: record.agent_earnings || 25.00,

            // Timestamps
            created_at: record.created_at,
            ready_at: record.ready_at || new Date().toISOString(),

            // Sync metadata
            last_synced_at: new Date().toISOString(),
            last_synced_from: source_db || 'user_db',
        }

        // Upsert the order (insert or update if exists)
        const { data, error } = await supabase
            .from('delivery_orders')
            .upsert(deliveryOrder, {
                onConflict: 'id',
                ignoreDuplicates: false
            })
            .select()

        if (error) {
            console.error('[receive-order-sync] Error upserting order:', error)
            throw error
        }

        console.log(`[receive-order-sync] Successfully synced order: ${record.order_number}`)
        console.log(`[receive-order-sync] Pickup: ${pickupAddress.address} (${pickupAddress.lat}, ${pickupAddress.lng})`)
        console.log(`[receive-order-sync] Delivery: ${deliveryAddress.address} (${deliveryAddress.lat}, ${deliveryAddress.lng})`)

        return new Response(
            JSON.stringify({
                success: true,
                message: 'Order synced successfully',
                order_id: record.id,
                order_number: record.order_number,
                geocoded: {
                    pickup: pickupAddress,
                    delivery: deliveryAddress,
                }
            }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error: unknown) {
        const errorMessage = error instanceof Error ? error.message : 'Unknown error'
        console.error('[receive-order-sync] Error:', errorMessage)
        return new Response(
            JSON.stringify({
                success: false,
                error: errorMessage
            }),
            {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
        )
    }
})
