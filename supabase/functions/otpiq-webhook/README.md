# Wasso Location Webhook

This edge function receives location coordinates from customers via Wasso webhook and updates the order delivery location.

## Features

- Receives location webhooks from Wasso
- Validates customer phone number against pending orders
- Updates order delivery coordinates
- Sends confirmation message to customer
- Notifies merchant about location receipt

## Environment Variables

Required:
- `WASSO_API_KEY` - Your Wasso API key
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Your Supabase service role key

## Webhook Setup

Configure this webhook URL in your Wasso dashboard:

```
https://your-project.supabase.co/functions/v1/otpiq-webhook
```

## Webhook Payload

Expected format from Wasso:

```json
{
  "type": "location",
  "from": "9647812345678",
  "location": {
    "latitude": 33.312805,
    "longitude": 44.361488
  },
  "message_id": "msg_123",
  "timestamp": "2025-01-06T12:00:00Z"
}
```

## Response

Success:
```json
{
  "success": true,
  "message": "Customer location updated successfully",
  "order_id": "uuid",
  "coordinates": {
    "latitude": 33.312805,
    "longitude": 44.361488
  },
  "updated_at": "2025-01-06T12:00:00Z"
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

1. Webhook receives location from customer
2. Validates location coordinates
3. Finds pending location request by phone number
4. Verifies order exists and matches phone
5. Updates order delivery coordinates
6. Updates whatsapp_location_requests table
7. Sends confirmation to customer
8. Creates notification for merchant

## Database Updates

- Calls `update_customer_location()` function to update order
- Updates `whatsapp_location_requests` status to 'location_received'
- Creates notification for merchant

## Security

- Validates phone number matches order
- Checks for pending location requests
- Uses flexible phone number matching (last 10 digits)

## Deployment

**Important:** This function must be deployed with `--no-verify-jwt` to allow unauthenticated webhook calls from Wasso:

```bash
supabase functions deploy otpiq-webhook --no-verify-jwt
```

This is required because Wasso webhooks don't include Supabase authentication headers.

## Testing

```bash
curl -X POST "https://your-project.supabase.co/functions/v1/otpiq-webhook" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "location",
    "from": "9647812345678",
    "location": {
      "latitude": 33.312805,
      "longitude": 44.361488
    },
    "message_id": "test_msg_123"
  }'
```

## Notes

- Non-location messages are ignored gracefully
- Failed confirmations don't fail the whole request
- Merchant notifications are best-effort
- Phone number format is flexible (handles +964, 964, 0 prefixes)

