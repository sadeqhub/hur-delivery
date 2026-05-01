import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface DailyStats {
  // Period (24h) stats
  merchantsCreated: number
  driversCreated: number
  ordersCreated: number
  ordersDelivered: number
  ordersCancelled: number
  ordersRejected: number
  ordersPending: number
  ordersInProgress: number // accepted + on_the_way
  topupCount: number
  topupAmount: number
  deliveredOrdersRevenue: number
  orderFeesCollected: number
  newMessagesFromUsers: number
  bulkOrdersDelivered: number
  whatsappLocationRequestsSent: number
  whatsappLocationRequestsFailed: number
  // Totals (all-time)
  totalMerchants: number
  totalDrivers: number
  totalOrders: number
  totalOrdersDelivered: number
  totalRevenue: number
  driversOnlineNow: number
  date: string
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

    console.log('\n═══════════════════════════════════════════════════════')
    console.log('📧 DAILY SUMMARY - EDGE FUNCTION')
    console.log('═══════════════════════════════════════════════════════\n')

  try {
    // Initialize Supabase client with service role
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Get admin phone numbers from environment (comma-separated)
    // Prioritize ADMIN_PHONES (multiple numbers) over ADMIN_PHONE (single number)
    const adminPhonesEnv = Deno.env.get('ADMIN_PHONES')
    const adminPhoneEnv = Deno.env.get('ADMIN_PHONE')
    
    console.log('🔍 Checking environment variables:')
    console.log('   ADMIN_PHONES exists:', !!adminPhonesEnv)
    if (adminPhonesEnv) {
      console.log('   ADMIN_PHONES value length:', adminPhonesEnv.length)
      console.log('   ADMIN_PHONES preview:', adminPhonesEnv.substring(0, 50) + '...')
    }
    console.log('   ADMIN_PHONE exists:', !!adminPhoneEnv)
    
    // Use ADMIN_PHONES if available, otherwise fall back to ADMIN_PHONE
    const adminPhonesStr = adminPhonesEnv || adminPhoneEnv
    
    if (!adminPhonesStr) {
      console.error('❌ ADMIN_PHONES or ADMIN_PHONE environment variable not set')
      return new Response(
        JSON.stringify({ error: 'ADMIN_PHONES not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('📋 Using secret:', adminPhonesEnv ? 'ADMIN_PHONES' : 'ADMIN_PHONE')
    console.log('📋 Raw phone numbers string:', adminPhonesStr)
    console.log('📋 String length:', adminPhonesStr.length)

    // Parse comma-separated phone numbers
    const adminPhones = adminPhonesStr
      .split(',')
      .map(phone => phone.trim())
      .filter(phone => phone.length > 0)

    console.log('📋 Parsed phone numbers:', JSON.stringify(adminPhones))
    console.log(`📱 Found ${adminPhones.length} admin phone number(s)`)

    if (adminPhones.length === 0) {
      console.error('❌ No valid phone numbers found after parsing')
      return new Response(
        JSON.stringify({ error: 'No valid phone numbers found' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (adminPhones.length === 1) {
      console.warn('⚠️  WARNING: Only one phone number found. Expected multiple numbers in ADMIN_PHONES.')
    }

    console.log(`📱 Sending to ${adminPhones.length} admin phone number(s):`, adminPhones)

    // Calculate date range for past 24 hours
    const now = new Date()
    const twentyFourHoursAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000)

    console.log('📅 Date range (24 hours):')
    console.log('   From:', twentyFourHoursAgo.toISOString())
    console.log('   To:', now.toISOString())

    // Fetch statistics
    console.log('\n📊 Fetching daily statistics...')
    const stats = await fetchDailyStats(supabaseClient, twentyFourHoursAgo, now)

    console.log('\n✅ Statistics collected:')
    console.log('   Period: merchants +', stats.merchantsCreated, ', drivers +', stats.driversCreated)
    console.log('   Orders today: created', stats.ordersCreated, ', delivered', stats.ordersDelivered)
    console.log('   Revenue today:', stats.deliveredOrdersRevenue, 'IQD')
    console.log('   Totals: merchants', stats.totalMerchants, ', drivers', stats.totalDrivers, ', orders', stats.totalOrders)

    // Generate email message content
    const messageContent = generateEmailMessage(stats)

    // Send via Whapi.Cloud to all admin phone numbers
    console.log('\n📧 Sending daily summary via Whapi.Cloud to all admins...')
    const sendResults = await Promise.allSettled(
      adminPhones.map(phone => sendWhapiMessage(supabaseClient, phone, messageContent))
    )

    // Process results
    const results = sendResults.map((result, index) => {
      if (result.status === 'fulfilled') {
        return {
          phone: adminPhones[index],
          success: result.value.success,
          message_id: result.value.message_id,
          error: result.value.error
        }
      } else {
        return {
          phone: adminPhones[index],
          success: false,
          error: result.reason?.message || 'Unknown error'
        }
      }
    })

    const successCount = results.filter(r => r.success).length
    const failureCount = results.filter(r => !r.success).length

    console.log(`\n✅ Results: ${successCount} succeeded, ${failureCount} failed`)
    results.forEach((result, index) => {
      if (result.success) {
        console.log(`   ✅ ${result.phone}: Sent (ID: ${result.message_id || 'N/A'})`)
      } else {
        console.error(`   ❌ ${result.phone}: Failed - ${result.error}`)
      }
    })

    console.log('═══════════════════════════════════════════════════════\n')

    // Return success if at least one message was sent successfully
    if (successCount > 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: `Daily summary sent to ${successCount} of ${adminPhones.length} admin(s)`,
          stats: stats,
          results: results,
          success_count: successCount,
          failure_count: failureCount
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    } else {
      return new Response(
        JSON.stringify({
          error: 'Failed to send daily summary to all admins',
          results: results
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

  } catch (error: any) {
    console.error('\n❌ EDGE FUNCTION ERROR:', error.message)
    console.error('Stack:', error.stack)
    console.error('═══════════════════════════════════════════════════════\n')

    return new Response(
      JSON.stringify({
        error: 'Internal server error',
        message: error.message
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// ═══════════════════════════════════════════════════════════════════════════════
// FETCH DAILY STATISTICS (24 HOURS)
// ═══════════════════════════════════════════════════════════════════════════════
async function fetchDailyStats(
  supabase: any,
  fromDate: Date,
  toDate: Date
): Promise<DailyStats> {
  const fromISO = fromDate.toISOString()
  const toISO = toDate.toISOString()

  const safeCount = (c: number | null | undefined) => c ?? 0
  const safeSum = (arr: any[], fn: (x: any) => number) =>
    arr?.reduce((s, x) => s + fn(x), 0) ?? 0

  // ─── Period (24h) stats ───
  const [
    { count: merchantsCreated },
    { count: driversCreated },
    { data: ordersPeriod },
    { data: deliveredOrders },
    { data: topupsData },
    { data: orderFeesData },
    { data: messagesData },
    { count: bulkOrdersDeliveredCount },
    { data: whatsappData },
  ] = await Promise.all([
    supabase.from('users').select('*', { count: 'exact', head: true })
      .eq('role', 'merchant').gte('created_at', fromISO).lt('created_at', toISO),
    supabase.from('users').select('*', { count: 'exact', head: true })
      .eq('role', 'driver').gte('created_at', fromISO).lt('created_at', toISO),
    supabase.from('orders').select('status, created_at')
      .gte('created_at', fromISO).lt('created_at', toISO),
    supabase.from('orders').select('total_amount, delivery_fee')
      .eq('status', 'delivered').gte('delivered_at', fromISO).lt('delivered_at', toISO),
    supabase.from('wallet_transactions').select('amount')
      .eq('transaction_type', 'top_up').gte('created_at', fromISO).lt('created_at', toISO),
    supabase.from('wallet_transactions').select('amount')
      .eq('transaction_type', 'order_fee').gte('created_at', fromISO).lt('created_at', toISO),
    supabase.from('messages').select('sender_id, users!messages_sender_id_fkey(role)')
      .gte('created_at', fromISO).lt('created_at', toISO),
    supabase.from('bulk_orders').select('*', { count: 'exact', head: true })
      .eq('status', 'delivered').gte('delivered_at', fromISO).lt('delivered_at', toISO),
    supabase.from('whatsapp_location_requests').select('status, delivered_at')
      .gte('sent_at', fromISO).lt('sent_at', toISO),
  ])

  const orders = ordersPeriod || []
  const ordersCreated = orders.length
  const ordersDelivered = deliveredOrders?.length ?? 0
  const ordersCancelled = orders.filter((o: any) => o.status === 'cancelled').length
  const ordersRejected = orders.filter((o: any) => o.status === 'rejected').length
  const ordersPending = orders.filter((o: any) => o.status === 'pending').length
  const ordersInProgress = orders.filter((o: any) =>
    ['accepted', 'on_the_way'].includes(o.status)
  ).length

  const topupCount = topupsData?.length ?? 0
  const topupAmount = safeSum(topupsData || [], (t) => parseFloat(t.amount || 0))
  const deliveredOrdersRevenue = safeSum(deliveredOrders || [], (o) =>
    parseFloat(o.total_amount || 0) + parseFloat(o.delivery_fee || 0)
  )
  const orderFeesCollected = Math.abs(safeSum(orderFeesData || [], (t) => parseFloat(t.amount || 0)))
  const newMessagesFromUsers = messagesData?.filter((m: any) =>
    m.users && ['driver', 'merchant'].includes(m.users.role)
  ).length ?? 0
  const bulkOrdersDelivered = safeCount(bulkOrdersDeliveredCount)
  const whatsappReqs = whatsappData || []
  const whatsappLocationRequestsSent = whatsappReqs.filter((r: any) => r.delivered_at).length
  const whatsappLocationRequestsFailed = whatsappReqs.filter((r: any) => r.status === 'failed').length

  // ─── Totals (all-time) ───
  const [
    { count: totalMerchants },
    { count: totalDrivers },
    { count: totalOrders },
    { count: totalOrdersDelivered },
    { data: totalRevenueData },
    { count: driversOnlineNow },
  ] = await Promise.all([
    supabase.from('users').select('*', { count: 'exact', head: true }).eq('role', 'merchant'),
    supabase.from('users').select('*', { count: 'exact', head: true }).eq('role', 'driver'),
    supabase.from('orders').select('*', { count: 'exact', head: true }),
    supabase.from('orders').select('*', { count: 'exact', head: true }).eq('status', 'delivered'),
    supabase.from('orders').select('total_amount, delivery_fee')
      .eq('status', 'delivered'),
    supabase.from('users').select('*', { count: 'exact', head: true })
      .eq('role', 'driver').eq('is_online', true),
  ])

  const totalRevenue = safeSum(totalRevenueData || [], (o) =>
    parseFloat(o.total_amount || 0) + parseFloat(o.delivery_fee || 0)
  )

  return {
    merchantsCreated: safeCount(merchantsCreated),
    driversCreated: safeCount(driversCreated),
    ordersCreated,
    ordersDelivered,
    ordersCancelled,
    ordersRejected,
    ordersPending,
    ordersInProgress,
    topupCount,
    topupAmount,
    deliveredOrdersRevenue,
    orderFeesCollected,
    newMessagesFromUsers,
    bulkOrdersDelivered: safeCount(bulkOrdersDeliveredCount),
    whatsappLocationRequestsSent,
    whatsappLocationRequestsFailed,
    totalMerchants: safeCount(totalMerchants),
    totalDrivers: safeCount(totalDrivers),
    totalOrders: safeCount(totalOrders),
    totalOrdersDelivered: safeCount(totalOrdersDelivered),
    totalRevenue,
    driversOnlineNow: safeCount(driversOnlineNow),
    date: toDate.toLocaleString('ar-IQ', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      timeZone: 'Asia/Baghdad',
    }),
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GENERATE DETAILED DAILY MESSAGE (WhatsApp ~4096 char limit)
// ═══════════════════════════════════════════════════════════════════════════════
function formatNum(n: number): string {
  return n.toLocaleString('en')
}

function generateEmailMessage(stats: DailyStats): string {
  const fmt = (v: number, suffix = '') => (v > 0 ? `${formatNum(v)}${suffix}` : '0')
  const iqd = (v: number) => v > 0 ? `${formatNum(Math.round(v))} د.ع` : '0 د.ع'

  let msg = `📊 *ملخص يومي - تطبيق حر* 🚚\n`
  msg += `📅 ${stats.date}\n`
  msg += `─────────────────\n\n`

  msg += `*📈 آخر 24 ساعة:*\n`
  msg += `• تجار جدد: ${fmt(stats.merchantsCreated)}\n`
  msg += `• سائقين جدد: ${fmt(stats.driversCreated)}\n`
  msg += `• طلبات منشأة: ${fmt(stats.ordersCreated)}\n`
  msg += `• طلبات مسلمة: ${fmt(stats.ordersDelivered)}\n`
  if (stats.bulkOrdersDelivered > 0) {
    msg += `• طلبات جماعية مسلمة: ${fmt(stats.bulkOrdersDelivered)}\n`
  }
  msg += `• طلبات قيد التنفيذ: ${fmt(stats.ordersInProgress)}\n`
  msg += `• طلبات معلقة: ${fmt(stats.ordersPending)}\n`
  if (stats.ordersCancelled > 0 || stats.ordersRejected > 0) {
    msg += `• ملغاة: ${fmt(stats.ordersCancelled)} | مرفوضة: ${fmt(stats.ordersRejected)}\n`
  }
  msg += `• شحنات محفظة: ${fmt(stats.topupCount)} (${iqd(stats.topupAmount)})\n`
  msg += `• إيرادات الطلبات: ${iqd(stats.deliveredOrdersRevenue)}\n`
  if (stats.orderFeesCollected > 0) {
    msg += `• رسوم محصلة: ${iqd(stats.orderFeesCollected)}\n`
  }
  if (stats.newMessagesFromUsers > 0) {
    msg += `• رسائل جديدة: ${fmt(stats.newMessagesFromUsers)}\n`
  }
  if (stats.whatsappLocationRequestsSent > 0 || stats.whatsappLocationRequestsFailed > 0) {
    msg += `• طلبات موقع واتساب: ✓${fmt(stats.whatsappLocationRequestsSent)} ✗${fmt(stats.whatsappLocationRequestsFailed)}\n`
  }
  msg += `\n*📊 الإجماليات:*\n`
  msg += `• تجار: ${formatNum(stats.totalMerchants)}\n`
  msg += `• سائقين: ${formatNum(stats.totalDrivers)}\n`
  msg += `• سائقين متصلين الآن: ${formatNum(stats.driversOnlineNow)}\n`
  msg += `• إجمالي الطلبات: ${formatNum(stats.totalOrders)}\n`
  msg += `• طلبات مسلمة (كل الوقت): ${formatNum(stats.totalOrdersDelivered)}\n`
  msg += `• إجمالي الإيرادات: ${iqd(stats.totalRevenue)}\n`
  msg += `\nشكراً لاستخدامكم تطبيق حر 🚚`

  return msg
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEND WHATSAPP MESSAGE VIA WHAPI.CLOUD API
// ═══════════════════════════════════════════════════════════════════════════════
async function sendWhapiMessage(
  supabaseClient: any,
  phoneNumber: string,
  message: string
): Promise<{ success: boolean; message_id?: string | null; error?: string }> {
  let whapiApiKey = Deno.env.get('WHAPI_API_KEY')
  if (!whapiApiKey) {
    const { data } = await supabaseClient
      .from('system_settings')
      .select('value')
      .eq('key', 'whapi_api_key')
      .maybeSingle()
    whapiApiKey = data?.value
  }

  const whapiApiUrl = 'https://gate.whapi.cloud/messages/text'

  if (!whapiApiKey) {
    console.error('❌ WHAPI_API_KEY not configured (env or system_settings)')
    return {
      success: false,
      error: 'WHAPI_API_KEY not configured in env or system_settings'
    }
  }

  console.log('📱 Sending WhatsApp message via Whapi.Cloud API...')
  console.log('   API URL:', whapiApiUrl)
  console.log('   To:', phoneNumber)
  console.log('   Message length:', message.length)

  const cleanPhone = phoneNumber.replace(/^\+/, '')

  try {
    const response = await fetch(whapiApiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${whapiApiKey}`,
      },
      body: JSON.stringify({
        to: cleanPhone,
        body: message,
      }),
    })

    console.log('📨 Whapi API response status:', response.status)

    if (!response.ok) {
      const errorText = await response.text()
      console.error('❌ Whapi API error:', errorText)
      return {
        success: false,
        error: `Whapi API error: ${response.status} - ${errorText}`
      }
    }

    const result = await response.json()
    console.log('✅ Whapi response:', JSON.stringify(result))

    const messageId = result.id || result.message_id || result.messages?.[0]?.id
    if (messageId || response.ok) {
      return {
        success: true,
        message_id: messageId || null
      }
    } else {
      return {
        success: false,
        error: result.error || result.message || 'Unknown error'
      }
    }
  } catch (fetchError: any) {
    console.error('❌ Fetch error:', fetchError.message)
    return {
      success: false,
      error: `Network error: ${fetchError.message}`
    }
  }
}
