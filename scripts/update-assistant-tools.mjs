const KEY = process.env.OPENAI_API_KEY;
const ID = process.env.OPENAI_ASSISTANT_ID;

if (!KEY) {
  throw new Error("OPENAI_API_KEY is required");
}

if (!ID) {
  throw new Error("OPENAI_ASSISTANT_ID is required");
}

const tools = [
  {
    type: "function",
    function: {
      name: "get_user_orders",
      description:
        "Fetch active (or recent) orders for a user without needing an order ID. Use this first whenever the user mentions an order but does not provide an ID.",
      parameters: {
        type: "object",
        properties: {
          user_id: { type: "string", description: "The user UUID — use sender_id from context" },
          status: {
            type: "string",
            description: "Optional status filter: pending, assigned, accepted, picked_up, delivered, rejected, cancelled. Omit for active orders.",
          },
        },
        required: ["user_id"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_order_details",
      description: "Fetch complete details for a specific order by UUID.",
      parameters: {
        type: "object",
        properties: {
          order_id: { type: "string", description: "The order UUID" },
        },
        required: ["order_id"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_user_profile",
      description: "Fetch a user profile including name, phone, role, city, online status, and wallet balance.",
      parameters: {
        type: "object",
        properties: {
          user_id: { type: "string", description: "The user UUID" },
        },
        required: ["user_id"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_wallet_and_transactions",
      description: "Fetch a user's wallet balance and recent transactions. Works for drivers and merchants.",
      parameters: {
        type: "object",
        properties: {
          user_id: { type: "string", description: "The user UUID" },
          limit: { type: "number", description: "Number of recent transactions (default 20, max 50)" },
        },
        required: ["user_id"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_city_settings",
      description: "Fetch commission rates, rank system rules, and city-specific settings.",
      parameters: {
        type: "object",
        properties: {
          city: { type: "string", description: "City name (e.g. najaf, mosul). Omit for all cities." },
        },
        required: [],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_merchant_contact",
      description: "Fetch a merchant's contact details (name, phone, stored address).",
      parameters: {
        type: "object",
        properties: {
          merchant_id: { type: "string", description: "The merchant user UUID" },
        },
        required: ["merchant_id"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "check_driver_timing",
      description: "Analyze driver performance on an order to determine fault in a rejection. Returns timing metrics and a verdict.",
      parameters: {
        type: "object",
        properties: {
          order_id: { type: "string", description: "The order UUID to analyze" },
        },
        required: ["order_id"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "escalate_to_human",
      description: "Escalate the support case to a human admin via email when the AI cannot resolve the issue.",
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
  },
  {
    type: "function",
    function: {
      name: "advance_order_to_on_the_way",
      description:
        "Advance a driver's order status from picked_up to on_the_way. Will fail if customer_phone is missing — call update_customer_phone first in that case.",
      parameters: {
        type: "object",
        properties: {
          order_id: { type: "string", description: "The order UUID" },
          driver_id: { type: "string", description: "The driver's user UUID — use sender_id from context" },
        },
        required: ["order_id", "driver_id"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "update_customer_phone",
      description:
        "Update the customer phone number on an order. Use when the driver needs to advance a picked_up order but customer_phone is missing.",
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
  },
  {
    type: "function",
    function: {
      name: "cancel_order",
      description:
        "Cancel an order on behalf of the merchant. Only works pre-pickup and only for the order's merchant.",
      parameters: {
        type: "object",
        properties: {
          order_id: { type: "string", description: "The order UUID" },
          requester_id: { type: "string", description: "Use sender_id from context" },
          reason: { type: "string", description: "Why the merchant wants to cancel" },
        },
        required: ["order_id", "requester_id", "reason"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "update_delivery_address",
      description:
        "Update the delivery address on an active order. Only works for the order's merchant. Driver is auto-notified.",
      parameters: {
        type: "object",
        properties: {
          order_id: { type: "string", description: "The order UUID" },
          requester_id: { type: "string", description: "Use sender_id from context" },
          new_address: { type: "string", description: "Full new delivery address" },
        },
        required: ["order_id", "requester_id", "new_address"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_order_assignment_history",
      description:
        "Fetch which drivers were notified for an order and how each responded (accepted/rejected/timeout).",
      parameters: {
        type: "object",
        properties: {
          order_id: { type: "string", description: "The order UUID" },
        },
        required: ["order_id"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_recent_notifications",
      description:
        "Fetch a user's recent push notifications with a server-vs-device diagnosis. Use when the user complains they're not receiving notifications.",
      parameters: {
        type: "object",
        properties: {
          user_id: { type: "string", description: "Use sender_id from context" },
          limit: { type: "number", description: "Default 15, max 50" },
        },
        required: ["user_id"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_driver_online_hours",
      description:
        "Fetch a driver's monthly online hours and projected next-month rank. Use for rank progress questions.",
      parameters: {
        type: "object",
        properties: {
          driver_id: { type: "string", description: "Use sender_id from context" },
          month: { type: "string", description: "Optional YYYY-MM. Omit for current month." },
        },
        required: ["driver_id"],
      },
    },
  },
];

const res = await fetch(`https://api.openai.com/v1/assistants/${ID}`, {
  method: "POST",
  headers: {
    Authorization: `Bearer ${KEY}`,
    "Content-Type": "application/json",
    "OpenAI-Beta": "assistants=v2",
  },
  body: JSON.stringify({ tools }),
});

const data = await res.json();
if (data.id) {
  console.log("Assistant tools updated successfully. Tool count:", data.tools?.length);
} else {
  console.error("Failed:", JSON.stringify(data, null, 2));
}
