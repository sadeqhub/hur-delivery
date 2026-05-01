# AI Chatbot Use Cases for Drivers

This document identifies common questions and issues drivers face, and specifies how the AI chatbot should respond to resolve them or answer their questions.

---

## 🚗 DRIVER QUESTIONS & ISSUES

The chatbot should handle natural language questions from drivers and either:
1. **Answer the question** with helpful information
2. **Resolve the issue** by taking appropriate actions
3. **Guide the driver** to resolve the issue themselves

---

## 📋 DRIVER USE CASES

### 1. **Driver Online Status Questions**
**Use Case Name:** `DRIVER_CHECK_ONLINE_STATUS`

**Common Questions:**
- "هل أنا متصل؟" / "Am I online?"
- "لماذا لا أستقبل طلبات؟" / "Why am I not receiving orders?"
- "كيف أتصل؟" / "How do I go online?"
- "أنا غير متصل" / "I'm offline"

**Chatbot Response Logic:**
- **IF** driver is online (`_isOnline = true`)
  - **THEN** respond: `"نعم، أنت متصل الآن وجاهز لاستقبال الطلبات. ✅"`
  - **Action:** None needed
- **ELSE IF** driver is offline (`_isOnline = false`)
  - **THEN** respond: `"أنت غير متصل حالياً. لاستقبال الطلبات، يرجى تفعيل وضع الاتصال من الشاشة الرئيسية. 🔴"`
  - **Action:** Offer to toggle online status: `"هل تريد أن أفعّل وضع الاتصال لك الآن؟"`
  - **If driver confirms:** Execute `toggleOnline()` action

---

### 2. **Available Orders Questions**
**Use Case Name:** `DRIVER_CHECK_AVAILABLE_ORDERS`

**Common Questions:**
- "هل يوجد طلبات متاحة؟" / "Are there any orders available?"
- "كم طلب لدي؟" / "How many orders do I have?"
- "لماذا لا أرى طلبات؟" / "Why don't I see any orders?"
- "ما هي الطلبات المتاحة؟" / "What orders are available?"

**Chatbot Response Logic:**
- **IF** driver has active orders assigned (`status = 'assigned'` or `status = 'accepted'`)
  - **THEN** respond: `"لديك {count} طلب نشط حالياً:\n{list_orders_with_details}"`
  - **Action:** Show order cards with details
- **ELSE IF** driver has no active orders BUT orders are available in system
  - **THEN** respond: `"لا توجد طلبات نشطة حالياً، لكن هناك {count} طلب متاح في النظام. تأكد من أنك متصل لاستقبال الطلبات. 📦"`
  - **Action:** Check if driver is online, suggest going online if offline
- **ELSE IF** driver is offline
  - **THEN** respond: `"لا توجد طلبات متاحة حالياً. تأكد من أنك متصل (وضع الاتصال مفعّل) لاستقبال الطلبات الجديدة. 🔴"`
  - **Action:** Suggest toggling online status
- **ELSE** (no orders in system)
  - **THEN** respond: `"لا توجد طلبات متاحة حالياً. سيتم إشعارك فور توفر طلب جديد. ⏳"`

---

### 3. **Accept Order Issues**
**Use Case Name:** `DRIVER_ACCEPT_ORDER`

**Common Questions/Issues:**
- "لماذا لا أستطيع قبول هذا الطلب؟" / "Why can't I accept this order?"
- "قبول الطلب" / "Accept order"
- "الطلب اختفى" / "The order disappeared"
- "خطأ عند قبول الطلب" / "Error accepting order"

**Chatbot Response Logic:**
- **IF** driver tries to accept order AND order exists AND order status is 'assigned' AND driver is online AND order not expired
  - **THEN** respond: `"تم قبول الطلب بنجاح! ✅\n\nتفاصيل الطلب:\n- العميل: {customerName}\n- رسوم التوصيل: {deliveryFee} IQD\n- عنوان الاستلام: {pickupAddress}\n\nالآن يمكنك التنقل إلى موقع الاستلام. 🗺️"`
  - **Action:** Execute `acceptOrder(orderId)` and show navigation options
- **ELSE IF** driver is offline
  - **THEN** respond: `"يجب أن تكون متصلاً لقبول الطلبات. 🔴\n\nهل تريد تفعيل وضع الاتصال الآن؟"`
  - **Action:** Offer to toggle online, then retry accept
- **ELSE IF** order status is not 'assigned' (already accepted/cancelled)
  - **THEN** respond: `"عذراً، هذا الطلب غير متاح للقبول. الحالة الحالية: {statusDisplay}.\n\n{If accepted: 'تم قبول هذا الطلب من قبل سائق آخر.'}\n{If cancelled: 'تم إلغاء هذا الطلب.'}"`
  - **Action:** Show available orders instead
- **ELSE IF** order expired (timeout remaining <= 0)
  - **THEN** respond: `"انتهت مدة الطلب ولم يعد متاحاً. ⏰\n\nيمكنك البحث عن طلبات أخرى متاحة. 🔍"`
  - **Action:** Refresh available orders list
- **ELSE IF** order already accepted by another driver
  - **THEN** respond: `"تم قبول هذا الطلب من قبل سائق آخر. ✅\n\nجاري البحث عن طلبات أخرى متاحة لك... 🔍"`
  - **Action:** Refresh available orders list

---

### 4. **Reject Order Questions**
**Use Case Name:** `DRIVER_REJECT_ORDER`

**Common Questions/Issues:**
- "كيف أرفض طلب؟" / "How do I reject an order?"
- "رفض الطلب" / "Reject order"
- "لا أريد هذا الطلب" / "I don't want this order"

**Chatbot Response Logic:**
- **IF** driver wants to reject order AND order exists AND order is assigned to this driver AND order status is 'assigned'
  - **THEN** respond: `"هل أنت متأكد من رفض هذا الطلب؟\n\nبعد الرفض، سيتم تخصيصه لسائق آخر. ❌"`
  - **Action:** If confirmed, execute `rejectOrder(orderId)` and respond: `"تم رفض الطلب. سيتم إشعارك بطلبات جديدة. 📦"`
- **ELSE IF** order not assigned to this driver
  - **THEN** respond: `"هذا الطلب غير مخصص لك، لذا لا يمكنك رفضه. ℹ️"`
- **ELSE IF** order already accepted
  - **THEN** respond: `"لا يمكن رفض طلب تم قبوله بالفعل. إذا كنت تواجه مشكلة، يرجى التواصل مع الدعم. 📞"`
  - **Action:** Offer to contact support

---

### 5. **Order Status Update Issues (Pickup)**
**Use Case Name:** `DRIVER_UPDATE_STATUS_PICKUP`

**Common Questions/Issues:**
- "الطلب غير جاهز" / "Order is not ready"
- "كيف أحدث حالة الطلب؟" / "How do I update order status?"
- "وصلت للموقع لكن الطلب غير جاهز" / "I arrived but order is not ready"
- "تم الاستلام" / "Picked up"

**Chatbot Response Logic:**
- **IF** driver wants to mark as picked up AND order exists AND order status is 'accepted' AND driver is assigned AND order is ready (`isReady = true`)
  - **THEN** respond: `"تم تحديث حالة الطلب إلى 'في الطريق'. ✅\n\nالآن يمكنك التنقل إلى عنوان التوصيل. 🗺️"`
  - **Action:** Execute `updateOrderStatus(orderId, 'on_the_way')` and show delivery navigation
- **ELSE IF** order not ready (`isReady = false`)
  - **THEN** respond: `"الطلب غير جاهز بعد. ⏳\n\nالوقت المتبقي: {readyCountdown} دقيقة\n\nسيتم إشعارك عندما يصبح الطلب جاهزاً. 🔔"`
  - **Action:** Show countdown timer, offer to wait or contact merchant
- **ELSE IF** order status is not 'accepted'
  - **THEN** respond: `"يجب قبول الطلب أولاً قبل تحديث حالته. ℹ️\n\nالحالة الحالية: {statusDisplay}"`
- **ELSE IF** driver not assigned to order
  - **THEN** respond: `"هذا الطلب غير مخصص لك. ℹ️"`

---

### 6. **Order Delivery Issues**
**Use Case Name:** `DRIVER_UPDATE_STATUS_DELIVERED`

**Common Questions/Issues:**
- "كيف أسلم الطلب؟" / "How do I deliver the order?"
- "تم التسليم" / "Order delivered"
- "لماذا لا أستطيع تأكيد التسليم؟" / "Why can't I confirm delivery?"
- "نسيت أخذ صورة" / "I forgot to take a photo"

**Chatbot Response Logic:**
- **IF** driver wants to mark as delivered AND order exists AND order status is 'on_the_way' AND driver is assigned AND proof of delivery provided
  - **THEN** respond: `"تم تسليم الطلب بنجاح! 🎉\n\nالأرباح: {earnings} IQD\nرصيدك الحالي: {walletBalance} IQD\n\nشكراً لك! يمكنك الآن استقبال طلبات جديدة. 📦"`
  - **Action:** Execute `updateOrderStatus(orderId, 'delivered')` and show earnings summary
- **ELSE IF** order status is not 'on_the_way'
  - **THEN** respond: `"يجب تحديث حالة الطلب إلى 'في الطريق' أولاً قبل تأكيد التسليم. ℹ️\n\nالحالة الحالية: {statusDisplay}"`
  - **Action:** Guide driver to update status to 'on_the_way' first
- **ELSE IF** proof of delivery missing
  - **THEN** respond: `"يجب إضافة إثبات التسليم (صورة أو توقيع العميل) قبل تأكيد التسليم. 📸\n\nيرجى التقاط صورة أو الحصول على توقيع العميل."`
  - **Action:** Show option to add proof of delivery

---

### 7. **Wallet Balance Questions**
**Use Case Name:** `DRIVER_CHECK_WALLET`

**Common Questions:**
- "كم رصيدي؟" / "What's my balance?"
- "متى سأستلم أموالي؟" / "When will I receive my money?"
- "لماذا رصيدي صفر؟" / "Why is my balance zero?"
- "أين أرباحي؟" / "Where are my earnings?"

**Chatbot Response Logic:**
- **IF** driver asks about balance AND driver wallet is enabled AND wallet exists
  - **THEN** respond: `"رصيدك الحالي: {balance} IQD 💰\n\n{If balance > 0: 'يمكنك سحب الأموال من المحفظة.'}\n{If balance = 0: 'سيتم إضافة الأرباح تلقائياً عند إتمام الطلبات.'}"`
  - **Action:** Show wallet details and transaction history
- **ELSE IF** driver wallet is disabled
  - **THEN** respond: `"نظام المحفظة غير مفعّل حالياً. ℹ️\n\nيرجى التواصل مع الدعم لمزيد من المعلومات. 📞"`
  - **Action:** Offer to contact support
- **ELSE IF** wallet not initialized
  - **THEN** respond: `"المحفظة غير مهيأة بعد. ⏳\n\nسيتم إنشاؤها تلقائياً عند إتمام أول طلب وتحصل على أرباحك مباشرة. 💰"`

---

### 8. **Earnings Questions**
**Use Case Name:** `DRIVER_VIEW_EARNINGS`

**Common Questions:**
- "كم أرباحي اليوم؟" / "How much did I earn today?"
- "ما إجمالي أرباحي؟" / "What's my total earnings?"
- "أين يمكنني رؤية أرباحي؟" / "Where can I see my earnings?"
- "لماذا لم أستلم أموالي؟" / "Why didn't I receive my money?"

**Chatbot Response Logic:**
- **IF** driver asks about earnings AND driver has earnings (transactions exist)
  - **THEN** respond: `"إحصائيات الأرباح: 📊\n\n• إجمالي الأرباح: {totalEarnings} IQD\n• أرباح اليوم: {todayEarnings} IQD\n• أرباح هذا الشهر: {thisMonthEarnings} IQD\n\n{Show recent transactions if requested}"`
  - **Action:** Show earnings breakdown and transaction history
- **ELSE**
  - **THEN** respond: `"لا توجد أرباح حتى الآن. 💰\n\nستحصل على أرباحك تلقائياً عند إتمام الطلبات وتسليمها بنجاح. 📦"`

---

### 9. **Order Ready Status Questions**
**Use Case Name:** `DRIVER_CHECK_ORDER_READY`

**Common Questions:**
- "هل الطلب جاهز؟" / "Is the order ready?"
- "متى سيكون الطلب جاهزاً؟" / "When will the order be ready?"
- "وصلت لكن الطلب غير جاهز" / "I arrived but order is not ready"

**Chatbot Response Logic:**
- **IF** driver asks if order is ready AND order has `readyAt` AND current time < `readyAt`
  - **THEN** respond: `"الطلب غير جاهز بعد. ⏳\n\nالوقت المتبقي: {readyCountdown} دقيقة\nالوقت المتوقع: {readyAt_formatted}\n\nيمكنك الانتظار أو التواصل مع التاجر. 📞"`
  - **Action:** Show countdown, offer to contact merchant
- **ELSE IF** order has `readyAt` AND current time >= `readyAt`
  - **THEN** respond: `"الطلب جاهز الآن للاستلام! ✅\n\nيمكنك الآن تحديث حالة الطلب إلى 'في الطريق'. 🚗"`
  - **Action:** Enable pickup status update button
- **ELSE** (no `readyAt` specified)
  - **THEN** respond: `"الطلب جاهز للاستلام. ✅\n\nيمكنك الذهاب لموقع الاستلام وتحديث حالة الطلب. 📍"`

---

### 10. **Navigation Questions**
**Use Case Name:** `DRIVER_NAVIGATE_TO_LOCATION`

**Common Questions:**
- "كيف أصل للعنوان؟" / "How do I get to the address?"
- "افتح الخريطة" / "Open map"
- "أين موقع الاستلام؟" / "Where is the pickup location?"
- "أين موقع التوصيل؟" / "Where is the delivery location?"

**Chatbot Response Logic:**
- **IF** driver asks for navigation AND order exists AND location coordinates valid
  - **THEN** respond: `"عنوان {locationType}:\n{address}\n\nيمكنك فتح الخريطة عبر:\n• خرائط جوجل 🗺️\n• ويز 🧭"`
  - **Action:** Show navigation buttons (Google Maps, Waze) with coordinates
- **ELSE IF** coordinates invalid
  - **THEN** respond: `"عذراً، إحداثيات الموقع غير صحيحة. 📍\n\nيرجى التواصل مع {merchant/customer} للحصول على العنوان الصحيح. 📞"`
  - **Action:** Offer to contact merchant/customer
- **ELSE IF** navigation app not available
  - **THEN** respond: `"تطبيق الملاحة غير متاح على جهازك. 📱\n\nالعنوان: {address}\n\nيمكنك نسخ العنوان واستخدامه في تطبيق الملاحة المفضل لديك. 📋"`

---

### 11. **Contact Questions**
**Use Case Name:** `DRIVER_CONTACT_PARTY`

**Common Questions:**
- "كيف أتواصل مع التاجر؟" / "How do I contact the merchant?"
- "أريد الاتصال بالعميل" / "I want to call the customer"
- "رقم هاتف التاجر" / "Merchant phone number"
- "لا أستطيع الوصول للعنوان" / "I can't reach the address"

**Chatbot Response Logic:**
- **IF** driver wants to contact merchant/customer AND order exists AND phone number exists
  - **THEN** respond: `"معلومات الاتصال:\n\n{contactType}: {name}\nالهاتف: {phone}\n\nيمكنك:\n• الاتصال مباشرة 📞\n• إرسال رسالة واتساب 💬"`
  - **Action:** Show call and WhatsApp buttons
- **ELSE IF** phone number missing
  - **THEN** respond: `"عذراً، رقم الهاتف غير متوفر. 📞\n\nيرجى التواصل مع الدعم للمساعدة. 🆘"`
  - **Action:** Offer to contact support

---

### 12. **Order Details Questions**
**Use Case Name:** `DRIVER_VIEW_ORDER_DETAILS`

**Common Questions:**
- "ما تفاصيل الطلب؟" / "What are the order details?"
- "أين عنوان التوصيل؟" / "Where is the delivery address?"
- "كم رسوم التوصيل؟" / "What's the delivery fee?"
- "ما ملاحظات الطلب؟" / "What are the order notes?"

**Chatbot Response Logic:**
- **IF** driver asks about order details AND order exists AND driver has access
  - **THEN** respond: `"تفاصيل الطلب #{orderId}:\n\n👤 العميل: {customerName}\n📞 الهاتف: {customerPhone}\n📍 عنوان الاستلام: {pickupAddress}\n📍 عنوان التوصيل: {deliveryAddress}\n💰 رسوم التوصيل: {deliveryFee} IQD\n🚗 نوع المركبة: {vehicleType}\n📝 الحالة: {statusDisplay}\n{If notes: 'ملاحظات: {notes}'}"`
  - **Action:** Show full order details card
- **ELSE IF** order not found
  - **THEN** respond: `"الطلب غير موجود. ❌\n\nيرجى التحقق من رقم الطلب أو تحديث قائمة الطلبات. 🔄"`
- **ELSE IF** driver doesn't have access
  - **THEN** respond: `"ليس لديك صلاحية لعرض هذا الطلب. 🔒\n\nهذا الطلب غير مخصص لك. ℹ️"`

### 13. **General Support Questions**
**Use Case Name:** `DRIVER_GENERAL_SUPPORT`

**Common Questions:**
- "كيف أستخدم التطبيق؟" / "How do I use the app?"
- "لدي مشكلة" / "I have a problem"
- "مساعدة" / "Help"
- "كيف أكسب أكثر؟" / "How do I earn more?"

**Chatbot Response Logic:**
- **IF** driver asks general questions
  - **THEN** respond with helpful information or guide to relevant section
  - **Action:** Provide contextual help based on question topic
- **IF** driver reports an issue
  - **THEN** respond: `"أنا هنا لمساعدتك! 🆘\n\nما هي المشكلة التي تواجهها؟ يمكنك وصفها وسأحاول حلها. 💬"`
  - **Action:** Listen to issue description and route to appropriate use case

### 14. **Technical Issues**
**Use Case Name:** `DRIVER_TECHNICAL_ISSUES`

**Common Issues:**
- "التطبيق لا يعمل" / "App is not working"
- "لا أستقبل إشعارات" / "I'm not receiving notifications"
- "الخريطة لا تفتح" / "Map won't open"
- "خطأ في التطبيق" / "App error"

**Chatbot Response Logic:**
- **IF** driver reports technical issue
  - **THEN** respond: `"دعني أساعدك في حل هذه المشكلة. 🔧\n\n{Provide troubleshooting steps based on issue}\n\nإذا استمرت المشكلة، يرجى التواصل مع الدعم الفني. 📞"`
  - **Action:** Provide troubleshooting steps, offer to contact support if needed

---

## 🏪 MERCHANT USE CASES (Optional - for future expansion)

### 1. **Check Wallet Balance Before Order Creation**
**Use Case Name:** `MERCHANT_CHECK_WALLET_BEFORE_ORDER`

**Conditions:**
- **IF** wallet balance > credit limit
  - **THEN** return: `{ "canCreateOrder": true, "balance": <amount>, "creditLimit": <limit>, "availableBalance": <available>, "message": "رصيدك كافٍ لإنشاء الطلب. الرصيد المتاح: {available} IQD" }`
- **ELSE IF** wallet balance <= credit limit
  - **THEN** return: `{ "canCreateOrder": false, "balance": <amount>, "creditLimit": <limit>, "requiredTopUp": <required>, "message": "رصيدك غير كافٍ. يرجى شحن المحفظة بمبلغ {required} IQD على الأقل", "action": "topUpWallet" }`
- **ELSE IF** wallet not initialized
  - **THEN** return: `{ "canCreateOrder": true, "balance": 10000, "message": "سيتم إنشاء محفظة جديدة برصيد ابتدائي 10,000 IQD" }`

---

### 2. **Create Order**
**Use Case Name:** `MERCHANT_CREATE_ORDER`

**Conditions:**
- **IF** wallet balance > credit limit AND all required fields filled (customer name, phone, addresses, coordinates) AND online drivers available
  - **THEN** return: `{ "success": true, "orderId": <id>, "message": "تم إنشاء الطلب بنجاح. سيتم تخصيص سائق قريباً", "estimatedDriverAssignment": "few_minutes" }`
- **ELSE IF** wallet balance <= credit limit
  - **THEN** return: `{ "success": false, "error": "INSUFFICIENT_BALANCE", "message": "رصيدك غير كافٍ. يرجى شحن المحفظة", "action": "topUpWallet", "requiredAmount": <amount> }`
- **ELSE IF** required fields missing
  - **THEN** return: `{ "success": false, "error": "MISSING_FIELDS", "message": "يرجى ملء جميع الحقول المطلوبة", "missingFields": [<field_list>] }`
- **ELSE IF** no online drivers available
  - **THEN** return: `{ "success": false, "error": "NO_DRIVERS_AVAILABLE", "message": "لا يوجد سائقون متاحون حالياً. سيتم تخصيص سائق عند توفر واحد", "orderCreated": true, "orderId": <id> }`

---

### 3. **Cancel Order**
**Use Case Name:** `MERCHANT_CANCEL_ORDER`

**Conditions:**
- **IF** order exists AND order belongs to merchant AND order status is NOT 'delivered' AND order status is NOT 'cancelled'
  - **THEN** return: `{ "success": true, "message": "تم إلغاء الطلب بنجاح", "orderId": <id>, "refundStatus": "pending|processed" }`
- **ELSE IF** order already delivered
  - **THEN** return: `{ "success": false, "error": "ORDER_ALREADY_DELIVERED", "message": "لا يمكن إلغاء طلب تم تسليمه بالفعل" }`
- **ELSE IF** order already cancelled
  - **THEN** return: `{ "success": false, "error": "ORDER_ALREADY_CANCELLED", "message": "هذا الطلب ملغي بالفعل" }`
- **ELSE IF** order doesn't belong to merchant
  - **THEN** return: `{ "success": false, "error": "UNAUTHORIZED", "message": "هذا الطلب لا ينتمي لك" }`

---

### 4. **Track Order Status**
**Use Case Name:** `MERCHANT_TRACK_ORDER`

**Conditions:**
- **IF** order exists AND order belongs to merchant
  - **THEN** return: `{ "success": true, "order": { "id": <id>, "status": <status>, "statusDisplay": <arabic_status>, "driverName": <name> | null, "driverPhone": <phone> | null, "estimatedDelivery": <time> | null, "currentLocation": { "lat": <lat>, "lng": <lng> } | null }, "message": "حالة الطلب: {statusDisplay}" }`
- **ELSE IF** order not found
  - **THEN** return: `{ "success": false, "error": "ORDER_NOT_FOUND", "message": "الطلب غير موجود" }`
- **ELSE IF** order doesn't belong to merchant
  - **THEN** return: `{ "success": false, "error": "UNAUTHORIZED", "message": "ليس لديك صلاحية لعرض هذا الطلب" }`

---

### 5. **View Order History**
**Use Case Name:** `MERCHANT_VIEW_ORDER_HISTORY`

**Conditions:**
- **IF** merchant has orders
  - **THEN** return: `{ "hasOrders": true, "totalOrders": <count>, "orders": [<order_list>], "filters": { "status": <status>, "dateRange": <range> }, "message": "لديك {count} طلب في السجل" }`
- **ELSE**
  - **THEN** return: `{ "hasOrders": false, "totalOrders": 0, "message": "لا توجد طلبات في السجل" }`

---

### 6. **Top Up Wallet**
**Use Case Name:** `MERCHANT_TOP_UP_WALLET`

**Conditions:**
- **IF** payment method available (Wayl, Zain Cash, etc.) AND amount >= minimum
  - **THEN** return: `{ "success": true, "paymentUrl": <url>, "referenceId": <id>, "amount": <amount>, "message": "تم إنشاء رابط الدفع. الرجاء إتمام عملية الدفع", "paymentMethod": <method> }`
- **ELSE IF** amount < minimum
  - **THEN** return: `{ "success": false, "error": "AMOUNT_TOO_LOW", "message": "المبلغ أقل من الحد الأدنى ({minimum} IQD)", "minimumAmount": <amount> }`
- **ELSE IF** payment method unavailable
  - **THEN** return: `{ "success": false, "error": "PAYMENT_UNAVAILABLE", "message": "طريقة الدفع غير متاحة حالياً. يرجى التواصل مع الدعم" }`

---

### 7. **Check Driver Assignment**
**Use Case Name:** `MERCHANT_CHECK_DRIVER_ASSIGNMENT`

**Conditions:**
- **IF** order exists AND order has driver assigned (`driverId` is not null)
  - **THEN** return: `{ "hasDriver": true, "driverName": <name>, "driverPhone": <phone>, "assignedAt": <timestamp>, "status": <status>, "message": "تم تخصيص السائق: {name}" }`
- **ELSE IF** order exists BUT no driver assigned yet
  - **THEN** return: `{ "hasDriver": false, "status": <status>, "message": "لم يتم تخصيص سائق بعد. جاري البحث عن سائق متاح" }`
- **ELSE IF** order not found
  - **THEN** return: `{ "success": false, "error": "ORDER_NOT_FOUND", "message": "الطلب غير موجود" }`

---

### 8. **Request Customer Location Update**
**Use Case Name:** `MERCHANT_REQUEST_CUSTOMER_LOCATION`

**Conditions:**
- **IF** order exists AND customer phone exists AND WhatsApp integration enabled
  - **THEN** return: `{ "success": true, "message": "تم إرسال رابط مشاركة الموقع للعميل عبر واتساب", "orderId": <id>, "whatsappLink": <link> }`
- **ELSE IF** customer phone missing
  - **THEN** return: `{ "success": false, "error": "PHONE_MISSING", "message": "رقم هاتف العميل غير متوفر" }`
- **ELSE IF** WhatsApp integration disabled
  - **THEN** return: `{ "success": false, "error": "WHATSAPP_DISABLED", "message": "خدمة واتساب غير متاحة حالياً" }`

---

### 9. **View Analytics/Earnings**
**Use Case Name:** `MERCHANT_VIEW_ANALYTICS`

**Conditions:**
- **IF** merchant has order history
  - **THEN** return: `{ "hasData": true, "analytics": { "totalOrders": <count>, "completedOrders": <count>, "totalSpent": <amount>, "averageOrderValue": <amount>, "todayOrders": <count>, "thisMonthOrders": <count> }, "message": "إحصائياتك: {totalOrders} طلب إجمالي" }`
- **ELSE**
  - **THEN** return: `{ "hasData": false, "message": "لا توجد بيانات إحصائية متاحة بعد" }`

---

### 10. **Check Order Creation Eligibility**
**Use Case Name:** `MERCHANT_CHECK_ORDER_ELIGIBILITY`

**Conditions:**
- **IF** wallet balance > credit limit AND merchant address configured AND merchant location set
  - **THEN** return: `{ "eligible": true, "message": "يمكنك إنشاء طلب جديد", "readyToCreate": true }`
- **ELSE IF** wallet balance <= credit limit
  - **THEN** return: `{ "eligible": false, "reason": "INSUFFICIENT_BALANCE", "message": "رصيدك غير كافٍ. يرجى شحن المحفظة", "action": "topUpWallet" }`
- **ELSE IF** merchant address missing
  - **THEN** return: `{ "eligible": false, "reason": "ADDRESS_MISSING", "message": "يرجى إضافة عنوان المتجر أولاً", "action": "updateProfile" }`
- **ELSE IF** merchant location missing
  - **THEN** return: `{ "eligible": false, "reason": "LOCATION_MISSING", "message": "يرجى تحديد موقع المتجر على الخريطة", "action": "updateLocation" }`

---

### 11. **View Wallet Summary**
**Use Case Name:** `MERCHANT_VIEW_WALLET_SUMMARY`

**Conditions:**
- **IF** wallet exists
  - **THEN** return: `{ "success": true, "wallet": { "balance": <amount>, "creditLimit": <limit>, "orderFee": <fee>, "totalSpent": <amount>, "totalToppedUp": <amount>, "totalOrders": <count> }, "message": "رصيدك: {balance} IQD" }`
- **ELSE IF** wallet not initialized
  - **THEN** return: `{ "success": false, "error": "WALLET_NOT_INITIALIZED", "message": "المحفظة غير مهيأة. سيتم إنشاؤها تلقائياً عند أول طلب" }`

---

### 12. **Create Voice Order**
**Use Case Name:** `MERCHANT_CREATE_VOICE_ORDER`

**Conditions:**
- **IF** wallet balance > credit limit AND voice recording provided AND transcription successful
  - **THEN** return: `{ "success": true, "transcription": <text>, "extractedData": { "customerName": <name>, "customerPhone": <phone>, "address": <address> }, "message": "تم تحويل الصوت إلى نص. يرجى مراجعة البيانات وإنشاء الطلب", "nextAction": "reviewAndCreate" }`
- **ELSE IF** wallet balance <= credit limit
  - **THEN** return: `{ "success": false, "error": "INSUFFICIENT_BALANCE", "message": "رصيدك غير كافٍ لإنشاء الطلب" }`
- **ELSE IF** transcription failed
  - **THEN** return: `{ "success": false, "error": "TRANSCRIPTION_FAILED", "message": "فشل تحويل الصوت إلى نص. يرجى المحاولة مرة أخرى" }`
- **ELSE IF** required data missing from transcription
  - **THEN** return: `{ "success": false, "error": "INCOMPLETE_DATA", "message": "لم يتم استخراج جميع البيانات المطلوبة. يرجى المحاولة مرة أخرى أو إدخال البيانات يدوياً", "missingFields": [<field_list>] }`

---

## 📋 SYSTEM-LEVEL USE CASES

### 1. **System Status Questions**
**Use Case Name:** `CHECK_SYSTEM_STATUS`

**Common Questions:**
- "هل النظام يعمل؟" / "Is the system working?"
- "لماذا التطبيق بطيء؟" / "Why is the app slow?"
- "هل هناك صيانة؟" / "Is there maintenance?"

**Chatbot Response Logic:**
- **IF** system is enabled
  - **THEN** respond: `"النظام يعمل بشكل طبيعي. ✅\n\nجميع الخدمات متاحة. 🟢"`
- **ELSE IF** system is in maintenance mode
  - **THEN** respond: `"النظام قيد الصيانة حالياً. 🔧\n\nيرجى المحاولة لاحقاً. شكراً لصبرك! ⏳"`
- **ELSE IF** system is disabled
  - **THEN** respond: `"النظام غير متاح حالياً. ❌\n\nيرجى المحاولة لاحقاً أو التواصل مع الدعم. 📞"`

---

### 2. **Notifications Questions**
**Use Case Name:** `VIEW_NOTIFICATIONS`

**Common Questions:**
- "هل لدي إشعارات؟" / "Do I have notifications?"
- "لماذا لا أستقبل إشعارات؟" / "Why am I not receiving notifications?"

**Chatbot Response Logic:**
- **IF** driver has notifications
  - **THEN** respond: `"لديك {count} إشعار جديد. 🔔\n\n{Show notification summary}"`
  - **Action:** Show notifications list
- **ELSE**
  - **THEN** respond: `"لا توجد إشعارات جديدة. 📭\n\nستتلقى إشعاراً عند توفر طلب جديد أو تحديث مهم. 🔔"`

---

### 3. **Contact Support**
**Use Case Name:** `CONTACT_SUPPORT`

**Common Questions:**
- "أريد التواصل مع الدعم" / "I want to contact support"
- "مساعدة" / "Help"
- "لدي مشكلة" / "I have a problem"

**Chatbot Response Logic:**
- **IF** support chat available
  - **THEN** respond: `"يمكنك التواصل مع الدعم عبر:\n\n• الدردشة المباشرة 💬\n• الهاتف: {phone}\n• واتساب: {whatsapp}\n\nكيف تفضل التواصل؟"`
  - **Action:** Open support channel based on driver preference
- **ELSE**
  - **THEN** respond: `"خدمة الدعم غير متاحة حالياً. ⏳\n\nيرجى المحاولة لاحقاً أو إرسال رسالة عبر التطبيق."`

---

## 🎯 CHATBOT RESPONSE STRUCTURE

The chatbot should respond in a conversational, helpful manner. Responses should:

1. **Be in Arabic** (RTL support)
2. **Be clear and friendly**
3. **Provide actionable information**
4. **Offer to take actions when possible**
5. **Guide drivers to solutions**

### Response Format:

```json
{
  "useCase": "<USE_CASE_NAME>",
  "response": "<conversational_arabic_message>",
  "type": "answer|action|guidance",
  "data": { /* relevant data */ },
  "actions": [ /* available actions */ ],
  "suggestions": [ /* helpful suggestions */ ],
  "timestamp": "<iso_timestamp>"
}
```

### Example Responses:

**Answer Type:**
```json
{
  "useCase": "DRIVER_CHECK_WALLET",
  "response": "رصيدك الحالي: 25,000 IQD 💰\n\nيمكنك سحب الأموال من المحفظة.",
  "type": "answer",
  "data": {
    "balance": 25000,
    "formattedBalance": "25,000 IQD"
  },
  "actions": ["viewTransactions", "withdraw"],
  "suggestions": []
}
```

**Action Type:**
```json
{
  "useCase": "DRIVER_ACCEPT_ORDER",
  "response": "تم قبول الطلب بنجاح! ✅\n\nالآن يمكنك التنقل إلى موقع الاستلام. 🗺️",
  "type": "action",
  "data": {
    "orderId": "123e4567-e89b-12d3-a456-426614174000",
    "pickupAddress": "شارع الكوفة، النجف",
    "deliveryFee": 5000
  },
  "actions": ["navigateToPickup", "viewOrderDetails"],
  "suggestions": ["تأكد من أن الطلب جاهز قبل الذهاب"]
}
```

**Guidance Type:**
```json
{
  "useCase": "DRIVER_UPDATE_STATUS_PICKUP",
  "response": "الطلب غير جاهز بعد. ⏳\n\nالوقت المتبقي: 15 دقيقة\n\nيمكنك الانتظار أو التواصل مع التاجر.",
  "type": "guidance",
  "data": {
    "readyCountdown": 15,
    "readyAt": "2025-01-27T11:00:00Z"
  },
  "actions": ["contactMerchant", "waitForReady"],
  "suggestions": ["سيتم إشعارك عندما يصبح الطلب جاهزاً"]
}
```

---

## 📝 IMPLEMENTATION NOTES

### Chatbot Behavior:
1. **Be conversational**: Respond naturally, as if talking to a friend
2. **Be proactive**: Offer solutions, don't just answer questions
3. **Be helpful**: Guide drivers through issues step-by-step
4. **Be clear**: Use simple Arabic, avoid technical jargon
5. **Be empathetic**: Acknowledge frustrations, celebrate successes

### Technical Requirements:
1. All messages in **Arabic** (RTL support)
2. All monetary amounts in **IQD** (Iraqi Dinar)
3. All timestamps in **ISO 8601** format
4. Use case names in **UPPER_SNAKE_CASE**
5. Phone numbers follow Iraqi format (+964)
6. Location coordinates in decimal degrees (latitude, longitude)

### Question Recognition:
The chatbot should recognize variations of questions:
- Formal and informal Arabic
- Different phrasings of the same question
- Questions with typos or missing words
- Questions in English (if driver prefers)

### Action Execution:
When the chatbot offers to take an action:
- **Always confirm** before executing critical actions (reject order, cancel, etc.)
- **Show progress** for actions that take time
- **Provide feedback** after action completion
- **Handle errors gracefully** with helpful error messages

