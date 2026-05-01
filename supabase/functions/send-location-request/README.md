# Wasso Send Location Request

This edge function sends a WhatsApp message to customers requesting their location when a new order is created.

## Features

- Sends automated WhatsApp messages via Wasso API
- Requests customer location for order delivery
- Updates database with delivery status
- Handles phone number formatting for Iraqi numbers

## Environment Variables

Required:
- `WASSO_API_KEY` - Your Wasso API key (wass_grstUCgadAQ_Fv-6v7T4sCiPwIFryfgW6Utx8VcS5AI)
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Your Supabase service role key

## API Endpoint

```
POST /functions/v1/send-location-request
```

## Request Body

```json
{
  "order_id": "uuid",
  "customer_phone": "+9647812345678",
  "customer_name": "أحمد",
  "merchant_name": "متجر الطعام"
}
```

## Response

Success:
```json
{
  "success": true,
  "sent_to": "9647812345678",
  "message_id": "msg_123",
  "delivered_at": "2025-01-06T12:00:00Z"
}
```

Error:
```json
{
  "error": "Error message",
  "details": "Detailed error information"
}
```

## Wasso API Integration

This function uses the Wasso API to send WhatsApp messages:

- **API URL**: `https://wasso.up.railway.app/api/v1/messages/send`
- **Authentication**: X-API-Key header
- **Phone Format**: 964XXXXXXXXX (no + prefix)

## Database Updates

Updates the `whatsapp_location_requests` table:
- Sets status to 'delivered' on success
- Sets status to 'failed' on error
- Stores message_sid from Wasso

## Deployment

```bash
supabase functions deploy send-location-request
```

## Testing

```bash
curl -X POST "https://your-project.supabase.co/functions/v1/send-location-request" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "test-order-id",
    "customer_phone": "+9647812345678",
    "customer_name": "Test Customer",
    "merchant_name": "Test Merchant"
  }'
```

