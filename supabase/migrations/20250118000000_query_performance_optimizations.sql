-- =====================================================================================
-- QUERY PERFORMANCE OPTIMIZATIONS
-- Based on pg_stat_statements analysis showing slow queries
-- =====================================================================================
-- 
-- Issues Identified:
-- 1. Orders queries filtering by driver_id + status need composite indexes
-- 2. driver_locations queries need better indexing for (driver_id, created_at DESC)
-- 3. Merchant orders queries need (merchant_id, created_at DESC) index
-- 4. update_order_timeout_states() function can be optimized
-- 5. Missing indexes for common query patterns
--
-- Performance Data:
-- - Orders query with driver_id + status: 220K calls, 2.2ms mean (can improve)
-- - driver_locations query: 729 calls, 216ms mean (needs optimization)
-- - Merchant orders query: 255K calls, 1.5ms mean (can improve)
-- =====================================================================================

-- =====================================================================================
-- 1. ORDERS TABLE INDEXES
-- =====================================================================================

-- Composite index for driver orders filtered by status
-- Query pattern: WHERE driver_id = X AND status IN (...) ORDER BY created_at DESC
CREATE INDEX IF NOT EXISTS idx_orders_driver_status_created 
ON orders(driver_id, status, created_at DESC)
WHERE driver_id IS NOT NULL;

COMMENT ON INDEX idx_orders_driver_status_created IS 
'Optimizes driver orders queries filtering by status and ordering by created_at. Used by PostgREST queries with driver_id and status filters.';

-- Composite index for merchant orders ordered by created_at
-- Query pattern: WHERE merchant_id = X ORDER BY created_at DESC
CREATE INDEX IF NOT EXISTS idx_orders_merchant_created 
ON orders(merchant_id, created_at DESC);

COMMENT ON INDEX idx_orders_merchant_created IS 
'Optimizes merchant orders queries ordering by created_at DESC. Used by merchant dashboard.';

-- Composite index for pending orders with driver assignment
-- Query pattern: WHERE status = 'pending' AND driver_id IS NOT NULL AND driver_assigned_at IS NOT NULL
CREATE INDEX IF NOT EXISTS idx_orders_pending_driver_assigned 
ON orders(status, driver_id, driver_assigned_at) 
WHERE status = 'pending' AND driver_id IS NOT NULL AND driver_assigned_at IS NOT NULL;

COMMENT ON INDEX idx_orders_pending_driver_assigned IS 
'Optimizes update_order_timeout_states() function that queries pending orders with assigned drivers.';

-- Index for orders by status (for general filtering)
-- This already exists but we ensure it's there
CREATE INDEX IF NOT EXISTS idx_orders_status_created 
ON orders(status, created_at DESC);

COMMENT ON INDEX idx_orders_status_created IS 
'Optimizes queries filtering by status and ordering by created_at.';

-- =====================================================================================
-- 2. DRIVER_LOCATIONS TABLE INDEXES
-- =====================================================================================

-- Composite index for driver location history queries
-- Query pattern: WHERE driver_id = X ORDER BY created_at DESC LIMIT N
CREATE INDEX IF NOT EXISTS idx_driver_locations_driver_created_desc 
ON driver_locations(driver_id, created_at DESC);

COMMENT ON INDEX idx_driver_locations_driver_created_desc IS 
'Optimizes driver location history queries. Addresses slow query with 216ms mean time.';

-- Drop the old single-column index if it exists (covered by composite)
-- We keep idx_driver_locations_driver as it might be used elsewhere, but the composite is more efficient

-- =====================================================================================
-- 3. ORDER_TIMEOUT_STATE TABLE INDEXES
-- =====================================================================================

-- Composite index for timeout state queries
-- Query pattern: SELECT * FROM order_timeout_state ORDER BY remaining_seconds ASC
CREATE INDEX IF NOT EXISTS idx_order_timeout_state_expired_remaining 
ON order_timeout_state(expired, remaining_seconds) 
WHERE NOT expired;

COMMENT ON INDEX idx_order_timeout_state_expired_remaining IS 
'Optimizes timeout state queries ordering by remaining seconds for non-expired orders.';

-- =====================================================================================
-- 4. OPTIMIZE update_order_timeout_states() FUNCTION
-- =====================================================================================

-- Improved version that uses the new index more efficiently
CREATE OR REPLACE FUNCTION update_order_timeout_states()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order RECORD;
  v_elapsed INTEGER;
  v_remaining INTEGER;
  v_updated INTEGER := 0;
BEGIN
  -- Use the new composite index for faster lookups
  -- This query now benefits from idx_orders_pending_driver_assigned
  FOR v_order IN
    SELECT id, driver_id, driver_assigned_at
    FROM orders
    WHERE status = 'pending'
      AND driver_id IS NOT NULL
      AND driver_assigned_at IS NOT NULL
    -- Order by driver_assigned_at to process oldest first (more likely to need updates)
    ORDER BY driver_assigned_at ASC
  LOOP
    -- Calculate elapsed and remaining time
    v_elapsed := EXTRACT(EPOCH FROM (NOW() - v_order.driver_assigned_at))::INTEGER;
    v_remaining := GREATEST(0, 30 - v_elapsed);
    
    -- Use DELETE then INSERT (simpler and works without constraints)
    DELETE FROM order_timeout_state WHERE order_id = v_order.id;
    
    INSERT INTO order_timeout_state (
      order_id,
      driver_id,
      assigned_at,
      remaining_seconds,
      expired,
      updated_at
    ) VALUES (
      v_order.id,
      v_order.driver_id,
      v_order.driver_assigned_at,
      v_remaining,
      (v_remaining = 0),
      NOW()
    );
    
    v_updated := v_updated + 1;
  END LOOP;
  
  -- Delete entries for orders that are no longer pending with driver
  -- This query is fast with the order_id primary key index
  DELETE FROM order_timeout_state
  WHERE order_id NOT IN (
    SELECT id FROM orders 
    WHERE status = 'pending' AND driver_id IS NOT NULL AND driver_assigned_at IS NOT NULL
  );
  
  RETURN v_updated;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail
    RAISE WARNING 'Error in update_order_timeout_states: %', SQLERRM;
    RETURN 0;
END;
$$;

COMMENT ON FUNCTION update_order_timeout_states() IS 
'Updates timeout states for all pending orders with assigned drivers. Optimized to use new composite indexes.';

-- =====================================================================================
-- 5. SCHEDULED_ORDERS TABLE INDEXES
-- =====================================================================================

-- Note: There's a schema mismatch - the scheduled_orders table uses scheduled_at (single column),
-- but process_scheduled_orders() function references scheduled_date + scheduled_time which don't exist.
-- This index optimizes queries on the actual table structure (scheduled_at).

-- Add composite index if not exists for scheduled order queries
-- This helps process_scheduled_orders() function (123K calls, 4.5ms mean)
-- The existing index idx_scheduled_orders_scheduled_at already exists with WHERE clause,
-- but we add a composite one for better performance when filtering by status
CREATE INDEX IF NOT EXISTS idx_scheduled_orders_status_scheduled_at 
ON scheduled_orders(status, scheduled_at) 
WHERE status = 'scheduled';

COMMENT ON INDEX idx_scheduled_orders_status_scheduled_at IS 
'Optimizes scheduled order queries filtering by status and scheduled_at. Note: process_scheduled_orders() function may need update to use scheduled_at instead of scheduled_date + scheduled_time.';

-- =====================================================================================
-- 6. ORDER_ITEMS TABLE INDEXES (for joins)
-- =====================================================================================

-- Ensure order_items has proper index for order_id joins
-- This is critical for the complex orders queries with items joins
-- The index should already exist, but we verify
CREATE INDEX IF NOT EXISTS idx_order_items_order_id_created 
ON order_items(order_id, id);

COMMENT ON INDEX idx_order_items_order_id_created IS 
'Optimizes order_items joins in PostgREST queries that fetch orders with items.';

-- =====================================================================================
-- 7. ANALYZE TABLES TO UPDATE STATISTICS
-- =====================================================================================

-- Update table statistics so the query planner can make better decisions
ANALYZE orders;
ANALYZE driver_locations;
ANALYZE order_timeout_state;
ANALYZE order_items;
ANALYZE scheduled_orders;
ANALYZE users;

-- =====================================================================================
-- 8. DOCUMENTATION
-- =====================================================================================

COMMENT ON INDEX idx_orders_driver_status_created IS 
'QUERY PERFORMANCE: Optimizes driver orders queries with status filter. 
Usage: SELECT * FROM orders WHERE driver_id = X AND status IN (...) ORDER BY created_at DESC.
Improves: ~220K calls with 2.2ms mean time.';

COMMENT ON INDEX idx_driver_locations_driver_created_desc IS 
'QUERY PERFORMANCE: Optimizes driver location history queries.
Usage: SELECT * FROM driver_locations WHERE driver_id = X ORDER BY created_at DESC LIMIT N.
Improves: 729 calls with 216ms mean time (significant improvement expected).';

-- =====================================================================================
-- VERIFICATION QUERIES (commented out - run manually to verify indexes)
-- =====================================================================================

/*
-- Verify indexes were created
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
    AND tablename IN ('orders', 'driver_locations', 'order_timeout_state', 'order_items', 'scheduled_orders')
ORDER BY tablename, indexname;

-- Check index sizes
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
    AND tablename IN ('orders', 'driver_locations', 'order_timeout_state', 'order_items', 'scheduled_orders')
ORDER BY pg_relation_size(indexrelid) DESC;

-- Check index usage (after running queries)
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
    AND tablename IN ('orders', 'driver_locations', 'order_timeout_state')
ORDER BY idx_scan DESC;
*/

