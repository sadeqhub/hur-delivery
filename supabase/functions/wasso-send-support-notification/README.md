# Wasso Support Request Notification

This edge function sends a WhatsApp notification to the admin when a user sends a support request in the app.

## Overview

When a non-admin user (merchant or driver) sends a message in a support conversation, this function is automatically triggered to notify the admin via WhatsApp using the Wasso API.

## Configuration

### Required Environment Variables

Set these via Supabase CLI:
```bash
supabase secrets set WASSO_API_KEY=your_wasso_api_key
supabase secrets set ADMIN_PHONE=964XXXXXXXXX  # Admin phone number (no + sign)
```

### Database Configuration

The database trigger requires the following settings to be configured:

```sql
-- Set Supabase URL
ALTER DATABASE postgres SET app.settings.supabase_url TO 'https://your-project.supabase.co';

-- Set service role key (get from Supabase Dashboard > Settings > API)
ALTER DATABASE postgres SET app.settings.service_role_key TO 'your-service-role-key';
```

## How It Works

1. When a user sends a message in a support conversation, the `send_message` database function detects it
2. If the sender is not an admin, it automatically calls this edge function via `net.http_post`
3. This function:
   - Fetches sender information (name, phone, role)
   - Fetches conversation details
   - Formats a bilingual (Arabic/English) WhatsApp message
   - Sends the message to the admin via Wasso API

## Message Format

The WhatsApp message sent to admin includes:
- 🔔 Support request indicator
- 👤 Sender name
- 📱 Sender phone number
- 🏷️ Sender role (merchant/driver/user)
- 📝 Message preview (first 200 characters)
- 🛒 Order ID (if related to an order)
- 🔗 Conversation ID (shortened)

## Error Handling

- If Wasso API fails, the error is logged but message sending is not blocked
- If database configuration is missing, a notice is logged but the function continues
- All errors are gracefully handled to ensure message delivery is not interrupted

## Testing

To test manually, you can call the function directly:

```bash
curl -X POST https://your-project.supabase.co/functions/v1/wasso-send-support-notification \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": "conversation-uuid",
    "message_id": "message-uuid",
    "sender_id": "sender-uuid",
    "message_body": "Test support request",
    "sender_name": "Test User",
    "sender_role": "merchant",
    "sender_phone": "+964XXXXXXXXX"
  }'
```

## Security

- Uses rate limiting (30 requests per minute)
- Validates required fields
- Logs security events
- Uses service role key for database access (only from trusted database function)















