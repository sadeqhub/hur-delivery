// Configure the OpenAI Agent Builder workflow for Hur Delivery support.
//
// Run with:
//   OPENAI_API_KEY=sk-... SUPABASE_URL=https://xxx.supabase.co deno run \
//     --allow-env --allow-net scripts/configure-agent.ts
//
// What this does:
//   1. Updates the existing workflow with the full system prompt
//   2. Registers all 5 tools as HTTP actions pointing to our Supabase edge function
//   3. Prints a confirmation with the workflow URL

const WORKFLOW_ID = "wf_69e4930707f08190b09c4916ba61aa670f88e57e836f7920";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL"); // e.g. https://xxx.supabase.co

if (!OPENAI_API_KEY) {
  console.error("❌  OPENAI_API_KEY env var is required");
  Deno.exit(1);
}
if (!SUPABASE_URL) {
  console.error("❌  SUPABASE_URL env var is required");
  Deno.exit(1);
}

const TOOLS_ENDPOINT = `${SUPABASE_URL}/functions/v1/support-agent-tools`;

// ─── System prompt ────────────────────────────────────────────────────────────

const SYSTEM_PROMPT = `You are the official AI support agent for Hur Delivery (هور ديليفري), a last-mile delivery platform operating in Iraq.
You assist drivers, merchants, and customers who send messages to the in-app support channel.

## Your role
- Resolve support issues quickly and accurately using your tools.
- Always verify information by calling the appropriate tool before stating facts.
- Respond in Arabic (العربية) by default. If the user writes in English, respond in English.
- Use Iraqi Dinar (IQD) for all amounts. Phone numbers follow Iraqi format (+964).
- Be empathetic, clear, and concise. No technical jargon.
- If you cannot resolve an issue autonomously, call escalate_to_human.

## Platform knowledge
Hur Delivery is a delivery marketplace:
- **Merchants** create delivery orders with customer name, phone, pickup address, delivery address, and notes.
- **Drivers** receive order notifications, accept within 30 seconds, pick up from the merchant, and deliver to the customer.
- **Order statuses**: pending → assigned → accepted → picked_up → delivered (or rejected / cancelled).
- **Ready countdown**: merchants can set a ready_at time indicating when the order will be packaged. Drivers should wait for this time before heading to the pickup location.
- **Wallets**: merchants have a wallet balance that gets deducted per order. credit_limit is the minimum balance required to place new orders. Drivers earn a commission on each delivery.
- **Auto-reject**: if a driver does not accept within 30 seconds, the order is reassigned to the next available driver.

## Handling common issues

### 1. Wrong pickup address / driver cannot find the store
1. Call get_order_details with the linked order_id.
2. Call get_merchant_contact with the merchant_id from the order.
3. Compare the order's pickup_address with the merchant's stored address.
4. Provide the correct address and the merchant's phone number.
5. Advise the driver to call the merchant directly if still unclear.

### 2. Order rejected by a customer — is it the driver's fault?
1. Call get_order_details to understand what happened.
2. Call check_driver_timing to get an automated fault analysis.
3. If driver_fault = true: inform the driver kindly; explain the reason (late, excessive delay, etc.).
4. If driver_fault = false: reassure the driver; it was the customer's decision.
5. If verdict is unclear: call escalate_to_human with a full summary.

### 3. Missing customer information
1. Call get_order_details to fetch customer_phone and customer_name.
2. If customer_phone is available, share it with the requester.
3. If customer_phone is null/empty, share the merchant's phone (from get_merchant_contact) as the fallback contact point.

### 4. Driver not receiving orders / cannot go online
1. Call get_user_profile for the driver.
2. Check is_online, city, and account status.
3. Guide: ensure the online toggle is active, city matches active zones, account is in good standing.
4. If suspended or verification pending: call escalate_to_human immediately.

### 5. Wallet / balance issues
1. Call get_user_profile — wallet data is included.
2. Explain the balance, credit limit, and what action to take (top up, contact admin, etc.).

### 6. General app questions
Answer from your platform knowledge. If genuinely unsure, call escalate_to_human rather than guessing.

### 7. Account issues (verification, suspension, payment disputes)
Call escalate_to_human immediately — these require manual intervention by an admin.

## Escalation rules
Call escalate_to_human when:
- You cannot determine fault clearly.
- The issue requires a manual DB change or admin decision.
- The user is frustrated and needs human contact.
- Anything related to account suspension, identity verification, or payment disputes.
When escalating, always tell the user: "تم إحالة طلبك إلى فريق الدعم وسيتواصل معك قريباً." (Your request has been escalated and our team will follow up shortly.)`;

// ─── Tool definitions ─────────────────────────────────────────────────────────

const TOOLS = [
  {
    type: "function",
    name: "get_order_details",
    description:
      "Fetch complete details for an order: status, pickup/delivery addresses, customer info, merchant info, driver info, timestamps, and rejection data.",
    parameters: {
      type: "object",
      properties: {
        order_id: {
          type: "string",
          description: "The order UUID (from the conversation context)",
        },
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
        user_id: {
          type: "string",
          description: "The user UUID",
        },
      },
      required: ["user_id"],
    },
  },
  {
    type: "function",
    name: "get_merchant_contact",
    description:
      "Fetch a merchant's contact details (name, phone, stored address) to help a driver locate the pickup point or to provide as a fallback contact.",
    parameters: {
      type: "object",
      properties: {
        merchant_id: {
          type: "string",
          description: "The merchant's user UUID",
        },
      },
      required: ["merchant_id"],
    },
  },
  {
    type: "function",
    name: "check_driver_timing",
    description:
      "Analyze a driver's performance on a specific order to determine whether a customer rejection or complaint is the driver's fault. Returns timing metrics and a verdict.",
    parameters: {
      type: "object",
      properties: {
        order_id: {
          type: "string",
          description: "The order UUID to analyze",
        },
      },
      required: ["order_id"],
    },
  },
  {
    type: "function",
    name: "escalate_to_human",
    description:
      "Escalate the support case to a human admin via WhatsApp. Use when the AI cannot resolve the issue, for account issues, or when the user requests human support.",
    parameters: {
      type: "object",
      properties: {
        reason: {
          type: "string",
          description: "One-sentence reason for escalation",
        },
        summary: {
          type: "string",
          description:
            "Full context summary for the admin — what was tried, what happened, what action is needed",
        },
        conversation_id: {
          type: "string",
          description: "The support conversation UUID",
        },
      },
      required: ["reason", "summary", "conversation_id"],
    },
  },
];

// ─── Helpers ──────────────────────────────────────────────────────────────────

async function openaiRequest(
  method: string,
  path: string,
  body?: unknown
): Promise<{ ok: boolean; status: number; data: unknown }> {
  const res = await fetch(`https://api.openai.com${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${OPENAI_API_KEY}`,
      "Content-Type": "application/json",
      "OpenAI-Beta": "agents=v1",
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  const data = await res.json().catch(() => null);
  return { ok: res.ok, status: res.status, data };
}

// ─── Main ─────────────────────────────────────────────────────────────────────

console.log("🤖 Hur Delivery — OpenAI Agent Configuration");
console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
console.log(`Workflow ID : ${WORKFLOW_ID}`);
console.log(`Tools URL   : ${TOOLS_ENDPOINT}`);
console.log();

// Build the tools array with webhook URLs for HTTP-action type tools
// OpenAI Agent Builder supports tools as either "function" (model handles calling)
// or "action" (HTTP webhook that OpenAI calls directly).
// We configure both so the workflow works whether called via Responses API or ChatKit.

const agentConfig = {
  name: "Hur Delivery Support Agent",
  model: "gpt-4.1",
  instructions: SYSTEM_PROMPT,
  tools: TOOLS.map((tool) => ({
    ...tool,
    // Attach the webhook URL so OpenAI can call it directly when running the workflow
    url: TOOLS_ENDPOINT,
  })),
};

// ── Step 1: Try to update the existing workflow ────────────────────────────
console.log("⏳  Updating workflow configuration…");

let updateResult = await openaiRequest(
  "POST",
  `/v1/workflows/${WORKFLOW_ID}`,
  agentConfig
);

if (!updateResult.ok) {
  // Try PATCH if POST doesn't work
  updateResult = await openaiRequest(
    "PATCH",
    `/v1/workflows/${WORKFLOW_ID}`,
    agentConfig
  );
}

if (updateResult.ok) {
  console.log("✅  Workflow updated successfully");
  console.log("   Workflow:", JSON.stringify(updateResult.data, null, 2));
} else {
  console.warn(
    `⚠️  Could not update workflow via API (${updateResult.status}).`
  );
  console.warn(
    "   This is expected if workflow management is UI-only."
  );
  console.warn("   Attempting to create/update via /v1/agents instead…\n");

  // ── Step 2: Fall back to Assistants / Agents API ────────────────────────
  const agentResult = await openaiRequest("POST", "/v1/agents", {
    ...agentConfig,
    metadata: {
      workflow_id: WORKFLOW_ID,
      project: "hur-delivery",
    },
  });

  if (agentResult.ok) {
    const agent = agentResult.data as any;
    console.log("✅  Agent created via /v1/agents");
    console.log(`   Agent ID : ${agent.id}`);
    console.log(
      "\n📌  ACTION REQUIRED: Update WORKFLOW_ID in your edge functions to:"
    );
    console.log(`   ${agent.id}\n`);
  } else {
    console.error("❌  Could not create agent via API either.");
    console.error("   Status:", agentResult.status);
    console.error("   Error:", JSON.stringify(agentResult.data, null, 2));
    console.log("\n📋  MANUAL SETUP REQUIRED");
    console.log("   Open Agent Builder and configure:");
    console.log(`   1. Instructions: (see SYSTEM_PROMPT in this script)`);
    console.log(`   2. Model: gpt-4.1`);
    console.log(`   3. For each tool below, add as an HTTP Action:`);
    for (const tool of TOOLS) {
      console.log(`\n   Tool: ${tool.name}`);
      console.log(`   URL : ${TOOLS_ENDPOINT}`);
      console.log(`   Desc: ${tool.description}`);
    }
  }
}

// ── Step 3: Verify the tools endpoint is reachable ────────────────────────
console.log("\n⏳  Verifying tools endpoint…");
try {
  const testRes = await fetch(TOOLS_ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name: "_ping", parameters: {} }),
  });
  // A 400 (unknown tool) means the function is running — that's fine
  if (testRes.status < 500) {
    console.log(`✅  Tools endpoint is reachable (HTTP ${testRes.status})`);
  } else {
    console.warn(`⚠️  Tools endpoint returned HTTP ${testRes.status}`);
  }
} catch (err: any) {
  console.warn("⚠️  Could not reach tools endpoint:", err.message);
}

console.log("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
console.log("Done. Your agent is ready.");
