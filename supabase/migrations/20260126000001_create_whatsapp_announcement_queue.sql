-- =====================================================================================
-- WHATSAPP ANNOUNCEMENT QUEUE
-- =====================================================================================
-- Queue table for processing WhatsApp announcements asynchronously
-- =====================================================================================

-- Create queue table for pending announcements
CREATE TABLE IF NOT EXISTS whatsapp_announcement_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  phone TEXT NOT NULL,
  message_hash TEXT NOT NULL,
  message_content TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'sent', 'failed')),
  attempts INTEGER DEFAULT 0,
  last_attempt_at TIMESTAMPTZ,
  error_message TEXT,
  wasso_message_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ
);

-- Create indexes for efficient queue processing
CREATE INDEX IF NOT EXISTS idx_whatsapp_queue_status ON whatsapp_announcement_queue(status, created_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_whatsapp_queue_user_hash ON whatsapp_announcement_queue(user_id, message_hash);

-- Function to get next batch of pending messages
CREATE OR REPLACE FUNCTION get_next_announcement_batch(
  p_batch_size INTEGER DEFAULT 20
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  phone TEXT,
  message_hash TEXT,
  message_content TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Mark messages as processing and return them
  RETURN QUERY
  UPDATE whatsapp_announcement_queue
  SET 
    status = 'processing',
    last_attempt_at = NOW(),
    attempts = attempts + 1
  FROM (
    SELECT q.id
    FROM whatsapp_announcement_queue q
    WHERE q.status = 'pending'
    ORDER BY q.created_at ASC
    LIMIT p_batch_size
    FOR UPDATE SKIP LOCKED
  ) batch
  WHERE whatsapp_announcement_queue.id = batch.id
  RETURNING 
    whatsapp_announcement_queue.id,
    whatsapp_announcement_queue.user_id,
    whatsapp_announcement_queue.phone,
    whatsapp_announcement_queue.message_hash,
    whatsapp_announcement_queue.message_content;
END;
$$;

-- Function to mark message as sent
CREATE OR REPLACE FUNCTION mark_announcement_sent(
  p_queue_id UUID,
  p_wasso_message_id TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE whatsapp_announcement_queue
  SET 
    status = 'sent',
    wasso_message_id = p_wasso_message_id,
    processed_at = NOW()
  WHERE id = p_queue_id;
  
  -- Also record in announcements tracking table
  INSERT INTO whatsapp_announcements (user_id, phone, message_hash, message_content, wasso_message_id)
  SELECT user_id, phone, message_hash, message_content, p_wasso_message_id
  FROM whatsapp_announcement_queue
  WHERE id = p_queue_id
  ON CONFLICT DO NOTHING;
END;
$$;

-- Function to mark message as failed
CREATE OR REPLACE FUNCTION mark_announcement_failed(
  p_queue_id UUID,
  p_error_message TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE whatsapp_announcement_queue
  SET 
    status = CASE 
      WHEN attempts >= 3 THEN 'failed'
      ELSE 'pending' -- Retry if attempts < 3
    END,
    error_message = p_error_message,
    last_attempt_at = NOW()
  WHERE id = p_queue_id;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_next_announcement_batch(INTEGER) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION mark_announcement_sent(UUID, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION mark_announcement_failed(UUID, TEXT) TO authenticated, anon;

-- Add comments
COMMENT ON TABLE whatsapp_announcement_queue IS 'Queue for processing WhatsApp announcements asynchronously to avoid timeout';
COMMENT ON FUNCTION get_next_announcement_batch IS 'Gets next batch of pending announcements and marks them as processing';
COMMENT ON FUNCTION mark_announcement_sent IS 'Marks announcement as sent and records in tracking table';
COMMENT ON FUNCTION mark_announcement_failed IS 'Marks announcement as failed or resets to pending for retry';

