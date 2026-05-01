-- =====================================================================================
-- WHATSAPP ANNOUNCEMENTS TRACKING
-- =====================================================================================
-- Tracks WhatsApp announcements sent to users to prevent duplicate sends
-- =====================================================================================

-- Create table to track WhatsApp announcements
CREATE TABLE IF NOT EXISTS whatsapp_announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  phone TEXT NOT NULL,
  message_hash TEXT NOT NULL, -- Hash of the message content for quick comparison
  message_content TEXT NOT NULL, -- Store actual message for reference
  sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  wasso_message_id TEXT, -- Message ID from Wasso API if available
  
  -- Indexes for performance
  CONSTRAINT idx_whatsapp_announcements_user_message UNIQUE(user_id, message_hash, sent_at)
);

-- Create indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_whatsapp_announcements_user_id ON whatsapp_announcements(user_id);
CREATE INDEX IF NOT EXISTS idx_whatsapp_announcements_sent_at ON whatsapp_announcements(sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_whatsapp_announcements_user_message_hash ON whatsapp_announcements(user_id, message_hash, sent_at DESC);

-- Function to check if user was notified with same message in last hour
CREATE OR REPLACE FUNCTION was_user_notified_recently(
  p_user_id UUID,
  p_message_hash TEXT,
  p_hours_ago INTEGER DEFAULT 1
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM whatsapp_announcements
  WHERE user_id = p_user_id
    AND message_hash = p_message_hash
    AND sent_at > NOW() - (p_hours_ago || ' hours')::INTERVAL;
  
  RETURN v_count > 0;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION was_user_notified_recently(UUID, TEXT, INTEGER) TO authenticated, anon;

-- Add comment
COMMENT ON TABLE whatsapp_announcements IS 'Tracks WhatsApp announcements sent to users to prevent duplicate sends within time window';
COMMENT ON FUNCTION was_user_notified_recently IS 'Checks if a user was notified with the same message hash within the specified hours (default 1 hour)';

