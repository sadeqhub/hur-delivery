// Support Agent Tools — Webhook endpoint called by OpenAI when the workflow
// needs to execute a tool. Routes each tool call to the appropriate
// Supabase query and returns structured JSON results.
//
// OpenAI calls: POST /functions/v1/support-agent-tools
// Body:         { name: string, parameters: object, call_id?: string }
// Returns:      { result: object }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, openai-beta, x-openai-signature",
};

// ─── Iraqi phone number helpers ───────────────────────────────────────────────

function formatIraqiPhone(raw: string | null | undefined): string | null {
  if (!raw) return null;
  // Keep only digits (drop +, spaces, dashes, parens)
  let digits = raw.replace(/[^\d]/g, "");
  // Strip country code prefix if present
  if (digits.startsWith("964")) digits = digits.slice(3);
  // Strip leading zero from local format (07XX → 7XX)
  if (digits.startsWith("0")) digits = digits.slice(1);
  // Must be 10 digits starting with 7 (Iraqi mobile prefix)
  if (!/^7\d{9}$/.test(digits)) return raw; // unrecognised — return as-is
  return `+964${digits}`;
}

function validateIraqiPhone(raw: string): { valid: boolean; formatted: string | null; error?: string } {
  const formatted = formatIraqiPhone(raw);
  if (!formatted) return { valid: false, formatted: null, error: "Empty phone number" };
  if (formatted === raw && !/^\+9647\d{9}$/.test(raw)) {
    return { valid: false, formatted: null, error: `"${raw}" is not a valid Iraqi mobile number. Must be 11 digits starting with 07, or international format +9647XXXXXXXXX.` };
  }
  if (!/^\+9647\d{9}$/.test(formatted)) {
    return { valid: false, formatted: null, error: `"${raw}" could not be converted to a valid Iraqi number (+9647XXXXXXXXX).` };
  }
  return { valid: true, formatted };
}

function formatPhoneInObject<T extends Record<string, any>>(obj: T, ...keys: string[]): T {
  const out = { ...obj };
  for (const key of keys) {
    if (key in out) out[key] = formatIraqiPhone(out[key]);
  }
  return out;
}

// ─── Tool handlers ────────────────────────────────────────────────────────────

async function getOrderDetails(
  params: { order_id: string },
  supabase: ReturnType<typeof createClient>
) {
  if (!params.order_id) return { error: "order_id is required" };

  const { data, error } = await supabase
    .from("orders")
    .select(
      `
      id, status, pickup_address, delivery_address,
      customer_name, customer_phone,
      merchant_id, driver_id,
      delivery_fee, notes,
      created_at, accepted_at, picked_up_at, delivered_at, rejected_at,
      rejection_reason,
      ready_at, ready_countdown,
      merchants:merchant_id (id, name, phone, address),
      drivers:driver_id   (id, name, phone)
    `
    )
    .eq("id", params.order_id)
    .maybeSingle();

  if (error) return { error: error.message };
  if (!data) return { error: "Order not found" };

  const result = formatPhoneInObject(data as any, "customer_phone");
  if (result.merchants) result.merchants = formatPhoneInObject(result.merchants as any, "phone");
  if (result.drivers) result.drivers = formatPhoneInObject(result.drivers as any, "phone");
  return result;
}

async function getUserProfile(
  params: { user_id: string },
  supabase: ReturnType<typeof createClient>
) {
  if (!params.user_id) return { error: "user_id is required" };

  const { data: user, error } = await supabase
    .from("users")
    .select("id, name, phone, role, city, is_online, created_at")
    .eq("id", params.user_id)
    .maybeSingle();

  if (error) return { error: error.message };
  if (!user) return { error: "User not found" };

  const profile = formatPhoneInObject(user as any, "phone");

  // Wallet summary (table differs by role)
  let wallet = null;
  if (profile.role === "driver") {
    const { data } = await supabase
      .from("driver_wallets")
      .select("balance")
      .eq("driver_id", params.user_id)
      .maybeSingle();
    wallet = data;
  } else if (profile.role === "merchant") {
    const { data } = await supabase
      .from("merchant_wallets")
      .select("balance, order_fee, credit_limit")
      .eq("merchant_id", params.user_id)
      .maybeSingle();
    wallet = data;
  }

  return { ...profile, wallet };
}

async function getMerchantContact(
  params: { merchant_id: string },
  supabase: ReturnType<typeof createClient>
) {
  if (!params.merchant_id) return { error: "merchant_id is required" };

  const { data, error } = await supabase
    .from("users")
    .select("id, name, phone, address, city")
    .eq("id", params.merchant_id)
    .eq("role", "merchant")
    .maybeSingle();

  if (error) return { error: error.message };
  if (!data) return { error: "Merchant not found" };
  return formatPhoneInObject(data as any, "phone");
}

async function checkDriverTiming(
  params: { order_id: string },
  supabase: ReturnType<typeof createClient>
) {
  if (!params.order_id) return { error: "order_id is required" };

  const { data: order, error } = await supabase
    .from("orders")
    .select(
      `
      id, status, driver_id,
      accepted_at, picked_up_at, delivered_at, rejected_at,
      ready_at, ready_countdown,
      rejection_reason,
      drivers:driver_id (name)
    `
    )
    .eq("id", params.order_id)
    .maybeSingle();

  if (error || !order) return { error: "Order not found" };

  const metrics: Record<string, unknown> = {
    order_id: params.order_id,
    driver_name: (order.drivers as any)?.name ?? "Unknown",
    rejection_reason: order.rejection_reason,
    merchant_set_ready_countdown:
      order.ready_countdown != null && order.ready_countdown > 0,
    ready_at: order.ready_at,
  };

  if (order.accepted_at && order.picked_up_at) {
    metrics.minutes_to_pickup = Math.round(
      (new Date(order.picked_up_at).getTime() -
        new Date(order.accepted_at).getTime()) /
        60000
    );
  }

  if (order.ready_at && order.picked_up_at) {
    const diff = Math.round(
      (new Date(order.picked_up_at).getTime() -
        new Date(order.ready_at).getTime()) /
        60000
    );
    metrics.arrived_minutes_after_ready = diff;
    metrics.driver_arrived_late = diff > 15;
  }

  if (order.accepted_at && order.delivered_at) {
    metrics.total_delivery_minutes = Math.round(
      (new Date(order.delivered_at).getTime() -
        new Date(order.accepted_at).getTime()) /
        60000
    );
  }

  const isLate =
    metrics.driver_arrived_late === true ||
    (typeof metrics.minutes_to_pickup === "number" &&
      metrics.minutes_to_pickup > 45);

  const rejectionMentionsDriver =
    typeof order.rejection_reason === "string" &&
    /late|متأخر|slow|بطيء/i.test(order.rejection_reason);

  const rejectionByDriver =
    typeof order.rejection_reason === "string" &&
    /driver cancel|سائق رفض|driver reject/i.test(order.rejection_reason);

  if (rejectionByDriver) {
    metrics.driver_fault = false;
    metrics.verdict = "Driver cancelled the order themselves — not the customer's fault";
  } else if (isLate || rejectionMentionsDriver) {
    metrics.driver_fault = true;
    metrics.verdict = "Driver likely at fault: late arrival or slow delivery detected";
  } else if (order.rejection_reason) {
    metrics.driver_fault = false;
    metrics.verdict = "Rejection recorded — no timing evidence of driver fault";
  } else {
    metrics.driver_fault = null;
    metrics.verdict = "Unclear — manual review recommended";
  }

  return metrics;
}

async function escalateToHuman(
  params: { reason: string; summary: string; conversation_id: string }
) {
  const resendKey = Deno.env.get("RESEND_API_KEY");
  if (!resendKey) return { success: false, error: "RESEND_API_KEY not configured" };

  const convId = params.conversation_id ?? "";
  const shortId = convId.substring(0, 8);

  const html = `
    <div style="font-family:sans-serif;max-width:600px;margin:0 auto">
      <h2 style="color:#e53e3e">🚨 Support Escalation — Hur Delivery</h2>
      <table style="width:100%;border-collapse:collapse">
        <tr>
          <td style="padding:8px;font-weight:bold;width:120px">Reason</td>
          <td style="padding:8px">${params.reason}</td>
        </tr>
        <tr style="background:#f7fafc">
          <td style="padding:8px;font-weight:bold;vertical-align:top">Summary</td>
          <td style="padding:8px;white-space:pre-wrap">${params.summary}</td>
        </tr>
        <tr>
          <td style="padding:8px;font-weight:bold">Conversation</td>
          <td style="padding:8px;font-family:monospace">${shortId}...</td>
        </tr>
      </table>
    </div>`;

  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${resendKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "Hur Delivery Support <onboarding@resend.dev>",
        to: ["2000.sadic@gmail.com"],
        subject: `🚨 Support Escalation — ${params.reason.substring(0, 60)}`,
        html,
      }),
    });

    const data = await res.json();
    if (!res.ok) return { success: false, error: data.message ?? "Resend error" };
    return { success: true, email_id: data.id };
  } catch (err: any) {
    return { success: false, error: err.message };
  }
}

async function getWalletAndTransactions(
  params: { user_id: string; limit?: number },
  supabase: ReturnType<typeof createClient>
) {
  if (!params.user_id) return { error: "user_id is required" };
  const txLimit = Math.min(params.limit ?? 20, 50);

  const { data: user } = await supabase
    .from("users")
    .select("role, rank, city")
    .eq("id", params.user_id)
    .maybeSingle();

  if (!user) return { error: "User not found" };

  if (user.role === "driver") {
    const { data: wallet, error: wErr } = await supabase
      .from("driver_wallets")
      .select("balance, created_at, updated_at")
      .eq("driver_id", params.user_id)
      .maybeSingle();

    if (wErr) return { error: wErr.message };

    const { data: transactions } = await supabase
      .from("driver_wallet_transactions")
      .select(
        "id, transaction_type, amount, balance_before, balance_after, payment_method, notes, created_at, order_id"
      )
      .eq("driver_id", params.user_id)
      .order("created_at", { ascending: false })
      .limit(txLimit);

    return {
      role: "driver",
      rank: user.rank,
      city: user.city,
      wallet: wallet ?? { balance: 0 },
      transactions: transactions ?? [],
      transaction_count: (transactions ?? []).length,
    };
  }

  if (user.role === "merchant") {
    const { data: wallet, error: wErr } = await supabase
      .from("merchant_wallets")
      .select("balance, order_fee, credit_limit, created_at, updated_at")
      .eq("merchant_id", params.user_id)
      .maybeSingle();

    if (wErr) return { error: wErr.message };

    const { data: transactions } = await supabase
      .from("wallet_transactions")
      .select(
        "id, transaction_type, amount, balance_before, balance_after, payment_method, notes, created_at, order_id"
      )
      .eq("merchant_id", params.user_id)
      .order("created_at", { ascending: false })
      .limit(txLimit);

    return {
      role: "merchant",
      city: user.city,
      wallet: wallet ?? { balance: 0, order_fee: 500, credit_limit: -10000 },
      transactions: transactions ?? [],
      transaction_count: (transactions ?? []).length,
    };
  }

  return { error: `Wallet not available for role: ${user.role}` };
}

async function getCitySettings(
  params: { city?: string },
  supabase: ReturnType<typeof createClient>
) {
  // Rank thresholds are fixed in the system (evaluated monthly)
  const rankSystem = {
    trial: {
      description: "First month after joining — zero commission",
      commission_percentage: 0,
      duration: "Automatic for the first calendar month",
    },
    bronze: {
      description: "Default rank after trial month",
      commission_percentage: 10,
      requirement: "Less than 250 online hours in the previous month",
    },
    silver: {
      description: "Mid tier",
      commission_percentage: 7,
      requirement: "At least 250 online hours in the previous month",
    },
    gold: {
      description: "Top tier",
      commission_percentage: 5,
      requirement: "At least 300 online hours in the previous month",
    },
    how_rank_works:
      "Ranks are recalculated on the 1st of each month based on the driver's total online hours in the previous month.",
  };

  let query = supabase.from("city_settings").select(
    `city,
     driver_wallet_enabled,
     driver_commission_type,
     driver_commission_value,
     driver_commission_by_rank,
     merchant_wallet_enabled,
     merchant_commission_type,
     merchant_commission_value`
  );

  if (params.city) {
    query = query.eq("city", params.city.toLowerCase());
  }

  const { data, error } = await query;
  if (error) return { error: error.message };

  return {
    rank_system: rankSystem,
    city_settings: data ?? [],
    note: "driver_commission_by_rank overrides driver_commission_value per rank tier",
  };
}

async function getUserOrders(
  params: { user_id: string; status?: string },
  supabase: ReturnType<typeof createClient>
) {
  if (!params.user_id) return { error: "user_id is required" };

  // Determine the user's role to decide which column to filter on
  const { data: user } = await supabase
    .from("users")
    .select("role")
    .eq("id", params.user_id)
    .maybeSingle();

  const role = user?.role ?? "customer";

  let query = supabase
    .from("orders")
    .select(
      `
      id, status, pickup_address, delivery_address,
      customer_name, customer_phone,
      merchant_id, driver_id,
      delivery_fee, notes,
      created_at, accepted_at, picked_up_at, delivered_at, rejected_at,
      rejection_reason,
      ready_at, ready_countdown,
      merchants:merchant_id (name, phone, address),
      drivers:driver_id   (name, phone)
    `
    )
    .order("created_at", { ascending: false })
    .limit(10);

  if (role === "driver") {
    query = query.eq("driver_id", params.user_id);
  } else if (role === "merchant") {
    query = query.eq("merchant_id", params.user_id);
  } else {
    // customer — match by phone since customers may not have a user record
    const { data: u } = await supabase
      .from("users")
      .select("phone")
      .eq("id", params.user_id)
      .maybeSingle();
    if (u?.phone) {
      query = query.eq("customer_phone", u.phone);
    } else {
      return { error: "Cannot identify customer phone", role };
    }
  }

  // Optionally filter by status
  if (params.status) {
    query = query.eq("status", params.status);
  } else {
    // Default: active orders (not done)
    query = query.not("status", "in", '("delivered","cancelled")');
  }

  const { data, error } = await query;
  if (error) return { error: error.message };

  const orders = (data ?? []).map((o: any) => {
    const formatted = formatPhoneInObject(o, "customer_phone");
    if (formatted.merchants) formatted.merchants = formatPhoneInObject(formatted.merchants, "phone");
    if (formatted.drivers) formatted.drivers = formatPhoneInObject(formatted.drivers, "phone");
    return formatted;
  });

  return { role, orders, count: orders.length };
}

async function advanceOrderToOnTheWay(
  params: { order_id: string; driver_id: string },
  supabase: ReturnType<typeof createClient>
) {
  if (!params.order_id) return { error: "order_id is required" };
  if (!params.driver_id) return { error: "driver_id is required" };

  const { data: order, error: fetchErr } = await supabase
    .from("orders")
    .select("id, status, driver_id, customer_phone")
    .eq("id", params.order_id)
    .maybeSingle();

  if (fetchErr) return { error: fetchErr.message };
  if (!order) return { error: "Order not found" };
  if (order.driver_id !== params.driver_id) return { error: "You are not assigned to this order" };
  if (order.status !== "picked_up") {
    return { error: `Cannot advance — order is currently '${order.status}', expected 'picked_up'` };
  }
  if (!order.customer_phone || order.customer_phone.trim() === "") {
    return {
      error: "customer_phone is missing",
      action_required: "Call update_customer_phone first, then retry advance_order_to_on_the_way",
    };
  }

  const { error: updateErr } = await supabase
    .from("orders")
    .update({ status: "on_the_way", picked_up_at: new Date().toISOString() })
    .eq("id", params.order_id);

  if (updateErr) return { error: updateErr.message };
  return { success: true, new_status: "on_the_way", order_id: params.order_id };
}

async function updateCustomerPhone(
  params: { order_id: string; customer_phone: string; driver_id: string },
  supabase: ReturnType<typeof createClient>
) {
  if (!params.order_id) return { error: "order_id is required" };
  if (!params.customer_phone) return { error: "customer_phone is required" };
  if (!params.driver_id) return { error: "driver_id is required" };

  const phoneCheck = validateIraqiPhone(params.customer_phone);
  if (!phoneCheck.valid) return { error: phoneCheck.error };
  params.customer_phone = phoneCheck.formatted!;

  const { data: order, error: fetchErr } = await supabase
    .from("orders")
    .select("id, status, driver_id")
    .eq("id", params.order_id)
    .maybeSingle();

  if (fetchErr) return { error: fetchErr.message };
  if (!order) return { error: "Order not found" };
  if (order.driver_id !== params.driver_id) return { error: "You are not assigned to this order" };
  if (!["accepted", "picked_up"].includes(order.status)) {
    return { error: `Cannot update phone — order is '${order.status}'` };
  }

  const { error: updateErr } = await supabase
    .from("orders")
    .update({ customer_phone: params.customer_phone.trim() })
    .eq("id", params.order_id);

  if (updateErr) return { error: updateErr.message };
  return { success: true, customer_phone: params.customer_phone, order_id: params.order_id };
}

async function cancelOrder(
  params: { order_id: string; requester_id: string; reason: string },
  supabase: ReturnType<typeof createClient>
) {
  if (!params.order_id) return { error: "order_id is required" };
  if (!params.requester_id) return { error: "requester_id is required" };
  if (!params.reason) return { error: "reason is required" };

  const { data: order, error: fetchErr } = await supabase
    .from("orders")
    .select("id, status, merchant_id, driver_id")
    .eq("id", params.order_id)
    .maybeSingle();

  if (fetchErr) return { error: fetchErr.message };
  if (!order) return { error: "Order not found" };

  if (order.merchant_id !== params.requester_id) {
    return { error: "Only the order's merchant can cancel. Escalate to admin if a driver or other party requests cancellation." };
  }
  if (["picked_up", "on_the_way", "delivered", "cancelled"].includes(order.status)) {
    return { error: `Cannot cancel — order is already '${order.status}'. Escalate to admin if cancellation is still required.` };
  }

  // Find admin user for the RPC call
  const { data: admin } = await supabase.from("users").select("id").eq("role", "admin").limit(1).maybeSingle();
  if (!admin) return { error: "No admin user available to authorize cancellation" };

  const { data, error } = await supabase.rpc("admin_cancel_order", {
    p_order_id: params.order_id,
    p_admin_id: admin.id,
    p_reason: params.reason,
  });

  if (error) return { error: error.message };
  return { success: true, order_id: params.order_id, result: data };
}

async function updateDeliveryAddress(
  params: { order_id: string; requester_id: string; new_address: string },
  supabase: ReturnType<typeof createClient>
) {
  if (!params.order_id) return { error: "order_id is required" };
  if (!params.requester_id) return { error: "requester_id is required" };
  if (!params.new_address || params.new_address.trim().length < 5) {
    return { error: "new_address must be at least 5 characters" };
  }

  const { data: order, error: fetchErr } = await supabase
    .from("orders")
    .select("id, status, merchant_id, driver_id, delivery_address")
    .eq("id", params.order_id)
    .maybeSingle();

  if (fetchErr) return { error: fetchErr.message };
  if (!order) return { error: "Order not found" };

  if (order.merchant_id !== params.requester_id) {
    return { error: "Only the merchant can edit delivery address. Escalate if anyone else requests this." };
  }
  if (["delivered", "cancelled"].includes(order.status)) {
    return { error: `Cannot edit — order is '${order.status}'` };
  }

  const { data: admin } = await supabase.from("users").select("id").eq("role", "admin").limit(1).maybeSingle();

  const { data, error } = await supabase.rpc("admin_update_order_details", {
    p_order_id: params.order_id,
    p_delivery_address: params.new_address.trim(),
    p_admin_id: admin?.id ?? null,
  });

  if (error) return { error: error.message };

  // Notify the driver of the change if assigned
  if (order.driver_id) {
    await supabase.from("notifications").insert({
      user_id: order.driver_id,
      title: "تحديث عنوان التوصيل / Delivery address updated",
      body: `العنوان الجديد: ${params.new_address.trim()}`,
      type: "order_status_update",
      data: { order_id: params.order_id, new_delivery_address: params.new_address.trim() },
    });
  }

  return {
    success: true,
    old_address: order.delivery_address,
    new_address: params.new_address.trim(),
    driver_notified: !!order.driver_id,
    result: data,
  };
}

async function getOrderAssignmentHistory(
  params: { order_id: string },
  supabase: ReturnType<typeof createClient>
) {
  if (!params.order_id) return { error: "order_id is required" };

  const { data, error } = await supabase
    .from("order_assignments")
    .select(
      `id, status, assigned_at, timeout_at, responded_at, response_time_seconds,
       driver:driver_id(id, name, phone, is_online)`
    )
    .eq("order_id", params.order_id)
    .order("assigned_at", { ascending: false })
    .limit(20);

  if (error) return { error: error.message };

  const summary = {
    total_attempts: data?.length ?? 0,
    accepted: data?.filter((a: any) => a.status === "accepted").length ?? 0,
    rejected: data?.filter((a: any) => a.status === "rejected").length ?? 0,
    timeout: data?.filter((a: any) => a.status === "timeout").length ?? 0,
    pending: data?.filter((a: any) => a.status === "pending").length ?? 0,
  };

  return { summary, assignments: data ?? [] };
}

async function getRecentNotifications(
  params: { user_id: string; limit?: number },
  supabase: ReturnType<typeof createClient>
) {
  if (!params.user_id) return { error: "user_id is required" };
  const lim = Math.min(params.limit ?? 15, 50);

  const { data, error } = await supabase
    .from("notifications")
    .select("id, title, body, type, is_read, created_at, data")
    .eq("user_id", params.user_id)
    .order("created_at", { ascending: false })
    .limit(lim);

  if (error) return { error: error.message };

  const last24h = (data ?? []).filter(
    (n: any) => Date.now() - new Date(n.created_at).getTime() < 24 * 60 * 60 * 1000
  ).length;

  return {
    count: data?.length ?? 0,
    last_24h_count: last24h,
    notifications: data ?? [],
    diagnosis:
      (data?.length ?? 0) === 0
        ? "No notifications recorded — likely a device push-token or app-permission issue."
        : `${last24h} notifications were sent to this user in the last 24h. If they did not receive them, the issue is on the device side (notification permissions, internet, FCM token).`,
  };
}

async function getDriverOnlineHours(
  params: { driver_id: string; month?: string },
  supabase: ReturnType<typeof createClient>
) {
  if (!params.driver_id) return { error: "driver_id is required" };

  const now = new Date();
  let monthStart: Date;
  let monthEnd: Date;

  if (params.month && /^\d{4}-\d{2}$/.test(params.month)) {
    const [y, m] = params.month.split("-").map(Number);
    monthStart = new Date(Date.UTC(y, m - 1, 1));
    monthEnd = new Date(Date.UTC(y, m, 1));
  } else {
    monthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
    monthEnd = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1));
  }

  const startStr = monthStart.toISOString().slice(0, 10);
  const endStr = monthEnd.toISOString().slice(0, 10);

  const { data, error } = await supabase
    .from("driver_online_hours")
    .select("date, hours_online")
    .eq("driver_id", params.driver_id)
    .gte("date", startStr)
    .lt("date", endStr)
    .order("date", { ascending: false });

  if (error) return { error: error.message };

  const totalHours = (data ?? []).reduce((s: number, r: any) => s + Number(r.hours_online ?? 0), 0);
  const daysActive = (data ?? []).filter((r: any) => Number(r.hours_online ?? 0) > 0).length;

  let projectedRank = "bronze";
  let nextTierGap: string | null = null;
  if (totalHours >= 300) projectedRank = "gold";
  else if (totalHours >= 250) {
    projectedRank = "silver";
    nextTierGap = `Need ${(300 - totalHours).toFixed(1)}h more this month for gold`;
  } else {
    nextTierGap = `Need ${(250 - totalHours).toFixed(1)}h more this month for silver`;
  }

  return {
    month: startStr.slice(0, 7),
    total_hours: Number(totalHours.toFixed(2)),
    days_active: daysActive,
    projected_next_month_rank: projectedRank,
    next_tier_gap: nextTierGap,
    note: "Ranks are recalculated on the 1st of the following month based on this total.",
    daily_breakdown: data ?? [],
  };
}

// ─── Router ───────────────────────────────────────────────────────────────────

const TOOL_HANDLERS: Record<
  string,
  (params: any, supabase: ReturnType<typeof createClient>) => Promise<unknown>
> = {
  get_order_details: getOrderDetails,
  get_user_orders: getUserOrders,
  get_user_profile: getUserProfile,
  get_wallet_and_transactions: getWalletAndTransactions,
  get_city_settings: getCitySettings,
  get_merchant_contact: getMerchantContact,
  check_driver_timing: checkDriverTiming,
  escalate_to_human: (params) => escalateToHuman(params),
  advance_order_to_on_the_way: advanceOrderToOnTheWay,
  update_customer_phone: updateCustomerPhone,
  cancel_order: cancelOrder,
  update_delivery_address: updateDeliveryAddress,
  get_order_assignment_history: getOrderAssignmentHistory,
  get_recent_notifications: getRecentNotifications,
  get_driver_online_hours: getDriverOnlineHours,
};

// ─── Main handler ─────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    const body = await req.json();

    // OpenAI sends: { name, parameters, call_id }
    // Support both "parameters" and "input" field names
    const toolName: string = body.name ?? body.tool_name ?? "";
    const params: Record<string, unknown> =
      body.parameters ?? body.input ?? body.arguments ?? {};

    console.log(`🔧 Tool called: ${toolName}`, params);

    const handler = TOOL_HANDLERS[toolName];
    if (!handler) {
      return new Response(
        JSON.stringify({ error: `Unknown tool: ${toolName}` }),
        {
          status: 400,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        }
      );
    }

    const result = await handler(params, supabase);
    console.log(`✅ Result for ${toolName}:`, JSON.stringify(result).substring(0, 200));

    // OpenAI expects { output: ... } or { result: ... }
    return new Response(JSON.stringify({ output: result }), {
      status: 200,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (err: any) {
    console.error("Tool handler error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
