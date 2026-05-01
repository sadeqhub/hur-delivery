-- =====================================================================================
-- PERFORMANCE OPTIMIZATIONS FOR LIMITED RESOURCES
-- Target: 0.5GB memory, shared CPU
-- =====================================================================================
-- 
-- This migration optimizes the database for better performance with limited resources.
-- Focus areas:
-- 1. Additional indexes for common query patterns
-- 2. Optimize frequently called functions
-- 3. Add materialized views for expensive queries (if needed)
-- 4. Optimize notification queries
-- =====================================================================================

-- =====================================================================================
-- 1. NOTIFICATIONS TABLE OPTIMIZATIONS
-- =====================================================================================

-- Composite index for unread notifications by user (most common query)
-- This is already covered by idx_notifications_unread, but we ensure it exists
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread_created 
ON notifications(user_id, is_read, created_at DESC)
WHERE is_read = FALSE;

COMMENT ON INDEX idx_notifications_user_unread_created IS 
'Optimizes queries for unread notifications by user, ordered by creation date. Used by notification polling and realtime subscriptions.';

-- Index for notification type filtering (if frequently queried)
CREATE INDEX IF NOT EXISTS idx_notifications_type_created 
ON notifications(type, created_at DESC);

COMMENT ON INDEX idx_notifications_type_created IS 
'Optimizes queries filtering notifications by type (e.g., order_assigned, order_delivered).';

-- =====================================================================================
-- 2. USERS TABLE OPTIMIZATIONS
-- =====================================================================================

-- Composite index for online status checks (used by status check timer)
-- This query runs frequently: SELECT is_online FROM users WHERE id = X
-- The primary key already covers this, but we add a partial index for online drivers
CREATE INDEX IF NOT EXISTS idx_users_online_drivers 
ON users(id, is_online)
WHERE role = 'driver';

COMMENT ON INDEX idx_users_online_drivers IS 
'Optimizes frequent online status checks for drivers. Used by status check timer.';

-- =====================================================================================
-- 3. WHATSAPP_LOCATION_REQUESTS TABLE OPTIMIZATIONS
-- =====================================================================================

-- Composite index for location request lookups (used by webhook)
-- Query pattern: WHERE customer_phone = X AND status IN (...) ORDER BY sent_at DESC
CREATE INDEX IF NOT EXISTS idx_whatsapp_location_requests_phone_status_sent 
ON whatsapp_location_requests(customer_phone, status, sent_at DESC);

COMMENT ON INDEX idx_whatsapp_location_requests_phone_status_sent IS 
'Optimizes location request lookups by phone number and status. Used by Wasso webhook.';

-- Index for order_id lookups (used for deduplication)
CREATE INDEX IF NOT EXISTS idx_whatsapp_location_requests_order_id 
ON whatsapp_location_requests(order_id);

COMMENT ON INDEX idx_whatsapp_location_requests_order_id IS 
'Optimizes location request lookups by order_id. Used for deduplication checks.';

-- =====================================================================================
-- 4. OPTIMIZE FREQUENTLY CALLED FUNCTIONS
-- =====================================================================================

-- Optimize app_check_expired_orders() to use indexes more efficiently
-- This function is called every 30 seconds (reduced from 10s)
-- Note: Must drop first because we're changing return type from JSONB to JSONB (keeping same type but optimizing)
-- Actually, let's keep JSONB return type for compatibility with existing app code
DROP FUNCTION IF EXISTS app_check_expired_orders();

CREATE FUNCTION app_check_expired_orders()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_processed INTEGER := 0;
  v_start_time TIMESTAMPTZ;
  v_end_time TIMESTAMPTZ;
  v_execution_time_ms DOUBLE PRECISION;
BEGIN
  v_start_time := clock_timestamp();
  
  -- Call auto_reject_expired_orders() which handles everything efficiently
  -- This function uses indexes and processes expired orders
  SELECT auto_reject_expired_orders() INTO v_processed;
  
  v_end_time := clock_timestamp();
  v_execution_time_ms := EXTRACT(MILLISECONDS FROM (v_end_time - v_start_time));
  
  -- Return JSON response (keeping same format for app compatibility)
  RETURN jsonb_build_object(
    'success', true,
    'processed', v_processed,
    'execution_time_ms', v_execution_time_ms,
    'timestamp', NOW()
  );
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but return success=false
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM,
      'processed', 0,
      'timestamp', NOW()
    );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION app_check_expired_orders() TO authenticated;
GRANT EXECUTE ON FUNCTION app_check_expired_orders() TO anon;

COMMENT ON FUNCTION app_check_expired_orders() IS 
'Checks and processes expired orders. Returns JSONB with success status and processed count. Optimized to use indexes. Called every 30 seconds (reduced from 10s for performance).';

-- =====================================================================================
-- 5. ANALYZE TABLES TO UPDATE STATISTICS
-- =====================================================================================

-- Update table statistics for better query planning
ANALYZE notifications;
ANALYZE users;
ANALYZE whatsapp_location_requests;
ANALYZE orders;

-- =====================================================================================
-- 6. VACUUM AND REINDEX (if needed - run during low traffic)
-- =====================================================================================

-- Note: VACUUM and REINDEX should be run manually during low traffic periods
-- They are commented out here to avoid blocking during migration
-- Uncomment and run during maintenance window if needed:

-- VACUUM ANALYZE notifications;
-- VACUUM ANALYZE users;
-- VACUUM ANALYZE orders;
-- REINDEX TABLE notifications;
-- REINDEX TABLE users;

-- =====================================================================================
-- 7. QUERY PERFORMANCE MONITORING
-- =====================================================================================

-- Enable pg_stat_statements if not already enabled (for monitoring)
-- This helps identify slow queries in production
-- Note: This requires superuser privileges and may already be enabled

-- =====================================================================================
-- VERIFICATION QUERIES (commented out - run manually to verify)
-- =====================================================================================

/*
-- Verify new indexes were created
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
    AND tablename IN ('notifications', 'users', 'whatsapp_location_requests')
    AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- Check index sizes
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
    AND tablename IN ('notifications', 'users', 'whatsapp_location_requests')
ORDER BY pg_relation_size(indexrelid) DESC;

-- Check table sizes
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS indexes_size
FROM pg_tables
WHERE schemaname = 'public'
    AND tablename IN ('orders', 'notifications', 'users', 'whatsapp_location_requests')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
*/

