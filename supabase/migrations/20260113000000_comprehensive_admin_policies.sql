-- =====================================================================================
-- COMPREHENSIVE ADMIN POLICIES FOR ADMIN DASHBOARD
-- =====================================================================================
-- This migration adds comprehensive admin policies for all tables to allow
-- admins to read, write, update, and delete data as needed for the admin dashboard.
-- All policies check that the user has role = 'admin' in the users table.
-- =====================================================================================

-- Helper function to check if user is admin (reusable)
CREATE OR REPLACE FUNCTION is_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users 
    WHERE id = user_id AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- ORDERS TABLE - Admin Policies
-- =====================================================================================

-- Admin can insert orders
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'orders' 
    AND policyname = 'orders_admin_insert'
  ) THEN
    CREATE POLICY "orders_admin_insert" ON orders
      FOR INSERT
      WITH CHECK (is_admin(auth.uid()));
  END IF;
END $$;

-- Admin can update orders
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'orders' 
    AND policyname = 'orders_admin_update'
  ) THEN
    CREATE POLICY "orders_admin_update" ON orders
      FOR UPDATE
      USING (is_admin(auth.uid()));
  END IF;
END $$;

-- Admin can delete orders
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'orders' 
    AND policyname = 'orders_admin_delete'
  ) THEN
    CREATE POLICY "orders_admin_delete" ON orders
      FOR DELETE
      USING (is_admin(auth.uid()));
  END IF;
END $$;

-- =====================================================================================
-- ORDER_ITEMS TABLE - Admin Policies
-- =====================================================================================

-- Admin can insert order items
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'order_items' 
    AND policyname = 'order_items_admin_insert'
  ) THEN
    CREATE POLICY "order_items_admin_insert" ON order_items
      FOR INSERT
      WITH CHECK (is_admin(auth.uid()));
  END IF;
END $$;

-- Admin can update order items
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'order_items' 
    AND policyname = 'order_items_admin_update'
  ) THEN
    CREATE POLICY "order_items_admin_update" ON order_items
      FOR UPDATE
      USING (is_admin(auth.uid()));
  END IF;
END $$;

-- Admin can delete order items
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'order_items' 
    AND policyname = 'order_items_admin_delete'
  ) THEN
    CREATE POLICY "order_items_admin_delete" ON order_items
      FOR DELETE
      USING (is_admin(auth.uid()));
  END IF;
END $$;

-- =====================================================================================
-- ORDER_REJECTED_DRIVERS TABLE - Admin Policies
-- =====================================================================================

-- Admin can view all rejected drivers
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'order_rejected_drivers' 
    AND policyname = 'order_rejected_drivers_admin_all'
  ) THEN
    CREATE POLICY "order_rejected_drivers_admin_all" ON order_rejected_drivers
      FOR ALL
      USING (is_admin(auth.uid()));
  END IF;
END $$;

-- =====================================================================================
-- ORDER_ASSIGNMENTS TABLE - Admin Policies
-- =====================================================================================

-- Admin can insert order assignments
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'order_assignments' 
    AND policyname = 'order_assignments_admin_insert'
  ) THEN
    CREATE POLICY "order_assignments_admin_insert" ON order_assignments
      FOR INSERT
      WITH CHECK (is_admin(auth.uid()));
  END IF;
END $$;

-- Admin can update order assignments
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'order_assignments' 
    AND policyname = 'order_assignments_admin_update'
  ) THEN
    CREATE POLICY "order_assignments_admin_update" ON order_assignments
      FOR UPDATE
      USING (is_admin(auth.uid()));
  END IF;
END $$;

-- Admin can delete order assignments
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'order_assignments' 
    AND policyname = 'order_assignments_admin_delete'
  ) THEN
    CREATE POLICY "order_assignments_admin_delete" ON order_assignments
      FOR DELETE
      USING (is_admin(auth.uid()));
  END IF;
END $$;

-- =====================================================================================
-- NOTIFICATIONS TABLE - Admin Policies
-- =====================================================================================

-- Admin can view all notifications
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'notifications' 
    AND policyname = 'notifications_admin_view_all'
  ) THEN
    CREATE POLICY "notifications_admin_view_all" ON notifications
      FOR SELECT
      USING (is_admin(auth.uid()));
  END IF;
END $$;

-- Admin can insert notifications
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'notifications' 
    AND policyname = 'notifications_admin_insert'
  ) THEN
    CREATE POLICY "notifications_admin_insert" ON notifications
      FOR INSERT
      WITH CHECK (is_admin(auth.uid()));
  END IF;
END $$;

-- Admin can update notifications
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'notifications' 
    AND policyname = 'notifications_admin_update'
  ) THEN
    CREATE POLICY "notifications_admin_update" ON notifications
      FOR UPDATE
      USING (is_admin(auth.uid()));
  END IF;
END $$;

-- Admin can delete notifications
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'notifications' 
    AND policyname = 'notifications_admin_delete'
  ) THEN
    CREATE POLICY "notifications_admin_delete" ON notifications
      FOR DELETE
      USING (is_admin(auth.uid()));
  END IF;
END $$;

-- =====================================================================================
-- DRIVER_LOCATIONS TABLE - Admin Policies
-- =====================================================================================

-- Admin can view all driver locations
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'driver_locations' 
    AND policyname = 'driver_locations_admin_view_all'
  ) THEN
    CREATE POLICY "driver_locations_admin_view_all" ON driver_locations
      FOR SELECT
      USING (is_admin(auth.uid()));
  END IF;
END $$;

-- Admin can update driver locations
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'driver_locations' 
    AND policyname = 'driver_locations_admin_update'
  ) THEN
    CREATE POLICY "driver_locations_admin_update" ON driver_locations
      FOR UPDATE
      USING (is_admin(auth.uid()));
  END IF;
END $$;

-- Admin can delete driver locations
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'driver_locations' 
    AND policyname = 'driver_locations_admin_delete'
  ) THEN
    CREATE POLICY "driver_locations_admin_delete" ON driver_locations
      FOR DELETE
      USING (is_admin(auth.uid()));
  END IF;
END $$;

-- =====================================================================================
-- SCHEDULED_ORDERS TABLE - Admin Policies
-- =====================================================================================

-- Admin can insert scheduled orders
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'scheduled_orders' 
    AND policyname = 'scheduled_orders_admin_insert'
  ) THEN
    CREATE POLICY "scheduled_orders_admin_insert" ON scheduled_orders
      FOR INSERT
      WITH CHECK (is_admin(auth.uid()));
  END IF;
END $$;

-- Admin can update scheduled orders
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'scheduled_orders' 
    AND policyname = 'scheduled_orders_admin_update'
  ) THEN
    CREATE POLICY "scheduled_orders_admin_update" ON scheduled_orders
      FOR UPDATE
      USING (is_admin(auth.uid()));
  END IF;
END $$;

-- Admin can delete scheduled orders
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'scheduled_orders' 
    AND policyname = 'scheduled_orders_admin_delete'
  ) THEN
    CREATE POLICY "scheduled_orders_admin_delete" ON scheduled_orders
      FOR DELETE
      USING (is_admin(auth.uid()));
  END IF;
END $$;

-- =====================================================================================
-- MERCHANT_WALLETS TABLE - Admin Policies
-- =====================================================================================

-- Admin can view all merchant wallets
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'merchant_wallets' 
    AND policyname = 'merchant_wallets_admin_all'
  ) THEN
    CREATE POLICY "merchant_wallets_admin_all" ON merchant_wallets
      FOR ALL
      USING (is_admin(auth.uid()));
  END IF;
END $$;

-- =====================================================================================
-- WALLET_TRANSACTIONS TABLE - Admin Policies
-- =====================================================================================

-- Admin can view all wallet transactions
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'wallet_transactions' 
    AND policyname = 'wallet_transactions_admin_all'
  ) THEN
    CREATE POLICY "wallet_transactions_admin_all" ON wallet_transactions
      FOR ALL
      USING (is_admin(auth.uid()));
  END IF;
END $$;

-- =====================================================================================
-- DRIVER_WALLETS TABLE - Admin Policies
-- =====================================================================================

-- Admin can view all driver wallets (if table exists)
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'driver_wallets') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE schemaname = 'public' 
      AND tablename = 'driver_wallets' 
      AND policyname = 'driver_wallets_admin_all'
    ) THEN
      CREATE POLICY "driver_wallets_admin_all" ON driver_wallets
        FOR ALL
        USING (is_admin(auth.uid()));
    END IF;
  END IF;
END $$;

-- =====================================================================================
-- DRIVER_WALLET_TRANSACTIONS TABLE - Admin Policies
-- =====================================================================================

-- Admin can view all driver wallet transactions (if table exists)
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'driver_wallet_transactions') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE schemaname = 'public' 
      AND tablename = 'driver_wallet_transactions' 
      AND policyname = 'driver_wallet_transactions_admin_all'
    ) THEN
      CREATE POLICY "driver_wallet_transactions_admin_all" ON driver_wallet_transactions
        FOR ALL
        USING (is_admin(auth.uid()));
    END IF;
  END IF;
END $$;

-- =====================================================================================
-- DRIVER_ONLINE_HOURS TABLE - Admin Policies
-- =====================================================================================

-- Admin can view all driver online hours (if table exists)
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'driver_online_hours') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE schemaname = 'public' 
      AND tablename = 'driver_online_hours' 
      AND policyname = 'driver_online_hours_admin_all'
    ) THEN
      CREATE POLICY "driver_online_hours_admin_all" ON driver_online_hours
        FOR ALL
        USING (is_admin(auth.uid()));
    END IF;
  END IF;
END $$;

-- =====================================================================================
-- EMERGENCY_ALERTS TABLE - Admin Policies
-- =====================================================================================

-- Admin can view all emergency alerts (if table exists)
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'emergency_alerts') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE schemaname = 'public' 
      AND tablename = 'emergency_alerts' 
      AND policyname = 'emergency_alerts_admin_all'
    ) THEN
      CREATE POLICY "emergency_alerts_admin_all" ON emergency_alerts
        FOR ALL
        USING (is_admin(auth.uid()));
    END IF;
  END IF;
END $$;

-- =====================================================================================
-- CITY_SETTINGS TABLE - Admin Policies (already has policies, but ensure INSERT/DELETE)
-- =====================================================================================

-- Admin can insert city settings (if table exists)
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'city_settings') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE schemaname = 'public' 
      AND tablename = 'city_settings' 
      AND policyname = 'city_settings_admin_insert'
    ) THEN
      CREATE POLICY "city_settings_admin_insert" ON city_settings
        FOR INSERT
        WITH CHECK (is_admin(auth.uid()));
    END IF;
    
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE schemaname = 'public' 
      AND tablename = 'city_settings' 
      AND policyname = 'city_settings_admin_delete'
    ) THEN
      CREATE POLICY "city_settings_admin_delete" ON city_settings
        FOR DELETE
        USING (is_admin(auth.uid()));
    END IF;
  END IF;
END $$;

-- =====================================================================================
-- USERS TABLE - Admin Insert Policy (if needed)
-- =====================================================================================

-- Admin can insert users (for manual user creation)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'users' 
    AND policyname = 'users_admin_insert'
  ) THEN
    CREATE POLICY "users_admin_insert" ON users
      FOR INSERT
      WITH CHECK (is_admin(auth.uid()));
  END IF;
END $$;

-- Admin can delete users (with caution)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'users' 
    AND policyname = 'users_admin_delete'
  ) THEN
    CREATE POLICY "users_admin_delete" ON users
      FOR DELETE
      USING (is_admin(auth.uid()));
  END IF;
END $$;

-- =====================================================================================
-- SYSTEM_SETTINGS TABLE - Admin Insert/Delete Policies
-- =====================================================================================

-- Admin can insert system settings
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'system_settings' 
    AND policyname = 'system_settings_admin_insert'
  ) THEN
    CREATE POLICY "system_settings_admin_insert" ON system_settings
      FOR INSERT
      WITH CHECK (is_admin(auth.uid()));
  END IF;
END $$;

-- Admin can delete system settings
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'system_settings' 
    AND policyname = 'system_settings_admin_delete'
  ) THEN
    CREATE POLICY "system_settings_admin_delete" ON system_settings
      FOR DELETE
      USING (is_admin(auth.uid()));
  END IF;
END $$;

-- =====================================================================================
-- GRANT PERMISSIONS
-- =====================================================================================

-- Grant execute permission on is_admin function
GRANT EXECUTE ON FUNCTION is_admin(UUID) TO authenticated, anon;

-- =====================================================================================
-- COMMENTS
-- =====================================================================================

COMMENT ON FUNCTION is_admin(UUID) IS 'Helper function to check if a user is an admin. Used by RLS policies.';
















