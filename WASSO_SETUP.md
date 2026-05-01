# Wasso WhatsApp Automation Setup Guide

This guide explains how to set up the Wasso WhatsApp automation for customer location requests.

## Overview

The system automatically sends WhatsApp messages to customers when orders are created, requesting their location. When customers share their location, it's automatically updated in the order.

## Architecture

```
Order Created → Database Trigger → send-location-request Function → Wasso API → Customer WhatsApp
                                                                                              ↓
Customer Shares Location → Wasso Webhook → otpiq-webhook Function → Update Order → Confirm to Customer
```

## Setup Steps

### 1. Configure Wasso API Key

Add the Wasso API key to your Supabase environment variables:

```bash
# In Supabase Dashboard → Settings → Edge Functions → Secrets
WASSO_API_KEY=wass_grstUCgadAQ_Fv-6v7T4sCiPwIFryfgW6Utx8VcS5AI
```

Or via CLI:
```bash
supabase secrets set WASSO_API_KEY=wass_grstUCgadAQ_Fv-6v7T4sCiPwIFryfgW6Utx8VcS5AI
```

### 2. Deploy Edge Functions

Deploy both edge functions to Supabase:

```bash
# Deploy location request sender
supabase functions deploy send-location-request

# Deploy location webhook receiver
supabase functions deploy otpiq-webhook
```

### 3. Run Database Migration

Apply the migration to update the trigger:

```bash
supabase db push
```

Or manually run the migration:
```bash
psql -h your-db-host -U postgres -d postgres -f supabase/migrations/20250106000000_switch_to_wasso_api.sql
```

### 4. Configure Wasso Webhook

In your Wasso dashboard (https://wasso.up.railway.app):

1. Go to **Webhooks** section
2. Add a new webhook with URL:
   ```
   https://your-project-ref.supabase.co/functions/v1/otpiq-webhook
   ```
3. Select event type: **Location Messages**
4. Save the webhook

### 5. Test the Integration

#### Test Location Request:

```bash
curl -X POST "https://your-project.supabase.co/functions/v1/send-location-request" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "test-order-uuid",
    "customer_phone": "+9647812345678",
    "customer_name": "أحمد",
    "merchant_name": "متجر الطعام"
  }'
```

#### Test Webhook:

```bash
curl -X POST "https://your-project.supabase.co/functions/v1/otpiq-webhook" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "location",
    "from": "9647812345678",
    "location": {
      "latitude": 33.312805,
      "longitude": 44.361488
    }
  }'
```

## Wasso API Details

### API Key
- **Key**: `wass_grstUCgadAQ_Fv-6v7T4sCiPwIFryfgW6Utx8VcS5AI`
- **Phone**: 9647890003093
- **Status**: Active
- **Cost**: 10 IQD per message
- **Balance**: 41,190 IQD (~4,119 messages)

### API Endpoints

#### Send Message
```bash
curl -X POST "https://wasso.up.railway.app/api/v1/messages/send" \
  -H "X-API-Key: wass_grstUCgadAQ_Fv-6v7T4sCiPwIFryfgW6Utx8VcS5AI" \
  -H "Content-Type: application/json" \
  -d '{
    "recipient": "9647812345678",
    "message": "Hello from Wasso!"
  }'
```

#### Get Wallet Balance
```bash
curl -X GET "https://wasso.up.railway.app/api/v1/wallet/balance" \
  -H "X-API-Key: wass_grstUCgadAQ_Fv-6v7T4sCiPwIFryfgW6Utx8VcS5AI"
```

## Database Tables

### whatsapp_location_requests

Tracks all WhatsApp location requests:

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| order_id | UUID | Reference to orders table |
| customer_phone | TEXT | Customer phone number |
| message_sid | TEXT | Wasso message ID |
| status | TEXT | sent, delivered, failed, location_received |
| sent_at | TIMESTAMPTZ | When message was sent |
| delivered_at | TIMESTAMPTZ | When message was delivered |
| location_received_at | TIMESTAMPTZ | When location was received |
| customer_latitude | DECIMAL | Received latitude |
| customer_longitude | DECIMAL | Received longitude |

## Monitoring

### Check Logs

View function logs in Supabase Dashboard:
- Go to **Edge Functions** → Select function → **Logs**

Or via CLI:
```bash
supabase functions logs send-location-request
supabase functions logs otpiq-webhook
```

### Check Database

Query location requests:
```sql
SELECT * FROM whatsapp_location_requests 
ORDER BY sent_at DESC 
LIMIT 10;
```

Check failed requests:
```sql
SELECT * FROM whatsapp_location_requests 
WHERE status = 'failed' 
ORDER BY sent_at DESC;
```

## Troubleshooting

### Message Not Sent

1. Check Wasso API key is configured
2. Verify phone number format (964XXXXXXXXX)
3. Check Wasso balance
4. Review function logs

### Location Not Received

1. Verify webhook is configured in Wasso
2. Check webhook URL is correct
3. Ensure customer phone matches order
4. Review webhook function logs

### Phone Number Format Issues

The system handles multiple formats:
- `+9647812345678` → `9647812345678`
- `9647812345678` → `9647812345678`
- `07812345678` → `9647812345678`

## Cost Estimation

- Cost per message: 10 IQD
- Average messages per order: 2 (request + confirmation)
- Cost per order: 20 IQD
- Current balance: 41,190 IQD
- Estimated orders: ~2,059 orders

## Migration from Old System

The old system used a different WhatsApp service. The new system:

✅ Uses Wasso API (more reliable)
✅ Better webhook handling
✅ Improved error handling
✅ Better phone number validation
✅ Automatic confirmations

Old edge functions (can be removed after testing):
- `send-whatsapp-location-request`
- `receive-customer-location`
- `twilio-webhook`
- `twilio-webhook-fixed`

## Support

- Wasso Dashboard: https://wasso.up.railway.app
- Wasso API Docs: Check dashboard for latest documentation
- Supabase Docs: https://supabase.com/docs/guides/functions

