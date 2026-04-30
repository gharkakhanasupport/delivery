// ================================================================
// SYNC DELIVERY STATUS - Edge Function for Delivery DB
// This function syncs status updates FROM Delivery DB TO User DB & Admin DB
// Triggered by webhook on delivery_orders table UPDATE
// Deploy: supabase functions deploy sync-delivery-status
// ================================================================

// @ts-ignore - Deno imports
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
// @ts-ignore - Deno imports
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

declare const Deno: {
    env: {
        get(key: string): string | undefined;
    };
};

interface TargetDB {
    name: string;
    client: SupabaseClient;
}

// Target databases to sync to (configured via secrets)
const getTargetClients = (): TargetDB[] => {
    const targets: TargetDB[] = []

    // User DB
    const userDbUrl = Deno.env.get('USER_DB_URL')
    const userDbKey = Deno.env.get('USER_DB_SERVICE_KEY')
    if (userDbUrl && userDbKey) {
        targets.push({
            name: 'user_db',
            client: createClient(userDbUrl, userDbKey)
        })
    }

    // Admin DB
    const adminDbUrl = Deno.env.get('ADMIN_DB_URL')
    const adminDbKey = Deno.env.get('ADMIN_DB_SERVICE_KEY')
    if (adminDbUrl && adminDbKey) {
        targets.push({
            name: 'admin_db',
            client: createClient(adminDbUrl, adminDbKey)
        })
    }

    return targets
}

serve(async (req: Request) => {
    if (req.method === 'OPTIONS') {
        return new Response(null, { headers: corsHeaders })
    }

    try {
        const { type, record, old_record } = await req.json()

        console.log(`[sync-delivery-status] Event: ${type}`)
        console.log(`[sync-delivery-status] Order: ${record?.order_number}, Status: ${record?.status}`)

        // Only sync meaningful status changes
        if (type !== 'UPDATE' && type !== 'INSERT') {
            return new Response(
                JSON.stringify({ success: true, message: 'No sync needed for this event type' }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Check if status actually changed (for updates)
        if (type === 'UPDATE' && old_record?.status === record?.status &&
            !record?.current_location) {
            console.log('[sync-delivery-status] No relevant changes, skipping sync')
            return new Response(
                JSON.stringify({ success: true, message: 'No changes to sync' }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const targets = getTargetClients()

        if (targets.length === 0) {
            console.warn('[sync-delivery-status] No target databases configured!')
            return new Response(
                JSON.stringify({
                    success: false,
                    error: 'No target databases configured. Set USER_DB_URL/KEY and ADMIN_DB_URL/KEY secrets.'
                }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Prepare update data
        const updateData = {
            status: record.status,
            delivery_partner_id: record.delivery_partner_id,
            current_location: record.current_location,
            assigned_at: record.assigned_at,
            picked_up_at: record.picked_up_at,
            delivered_at: record.delivered_at,
        }

        // Sync to all target databases
        const results = await Promise.allSettled(
            targets.map(async ({ name, client }) => {
                console.log(`[sync-delivery-status] Syncing to ${name}...`)

                // Determine table name based on target
                const tableName = name === 'admin_db' ? 'all_orders' : 'orders'

                const { error } = await client
                    .from(tableName)
                    .update({
                        ...updateData,
                        last_synced_at: new Date().toISOString(),
                        last_synced_from: 'delivery_db',
                    })
                    .eq('id', record.id)

                if (error) {
                    console.error(`[sync-delivery-status] Error syncing to ${name}:`, error)
                    throw new Error(`${name}: ${error.message}`)
                }

                console.log(`[sync-delivery-status] Successfully synced to ${name}`)
                return { db: name, success: true }
            })
        )

        // Summarize results
        const summary = results.map((result, index) => ({
            db: targets[index].name,
            status: result.status,
            error: result.status === 'rejected' ? (result as PromiseRejectedResult).reason?.message : null
        }))

        const allSuccessful = results.every(r => r.status === 'fulfilled')

        return new Response(
            JSON.stringify({
                success: allSuccessful,
                message: allSuccessful ? 'Status synced to all databases' : 'Some syncs failed',
                results: summary
            }),
            {
                status: allSuccessful ? 200 : 207,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
        )

    } catch (error: unknown) {
        const errorMessage = error instanceof Error ? error.message : 'Unknown error'
        console.error('[sync-delivery-status] Error:', errorMessage)
        return new Response(
            JSON.stringify({ success: false, error: errorMessage }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
