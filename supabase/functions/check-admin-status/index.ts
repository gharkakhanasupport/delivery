import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { email } = await req.json()

    if (!email) {
      throw new Error('Email is required')
    }

    const adminDbUrl = Deno.env.get('ADMIN_DB_URL')
    const adminDbKey = Deno.env.get('ADMIN_DB_SERVICE_KEY')

    if (!adminDbUrl || !adminDbKey) {
      throw new Error('Server configuration error: Admin DB credentials missing')
    }

    const adminClient = createClient(adminDbUrl, adminDbKey)

    // Check candidate_profiles
    const { data: profile, error: profileError } = await adminClient
      .from('candidate_profiles')
      .select('id')
      .eq('email', email)
      .maybeSingle()

    if (profileError) throw profileError
    if (!profile) {
       return new Response(JSON.stringify({ status: 'not_found' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })
    }

    // Check admin_candidates
    const { data: candidate, error: candidateError } = await adminClient
      .from('admin_candidates')
      .select('status')
      .eq('candidate_profile_id', profile.id)
      .maybeSingle()

    if (candidateError) throw candidateError

    return new Response(JSON.stringify({ status: candidate?.status || 'not_found' }), {
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
