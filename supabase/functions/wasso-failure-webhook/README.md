# Wasso Failure Webhook

This edge function receives failure notifications from Wasso when WhatsApp messages fail to send and automatically sends error emails to the admin.

## Features

- Receives failure webhooks from Wasso
- Finds the associated order by phone number and message ID
- Updates database with failure status
- Sends error email to admin via Resend API
- Rate limits error emails (once every 6 hours per order)

## Environment Variables

Required:
- `RESEND_API_KEY` - Your Resend API key
- `ADMIN_EMAIL` - Admin email address to receive error notifications
- `RESEND_FROM_EMAIL` - Email address to send from (must be verified in Resend)
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Your Supabase service role key

## Webhook Setup

Configure this webhook URL in your Wasso dashboard for failure notifications:

```
https://your-project.supabase.co/functions/v1/wasso-failure-webhook
```

## Webhook Payload

Expected format from Wasso (adjust based on actual webhook format):

```json
{
  "type": "message_failed",
  "message_id": "msg_123",
  "recipient": "9647812345678",
  "error": "Failed to send message",
  "reason": "Invalid phone number",
  "timestamp": "2025-01-12T12:00:00Z",
  "order_id": "uuid" // Optional: if included in original message
}
```

The function will accept any of these failure indicators:
- `type` === `"message_failed"`, `"error"`, or `"failed"`
- `status` === `"failed"` or `"error"`
- Presence of `error` or `reason` fields

## Response

Success:
```json
{
  "success": true,
  "message": "Failure webhook processed",
  "order_id": "uuid",
  "email_sent": true
}
```

Error:
```json
{
  "error": "Error message",
  "details": "Detailed error information"
}
```

## Process Flow

1. Webhook receives failure notification from Wasso
2. Validates it's a failure notification
3. Extracts order ID from payload or searches by phone number + message ID
4. Fetches order details from database
5. Updates `whatsapp_location_requests` status to 'failed'
6. Checks if error email should be sent (rate limit: 6 hours)
7. Sends error email to admin if rate limit allows
8. Updates `last_error_email_sent_at` timestamp

## Order Lookup

The function tries to find the order in this order:
1. `order_id` from webhook payload (if included)
2. Search by `customer_phone` + `message_sid` in `whatsapp_location_requests`
3. Search by `customer_phone` (most recent request)

## Rate Limiting

Error emails are rate-limited to **once every 6 hours** per order to avoid spamming the admin. The function checks the `last_error_email_sent_at` timestamp in the `whatsapp_location_requests` table.

## Email Content

The error email includes:
- Order ID
- Store name
- Customer name and phone number
- Message ID
- Error details
- Timestamp

## Database Updates

- Updates `whatsapp_location_requests.status` to `'failed'`
- Updates `whatsapp_location_requests.last_error_email_sent_at` after sending email

## Security

- Rate limiting applied (30 requests per minute)
- Validates webhook payload
- Uses service role key for database access
- CORS headers configured

## Deployment

Deploy using Supabase CLI:

```bash
supabase functions deploy wasso-failure-webhook
```

## Testing

You can test the webhook by sending a POST request:

```bash
curl -X POST https://your-project.supabase.co/functions/v1/wasso-failure-webhook \
  -H "Content-Type: application/json" \
  -d '{
    "type": "message_failed",
    "message_id": "test_msg_123",
    "recipient": "9647812345678",
    "error": "Test error message",
    "timestamp": "2025-01-12T12:00:00Z"
  }'
```
















