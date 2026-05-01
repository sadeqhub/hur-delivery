// Support Agent — AI-powered support for Hur Delivery
// Triggered by a Postgres trigger after any non-admin message is inserted
// into a support conversation. Runs an OpenAI agentic loop using the
// configured workflow and posts the final response back as an admin message.
//
// Architecture:
//   Postgres trigger → this function → OpenAI Responses API (workflow)
//                                   ↕ tool calls
//                          support-agent-tools edge function
//                          (queries Supabase, sends WhatsApp escalations)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const WORKFLOW_ID = "wf_69e4930707f08190b09c4916ba61aa670f88e57e836f7920";
const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const MODEL = "gpt-4.1-mini"; // cost-optimised; same capability for tool-calling support
const MAX_TOOL_ITERATIONS = 6;
const HISTORY_MESSAGES = 6; // limit context window — older messages rarely add value

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ─── Agent instructions ───────────────────────────────────────────────────────
// Kept concise to reduce token usage. All factual answers must come from tools.

const INSTRUCTIONS = `You are the AI support agent for **حُر للتوصيل** (Hur Delivery in English) — a last-mile delivery platform in Iraq. Tagline: "Freedom in Every Delivery" / "حرية في كل توصيل".

BRAND IDENTITY (use the correct names — never transliterate):
- Arabic name: حُر للتوصيل  (NOT "هور ديليفري" / "هور دليفري" — those are wrong)
- English name: Hur Delivery
- Website: https://hur.delivery
- Support email: support@hur.delivery
- Support phone / WhatsApp: +964 789 000 3093
- Headquarters: Iraq (operates across multiple Iraqi cities)
- What we do: a B2B last-mile delivery marketplace connecting merchants (shops, restaurants, businesses) with independent drivers (motorcycle, car, truck) who pick up orders and deliver them to the merchant's customers. Cash-on-delivery is the standard. Customers do not have their own app — they receive deliveries arranged by the merchant.
- Who you talk to: drivers and merchants who use the in-app support chat.

When introducing yourself or referring to the app:
- Arabic: قل "حُر للتوصيل" دائماً.
- English: say "Hur Delivery".
- Never use phonetic transliterations like "هور ديليفري" / "هور دليفري" / "Hor Delivery".

When someone asks for contact information, how to reach us, our phone, our website, or anything about the company:
  Share all relevant details together:
  - 📞 واتساب / WhatsApp: +9647890003093
  - 📧 البريد الإلكتروني / Email: support@hur.delivery
  - 🌐 الموقع / Website: https://hur.delivery
  - 💬 وهذا الشات هو قناة الدعم المباشرة / This chat is also a direct support channel.
  You do not need an explicit trigger — if the question is about reaching us, share everything above.

RULES
- Always call a tool before stating any fact about an order, wallet, or user.
- Default language: Arabic. Switch to English if the user writes in English.
- You always have the sender's user ID (sender_id) in context — use it to look up their information without asking them anything.
- For any user question (who they are, their city, their role, their wallet, their status): call get_user_profile(sender_id). This works regardless of whether they have active orders.
- For order-related questions: call get_user_orders(sender_id). If no active orders found, call again with status='delivered' or status='rejected' to look at recent history.
- Never ask the user for their order ID — always look it up via get_user_orders(sender_id) first.
- Amounts in IQD.
- Phone numbers: ALWAYS present in international Iraqi format (+964 7XX XXX XXXX). Tool results are pre-formatted. If a user gives you a local number (07XX...), convert it mentally: drop the leading 0, prepend +964. Never share a number that starts with 07 or is missing the country code.
- If you cannot resolve, call escalate_to_human.

SCOPE — STRICT TOPIC RESTRICTION
You are a delivery support assistant. You ONLY handle topics related to:
  orders, deliveries, drivers, merchants, wallets, commissions, ranks, notifications,
  the Hur Delivery app, account issues, and company contact information.

For ANYTHING outside this scope (jokes, stories, poems, general knowledge, coding help,
translation, advice, chitchat, math, geography, history, etc.) respond ONLY with:
  AR: "أنا مساعد دعم حُر للتوصيل فقط. كيف أقدر أساعدك بخصوص طلباتك أو حسابك؟"
  EN: "I'm only here to help with Hur Delivery support. How can I assist you with your orders or account?"
Use Arabic if the message is in Arabic, English if in English. No exceptions, no apologies, no explanations.

TONE AND STYLE
- Be concise and direct — like a knowledgeable human agent, not a formal chatbot.
- No long intros, no restating the question, no filler words like "of course!" or "great question!".
- Get to the point immediately. One or two sentences is usually enough.
- Use natural Arabic or English depending on the user. Avoid mixing languages mid-sentence unless sharing contact info.
- If you need to list info (address, phone, etc.), use short bullet points, not paragraphs.
- Never over-explain. If the user needs more detail, they will ask.

PLATFORM QUICK-REFERENCE
- Order flow: pending → assigned → accepted → picked_up → delivered | rejected | cancelled
- Auto-reject: driver has 30 s to accept, then order reassigns.
- Ready countdown: merchant sets ready_at. Driver should arrive after that time.
- HOW MONEY WORKS:
    • Driver collects the full delivery fee in CASH from the customer upon delivery.
    • The platform deducts a commission from the driver's wallet based on their rank.
    • Drivers do NOT withdraw — they already have the cash. The wallet only tracks commission deductions.
    • Merchant wallet is deducted per order (order_fee). Merchant needs balance > credit_limit to create orders.
- Ranks (reset monthly on 1st based on last month's online hours):
    trial → first calendar month, 0 % commission
    bronze → <250 h last month, 10 % commission
    silver → ≥250 h last month,  7 % commission
    gold   → ≥300 h last month,  5 % commission

USE CASES — follow these flows exactly:

WRONG PICKUP ADDRESS / CAN'T FIND STORE
  get_user_orders → get_merchant_contact → give correct address + phone.

ORDER REJECTED BY CUSTOMER
  get_user_orders or get_order_details → check_driver_timing → report verdict.
  Unclear verdict → escalate_to_human.

MISSING CUSTOMER INFO
  get_order_details → share customer_phone. If null → give merchant phone as fallback.

DRIVER NOT RECEIVING ORDERS
  get_user_profile → check is_online, city, rank. Guide to fix or escalate if suspended.

ORDER STUCK IN PENDING
  get_user_orders → explain auto-assign is looking for a driver. If >30 min → escalate.

DRIVER CAN'T GO ONLINE
  get_user_profile → check account status. If suspended or unverified → escalate_to_human.

ORDER CANCELLATION (MERCHANT, BEFORE PICKUP)
  If sender_role is merchant AND order is in pending/assigned/accepted:
    Confirm intent + reason → call cancel_order(order_id, sender_id, reason).
  If post-pickup OR requester is not the merchant → escalate_to_human.

DELIVERY ADDRESS CHANGE (MERCHANT REQUEST)
  Verify sender is the merchant of the order, confirm new full address with them,
  then call update_delivery_address(order_id, sender_id, new_address).
  Driver is auto-notified. If post-delivery → cannot edit, escalate.

DRIVER ASKS "WHY DIDN'T I GET THIS ORDER?"
  get_order_assignment_history(order_id). Look at the assignment list:
    - If driver is not in it → they were not in the rotation (offline, wrong city, or vehicle mismatch).
    - If their row shows status='timeout' → they didn't accept within 30 s.
    - If status='rejected' → they (or auto-system) rejected it.
  Explain honestly. If they think it's unfair → escalate.

MERCHANT: "MY ORDER IS TAKING TOO LONG TO ASSIGN"
  get_order_assignment_history(order_id). If many timeouts/rejections → escalate.
  If under 5 min and no attempts yet → reassure auto-assign is searching.

NOT RECEIVING NOTIFICATIONS
  get_recent_notifications(sender_id). Read the diagnosis field:
    - If 0 sent → server-side issue, escalate.
    - If recent ones were sent → device-side (notification permission, FCM token, internet).
      Advise: enable notifications in phone settings, force-close + reopen the app, check internet.
  If still not working after troubleshooting → escalate.

DRIVER RANK PROGRESS / "HOW DO I REACH SILVER/GOLD?"
  get_driver_online_hours(sender_id). Share total hours this month, days active,
  projected next-month rank, and how many more hours needed for the next tier.
  Remind: ranks are recalculated on the 1st of each month from the previous month.

DRIVER VEHICLE BREAKDOWN / ACCIDENT / EMERGENCY
  Express empathy. Get the order_id and a brief description.
  escalate_to_human immediately — admin will reassign and follow up.

CUSTOMER NOT AT DELIVERY ADDRESS / NO ANSWER
  get_order_details → confirm customer_phone. Advise: try calling 2-3 times,
  wait 5 min at the delivery point. If still unreachable → escalate so admin
  can decide between return-to-merchant or marking failed delivery.

DAMAGED ITEM / WRONG ITEM / MISSING ITEM COMPLAINTS
  These require investigation and possibly a refund — escalate_to_human immediately.

LOST CASH / PAYMENT DISPUTE
  Anything involving missing money — escalate_to_human immediately. Never attempt resolution.

WALLET TOP-UP REQUEST (MERCHANT)
  Explain self-service options (Zain Cash, QI Card, Hur representative).
  If they need confirmation of a payment they already made or a bank transfer → escalate_to_human.

DRIVER CONFUSED ABOUT ORDER FEE / PAYING MERCHANT BEFORE PICKUP
  This is a common misunderstanding. Explain clearly:
  "عند وصولك للمتجر لاستلام الطلب، ستدفع للتاجر رسوم المنتج أو التوصيل حسب اتفاقكم.
   بعد التوصيل، تستلم من الزبون مبلغ رسوم التوصيل نقداً.
   المنصة تخصم نسبة عمولتك فقط من محفظتك تلقائياً."
  EN: "When you arrive at the store, you pay the merchant the agreed amount before taking the order.
       After delivery, you collect the delivery fee in cash from the customer.
       The platform automatically deducts only your commission percentage from your wallet."
  If driver is confused about the specific amount → get_order_details → share delivery_fee and notes.

DRIVER WALLET / COMMISSION DEDUCTIONS
  get_wallet_and_transactions → show current balance and recent commission deductions.
  Clarify: the wallet balance represents net commissions owed or paid — drivers do not withdraw from it.
  Explain: commission = delivery_fee × rank_percentage (e.g. bronze = 10%).
  For rank details → get_city_settings.

MERCHANT WALLET / BALANCE
  get_wallet_and_transactions → show balance, order_fee, credit_limit, recent transactions.
  If balance below credit_limit: explain top-up options (Zain Cash, QI Card, representative).

HOW TO TOP UP (merchant)
  Methods: Zain Cash, QI Card, or visiting a Hur representative. For bank transfer → escalate.

COMMISSION / RANK QUESTIONS
  get_city_settings → explain rank tiers, percentages, and monthly reset logic.

SCHEDULED ORDERS
  Orders can be scheduled in advance; they enter the pending pool at the scheduled time.

BULK ORDERS
  Multiple orders can be booked together; each is treated as an individual delivery.

VEHICLE TYPE ISSUES
  get_user_profile → check vehicle_type. If mismatch with order requirements → escalate.

AREA NOT COVERED
  Delivery zones are set by the city. If customer address is outside → escalate.

DRIVER STUCK AFTER PICKUP — NEEDS TO MARK ON THE WAY
  Step 1: call advance_order_to_on_the_way(order_id, sender_id).
  Step 2: if it returns customer_phone missing error:
    Ask the driver: "من فضلك أعطني رقم هاتف الزبون لإكمال الطلب."
    EN: "Please provide the customer's phone number to continue."
  Step 3: once driver provides phone → call update_customer_phone(order_id, phone, sender_id).
  Step 4: retry advance_order_to_on_the_way(order_id, sender_id).
  Note: always use sender_id (from context) as driver_id, never ask the driver for their ID.

CUSTOMER CANNOT BE REACHED
  get_order_details → share customer_phone with driver. Advise to try again or note in delivery.

APP TECHNICAL ISSUES (crash, slow, login)
  Advise: force-close and reopen, check internet. If persists → escalate_to_human.

ACCOUNT ISSUES (suspension, verification, payment disputes)
  escalate_to_human immediately — never guess on these.

ESCALATION MESSAGE (always say this after escalating):
  AR: "تم إحالة طلبك إلى فريق الدعم وسيتواصل معك قريباً."
  EN: "Your request has been escalated and our team will follow up shortly."`;

// Tool definitions — must match what's configured in the OpenAI workflow.
// When OpenAI calls a tool, we forward the call to support-agent-tools.
const TOOLS = [
  {
    type: "function",
    name: "get_user_orders",
    description:
      "Fetch active (or recent) orders for a user without needing an order ID. Use this first whenever the user mentions an order but doesn't provide an ID. Automatically filters by the user's role (driver, merchant, or customer). Pass status='delivered' or status='rejected' to see past orders.",
    parameters: {
      type: "object",
      properties: {
        user_id: {
          type: "string",
          description: "The user UUID — use the sender_id from context",
        },
        status: {
          type: "string",
          description:
            "Optional status filter: pending, assigned, accepted, picked_up, delivered, rejected, cancelled. Omit to get all active orders.",
        },
      },
      required: ["user_id"],
    },
  },
  {
    type: "function",
    name: "get_order_details",
    description:
      "Fetch complete details for a specific order by ID. Use get_user_orders first if you don't have an order ID.",
    parameters: {
      type: "object",
      properties: {
        order_id: { type: "string", description: "The order UUID" },
      },
      required: ["order_id"],
    },
  },
  {
    type: "function",
    name: "get_user_profile",
    description:
      "Fetch a user profile including name, phone, role, city, online status, and wallet balance.",
    parameters: {
      type: "object",
      properties: {
        user_id: { type: "string", description: "The user UUID" },
      },
      required: ["user_id"],
    },
  },
  {
    type: "function",
    name: "get_wallet_and_transactions",
    description:
      "Fetch a user's wallet balance and recent transactions. Works for both drivers (driver_wallets) and merchants (merchant_wallets). Use when the user asks about balance, earnings, deductions, top-ups, or transaction history.",
    parameters: {
      type: "object",
      properties: {
        user_id: { type: "string", description: "The user UUID (use sender_id from context)" },
        limit: { type: "number", description: "Number of recent transactions to return (default 20, max 50)" },
      },
      required: ["user_id"],
    },
  },
  {
    type: "function",
    name: "get_city_settings",
    description:
      "Fetch commission rates, rank system rules, and city-specific settings. Use when the user asks about commission percentages, rank tiers (trial/bronze/silver/gold), how to rank up, or city-level wallet settings.",
    parameters: {
      type: "object",
      properties: {
        city: { type: "string", description: "City name (e.g. 'najaf', 'mosul'). Omit to get all cities." },
      },
      required: [],
    },
  },
  {
    type: "function",
    name: "get_merchant_contact",
    description:
      "Fetch a merchant's contact details (name, phone, stored address) to help a driver locate the pickup point.",
    parameters: {
      type: "object",
      properties: {
        merchant_id: { type: "string", description: "The merchant user UUID" },
      },
      required: ["merchant_id"],
    },
  },
  {
    type: "function",
    name: "check_driver_timing",
    description:
      "Analyze driver performance on an order to determine fault in a rejection. Returns timing metrics and a verdict.",
    parameters: {
      type: "object",
      properties: {
        order_id: { type: "string", description: "The order UUID to analyze" },
      },
      required: ["order_id"],
    },
  },
  {
    type: "function",
    name: "escalate_to_human",
    description:
      "Escalate the support case to a human admin via email when the AI cannot resolve the issue.",
    parameters: {
      type: "object",
      properties: {
        reason: { type: "string" },
        summary: { type: "string" },
        conversation_id: { type: "string" },
      },
      required: ["reason", "summary", "conversation_id"],
    },
  },
  {
    type: "function",
    name: "advance_order_to_on_the_way",
    description:
      "Advance a driver's order status from picked_up to on_the_way. Will fail if customer_phone is missing — call update_customer_phone first in that case. Only works for the order's assigned driver.",
    parameters: {
      type: "object",
      properties: {
        order_id: { type: "string", description: "The order UUID" },
        driver_id: { type: "string", description: "The driver's user UUID — use sender_id from context" },
      },
      required: ["order_id", "driver_id"],
    },
  },
  {
    type: "function",
    name: "update_customer_phone",
    description:
      "Update the customer phone number on an order. Use when the driver needs to advance a picked_up order but the customer_phone is missing. Only works for the order's assigned driver.",
    parameters: {
      type: "object",
      properties: {
        order_id: { type: "string", description: "The order UUID" },
        customer_phone: { type: "string", description: "Customer phone in Iraqi format (+964...)" },
        driver_id: { type: "string", description: "The driver's user UUID — use sender_id from context" },
      },
      required: ["order_id", "customer_phone", "driver_id"],
    },
  },
  {
    type: "function",
    name: "cancel_order",
    description:
      "Cancel an order on behalf of the merchant. Only works if the requester is the order's merchant AND the order is still in pending/assigned/accepted status (before pickup). For any other party or post-pickup, escalate instead.",
    parameters: {
      type: "object",
      properties: {
        order_id: { type: "string", description: "The order UUID" },
        requester_id: { type: "string", description: "The requesting user's UUID — use sender_id from context" },
        reason: { type: "string", description: "Why the merchant wants to cancel" },
      },
      required: ["order_id", "requester_id", "reason"],
    },
  },
  {
    type: "function",
    name: "update_delivery_address",
    description:
      "Update the delivery address on an active order. Only works if the requester is the order's merchant. Driver is automatically notified if assigned.",
    parameters: {
      type: "object",
      properties: {
        order_id: { type: "string", description: "The order UUID" },
        requester_id: { type: "string", description: "The requesting user's UUID — use sender_id from context" },
        new_address: { type: "string", description: "Full new delivery address" },
      },
      required: ["order_id", "requester_id", "new_address"],
    },
  },
  {
    type: "function",
    name: "get_order_assignment_history",
    description:
      "Fetch the full assignment history for an order — which drivers were notified, who accepted/rejected/timed out. Use when a driver asks why they did not receive an order, or when a merchant complains an order is taking too long.",
    parameters: {
      type: "object",
      properties: {
        order_id: { type: "string", description: "The order UUID" },
      },
      required: ["order_id"],
    },
  },
  {
    type: "function",
    name: "get_recent_notifications",
    description:
      "Fetch a user's recent push notifications. Use when the user complains they're not receiving notifications. Result includes a diagnosis of whether the issue is server-side (no notifications sent) or device-side (sent but not received).",
    parameters: {
      type: "object",
      properties: {
        user_id: { type: "string", description: "The user UUID — use sender_id from context" },
        limit: { type: "number", description: "How many recent notifications to return (default 15, max 50)" },
      },
      required: ["user_id"],
    },
  },
  {
    type: "function",
    name: "get_driver_online_hours",
    description:
      "Fetch a driver's monthly online hours total and projected next-month rank. Use when a driver asks about rank progress, how close they are to silver/gold, or why their rank changed.",
    parameters: {
      type: "object",
      properties: {
        driver_id: { type: "string", description: "The driver's user UUID — use sender_id from context" },
        month: { type: "string", description: "Optional: month in YYYY-MM format. Omit for current month." },
      },
      required: ["driver_id"],
    },
  },
];

// ─── Tool executor ────────────────────────────────────────────────────────────
// Forwards tool calls to the support-agent-tools webhook, which runs the
// actual Supabase queries. Keeping tool execution in a dedicated function
// means the workflow and the tools endpoint stay independently deployable.

async function executeTool(
  toolName: string,
  parameters: Record<string, unknown>,
  supabaseUrl: string,
  serviceKey: string
): Promise<unknown> {
  const toolsUrl = `${supabaseUrl}/functions/v1/support-agent-tools`;

  const res = await fetch(toolsUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${serviceKey}`,
    },
    body: JSON.stringify({ name: toolName, parameters }),
  });

  if (!res.ok) {
    const text = await res.text();
    return { error: `Tool endpoint error ${res.status}: ${text}` };
  }

  const json = await res.json();
  // support-agent-tools returns { output: ... }
  return json.output ?? json;
}

// ─── OpenAI agentic loop ──────────────────────────────────────────────────────

async function runAgentLoop(
  inputMessages: unknown[],
  conversationId: string,
  openaiKey: string,
  supabaseUrl: string,
  serviceKey: string
): Promise<string> {
  let currentInput = inputMessages;
  let previousResponseId: string | null = null;

  for (let i = 0; i < MAX_TOOL_ITERATIONS; i++) {
    const body: Record<string, unknown> = {
      model: MODEL,
      instructions: INSTRUCTIONS,
      tools: TOOLS,
      input: currentInput,
      metadata: { workflow_id: WORKFLOW_ID, conversation_id: conversationId },
    };

    if (previousResponseId) {
      body.previous_response_id = previousResponseId;
    }

    const res = await fetch(OPENAI_RESPONSES_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openaiKey}`,
        "Content-Type": "application/json",
        "OpenAI-Beta": "agents=v1",
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const errText = await res.text();
      console.error(`OpenAI error ${res.status}:`, errText);
      throw new Error(`OpenAI API error ${res.status}: ${errText}`);
    }

    const result = await res.json();
    previousResponseId = result.id ?? null;

    if (!result.output || result.output.length === 0) break;

    // ── Final text response ───────────────────────────────────────────────
    const messageOutput = result.output.find(
      (o: any) => o.type === "message" || o.type === "text"
    );
    if (messageOutput) {
      const content = messageOutput.content ?? messageOutput.text ?? "";
      if (Array.isArray(content)) {
        const part = content.find(
          (c: any) => c.type === "output_text" || c.type === "text"
        );
        return part?.text ?? "";
      }
      return String(content);
    }

    // ── Tool calls — execute via support-agent-tools, then continue ───────
    const toolCalls = result.output.filter(
      (o: any) => o.type === "function_call"
    );
    if (toolCalls.length === 0) break;

    const toolResults: unknown[] = [];

    for (const call of toolCalls) {
      const args =
        typeof call.arguments === "string"
          ? JSON.parse(call.arguments)
          : call.arguments ?? {};

      console.log(`🔧 Tool: ${call.name}`, JSON.stringify(args));

      const output = await executeTool(
        call.name,
        args,
        supabaseUrl,
        serviceKey
      );

      console.log(`✅ ${call.name} →`, JSON.stringify(output).substring(0, 200));

      toolResults.push({
        type: "function_call_output",
        call_id: call.call_id,
        output: JSON.stringify(output),
      });
    }

    currentInput = toolResults;
  }

  return (
    "عذرًا، لم أتمكن من معالجة طلبك. سيتواصل معك فريق الدعم قريبًا.\n" +
    "Sorry, I couldn't process your request. Our support team will follow up shortly."
  );
}

// ─── Main handler ─────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  console.log("\n══════════════════════════════════════════════");
  console.log("🤖  SUPPORT AGENT — processing message");
  console.log("══════════════════════════════════════════════\n");

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const openaiKey = Deno.env.get("OPENAI_API_KEY");

    if (!openaiKey) throw new Error("OPENAI_API_KEY not configured");
    if (!serviceKey) throw new Error("SUPABASE_SERVICE_ROLE_KEY not configured");

    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const body = await req.json();
    const {
      conversation_id,
      message_id,
      sender_id,
      message_body,
      sender_name,
      sender_role,
    } = body;

    if (!conversation_id || !message_id || !sender_id) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), {
        status: 400,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    console.log(`📨  Conversation : ${conversation_id}`);
    console.log(`👤  Sender       : ${sender_name ?? "?"} (${sender_role ?? "?"})`);
    console.log(`💬  Message      : ${(message_body ?? "").substring(0, 120)}`);

    // ── Rate limiting ─────────────────────────────────────────────────────────
    // Messages tied to an active order are never throttled — the driver or
    // merchant may genuinely need rapid back-and-forth during a live delivery.
    // Only idle / non-order conversations count toward limits.

    const ACTIVE_ORDER_STATUSES = ["pending", "assigned", "accepted", "picked_up", "on_the_way"];

    const { data: convOrder } = await supabase
      .from("conversations")
      .select("order_id, orders!inner(status)")
      .eq("id", conversation_id)
      .maybeSingle();

    const linkedOrderStatus = (convOrder?.orders as any)?.status ?? null;
    const hasActiveOrder = linkedOrderStatus && ACTIVE_ORDER_STATUSES.includes(linkedOrderStatus);

    let rateLimitMessage: string | null = null;

    if (!hasActiveOrder) {
      const now = Date.now();
      const since60s = new Date(now - 60_000).toISOString();
      const since1h  = new Date(now - 3_600_000).toISOString();
      const since24h = new Date(now - 86_400_000).toISOString();

      const [burstRes, hourlyRes, dailyRes] = await Promise.all([
        // Burst: user sent > 5 messages in the last 60 s
        supabase
          .from("messages")
          .select("id", { count: "exact", head: true })
          .eq("sender_id", sender_id)
          .gte("created_at", since60s),

        // Hourly: bot replied > 30 times in this conversation in the last hour
        supabase
          .from("messages")
          .select("id", { count: "exact", head: true })
          .eq("conversation_id", conversation_id)
          .neq("sender_id", sender_id)
          .gte("created_at", since1h),

        // Daily: user sent > 80 messages across all conversations in 24 h
        supabase
          .from("messages")
          .select("id", { count: "exact", head: true })
          .eq("sender_id", sender_id)
          .gte("created_at", since24h),
      ]);

      const burstCount  = burstRes.count  ?? 0;
      const hourlyCount = hourlyRes.count ?? 0;
      const dailyCount  = dailyRes.count  ?? 0;

      if (burstCount > 5) {
        console.warn(`🚫 Burst limit — sender ${sender_id}: ${burstCount} msgs/60s`);
        rateLimitMessage =
          "الرجاء الانتظار لحظة قبل إرسال رسائل أخرى.\n" +
          "Please wait a moment before sending more messages.";
      } else if (hourlyCount > 30) {
        console.warn(`🚫 Hourly limit — conv ${conversation_id}: ${hourlyCount} bot replies/1h`);
        rateLimitMessage =
          "تم تجاوز الحد المسموح به لهذه المحادثة. للمساعدة تواصل معنا على واتساب: +964 789 000 3093\n" +
          "This conversation has exceeded its hourly limit. Contact us on WhatsApp: +964 789 000 3093";
      } else if (dailyCount > 80) {
        console.warn(`🚫 Daily limit — sender ${sender_id}: ${dailyCount} msgs/24h`);
        rateLimitMessage =
          "لقد تجاوزت الحد اليومي للرسائل. تواصل معنا مباشرة: +964 789 000 3093\n" +
          "You've reached the daily message limit. Contact us directly: +964 789 000 3093";
      }
    } else {
      console.log(`✅ Active order (${linkedOrderStatus}) — rate limits bypassed`);
    }

    if (rateLimitMessage) {
      // Find admin to post the refusal as (same pattern as normal replies)
      const { data: adminUser } = await supabase
        .from("users").select("id").eq("role", "admin").limit(1).maybeSingle();
      if (adminUser) {
        await supabase.from("conversation_participants").upsert(
          { conversation_id, user_id: adminUser.id },
          { onConflict: "conversation_id,user_id", ignoreDuplicates: true }
        );
        await supabase.from("messages").insert({
          conversation_id,
          sender_id: adminUser.id,
          body: rateLimitMessage,
          kind: "text",
        });
      }
      return new Response(JSON.stringify({ success: false, reason: "rate_limited" }), {
        status: 429,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }
    // ── End rate limiting ─────────────────────────────────────────────────────

    // Fetch conversation to get the linked order_id
    const { data: conv } = await supabase
      .from("conversations")
      .select("id, order_id, is_support")
      .eq("id", conversation_id)
      .maybeSingle();

    // Recent conversation history — capped to limit token usage
    const { data: history } = await supabase
      .from("messages")
      .select("id, body, kind, sender_id, users:sender_id(role)")
      .eq("conversation_id", conversation_id)
      .neq("id", message_id)
      .order("created_at", { ascending: false })
      .limit(HISTORY_MESSAGES);

    const recentMessages = (history ?? []).reverse();

    // Build OpenAI input from conversation history
    const inputMessages: unknown[] = [];

    for (const msg of recentMessages) {
      const senderInfo = msg.users as any;
      const role = senderInfo?.role === "admin" ? "assistant" : "user";
      const text = msg.body ?? (msg.kind !== "text" ? "[Attachment]" : "");
      if (text) inputMessages.push({ role, content: text });
    }

    // Build context header attached to the current message
    const contextLines: string[] = [
      "## Sender",
      `- Name: ${sender_name ?? "Unknown"}`,
      `- Role: ${sender_role ?? "unknown"}`,
      `- User ID: ${sender_id}`,
      `- Tip: call get_user_orders("${sender_id}") to see their active orders without asking for an order ID.`,
    ];

    if (conv?.order_id) {
      contextLines.push(
        "\n## Linked Order",
        `- Order ID: ${conv.order_id}`,
        `- Tip: call get_order_details("${conv.order_id}") for full details`
      );
    }

    contextLines.push("\n## Support Message", message_body ?? "");

    inputMessages.push({ role: "user", content: contextLines.join("\n") });

    // Run the agentic loop
    console.log("🚀  Running agent loop…");
    const agentReply = await runAgentLoop(
      inputMessages,
      conversation_id,
      openaiKey,
      supabaseUrl,
      serviceKey
    );

    if (!agentReply.trim()) {
      console.warn("⚠️  Empty reply from agent");
      return new Response(
        JSON.stringify({ success: false, error: "Empty agent reply" }),
        { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    console.log(`✅  Reply (${agentReply.length} chars):`, agentReply.substring(0, 140));

    // Find an admin user to post the reply as (prevents the trigger from re-firing)
    const { data: adminUser } = await supabase
      .from("users")
      .select("id")
      .eq("role", "admin")
      .limit(1)
      .maybeSingle();

    if (!adminUser) {
      console.error("❌  No admin user found");
      return new Response(JSON.stringify({ error: "No admin user found" }), {
        status: 500,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    // Ensure the admin is a conversation participant so that:
    // 1. Supabase Realtime delivers the message to all subscribers (RLS check passes)
    // 2. The Flutter app's JOIN on conversation_participants resolves the sender info
    // ON CONFLICT DO NOTHING is safe — idempotent across multiple replies.
    await supabase.from("conversation_participants").upsert(
      { conversation_id, user_id: adminUser.id },
      { onConflict: "conversation_id,user_id", ignoreDuplicates: true }
    );

    // Insert the AI reply. Posting as admin ensures the Postgres trigger skips
    // it (trigger filters out admin senders — no infinite loop).
    const { error: insertError } = await supabase.from("messages").insert({
      conversation_id,
      sender_id: adminUser.id,
      body: agentReply,
      kind: "text",
    });

    if (insertError) {
      console.error("❌  Failed to insert reply:", insertError);
      throw insertError;
    }

    console.log("✅  Reply posted to conversation");

    return new Response(
      JSON.stringify({ success: true, workflow_id: WORKFLOW_ID }),
      { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("❌  Support agent error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
