-- ============================================================
-- Delivery DB production hardening: RLS and private KYC storage
-- ============================================================
-- Service-role Edge Functions still bypass RLS for server-side sync.

CREATE OR REPLACE FUNCTION public.gkk_delivery_is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', '') IN (
    'admin',
    'super_admin',
    'support_admin'
  )
  OR COALESCE(auth.jwt() ->> 'role', '') IN (
    'admin',
    'super_admin',
    'support_admin'
  );
$$;

-- Remove broad sync/test insert policies.
DROP POLICY IF EXISTS "allow_insert_delivery_orders" ON public.delivery_orders;
DROP POLICY IF EXISTS "service_insert_orders" ON public.delivery_orders;

-- Delivery orders: available orders can be read by verified/active agents;
-- assigned orders are visible only to the assigned agent. Inserts are backend-only
-- via service role, so no broad client insert policy is recreated.
DROP POLICY IF EXISTS "agents_see_available_orders" ON public.delivery_orders;
DROP POLICY IF EXISTS "agents_update_own_orders" ON public.delivery_orders;

CREATE POLICY "delivery_orders_select_available_or_assigned"
  ON public.delivery_orders
  FOR SELECT
  TO authenticated
  USING (
    public.gkk_delivery_is_admin()
    OR delivery_partner_id = auth.uid()
    OR (
      delivery_partner_id IS NULL
      AND status IN ('pending', 'confirmed', 'preparing', 'ready', 'ready_for_pickup')
      AND EXISTS (
        SELECT 1
        FROM public.delivery_profiles p
        WHERE p.id = auth.uid()
          AND p.is_active = true
          AND p.verification_status IN ('verified', 'approved')
      )
    )
  );

CREATE POLICY "delivery_orders_update_assigned_agent_or_admin"
  ON public.delivery_orders
  FOR UPDATE
  TO authenticated
  USING (
    public.gkk_delivery_is_admin()
    OR delivery_partner_id = auth.uid()
  )
  WITH CHECK (
    public.gkk_delivery_is_admin()
    OR delivery_partner_id = auth.uid()
  );

CREATE POLICY "delivery_orders_delete_admin_only"
  ON public.delivery_orders
  FOR DELETE
  TO authenticated
  USING (public.gkk_delivery_is_admin());

-- KYC rows: owner/admin only. Keep insert/update explicitly scoped.
DROP POLICY IF EXISTS "agents_own_kyc" ON public.kyc_documents;
DROP POLICY IF EXISTS "Users can view own kyc documents" ON public.kyc_documents;

CREATE POLICY "kyc_documents_select_owner_or_admin"
  ON public.kyc_documents
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR public.gkk_delivery_is_admin());

CREATE POLICY "kyc_documents_insert_owner_or_admin"
  ON public.kyc_documents
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid() OR public.gkk_delivery_is_admin());

CREATE POLICY "kyc_documents_update_owner_or_admin"
  ON public.kyc_documents
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid() OR public.gkk_delivery_is_admin())
  WITH CHECK (user_id = auth.uid() OR public.gkk_delivery_is_admin());

CREATE POLICY "kyc_documents_delete_admin_only"
  ON public.kyc_documents
  FOR DELETE
  TO authenticated
  USING (public.gkk_delivery_is_admin());

-- Storage: support both historical bucket spellings, keep them private.
UPDATE storage.buckets
SET public = false
WHERE id IN ('kyc_documents', 'kyc-documents');

DROP POLICY IF EXISTS "Public upload kyc documents" ON storage.objects;
DROP POLICY IF EXISTS "Public read kyc documents" ON storage.objects;
DROP POLICY IF EXISTS "kyc_documents_insert_owner_or_admin" ON storage.objects;
DROP POLICY IF EXISTS "kyc_documents_select_owner_or_admin" ON storage.objects;
DROP POLICY IF EXISTS "kyc_documents_update_owner_or_admin" ON storage.objects;
DROP POLICY IF EXISTS "kyc_documents_delete_owner_or_admin" ON storage.objects;

CREATE POLICY "kyc_storage_insert_owner_or_admin"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id IN ('kyc_documents', 'kyc-documents')
    AND (
      public.gkk_delivery_is_admin()
      OR owner = auth.uid()
      OR (storage.foldername(name))[1] = auth.uid()::text
    )
  );

CREATE POLICY "kyc_storage_select_owner_or_admin"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id IN ('kyc_documents', 'kyc-documents')
    AND (
      public.gkk_delivery_is_admin()
      OR owner = auth.uid()
      OR (storage.foldername(name))[1] = auth.uid()::text
    )
  );

CREATE POLICY "kyc_storage_update_owner_or_admin"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id IN ('kyc_documents', 'kyc-documents')
    AND (
      public.gkk_delivery_is_admin()
      OR owner = auth.uid()
      OR (storage.foldername(name))[1] = auth.uid()::text
    )
  )
  WITH CHECK (
    bucket_id IN ('kyc_documents', 'kyc-documents')
    AND (
      public.gkk_delivery_is_admin()
      OR owner = auth.uid()
      OR (storage.foldername(name))[1] = auth.uid()::text
    )
  );

CREATE POLICY "kyc_storage_delete_owner_or_admin"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id IN ('kyc_documents', 'kyc-documents')
    AND (
      public.gkk_delivery_is_admin()
      OR owner = auth.uid()
      OR (storage.foldername(name))[1] = auth.uid()::text
    )
  );
