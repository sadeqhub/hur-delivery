// Supabase Edge Function: Voice Order Transcription & Extraction
// Handles audio transcription via OpenAI Whisper and order data extraction via GPT-4o

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey, x-client-info',
}

interface OrderItem {
  name: string
  quantity: number
  price?: number
  notes?: string
}

interface OrderDetails {
  customer_name?: string
  customer_phone?: string
  pickup_address?: string
  delivery_address?: string
  items: OrderItem[]
  notes?: string
  delivery_fee?: number
  payment_method?: string
  grand_total?: number
  confidence_score: number
  missing_fields: string[]
  transcription: string
}

// Comprehensive extraction prompt with Najaf neighborhoods
const EXTRACTION_PROMPT = `You are an expert order processing assistant for a delivery service in Najaf, Iraq. Your task is to extract and VALIDATE structured order information from Arabic or English voice transcriptions that may contain background noise or unclear speech.

**CRITICAL: Noise Correction & Validation**
The recording may be from a noisy environment. Use context and common patterns to correct obvious errors:
- If a phone number seems incomplete or has extra digits, try to identify the correct 11-digit number
- If neighborhood names are mispronounced, match them to the closest known neighborhood from the list below
- Apply acoustic and phonetic matching for Arabic speech recognition errors
- Cross-validate extracted data for consistency
- Use contextual clues to improve accuracy (e.g., common Iraqi names, address patterns)

**Context:**
- Location: ALL ADDRESSES ARE IN NAJAF, IRAQ (النجف) - Always assume Najaf city even if not explicitly mentioned
- Currency: Iraqi Dinar (IQD or د.ع)
- Phone numbers: MUST be exactly 11 digits starting with 07 (format: 07XXXXXXXXX)
- Valid currency denominations: 250, 500, 1000, 2000, 2500, 3000, 4000, 5000, 10000, 15000, 20000, 25000, 50000, 100000 IQD (multiples of 250, 500, or 1000 ONLY)

**Valid Neighborhoods in Najaf (match addresses to these):**
الفُرَات، الغدير، الكرامة، الصحة، الحنانة، الحسين، العلماء، الشعراء، الشرطة، الثورة، الغري، السلام الجديد، السلام، الجامعة، الوفاء، العروبة، الجمعية، الهندية، العسكري، الكرمة، النصر، الميلاد، الميلاد الجديد، الجديدات، السعد، المثنى، الرحمة، الأمير، القدس، المعلمين، القادسية، الزهراء، الأنصار، العدالة، الأطباء، محلة المشراق، محلة العمارة، محلة الحويش، محلة البراق، المشهد، الجودي، الطور، الربوة، بانقيا، وادي السلام، المشروع، الستين

**Phone Number Validation Rules:**
1. MUST be exactly 11 digits
2. MUST start with 07
3. Common prefixes: 0770, 0771, 0772, 0773, 0774, 0775, 0776, 0777, 0778, 0780, 0781, 0782, 0783, 0784, 0785, 0786, 0787, 0788, 0789, 0790, 0791
4. If transcription has 10 digits starting with 7, add leading 0
5. If transcription has 9 digits, add 07 prefix
6. If transcription has extra digits or spaces, extract the valid 11-digit sequence

**Customer Name Extraction Rules (CRITICAL):**
1. If NO NAME is mentioned or unclear, set customer_name to null (leave it BLANK)
2. Do NOT make up names or use placeholders like "عميل" or "Customer"
3. Only extract if clearly mentioned
4. Common Iraqi names: محمد، أحمد، علي، حسين، صادق، حسن، عباس، جاسم، كريم، رضا (male); فاطمة، زينب، مريم، نور، هدى (female)

**Address Extraction Rules:**
1. ALL addresses are in Najaf - ALWAYS add "النجف" to the address even if not mentioned
2. Match mentioned neighborhoods to the valid list above
3. If neighborhood is unclear, choose the closest phonetic match
4. Include street names, building numbers, landmarks if mentioned
5. If address is just a neighborhood name, format as "حي [الحي]، النجف"
6. If completely missing, set to null and add to missing_fields
7. NEVER extract addresses from other cities - all deliveries are in Najaf only

**Amount Extraction Rules (CRITICAL - Iraqi Currency Denominations):**
1. Extract the EXACT delivery fee mentioned - do NOT make assumptions or defaults
2. If delivery fee is NOT mentioned at all, set to null (NOT 2000, NOT any number)
3. ROUND all amounts to valid Iraqi currency denominations (250, 500, 1000, or their multiples)
4. Examples of rounding: 2300 → 2500, 4600 → 5000, 7800 → 8000, 12500 → 12500 (already valid)
5. Convert Arabic number words to digits: "خمسين ألف" → 50000, "ثلاثة آلاف" → 3000, "عشرة آلاف" → 10000
6. Valid denominations: 250, 500, 750, 1000, 1250, 1500, 2000, 2500, 3000, 4000, 5000, 10000, 15000, 20000, 25000, 50000, 100000
7. Listen for delivery fee keywords:
   - "رسوم التوصيل" / "رسوم توصيل" / "رسوم"
   - "أجرة التوصيل" / "أجرة" / "الأجرة"
   - "مبلغ التوصيل" / "مبلغ التوصيلة"
   - "توصيلة" / "التوصيلة"
   - "كلفة التوصيل" / "تكلفة التوصيل"
   - "سعر التوصيل"
7. Example: "مبلغ التوصيل خمسة آلاف" → delivery_fee: 5000 (EXACT, not 2000)
8. Example: "الأجرة عشرة آلاف" → delivery_fee: 10000 (EXACT, even if high)
9. Example: No mention of delivery → delivery_fee: null (NOT 2000)

**Notes Field Rules (CRITICAL - DO NOT PUT AI NOTES IN ORDER NOTES):**
1. The "notes" field is ONLY for customer/merchant notes about the order (special instructions, items, etc.)
2. NEVER put AI processing information in notes like "تم تصحيح الرقم" or "matched to neighborhood"
3. NEVER put confidence or correction information in notes
4. Only include notes if the customer/caller explicitly mentions special instructions
5. Examples of VALID notes: "طابق ثاني" "الباب الخلفي" "اتصل عند الوصول" "طلب عاجل"
6. Examples of INVALID notes: "تم تطبيق التصحيح" "confidence 0.8" "corrected phone number"

**Error Correction Examples:**
- "صفر سبعة ثمانية واحد أربعة واحد صفر أربعة صفر تسعة سبعة" → "07814104097" (11 digits)
- "حي الجامعه" or "حي الجامعة" → "حي الجامعة، النجف" (match to valid neighborhood + add Najaf)
- "الجامعة" → "حي الجامعة، النجف" (add حي prefix and النجف)
- "خمسين ألف" or "50 ألف" → 50000 (convert Arabic numbers)
- "ثلاثة آلاف وخمسمائة" → 3500 (convert and combine)
- "عشرين ألف" → 20000
- "مائة ألف" → 100000
- 4700 IQD mentioned → 5000 (round to valid denomination)
- Misspelled neighborhood → closest match from the valid list
- No customer name mentioned → customer_name: null (DON'T use "عميل" or make up a name)

**CRITICAL RULES:**
1. NEVER assume or default delivery_fee - extract ONLY if explicitly mentioned
2. ROUND all amounts to valid Iraqi currency denominations (250, 500, 1000, or multiples)
3. If delivery fee is NOT mentioned, return null (not 2000, not any default)
4. If customer name is NOT mentioned, return null (leave BLANK)
5. ALWAYS add "النجف" to delivery addresses
6. NEVER put AI processing notes in the "notes" field - only customer instructions belong there

**Neighborhood Detection (CRITICAL):**
1. When extracting delivery_address, also detect which neighborhood it matches
2. Match the address to the exact neighborhood name from the valid list above
3. Return the neighborhood name (without "حي" prefix if present, just the name) in a separate "neighborhood" field
4. Examples:
   - "حي الجامعة" → neighborhood: "حي الجامعة"
   - "الجامعة" → neighborhood: "حي الجامعة" (add حي prefix)
   - "حي الأمير" → neighborhood: "حي الامير"
   - "الأمير" → neighborhood: "حي الامير" (add حي prefix)
5. If no neighborhood can be matched, set neighborhood to null

**Expected JSON Structure:**
{
  "customer_name": "string or null (NULL if not mentioned - do NOT make up names)",
  "customer_phone": "string (exactly 11 digits: 07XXXXXXXXX) or null",
  "pickup_address": "string or null",
  "delivery_address": "string with النجف (e.g. 'حي الجامعة، النجف') or null",
  "neighborhood": "string or null (exact neighborhood name from valid list, e.g. 'حي الجامعة')",
  "items": [],
  "notes": "string or null (ONLY customer instructions - NO AI processing notes)",
  "delivery_fee": number or null (rounded to valid denomination, ONLY if mentioned),
  "payment_method": "string or null",
  "grand_total": number or null (rounded to valid denomination, ONLY if mentioned)",
  "confidence_score": number (0.0-1.0),
  "missing_fields": ["array of missing critical fields"]
}

Example 1 (Clear recording with all details):
Input: "اسم الزبون أحمد حسن، رقمه 07701234567، عنوان التوصيل حي الجامعة، المبلغ الكلي 25000 دينار، رسوم التوصيل 3000"

Output:
{
  "customer_name": "أحمد حسن",
  "customer_phone": "07701234567",
  "pickup_address": null,
  "delivery_address": "حي الجامعة، النجف",
  "neighborhood": "حي الجامعة",
  "items": [],
  "notes": null,
  "delivery_fee": 3000,
  "payment_method": null,
  "grand_total": 25000,
  "confidence_score": 0.95,
  "missing_fields": ["pickup_address", "items"]
}

Example 2 (No customer name - leave blank):
Input: "رقم الزبون 07814104097، عنوان الزبون حي الجامعة، مبلغ التوصيل خمسة آلاف، المبلغ الكلي عشرة آلاف"

Output:
{
  "customer_name": null,
  "customer_phone": "07814104097",
  "pickup_address": null,
  "delivery_address": "حي الجامعة، النجف",
  "neighborhood": "حي الجامعة",
  "items": [],
  "notes": null,
  "delivery_fee": 5000,
  "payment_method": null,
  "grand_total": 10000,
  "confidence_score": 0.90,
  "missing_fields": ["customer_name", "pickup_address", "items"]
}

Example 3 (No delivery fee, amount needs rounding):
Input: "اسم الزبون علي، رقمه 07701234567، التوصيل إلى الأمير، المبلغ 32700، اتصل عند الوصول"

Output:
{
  "customer_name": "علي",
  "customer_phone": "07701234567",
  "pickup_address": null,
  "delivery_address": "حي الأمير، النجف",
  "neighborhood": "حي الامير",
  "items": [],
  "notes": "اتصل عند الوصول",
  "delivery_fee": null,
  "payment_method": null,
  "grand_total": 33000,
  "confidence_score": 0.85,
  "missing_fields": ["pickup_address", "items", "delivery_fee"]
}

Now, extract the order information from the following transcription:

{transcription}

Respond ONLY with valid JSON, no additional text.`

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    console.log('📝 Received voice transcription request')
    console.log(`Method: ${req.method}, Content-Type: ${req.headers.get('content-type')}`)

    // Verify OpenAI API key
    if (!OPENAI_API_KEY) {
      console.error('❌ OPENAI_API_KEY not configured')
      return new Response(
        JSON.stringify({ error: 'OpenAI API key not configured' }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    // Parse multipart form data
    const formData = await req.formData()
    console.log('📋 Form data keys:', Array.from(formData.keys()))
    
    const audioFile = formData.get('audio') as File
    
    if (!audioFile) {
      console.error('❌ No audio file in request')
      console.log('Available form keys:', Array.from(formData.keys()))
      
      // Log all form entries for debugging
      for (const [key, value] of formData.entries()) {
        console.log(`Form entry - Key: ${key}, Value type: ${typeof value}, Value: ${value instanceof File ? 'File' : value}`)
      }
      
      return new Response(
        JSON.stringify({ 
          error: 'No audio file provided. Expected field: audio',
          available_keys: Array.from(formData.keys())
        }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    console.log(`📁 Audio file: ${audioFile.name}, type: ${audioFile.type}, size: ${audioFile.size} bytes`)
    
    // Get audio file content as array buffer
    const audioArrayBuffer = await audioFile.arrayBuffer()
    console.log(`📦 Audio buffer size: ${audioArrayBuffer.byteLength} bytes`)

    // Step 1: Transcribe audio with Whisper
    console.log('🎤 Sending to Whisper API...')
    
    // Create new FormData for OpenAI Whisper API
    const whisperFormData = new FormData()
    const audioBlob = new Blob([audioArrayBuffer], { type: audioFile.type || 'audio/mpeg' })
    whisperFormData.append('file', audioBlob, audioFile.name || 'audio.mp4')
    whisperFormData.append('model', 'whisper-1')
    whisperFormData.append('language', 'ar')
    whisperFormData.append('response_format', 'text')

    const whisperResponse = await fetch('https://api.openai.com/v1/audio/transcriptions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
      },
      body: whisperFormData,
    })

    if (!whisperResponse.ok) {
      const error = await whisperResponse.text()
      console.error(`❌ Whisper API error: ${error}`)
      return new Response(
        JSON.stringify({ error: `Transcription failed: ${whisperResponse.status}` }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    const transcription = await whisperResponse.text()
    console.log(`✅ Transcription: ${transcription.substring(0, 100)}...`)

    // Step 2: Extract order information with GPT-4o
    console.log('🤖 Calling GPT-4o for extraction...')

    const extractionPrompt = EXTRACTION_PROMPT.replace('{transcription}', transcription)

    const gptResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o',
        messages: [
          {
            role: 'system',
            content: 'أنت مساعد متخصص في تحليل التسجيلات الصوتية العراقية للنجف. قواعد صارمة: 1) استخرج فقط المعلومات المذكورة صراحة 2) لا تفترض أو تضع قيم افتراضية 3) إذا لم يذكر رسوم التوصيل، اجعله null 4) إذا لم يذكر المبلغ، اجعله null 5) دور جميع المبالغ لفئات العملة العراقية (250، 500، 1000 ومضاعفاتها) 6) إذا لم يذكر اسم الزبون، اجعله null - لا تفترض أسماء 7) أضف "النجف" لجميع العناوين 8) لا تضع ملاحظات الذكاء الاصطناعي في حقل notes - فقط تعليمات العميل',
          },
          {
            role: 'user',
            content: extractionPrompt,
          },
        ],
        max_tokens: 1500,
        response_format: { type: 'json_object' },
        temperature: 0.03,
      }),
    })

    if (!gptResponse.ok) {
      const error = await gptResponse.text()
      console.error(`❌ GPT-4o API error: ${error}`)
      return new Response(
        JSON.stringify({ error: `Extraction failed: ${gptResponse.status}` }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    const gptData = await gptResponse.json()
    const content = gptData.choices[0].message.content
    console.log(`📄 GPT response: ${content.substring(0, 200)}...`)

    // Parse and validate the extracted data
    let extractedData = JSON.parse(content)
    console.log(`✅ JSON parsed successfully`)

    // Round to valid Iraqi currency denominations (250, 500, 1000 and multiples)
    const roundToValidDenomination = (value: number): number => {
      // Valid base denominations: 250, 500, 1000
      // Round to nearest 250
      if (value <= 1000) {
        return Math.round(value / 250) * 250
      }
      // For values > 1000, round to nearest 500
      if (value <= 10000) {
        return Math.round(value / 500) * 500
      }
      // For larger values, round to nearest 1000
      return Math.round(value / 1000) * 1000
    }

    // Normalize numeric fields
    const ensureNumeric = (value: any, defaultValue: number | null = null): number | null => {
      if (value === null || value === undefined || value === '') return defaultValue
      if (typeof value === 'number') return roundToValidDenomination(value)
      if (typeof value === 'string') {
        const cleaned = value.replace(/[^\d.]/g, '')
        if (cleaned) {
          const num = parseFloat(cleaned)
          return isNaN(num) ? defaultValue : roundToValidDenomination(num)
        }
      }
      return defaultValue
    }

    // Normalize data - NO DEFAULTS for delivery_fee or grand_total
    extractedData.delivery_fee = ensureNumeric(extractedData.delivery_fee, null) // null if not mentioned
    extractedData.grand_total = ensureNumeric(extractedData.grand_total, null)  // null if not mentioned
    extractedData.transcription = transcription
    extractedData.confidence_score = extractedData.confidence_score || 0.8
    extractedData.missing_fields = extractedData.missing_fields || []

    // Normalize items
    if (Array.isArray(extractedData.items)) {
      extractedData.items = extractedData.items.map((item: any) => ({
        name: item.name,
        quantity: ensureNumeric(item.quantity, 1), // Default quantity to 1 if not specified
        price: ensureNumeric(item.price, null),    // null if price not mentioned
        notes: item.notes || null,
      }))
    } else {
      extractedData.items = []
    }

    // Check for missing critical fields
    const criticalFields = ['customer_name', 'customer_phone', 'delivery_address']
    for (const field of criticalFields) {
      if (!extractedData[field]) {
        if (!extractedData.missing_fields.includes(field)) {
          extractedData.missing_fields.push(field)
        }
      }
    }
    
    // Add delivery_fee to missing if not provided
    if (!extractedData.delivery_fee) {
      if (!extractedData.missing_fields.includes('delivery_fee')) {
        extractedData.missing_fields.push('delivery_fee')
      }
    }
    
    console.log(`📊 Final data - delivery_fee: ${extractedData.delivery_fee}, grand_total: ${extractedData.grand_total}`)

    console.log(`✅ Extraction complete. Confidence: ${extractedData.confidence_score}`)
    console.log(`✅ Missing fields: ${extractedData.missing_fields}`)

    return new Response(JSON.stringify(extractedData), {
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders,
      },
    })
  } catch (error) {
    console.error('❌ Error:', error)
    console.error('❌ Error stack:', error.stack)
    return new Response(
      JSON.stringify({
        error: error.message || 'Processing failed',
        details: error.toString(),
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders,
        },
      }
    )
  }
})

