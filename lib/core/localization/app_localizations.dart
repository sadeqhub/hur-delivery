import 'package:flutter/material.dart';

/// Simple in-app localization layer for Arabic and English.
/// 
/// This is intentionally key-based and keeps layouts unchanged by only
/// swapping strings, not widget structures.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  bool get isArabic => locale.languageCode == 'ar';

  static const List<Locale> supportedLocales = [
    Locale('ar', 'IQ'),
    Locale('en', 'US'),
  ];

  /// Core localized strings.
  /// 
  /// NOTE: This is a focused first pass covering global/common strings
  /// and main flows (auth, dashboards, orders, wallet, support, errors).
  /// Additional keys can be added here as needed without changing layouts.
  static final Map<String, Map<String, String>> _localizedValues = {
    'ar': {
      // General
      'app_title': 'حر - Hur Delivery',
      'general': 'عام',
      'ok': 'حسناً',
      'cancel': 'إلغاء',
      'back': 'رجوع',
      'retry': 'إعادة المحاولة',
      'loading': 'جاري التحميل...',
      'error_generic': 'حدث خطأ غير متوقع',

      // Connectivity
      'no_internet_title': 'لا يوجد اتصال بالإنترنت',
      'no_internet_message':
          'يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى.',

      // Auth / Onboarding
      'login': 'تسجيل الدخول',
      'logout': 'تسجيل الخروج',
      'phone_number': 'رقم الهاتف',
      'enter_phone_number': 'أدخل رقم هاتفك',
      'enter_iraqi_phone_login': 'أدخل رقم هاتفك العراقي لتسجيل الدخول',
      'enter_iraqi_phone_otp': 'أدخل رقم هاتفك العراقي لإرسال رمز التحقق عبر WhatsApp',
      'send_code': 'إرسال الرمز',
      'verify_code': 'تأكيد الرمز',
      'resend_code': 'إعادة إرسال الرمز',
      'continue': 'متابعة',
      'driver': 'سائق',
      'merchant': 'تاجر',
      'customer': 'عميل',
      'user': 'مستخدم',
      'select_role': 'اختر نوع الحساب',
      'welcome_to_hur': 'مرحباً بك في حر للتوصيل',
      'fast_delivery_service': 'خدمة التوصيل السريع',
      'platform_for_drivers_merchants': 'منصة التوصيل للسائقين والتجار',
      'have_account': 'حساب موجود',
      'no_account': 'لا يوجد حساب',
      'create_account': 'إنشاء حساب',
      'try_app': 'تجربة التطبيق',
      'demo_mode_title': 'تجربة التطبيق',
      'demo_mode_info': 'في وضع التجربة، يمكنك استكشاف التطبيق ولكن لا يمكنك إنشاء طلبات أو تفعيل وضع الاتصال',
      'demo_merchant': 'تاجر تجريبي',
      'demo_merchant_desc': 'استكشف لوحة تحكم التاجر',
      'demo_driver': 'سائق تجريبي',
      'demo_driver_desc': 'استكشف لوحة تحكم السائق',
      'change_phone': 'تغيير رقم الهاتف',
      'enter_otp': 'أدخل رمز التحقق',
      'otp_sent_to': 'تم إرسال رمز التحقق إلى',
      'test_number_hint': '🧪 رقم اختبار: استخدم الرمز 000000',
      'sent_via_whatsapp': 'تم الإرسال عبر واتساب',
      'confirm_otp': 'تأكيد الرمز',
      'resend_otp': 'إعادة إرسال الرمز',
      'resend_in_seconds': 'يمكنك إعادة الإرسال خلال {seconds} ثانية',
      'otp_failed_identity': 'فشل التحقق من الهوية',
      'otp_invalid': 'رمز التحقق غير صحيح',
      'otp_resent_via': 'تم إرسال رمز التحقق مرة أخرى عبر {method}',
      'otp_send_error': 'حدث خطأ في إرسال الرمز',
      'no_account_for_phone':
          'لا يوجد حساب مسجل بهذا الرقم. يرجى التسجيل أولاً.',
      'no_account_title': 'لا يوجد حساب',
      'error_selecting_image': 'حدث خطأ في اختيار الصورة: ',
      'user_data_error':
          'خطأ في بيانات المستخدم. يرجى التواصل مع الدعم الفني.',
      'enter_valid_iraqi_phone':
          'أدخل رقم هاتف عراقي صالح مكون من 10 أرقام يبدأ بـ 7',
      'phone_required': 'رقم الهاتف مطلوب',
      'phone_must_be_10_digits': 'رقم الهاتف يجب أن يكون 10 أرقام',
      'phone_must_start_with_pattern':
          'رقم الهاتف يجب أن يبدأ بـ 7 أو 78000000XX (سائق) أو 77000000XX (تاجر) أو 999 (اختبار)',

      // Dashboards
      'dashboard_driver_title': 'لوحة السائق',
      'dashboard_merchant_title': 'لوحة التاجر',
      'dashboard_admin_title': 'لوحة التحكم - الإدارة',
      'home': 'الرئيسية',
      'wallet': 'المحفظة',
      'support': 'الدعم',
      'voice': 'صوتي',
      'stats': 'الإحصائيات',
      'overview': 'نظرة عامة',
      'users': 'المستخدمين',
      'orders': 'الطلبات',
      'analytics': 'الإحصائيات',
      'driver_online': 'متصل',
      'driver_offline': 'غير متاح',
      'unregistered': 'غير مسجل',
      'must_login_first': 'يجب تسجيل الدخول أولاً',
      'accepted': 'تم القبول',
      'accept_success': 'تم قبول الطلب بنجاح',
      'rejected': 'تم الرفض',
      'reject_success': 'تم رفض الطلب',
      'error': 'خطأ',
      'operation_error': 'حدث خطأ في العملية',
      'accept_error': 'حدث خطأ في قبول الطلب',
      'reject_error': 'حدث خطأ في رفض الطلب',
      'order_number': 'رقم الطلب',
      'delivery_fee': 'رسوم التوصيل',
      'order_value': 'قيمة الطلب',
      'distance_label': 'المسافة',
      'now': 'الآن',
      'merchant_label': 'التاجر',
      'customer_label': 'العميل',
      'location_label': 'الموقع',
      'cancel': 'إلغاء',
      'confirm': 'تأكيد',
      'confirm_go_offline_title': 'تأكيد النزول عن الشبكة',
      'confirm_go_offline_message':
          'هل أنت متأكد من أنك تريد التوقف عن استقبال الطلبات؟ سيتم إيقاف تتبع موقعك وإشعارات الطلبات الجديدة.',
      'order_ready_now': 'الطلب جاهز الآن',
      'status_pending': 'في الانتظار',
      'status_assigned': 'تم التخصيص',
      'status_accepted': 'تم القبول',
      'status_on_the_way': 'في الطريق',
      'status_delivered': 'تم التسليم',
      'status_cancelled': 'ملغي',
      'status_unassigned': 'غير مخصص',
      'status_rejected': 'مرفوض',
      'status_scheduled': 'مجدول',
      'status_unknown': 'غير معروف',
      'in_progress_title': 'في الطريق',
      'in_progress_message': 'تم بدء التوصيل للعميل',
      'delivery_confirm_title': 'تأكيد التسليم',
      'delivery_confirm_question':
          'هل قمت بتسليم الطلب للعميل؟',
      'delivery_confirm_hint':
          'تأكد من استلام العميل للطلب قبل التأكيد',
      'delivery_error_title': 'خطأ في التسليم',
      'delivery_error_unknown': 'خطأ غير معروف',
      'delivery_success_title': 'تم التسليم',
      'delivery_success_message': 'تم تسليم الطلب بنجاح',
      'warning_title': 'تنبيه',
      'merchant_info_missing': 'معلومات التاجر غير متوفرة',
      'call_merchant_title': 'الاتصال بالتاجر',
      'call_customer_title': 'الاتصال بالعميل',
      'call_title': 'الاتصال',
      'privacy_policy': 'سياسة الخصوصية',
      'terms_and_conditions': 'شروط الاستخدام',
      'no_orders_yet': 'لا توجد طلبات بعد',
      'error_label': 'خطأ: ',
      'not_available': 'غير متوفر',
      'call_error_message': 'لا يمكن إجراء المكالمة',
      'whatsapp_call': 'اتصال عبر واتساب',
      'whatsapp_message': 'رسالة واتساب',
      'whatsapp_open_error': 'لا يمكن فتح واتساب',
      'whatsapp_driver_message':
          'مرحباً {name}، أنا سائق التوصيل من تطبيق حر',
      'invalid_coordinates': 'إحداثيات غير صالحة',
      'maps_open_error': 'لا يمكن فتح خرائط جوجل',
      'maps_launch_failed': 'فشل فتح خرائط جوجل',
      'waze_open_error': 'لا يمكن فتح تطبيق ويز',
      'waze_launch_failed': 'فشل فتح تطبيق ويز',
      'location_permission_required_title': 'إذن الموقع مطلوب',
      'location_permission_required_message':
          'للعمل كسائق، يجب منح إذن الموقع "طوال الوقت".',
      'location_permission_benefits':
          'هذا يسمح لك بـ:\n• استلام إشعارات الطلبات حتى عند إغلاق التطبيق\n• تتبع موقعك أثناء التوصيل\n• الظهور في قائمة السائقين المتاحين',
      'location_permission_settings_hint':
          'الرجاء اختيار "السماح طوال الوقت" في الإعدادات',
      'open_settings': 'فتح الإعدادات',
      'background_location_info_title':
          'معلومات مهمة عن الموقع بالخلفية',
      'background_location_info_message':
          'عند تفعيل وضع "متصل"، سيقوم التطبيق بجمع موقعك في الخلفية وعرض إشعار دائم لإبقائك متاحًا لطلبات التوصيل.\n\nيُستخدم ذلك فقط لوظائف التطبيق الأساسية (تتبع السائق، الإشعارات، وتسليم الطلبات).',

      // Orders
      'orders_active': 'الطلبات النشطة',
      'orders_completed': 'الطلبات المكتملة',
      'no_active_orders': 'لا توجد طلبات نشطة',
      'no_completed_orders': 'لا توجد طلبات مكتملة',
      'order_details': 'تفاصيل الطلب',
      'create_order': 'إنشاء طلب',
      'create_new_order': 'إنشاء طلب جديد',
      'scheduled_order': 'طلب مجدول',
      'bulk_order': 'طلب جماعي',
      'voice_order': 'طلب صوتي',
      'order_number_prefix': 'طلب #',
      'party_info': 'معلومات الأطراف',
      'customer_phone': 'هاتف العميل',
      'driver_phone': 'هاتف السائق',
      'searching_driver': 'جاري البحث عن سائق...',
      'created_at': 'وقت الإنشاء',
      'assigned_at': 'وقت التخصيص',
      'rejected_at': 'وقت الرفض',
      'delivery_locations': 'مواقع التوصيل',
      'from': 'من',
      'to': 'إلى',
      'delivery_proof': 'صور إثبات التسليم',
      'order_items': 'عناصر الطلب',
      'financial_summary': 'الملخص المالي',
      'order_price_no_delivery': 'سعر الطلب (بدون رسوم التوصيل)',
      'grand_total': 'المبلغ الإجمالي',
      'total_amount': 'المبلغ الإجمالي',
      'notes': 'ملاحظات',
      'cancel_order': 'إلغاء الطلب',
      'cancel_order_confirm': 'هل أنت متأكد من إلغاء هذا الطلب؟',
      'order_cancelled': 'تم إلغاء الطلب',
      'order_cancel_failed': 'فشل إلغاء الطلب',
      'all_drivers_rejected': 'تم رفض هذا الطلب من قبل جميع السائقين المتاحين',
      'repost_order': 'إعادة نشر (+500 د.ع)',
      'reject_order': 'رفض الطلب',
      'accept_order': 'قبول الطلب',
      'picked_up': 'تم الاستلام',
      'on_the_way': 'في الطريق',
      'delivered': 'تم التسليم',
      'track_driver': 'تتبع موقع السائق',
      'contact_support': 'التواصل مع الدعم',
      'insufficient_balance_repost': 'رصيد غير كافٍ. يرجى شحن محفظتك أولاً لإعادة نشر الطلب',
      'merchant_data_error': 'لا يمكن تحديد التاجر المرتبط بهذا الطلب. يرجى إعادة المحاولة لاحقاً.',
      'no_drivers_available': 'لا يوجد سائقون متاحون',
      'repost_order_title': 'إعادة نشر الطلب',
      'repost_order_message': 'سيتم إعادة نشر الطلب مع زيادة رسوم التوصيل:',
      'current_delivery_fee': 'رسوم التوصيل الحالية:',
      'new_delivery_fee': 'رسوم التوصيل الجديدة:',
      'repost_order_hint': 'سيتم تخصيص الطلب للسائقين مرة أخرى.',
      'repost_success': 'تم إعادة نشر الطلب بنجاح! سيتم تخصيصه للسائقين.',
      'repost_error': 'حدث خطأ في إعادة نشر الطلب',
      'driver_assigned_soon': 'سيتم تخصيص سائق قريباً',
      'order_accepted': 'تم قبول الطلب',
      'reject_order_confirm': 'هل أنت متأكد من رفض هذا الطلب؟',
      'order_rejected': 'تم رفض الطلب',
      'pickup_confirmed': 'تم تأكيد الاستلام',
      'delivery_started': 'تم تأكيد البدء بالتوصيل',
      'delivery_confirmed': 'تم تأكيد التسليم',
      'support_message_template': 'مرحباً، أحتاج مساعدة بخصوص الطلب #',
      'whatsapp_open_failed': 'لا يمكن فتح واتساب',
      'whatsapp_error': 'حدث خطأ في فتح واتساب',
      'am': 'ص',
      'pm': 'م',
      'status_created': 'تم الإنشاء',
      'no_delivery_proof': 'لا توجد صور مرفوعة لهذا الطلب بعد',
      'currency_symbol': 'د.ع',
      'insufficient_balance_create': 'يرجى شحن محفظتك لإنشاء طلب جديد',
      'form_filled_from_voice': '✅ تم ملء النموذج من التسجيل الصوتي',
      'store_location': 'موقع المتجر',
      'location_selected': 'موقع محدد',
      'pick_location_pickup': 'اختر موقع الاستلام',
      'pick_location_delivery': 'اختر موقع التسليم',
      'location_success': 'نجح',
      'location_success_message': 'تم تحديد الموقع بنجاح',
      'location_not_found': 'لم يتم العثور على الموقع في النجف',
      'location_error': 'حدث خطأ في تحديد الموقع',
      'checking_drivers': 'جارٍ التحقق من السائقين المتاحين...',
      'no_drivers_online': 'لا يوجد سائقين متصلين',
      'cannot_create_order': 'لا يمكن إنشاء الطلب حالياً. يرجى المحاولة لاحقاً.',
      'all_drivers_busy': 'جميع السائقين مشغولون',
      'drivers_online': 'سائق متصل ومتاح للتوصيل',
      'drivers_available_now': 'يوجد سائقون متاحون للتوصيل',
      'refresh': 'تحديث',
      'free_driver_available': 'هناك سائقون متاحون الآن.',
      'same_merchant_driver_available': 'سيتم تعيين الطلب إلى سائق يخدم نفس التاجر حالياً.',
      'no_driver_available': 'لا يوجد سائقون متصلون وفارغون، ولا يوجد سائق يخدم نفس التاجر لأخذ طلب إضافي.',
      'fallback_no_online_drivers': 'لا يوجد سائقون متصلون حالياً. يرجى المحاولة لاحقاً.',
      'fallback_exception': 'تعذر التحقق من توفر السائقين. يرجى المحاولة لاحقاً أو التواصل مع الدعم.',
      'unknown_availability': 'تعذر تحديد توفر السائقين حالياً. يرجى المحاولة مرة أخرى.',
      'customer_info': 'بيانات العميل',
      'customer_name_optional': 'اسم العميل (اختياري)',
      'enter_customer_name': 'أدخل اسم العميل',
      'locations': 'المواقع',
      'pickup_location': 'موقع الاستلام',
      'pickup_location_hint': 'اكتب العنوان أو اختر من الخريطة',
      'advanced_settings': 'الإعدادات المتقدمة',
      'delivery_location': 'موقع التسليم',
      'delivery_location_hint': 'اكتب العنوان أو اختر من الخريطة',
      'prices': 'الأسعار',
      'delivery_fee_required': 'رسوم التوصيل مطلوبة',
      'low_delivery_fee_warning': 'الرسوم منخفضة جداً. قد يكون من الصعب الحصول على سائق بهذا المبلغ. الرسوم الموصى بها',
      'enter_valid_number': 'أدخل رقم صحيح',
      'amount_required': 'المبلغ مطلوب',
      'vehicle_type': 'نوع المركبة',
      'select_vehicle_type': 'اختر نوع المركبة المطلوبة',
      'any_vehicle': 'أي مركبة متاحة',
      'default': 'افتراضي',
      'any_vehicle_hint': 'يتم تخصيص أقرب سائق بأي نوع مركبة',
      'motorbike': 'دراجة نارية',
      'car': 'سيارة',
      'truck': 'شاحنة',
      'motorbike_hint': 'سيتم إرسال الطلب لسائقي الدراجات النارية',
      'car_hint': 'سيتم إرسال الطلب لسائقي السيارات فقط',
      'truck_hint': 'سيتم إرسال الطلب لسائقي الشاحنات فقط',
      'order_driver_for_day': 'طلب سائق ليوم كامل',
      'bulk_order_description': 'احجز سائقاً ليوم كامل لتوصيل الطلبات في الأحياء المحددة',
      'order_date': 'تاريخ الطلب',
      'delivery_neighborhoods': 'أحياء التسليم',
      'minimum_three': 'الحد الأدنى 3',
      'add_neighborhood': 'إضافة حي',
      'select_neighborhood': 'اختر حي',
      'minimum_three_neighborhoods': 'يجب اختيار 3 أحياء على الأقل',
      'per_delivery_fee': 'رسوم كل توصيل',
      'bulk_order_fee': 'رسوم طلب السائق',
      'bulk_order_fee_description': 'رسوم ثابتة لطلب سائق ليوم كامل',
      'create_bulk_order': 'إنشاء طلب السائق',
      'bulk_order_created_success': 'تم إنشاء طلب السائق بنجاح',
      'bulk_order_accepted_success': 'تم قبول طلب السائق بنجاح',
      'bulk_order_active': 'تم قبول طلب السائق - جاهز للتوصيل',
      'notes_optional': 'ملاحظات (اختياري)',
      'additional_notes': 'ملاحظات إضافية',
      'add_notes_hint': 'أضف أي ملاحظات هنا...',
      'when_ready': 'متى يمكنك تجهيز الطلب؟',
      'ready_now': 'الطلب جاهز الآن',
      'ready_after_minutes': 'سيكون الطلب جاهزاً بعد {minutes} دقيقة',
      'now': 'الآن',
      'minutes': 'دقيقة',
      'sixty_minutes': '60 دقيقة',
      'grand_total_label': 'المجموع الكلي',
      'creating_order': 'جاري الإنشاء...',
      'order_created': 'تم إنشاء الطلب',
      'order_created_success': 'تم إنشاء الطلب بنجاح',
      'order_created_ready_after': 'سيكون الطلب جاهزاً بعد {minutes} دقيقة',
      'order_create_error': 'حدث خطأ في إنشاء الطلب',
      'customer_phone_label': 'رقم هاتف العميل',
      'phone_invalid_format': 'أدخل رقم عراقي صحيح يبدأ بـ 7 (10 أرقام)',
      'open_map': 'افتح الخريطة',
      'search_address': 'ابحث عن العنوان',
      'view_details': 'عرض التفاصيل',
      'order_display_error': 'خطأ في عرض الطلب',
      'ago_minutes': 'قبل {minutes} دقيقة',
      'ago_hours': 'قبل {hours} ساعة',
      'ago_days': 'قبل {days} يوم',
      'days_short': 'يوم',
      'hours_short': 'ساعة',
      'status_waiting': 'قيد الانتظار',
      'customer_name_fallback': 'عميل',
      'phone_not_available': 'غير متوفر',
      'pickup_address_fallback': 'عنوان الاستلام',
      'delivery_address_fallback': 'عنوان التوصيل',
      'grand_total_with_delivery': 'المبلغ الإجمالي (الطلب + التوصيل)',
      'assigned_status': 'تم التخصيص',
      'required': 'مطلوب',
      // Voice Order
      'voice_order': 'طلب صوتي',
      'microphone_permission_required': 'يرجى السماح بالوصول إلى الميكروفون',
      'recording': 'جاري التسجيل...',
      'processing_audio': 'جاري معالجة الصوت...',
      'click_to_start': 'انقر للبدء',
      'extracting_data': 'يتم استخراج البيانات من الصوت',
      'speak_order_details': 'قل تفاصيل الطلب بصوت واضح',
      'how_to_use': 'كيفية الاستخدام',
      'say_customer_name': 'قل اسم العميل: "الاسم: أحمد محمد"',
      'say_phone': 'قل رقم الهاتف: "الهاتف: 0771234567"',
      'say_pickup': 'قل موقع الاستلام: "من: شارع الكرادة"',
      'say_delivery': 'قل موقع التوصيل: "إلى: المنصور"',
      'say_amount': 'قل المبلغ: "المبلغ: خمسون ألف دينار"',
      'voice_library': 'مكتبة التسجيلات السابقة',
      'stop_recording': 'إيقاف التسجيل',
      'processing': 'جاري المعالجة...',
      'start_voice_recording': 'بدء التسجيل الصوتي',
      'extracted_data': 'البيانات المستخرجة',
      'customer_name_label': 'اسم العميل',
      'phone_label': 'الهاتف',
      'pickup_label': 'الاستلام',
      'delivery_label': 'التوصيل',
      'amount_label': 'المبلغ',
      'confirm_create_order': 'تأكيد وإنشاء الطلب',
      'transcription': 'النص المستخرج من الصوت',
      'extraction_accuracy': 'دقة الاستخراج: ',
      'missing_fields': 'حقول ناقصة: ',
      'no_drivers_available_now': 'لا يوجد سائقين متاحين في الوقت الحالي. يرجى المحاولة لاحقاً.',
      'error_starting_recording': 'خطأ في بدء التسجيل: ',
      'error_stopping_recording': 'خطأ في إيقاف التسجيل: ',
      'recording_loaded_success': 'تم تحميل التسجيل بنجاح',
      'recording_load_failed': 'فشل تحميل التسجيل: ',
      'audio_processing_failed': 'فشل معالجة الصوت: ',
      'error': 'خطأ: ',
      'incomplete_data': 'البيانات غير مكتملة. يرجى التأكد من وجود: الاسم، الهاتف، والعناوين',
      'alert': 'تنبيه',
      'low_confidence': 'دقة استخراج البيانات منخفضة ({percent}%). يرجى التحقق من البيانات قبل المتابعة.',
      'continue_action': 'متابعة',
      'customer_phone_required': 'رقم هاتف العميل مطلوب',
      'customer_phone_required_for_pickup': 'يجب إدخال رقم هاتف العميل قبل تأكيد الاستلام',
      'customer_phone_optional': 'رقم العميل (اختياري)',
      'multiple_orders': 'طلبات متعددة',
      'multiple_orders_description': 'إنشاء طلبات متعددة للتوصيل في أحياء مختلفة',
      'create_multiple_orders': 'إنشاء الطلبات المتعددة',
      'bulk_order_status_pending': 'قيد الانتظار',
      'bulk_order_status_assigned': 'تم التخصيص',
      'bulk_order_status_accepted': 'مقبول',
      'bulk_order_status_active': 'نشط',
      'bulk_order_status_completed': 'مكتمل',
      'bulk_order_status_cancelled': 'ملغي',
      'bulk_order_status_rejected': 'مرفوض',
      'assigned_driver': 'السائق المخصص',
      'assign_to_same_driver': 'تعيين الطلب لنفس السائق',
      'current_driver': 'السائق الحالي',
      'contact_driver': 'اتصل بالسائق',
      'call_via_whatsapp': 'واتساب',
      'driver_info_not_available': 'معلومات السائق غير متاحة',
      'driver_phone_not_available': 'رقم الهاتف غير متاح',
      'hello_driver': 'مرحبا',
      'close': 'إغلاق',
      'pickup_address_required': 'عنوان الاستلام مطلوب',
      'delivery_address_required': 'عنوان التسليم مطلوب',
      'order_created_success_voice': '✅ تم إنشاء الطلب بنجاح',
      'order_create_error_voice': 'حدث خطأ في إنشاء الطلب: ',
      // Wallet
      'my_wallet': 'محفظتي',
      'please_top_up': 'يرجى شحن المحفظة',
      'balance_low': 'الرصيد منخفض',
      'balance_good': 'الرصيد جيد',
      'current_balance': 'الرصيد الحالي',
      'credit_limit': 'الحد الائتماني: ',
      'top_up_wallet': 'شحن المحفظة',
      'fee_exempt_banner': 'أنت معفي من الرسوم',
      'fee_exempt_message': 'لأنك مسجل منذ أقل من شهر، لن يتم خصم أي رسوم من محفظتك',
      'fee_exempt_until': 'الإعفاء حتى',
      'total_orders': 'إجمالي الطلبات',
      'total_fees': 'إجمالي الرسوم',
      'no_transactions': 'لا توجد معاملات',
      'recent_transactions': 'آخر المعاملات',
      'balance': 'الرصيد: ',
      // Settings
      'notifications_enabled': 'تم تفعيل الإشعارات',
      'notifications_denied': 'تم رفض إذن الإشعارات',
      'notification_settings': 'إعدادات الإشعارات',
      'notification_settings_hint': 'لتغيير إعدادات الإشعارات، يرجى الانتقال إلى إعدادات التطبيق في النظام.',
      'open_settings': 'فتح الإعدادات',
      'notifications': 'الإشعارات',
      'instant_notifications': 'الإشعارات الفورية',
      'receive_notifications': 'تلقي إشعارات حول الطلبات والتحديثات',
      'notifications_disabled': 'الإشعارات معطلة - افتح إعدادات التطبيق لتفعيلها',
      'sound': 'الصوت',
      'sound_subtitle': 'تشغيل الصوت للإشعارات',
      'vibration': 'الاهتزاز',
      'vibration_subtitle': 'تشغيل الاهتزاز للإشعارات',
      'app': 'التطبيق',
      'about_app': 'حول التطبيق',
      'app_description': 'تطبيق توصيل متقدم لإدارة الطلبات والسائقين',
      'app_description_driver': 'تطبيق توصيل متقدم لإدارة الطلبات',
      'version': 'الإصدار ',
      'location': 'الموقع',
      'location_permission': 'إذن الموقع',
      'location_permission_subtitle': 'يجب منح إذن "طوال الوقت" للحصول على الطلبات',
      'check': 'فحص',
      'location_permission_required_driver': 'للحصول على طلبات توصيل، يجب منح إذن الموقع "طوال الوقت".\n\nهذا يسمح للتطبيق بتتبع موقعك أثناء التوصيل وإرسال إشعارات الطلبات الجديدة.',
      'receive_order_notifications': 'تلقي إشعارات الطلبات الجديدة',
      // Profile
      'edit_profile': 'تعديل الملف الشخصي',
      'profile_updated_success': 'تم تحديث الملف الشخصي بنجاح',
      'error_occurred': 'حدث خطأ: ',
      'feature_coming_soon': 'سيتم إضافة هذه الميزة قريباً',
      'name': 'الاسم',
      'name_required': 'الرجاء إدخال الاسم',
      'store_name': 'اسم المتجر',
      'store_name_required': 'الرجاء إدخال اسم المتجر',
      'phone_number_label': 'رقم الهاتف',
      'address': 'العنوان',
      'save_changes': 'حفظ التغييرات',
      'profile': 'الملف الشخصي',
      'profile_saved_success': 'تم حفظ الملف الشخصي بنجاح',
      'error_saving_profile': 'حدث خطأ أثناء حفظ الملف الشخصي',
      'no_user_data': 'لا توجد بيانات المستخدم',
      'account_info': 'معلومات الحساب',
      'name_required_field': 'الاسم مطلوب',
      'phone_cannot_change': 'لا يمكن تغيير رقم الهاتف',
      'account_status': 'حالة الحساب',
      'verification_status': 'حالة التحقق',
      'verified': 'متحقق',
      'not_verified': 'غير متحقق',
      'status': 'الحالة',
      'registration_date': 'تاريخ التسجيل',
      'enter_label': 'أدخل ',
      'pick_store_location': 'اختيار موقع المتجر',
      'pick_on_map': 'تحديد على الخريطة',
      'store_location_placeholder': 'انقر على أيقونة الخريطة لتحديد الموقع بدقة',
      'address_required': 'العنوان مطلوب',
      'location_saved_on_map': 'تم حفظ الموقع على الخريطة',
      // Messaging
      'support': 'الدعم',
      'failed_open_support': 'تعذر فتح محادثة الدعم. حاول مرة أخرى.',
      'retry': 'إعادة المحاولة',
      'open_messages_list': 'فتح قائمة الرسائل',
      'failed_select_image': 'تعذر اختيار الصورة. حاول مرة أخرى.',
      'failed_send_message': 'تعذر إرسال الرسالة. حاول مرة أخرى.',
      'conversation': 'المحادثة',
      'order': 'طلب: ',
      'reply': 'رد',
      'type_message': 'اكتب رسالة...',
      'messages': 'الرسائل',
      'no_conversations': 'لا توجد محادثات بعد',
      'technical_support': 'دعم فني',
      'conversation_label': 'محادثة',
      'support_order': 'دعم ',
      // Legal
      'error_loading_privacy': 'خطأ في تحميل سياسة الخصوصية',
      'error_loading_terms': 'خطأ في تحميل الشروط والأحكام',
      // Login with Password
      'login_with_password': 'تسجيل الدخول',
      'welcome_back': 'مرحباً بك من جديد',
      'enter_phone_password': 'أدخل رقم هاتفك وكلمة المرور',
      'invalid_phone': 'رقم غير صحيح',
      'password': 'كلمة المرور',
      'password_required': 'كلمة المرور مطلوبة',
      'invalid_credentials': 'بيانات الدخول غير صحيحة',
      'forgot_password': 'نسيت كلمة المرور؟',
      // Driver Orders
      'my_orders': 'طلباتي',
      'all': 'الكل',
      'pending': 'في الانتظار',
      'accepted': 'مقبولة',
      'completed': 'مكتملة',
      'cancelled': 'ملغية',
      'no_pending_orders': 'لا توجد طلبات في الانتظار',
      'no_accepted_orders': 'لا توجد طلبات مقبولة',
      'no_completed_orders': 'لا توجد طلبات مكتملة',
      'no_cancelled_orders': 'لا توجد طلبات ملغية',
      'no_orders': 'لا توجد طلبات',
      'order_price': 'سعر الطلب',
      'customer': 'العميل: ',
      'from': 'من: ',
      'to': 'إلى: ',
      'order_time': 'وقت الطلب: ',
      'notes': 'ملاحظات:',
      'accept_order': 'قبول الطلب',
      'reject': 'رفض',
      'complete_order': 'إكمال الطلب',
      'in_transit': 'في الطريق',
      'delivered': 'تم التسليم',
      'rejected': 'مرفوضة',
      'unknown': 'غير معروف',
      // Driver Earnings
      'earnings': 'الأرباح',
      'driver_id_not_found': 'خطأ: لم يتم العثور على معرف السائق',
      'classify_orders_by_status': 'تصنيف الطلبات حسب الحالة',
      'recent_orders': 'الطلبات الأخيرة',
      'no_orders_in_period': 'لا توجد طلبات في هذه الفترة',
      'error_loading_stats': 'خطأ في تحميل الإحصائيات',
      'today': 'اليوم',
      'week': 'الأسبوع',
      'month': 'الشهر',
      'rejected': 'مرفوضة',
      'total_orders': 'إجمالي الطلبات',
      'active_orders': 'طلبات نشطة',
      'delivered': 'تم التسليم',
      'acceptance_rate': 'معدل القبول',
      'cancelled_rejected': 'ملغية/مرفوضة',
      'hour': 'ساعة',
      'minute': 'دقيقة',
      'average_delivery_time': 'متوسط وقت التوصيل',
      'from_acceptance_to_delivery': 'من قبول الطلب حتى التسليم',
      'based_on_completed': 'بناءً على ',
      'completed_orders': ' طلب مكتمل',
      'earnings_summary': 'ملخص الأرباح',
      'total_earnings': 'إجمالي الأرباح',
      'average_earnings_per_order': 'متوسط الربح لكل طلب',
      // Notifications
      'notifications': 'الإشعارات',
      'notification_deleted': 'تم حذف الإشعار',
      'all_marked_read': 'تم تحديد جميع الإشعارات كمقروءة',
      'no_order_linked': 'لا يوجد طلب مرتبط بهذا الإشعار',
      'unread': ' غير مقروء',
      'mark_all_read': 'تحديد الكل كمقروء',
      'no_notifications': 'لا توجد إشعارات',
      // Scheduled Order
      'scheduled_order': 'طلب مجدول',
      'schedule_order_later': 'جدولة طلب لوقت لاحق',
      'date_time': 'التاريخ والوقت',
      'date': 'التاريخ',
      'time': 'الوقت',
      'recurring_order': 'طلب متكرر',
      'will_repeat_automatically': 'سيتم تكرار هذا الطلب تلقائيًا',
      'one_time_order': 'طلب لمرة واحدة',
      'recurrence_pattern': 'نمط التكرار',
      'daily': 'يومي',
      'weekly': 'أسبوعي',
      'monthly': 'شهري',
      'required': 'مطلوب',
      'recurrence_end_date': 'تاريخ انتهاء التكرار (اختياري)',
      'no_end': 'بدون نهاية',
      'order_details': 'تفاصيل الطلب',
      'customer_name': 'اسم العميل',
      'customer_phone': 'رقم هاتف العميل',
      'pickup_location': 'موقع الاستلام',
      'delivery_location': 'موقع التوصيل',
      'total_amount_iqd': 'المبلغ الإجمالي (د.ع)',
      'delivery_fee_iqd': 'رسوم التوصيل (د.ع)',
      'notes_optional': 'ملاحظات (اختياري)',
      'scheduling_summary': 'ملخص الجدولة',
      'will_be_published_at': 'سيتم نشر الطلب في: ',
      'recurrence': 'التكرار: ',
      'until': 'حتى: ',
      // Bulk Order
      'bulk_orders': 'طلبات متعددة',
      'multiple_orders_same_pickup': 'طلبات متعددة لنفس موقع الاستلام',
      'shared_details': 'التفاصيل المشتركة',
      'general_notes_optional': 'ملاحظات عامة (اختياري)',
      'when_need_drivers': 'متى تحتاج السائقين؟',
      'now_immediately': 'الآن (فوراً)',
      'after_minutes': 'بعد ',
      'minutes': ' دقيقة',
      'scheduled_orders': 'طلبات مجدولة',
      'now': 'الآن',
      'sixty_minutes': '60 دقيقة',
      'delivery_addresses': 'عناوين التوصيل (',
      'add_address': 'إضافة عنوان',
      'no_delivery_addresses': 'لم يتم إضافة أي عنوان توصيل بعد',
      'create_bulk_orders': 'إنشاء الطلبات المجمعة (',
      'please_select': 'الرجاء اختيار ',
      'vehicle_type': 'نوع المركبة',
      'motorcycle': 'دراجة نارية',
      'car': 'سيارة',
      'truck': 'شاحنة',
      'order_price_label': 'سعر الطلب: ',
      'please_select_pickup': 'الرجاء اختيار موقع الاستلام',
      'please_add_delivery': 'الرجاء إضافة عنوان توصيل واحد على الأقل',
      'merchant_data_error': 'حدث خطأ في التحقق من بيانات التاجر. يرجى تسجيل الدخول مرة أخرى.',
      'no_drivers_available': 'لا يوجد سائقون متاحون',
      'continue_at_own_risk': 'متابعة على مسؤوليتك',
      'confirm_bulk_orders': 'تأكيد الطلبات المجمعة',
      'confirm_bulk_orders_question': 'هل أنت متأكد من إنشاء {count} طلب توصيل؟',
      'scheduled_bulk_orders_message': 'سيتم جدولة الطلبات لبعد {minutes} دقيقة.',
      'publish_orders_immediately': 'سيتم نشر جميع الطلبات فورًا وإتاحتها للسائقين.',
      'bulk_orders_scheduled_success': 'تم جدولة {count} طلب لبعد {minutes} دقيقة',
      'bulk_orders_created_success': 'تم إنشاء {count} طلب بنجاح',
      'bulk_orders_failed': 'فشل نشر الطلبات: {error}',
      'add_delivery_address': 'إضافة عنوان توصيل',
      'customer_name': 'اسم العميل',
      'phone_number': 'رقم الهاتف',
      'delivery_location': 'موقع التوصيل',
      'order_amount': 'المبلغ',
      'notes_optional': 'ملاحظات (اختياري)',
      'add': 'إضافة',
      'failed': 'فشل',
      // Location Picker
      'move_map_select_location': 'حرك الخريطة لاختيار الموقع',
      'getting_address': 'جاري تحديد العنوان...',
      'location_selected': 'موقع محدد',
      'cannot_get_current_location': 'لا يمكن الحصول على الموقع الحالي',
      'move_map_to_select': 'حرك الخريطة لتحديد الموقع',
      'my_location': 'موقعي',
      'confirm_location': 'تأكيد الموقع',
      // Voice Library
      'voice_library': 'مكتبة التسجيلات الصوتية',
      'error_loading_recordings': 'حدث خطأ في تحميل التسجيلات',
      'no_voice_recordings': 'لا توجد تسجيلات صوتية',
      'record_first_order': 'سجل طلبك الأول باستخدام الصوت',
      'record_new_order': 'تسجيل طلب جديد',
      'delete_recording': 'حذف التسجيل',
      'confirm_delete_recording': 'هل أنت متأكد من حذف هذا التسجيل؟',
      'delete': 'حذف',
      'recording_deleted_success': 'تم حذف التسجيل بنجاح',
      // Top Up Dialog
      'please_select_payment_method': 'يرجى اختيار طريقة الدفع',
      'please_enter_valid_amount': 'يرجى إدخال مبلغ صحيح',
      'minimum_amount_is': 'الحد الأدنى للمبلغ هو ',
      'amount_must_be_greater': 'المبلغ يجب أن يكون أكبر من ',
      'plus_fee': ' + ',
      'fee': ' رسوم',
      'must_login_first': 'يجب تسجيل الدخول أولاً',
      'top_up_via_wayl': 'شحن المحفظة عبر Wayl',
      'payment_success': 'تم الدفع بنجاح! سيتم تحديث رصيد المحفظة قريباً',
      'payment_cancelled': 'تم إلغاء عملية الدفع',
      'error_loading_payment': 'حدث خطأ أثناء تحميل صفحة الدفع',
      'failed_create_payment_link': 'فشل إنشاء رابط الدفع: ',
      'top_up_via_rep': 'طلب شحن عبر ممثل حر',
      'top_up_request_sent': 'تم إرسال طلب شحن محفظتك بمبلغ ',
      'note_fee_deducted': 'ملاحظة: سيتم خصم ',
      'as_service_fee': ' IQD كرسوم خدمة',
      'rep_will_contact_soon': 'سيتصل بك ممثل حر قريباً لإكمال العملية.',
      'ok': 'حسناً',
      'top_up_wallet': 'شحن المحفظة',
      'amount_iqd': 'المبلغ (IQD)',
      'please_enter_amount': 'يرجى إدخال المبلغ',
      'please_enter_valid_number': 'يرجى إدخال رقم صحيح',
      'minimum_amount': 'الحد الأدنى ',
      'select_payment_method': 'اختر طريقة الدفع',
      'online_checkout': 'دفع إلكتروني - Online Checkout',
      'zain_cash_qi_visa_mastercard': 'Zain Cash, Qi Card, Visa, Mastercard - فوري',
      'hur_rep': 'ممثل حر',
      'fee_label': 'رسوم ',
      'continue': 'متابعة',
      // Announcement Dialog
      'got_it': 'فهمت',
      'skip': 'تخطي',
      'next': 'التالي',
      'start_now': 'ابدأ الآن',
      'update_required': 'تحديث مطلوب',
      'must_update_app': 'يجب تحديث التطبيق للاستمرار في الاستخدام',
      'current_version': 'الإصدار الحالي:',
      'required_version': 'الإصدار المطلوب:',
      'update_app': 'تحديث التطبيق',
      'maintenance_title': 'النظام في وضع الصيانة',
      'maintenance_message_driver': 'النظام حالياً تحت الصيانة. لا يمكنك الاتصال بالإنترنت أو قبول الطلبات في الوقت الحالي. سنعود قريباً!',
      'maintenance_message_merchant': 'النظام حالياً تحت الصيانة. لا يمكنك إنشاء طلبات جديدة في الوقت الحالي. سنعود قريباً!',
      'maintenance_message_default': 'النظام حالياً تحت الصيانة. بعض الميزات غير متاحة مؤقتاً. سنعود قريباً!',
      'maintenance_info': 'يمكنك تصفح التطبيق، لكن لا يمكن إنشاء أو قبول الطلبات حالياً',
      'maintenance_banner': 'وضع الصيانة - بعض الميزات غير متاحة',
      'understood': 'فهمت',
      // Driver Welcome
      'driver_welcome_title1': 'مرحباً بك في حُر',
      'driver_welcome_desc1': 'انضم إلى منصة حُر للتوصيل وابدأ رحلتك في تحقيق الدخل',
      'driver_welcome_title2': 'الحرية بلا تكلفة',
      'driver_welcome_desc2': 'نحن لا نأخذ عمولة منك. حريتك في العمل والكسب هي حقك الكامل',
      'driver_welcome_title3': 'ساعدنا في مكافحة الاحتيال',
      'driver_welcome_desc3': 'نعتمد على تعاونك في الإبلاغ عن أي نشاط مشبوه من التجار يضر بمنصة حُر',
      // Merchant Welcome
      'merchant_welcome_title1': 'كيف يعمل النظام؟',
      'merchant_welcome_desc1': 'حُر ستوفر لك سائق مستقل لاستلام طلباتك وتوصيلها للعملاء بكل سهولة',
      'merchant_welcome_title2': 'السلامة أولاً',
      'merchant_welcome_desc2': 'للحفاظ على أمانك، يُنصح بأخذ هويات السائقين أو ضمانات عند التسليم',
      'merchant_welcome_title3': 'هل لديك أسئلة؟',
      'merchant_welcome_desc3': 'تواصل مع فريق الدعم في أي وقت لأي استفسار عن النظام أو الرسوم',
      // Merchant Walkthrough
      'merchant_walkthrough_title1': 'العثور على سائق',
      'merchant_walkthrough_desc1': 'يجد التطبيق لك سائق توصيل مستقل قريب منك لاستلام طلبك',
      'merchant_walkthrough_title2': 'دفع رسوم الطلب',
      'merchant_walkthrough_desc2': 'يصل السائق ويدفع رسوم الطلب لك. تأكد من أن السائق يدفع قبل تسليم الطلب',
      'merchant_walkthrough_title3': 'التوصيل والربح',
      'merchant_walkthrough_desc3': 'يقوم السائق بتوصيل الطلب، ويحصل على رسوم الطلب بالإضافة إلى رسوم التوصيل',
      // Driver Walkthrough
      'driver_walkthrough_title1': 'طلبات قريبة',
      'driver_walkthrough_desc1': 'التطبيق يجيبلك طلبات قريبة عليك',
      'driver_walkthrough_title2': 'قبول الطلب ودفع من جيبك',
      'driver_walkthrough_desc2': 'لما تقبل الطلب، تروح للتاجر وانت تدفع رسوم الطلب من جيبك. تأكد تدفع قبل ما تستلم الطلب',
      'driver_walkthrough_title3': 'التوصيل والكسب',
      'driver_walkthrough_desc3': 'بعد التوصيل، تسترجع مبلغ الطلب من الزبون مع رسوم التوصيل. ولو رفض الطلب في التطبيق مع انك واصلته في الوقت المحدد، التطبيق أو التاجر يغطي تكلفة الطلب',
      'i_agree_to_the': 'أوافق على ',
      'complete': 'إكمال',
      'ends_in_days': 'ينتهي خلال ',
      'days': ' يوم',
      'ends_in_hours': 'ينتهي خلال ',
      'hours': ' ساعة',
      'ends_in_minutes': 'ينتهي خلال ',
      'minutes': ' دقيقة',
      'ends_in_seconds': 'ينتهي خلال ',
      'seconds': ' ثانية',
      'january': 'يناير',
      'february': 'فبراير',
      'march': 'مارس',
      'april': 'أبريل',
      'may': 'مايو',
      'june': 'يونيو',
      'july': 'يوليو',
      'august': 'أغسطس',
      'september': 'سبتمبر',
      'october': 'أكتوبر',
      'november': 'نوفمبر',
      'december': 'ديسمبر',
      // Splash Screen (loading already exists, using it)
      'fast_delivery_service': 'خدمة التوصيل السريع',
      // Password Reset
      'reset_password': 'إعادة تعيين كلمة المرور',
      'enter_code_new_password': 'أدخل الرمز وكلمة المرور الجديدة',
      'verification_code': 'رمز التحقق',
      'enter_6_digit_code': 'أدخل رمزاً من 6 أرقام',
      'new_password': 'كلمة المرور الجديدة',
      'password_updated_success': 'تم تحديث كلمة المرور بنجاح',
      'password_update_failed': 'تعذر تحديث كلمة المرور',
      'update_password': 'تحديث كلمة المرور',
      // Create Password
      'create_password': 'إنشاء كلمة المرور',
      'choose_strong_password': 'اختر كلمة مرور قوية',
      'letters_numbers_only_8_min': 'الأحرف والأرقام فقط، 8 أحرف على الأقل',
      'create_account': 'إنشاء الحساب',
      'account_creation_failed': 'تعذر إنشاء الحساب',
      // Verification Pending
      'verification_pending': 'قيد المراجعة',
      'verification_rejected': 'تم الرفض',
      'verification_under_review': 'جاري مراجعة بياناتك',
      'verification_review_message': 'سيتم مراجعة بياناتك والتحقق منها. سيتم إشعارك عند اكتمال المراجعة.',
      'verification_rejected_message': 'تم رفض طلب التحقق. يرجى مراجعة البيانات المرفوعة وإعادة المحاولة.',
      'resubmit_verification': 'إعادة إرسال',
      'logout': 'تسجيل الخروج',
      'error_selecting_image': 'خطأ في اختيار الصورة: ',
      'please_upload_id_front_back': 'يرجى رفع صور الهوية الأمامية والخلفية',
      'please_upload_selfie_with_id': 'يرجى رفع صورة سيلفي مع الهوية',
      'id_verification_failed': 'فشل التحقق من بطاقة الهوية',
      'connection_failed': 'فشل الاتصال بخدمة التحقق: ',
      'error': 'خطأ: ',
      'you_are_blocked': 'تم حظرك',
      'account_blocked_message': 'تم حظر حسابك. يرجى التواصل مع مالك التطبيق للمساعدة.',
      'contact_app_owner': 'التواصل مع مالك التطبيق',
      'please_reupload_ids': 'يرجى إعادة رفع صور الهوية للتحقق',
      'reupload_ids_message': 'حالة التحقق الخاصة بك قيد الانتظار. يرجى إعادة رفع صور الهوية لتحديث معلوماتك.',
      // User Registration
      'select_image_source': 'اختر طريقة رفع الصورة',
      'take_photo': 'التقاط صورة',
      'choose_from_gallery': 'اختيار من المعرض',
      'select_store_location': 'اختر موقع المتجر',
      'location_selected': 'موقع محدد',
      'please_upload_document': 'يرجى رفع صورة الوثيقة',
      'please_upload_document_back': 'يرجى رفع الجانب الخلفي من الوثيقة',
      'please_upload_selfie': 'يرجى رفع صورة سيلفي مع الهوية',
      'please_select_store_location': 'يرجى تحديد موقع المتجر',
      'id_verification_failed_reason': 'فشل التحقق من بطاقة الهوية',
      // Map Screen
      'map': 'الخريطة',
      'mapbox_integration_progress': 'Mapbox integration in progress...',
      'select_this_location': 'اختيار هذا الموقع',
      'tap_map_select_location': 'اضغط على الخريطة لتحديد الموقع',
      'my_current_location': 'موقعي الحالي',
      'confirm_location': 'تأكيد الموقع',
      'your_current_location': 'موقعك الحالي',
      'selected_location': 'الموقع المحدد',
      'verifying': 'جاري التحقق...',
      'please_upload_clear_id_images': 'يرجى رفع صور واضحة لبطاقة الهوية الأصلية',
      'what_happens_now': 'ما يحدث الآن؟',
      'verification_process_steps': '• التحقق من المستندات بواسطة الذكاء الاصطناعي\n• التحقق من صحة البيانات\n• إرسال إشعار بالموافقة تلقائياً',
      'refresh_status': 'تحديث الحالة',
      'upload_new_documents': 'رفع مستندات جديدة',
      'please_upload_clear_id': 'يرجى رفع صور واضحة لبطاقة الهوية الأصلية. تأكد من:',
      'id_upload_requirements': '• الصورة واضحة وغير مهتزة\n• البطاقة حقيقية (وليست صورة من شاشة)\n• جميع البيانات ظاهرة ومقروءة',
      'registration_sent_successfully': 'تم إرسال طلب التسجيل بنجاح',
      'review_by_ai_system': 'سيتم مراجعة بياناتك من قبل نظام التحقق الآلي',
      'documents_not_accepted': 'لم يتم قبول المستندات المرفوعة',
      'id_card_front': 'بطاقة الهوية - الجهة الأمامية',
      'id_card_back': 'بطاقة الهوية - الجهة الخلفية',
      'selfie_with_id': 'صورة سيلفي مع الهوية',
      'upload': 'رفع',
      'uploaded': 'تم الرفع',
      'error_selecting_image': 'خطأ في اختيار الصورة: ',
      'registration_error': 'حدث خطأ في التسجيل',
      'registering_as': 'التسجيل كـ ',
      'complete_data': 'إكمال بيانات ',
      'please_fill_all_required': 'يرجى تعبئة جميع البيانات المطلوبة',
      'how_did_you_hear': 'كيف سمعت عنا؟',
      'required_documents': 'المستندات المطلوبة',
      'registering': 'جاري التسجيل...',
      'complete_registration': 'إتمام التسجيل',
      'name_extracted_automatically': 'سيتم استخراج اسمك الكامل من بطاقة الهوية تلقائياً',
      'store_information': 'معلومات المتجر',
      'store_name': 'اسم المتجر',
      'enter_store_name': 'أدخل اسم متجرك',
      'store_name_required': 'اسم المتجر مطلوب',
      'store_address': 'عنوان المتجر',
      'select_store_location_map': 'حدد موقع متجرك على الخريطة',
      'city': 'المدينة',
      'select_city': 'اختر المدينة',
      'city_required': 'المدينة مطلوبة',
      'najaf': 'النجف',
      'mosul': 'الموصل',
      'full_name_extracted_automatically': 'سيتم استخراج اسمك الكامل من بطاقة الهوية تلقائياً',
      'vehicle_information': 'معلومات المركبة',
      'vehicle_type': 'نوع المركبة',
      'default': 'افتراضي',
      'do_you_have_license': 'هل لديك رخصة قيادة؟',
      'do_you_own_vehicle': 'هل تمتلك المركبة؟',
      'profile_photo_optional': 'الصورة الشخصية (اختياري)',
      'add_clear_profile_photo': 'أضف صورة شخصية واضحة لسهولة تمييزك من قبل العملاء.',
      // Order Creation Carousel
      'normal_order': 'طلب عادي',
      'bulk_orders_title': 'طلبات مجمعة',
      'scheduled_orders_title': 'طلبات مجدولة',
      'voice_order_title': 'طلب صوتي',
      'no_account_registered_this_number': 'لا يوجد حساب مسجل بهذا الرقم. يرجى التسجيل أولاً.',
      'register': 'التسجيل',
      'user_data_error_contact_support': 'خطأ في بيانات المستخدم. يرجى التواصل مع الدعم الفني.',
      'account_already_registered': 'يوجد حساب مسجل مسبقاً',
      'no_account_registered': 'لا يوجد حساب مسجل',
      'merchant_description': 'أضف منتجاتك وادير طلباتك بسهولة',
      'driver_description': 'احصل على طلبات التوصيل واربح المال',
      // Scheduled Order Additional
      'schedule_recurring_order': 'جدولة طلب متكرر',
      'schedule_order': 'جدولة طلب',
      'please_select': 'الرجاء اختيار ',
      'vehicle_type_label': 'نوع المركبة',
      'any_vehicle': 'أي مركبة',
      'daily_label': 'يومي',
      'weekly_label': 'أسبوعي',
      'monthly_label': 'شهري',
      'please_select_pickup_location': 'الرجاء اختيار موقع الاستلام',
      'please_select_delivery_location': 'الرجاء اختيار موقع التوصيل',
      'merchant_data_error_login_again': 'حدث خطأ في التحقق من بيانات التاجر. يرجى تسجيل الدخول مرة أخرى.',
      'alert': 'تنبيه',
      // Order Details
      'am_short': 'ص',
      'pm_short': 'م',
      'no_images_uploaded_order': 'لا توجد صور مرفوعة لهذا الطلب بعد',
      // Voice Order
      'voice_order_note': 'طلب صوتي - ',
      'can_continue_scheduled_order': 'يمكنك المتابعة في إنشاء الطلب المجدول، وسيتم نشره تلقائياً في الوقت المحدد إذا توفر سائقون.',
      'order_scheduled_success': 'تم جدولة الطلب بنجاح',
      // Driver Earnings
      'completed_orders_label': 'الطلبات المكتملة',
      'delivered_status': 'تم التسليم',
      'cancelled_status': 'ملغية',
      'rejected_status': 'مرفوضة',
      'active_status': 'نشطة',
      'order_hash': 'طلب #',
      'delivery_fees_label': 'رسوم التوصيل',
      'status_pending': 'في الانتظار',
      'status_assigned': 'تم التخصيص',
      // Driver Orders
      'order_accepted_success': 'تم قبول الطلب بنجاح',
      'error_occurred': 'حدث خطأ: ',
      'order_rejected_success': 'تم رفض الطلب',
      'order_completed_success': 'تم إكمال الطلب بنجاح',
      // Wallet Widgets
      'my_balance': 'رصيدي',
      'balance_needs_top_up': 'رصيدك بحاجة إلى شحن',
      'current_balance': 'رصيدك الحالي',
      'cannot_create_orders_until_top_up': 'لا يمكنك إنشاء طلبات جديدة حتى تقوم بشحن محفظتك',
      'zain_cash_ki': 'زين كاش / كي',
      'hur_rep': 'ممثل حر',
      // Payment WebView
      'error_loading_payment_page': 'خطأ في تحميل صفحة الدفع: ',
      // Voice Recording Card
      'failed_to_load_recording': 'فشل تحميل التسجيل',
      'error_playing_recording': 'خطأ في تشغيل التسجيل: ',
      // Customer Location Sharing
      'please_allow_location_access': 'يرجى السماح بالوصول إلى الموقع لمشاركة موقعك',
      'failed_to_send_location': 'فشل في إرسال الموقع. يرجى المحاولة مرة أخرى.',
      'error_getting_location': 'خطأ في الحصول على الموقع: ',
      'location_sent_successfully': 'تم إرسال الموقع بنجاح',
      'location_received_auto_update': 'تم استلام موقعك وسيتم تحديث عنوان التسليم تلقائياً.',
      'location_ready_no_call_needed': '🎉 الموقع جاهز - لا حاجة للاتصال',
      // Location Update Widget
      'error_checking_location_updates': 'خطأ في التحقق من تحديثات الموقع: ',
      // Dashboard
      'maintenance_mode': 'وضع الصيانة',
      'connected': 'متصل',
      'not_available': 'غير متاح',
      'not_logged_in': 'غير مسجل',
      'must_login_first': 'يجب تسجيل الدخول أولاً',
      'accepted': 'تم القبول',
      'order_accepted_success_message': 'تم قبول الطلب بنجاح',
      'error_accepting_order': 'حدث خطأ في قبول الطلب',
      'error_in_operation': 'حدث خطأ في العملية',
      'error_rejecting_order': 'حدث خطأ في رفض الطلب',
      'rejected': 'تم الرفض',
      'order_rejected_success_message': 'تم رفض الطلب',
      'motorbike_label': 'دراجة نارية',
      // Map Widget
      'your_current_location_label': 'موقعك الحالي',
      'store_location': 'موقع المتجر',
      'delivery_location': 'موقع التوصيل',
      'show_route': 'عرض المسار',
      'store': 'المتجر',
      'delivery': 'التوصيل',
      'your_location': 'موقعك',
      // ID Verification Review
      'error_saving_data': 'خطأ في حفظ البيانات: ',
      'review_id_data': 'مراجعة بيانات الهوية',
      'extracted_info_message': 'تم استخراج المعلومات التالية من بطاقة هويتك. يرجى التحقق من صحتها وتعديل أي أخطاء.',
      'full_name_section': 'الاسم الكامل',
      'first_name': 'الاسم الأول',
      'enter_name': 'أدخل الاسم',
      'name_required': 'الاسم مطلوب',
      'father_name': 'اسم الأب',
      'enter_father_name': 'أدخل اسم الأب',
      'father_name_required': 'اسم الأب مطلوب',
      'grandfather_name': 'اسم الجد',
      'enter_grandfather_name': 'أدخل اسم الجد',
      'grandfather_name_required': 'اسم الجد مطلوب',
      'family_name': 'اللقب',
      'enter_family_name': 'أدخل اللقب',
      'family_name_required': 'اللقب مطلوب',
      'card_information': 'معلومات البطاقة',
      'national_id_number': 'رقم الهوية الوطنية',
      'id_number_hint': 'رقم الهوية',
      'id_number_required': 'رقم الهوية مطلوب',
      // Splash Screen
      'loading': 'جاري التحميل...',
      'fast_delivery_service': 'خدمة التوصيل السريع',
      // User Registration Additional
      'remove_image': 'إزالة الصورة',
      'location_selected_checkmark': 'تم تحديد الموقع ✓',
      'how_did_you_hear_hur': 'كيف سمعت عن حر؟',
      'optional': 'اختياري',
      'document_type': 'نوع الوثيقة',
      'select_document_type': 'اختر نوع الوثيقة',
      'not_specified': 'غير محدد',
      'merchant_label': 'تاجر',
      'expiry_date': 'تاريخ انتهاء الصلاحية',
      'birth_date': 'تاريخ الميلاد',
      'delete_recording': 'حذف التسجيل',
      'confirm_delete_recording': 'هل أنت متأكد من حذف هذا التسجيل؟',
      'delete': 'حذف',
      'arabic_char': 'ع',
      'recent_activity': 'النشاط الأخير',
      'total_sales': 'إجمالي المبيعات',
      'merchants_label': 'التجار',
      'drivers_label': 'السائقين',
      'customers_label': 'العملاء',
      'analytics_title': 'الإحصائيات',
      'all_filter': 'الكل',
      'today_filter': 'اليوم',
      'week_filter': 'الأسبوع',
      'month_filter': 'الشهر',
      'total_orders_stat': 'إجمالي الطلبات',
      'completed_orders_stat': 'الطلبات المكتملة',
      'cancelled_orders_stat': 'الطلبات الملغاة',
      'rejected_orders_stat': 'الطلبات المرفوضة',
      'wallet_balance': 'رصيد المحفظة',
      'wallet_top_up': 'شحن المحفظة',

      // Support / Messaging
      'support_chat': 'الدعم الفني',
      'messages': 'الرسائل',

      // Settings
      'settings': 'الإعدادات',
      'profile': 'الملف الشخصي',
      'language': 'اللغة',
      'language_arabic': 'العربية',
      'language_english': 'الإنجليزية',
      'dark_mode': 'الوضع الليلي',
      'dark_mode_enabled': 'الوضع الليلي مفعّل',
      'light_mode_enabled': 'الوضع النهاري مفعّل',
      'appearance': 'المظهر',

      // System status / maintenance
      'system_maintenance_title': 'النظام قيد الصيانة',
      'system_maintenance_message':
          'التطبيق غير متاح حالياً بسبب أعمال الصيانة. يرجى المحاولة لاحقاً.',
      
      // Orders Tabs
      'active_orders': 'الطلبات النشطة',
      'past_orders': 'الطلبات المكتملة',
      'completed_orders': 'الطلبات المكتملة',
      
      // Order Status (already present, but added for clarity)
      'pending_status': 'في الانتظار',
      'assigned_status': 'تم التخصيص',
      'accepted_status': 'مقبولة',
      'on_the_way_status': 'في الطريق',
      'delivered_status': 'تم التسليم',
      'cancelled_status': 'ملغية',
      'rejected_status': 'مرفوضة',
      'scheduled_status': 'مجدول',
      'unknown_status': 'غير معروف',
      
      // Stats
      'delivered_label': 'تم التسليم',
      'cancelled_rejected_label': 'ملغية/مرفوضة',
      
      // Dialog Actions
      'agree': 'موافق',
      'cancel_and_close': 'إلغاء وإغلاق',
      
      // Driver Messages
      'driver_whatsapp_message': 'مرحباً {name}، أنا سائق التوصيل من تطبيق حر',
      'location_permission_driver_long': 'للعمل كسائق، يجب منح إذن الموقع "طوال الوقت".',
      'location_permission_explanation': '• استلام إشعارات الطلبات حتى عند إغلاق التطبيق\n• تتبع موقعك أثناء التوصيل\n• الظهور في قائمة السائقين المتاحين',
      'background_location_permission_title': 'إذن الموقع في الخلفية',
      'background_location_explanation': 'عند تفعيل وضع "متصل"، سيقوم التطبيق بجمع موقعك في الخلفية وعرض إشعار دائم لإبقائك متاحًا لطلبات التوصيل.\n\nيُستخدم ذلك فقط لوظائف التطبيق الأساسية (تتبع السائق، الإشعارات، وتسليم الطلبات).',
      
      // Order Actions
      'accept_order': 'قبول الطلب',
      'reject_order': 'رفض',
      'start_delivery': 'بدء التوصيل',
      'mark_delivered': 'تم التسليم',
      'merchant_button': 'التاجر',
      'customer_button': 'العميل',
      'map_button': 'الخريطة',
      'picked_up_start_delivery': 'تم الاستلام - بدء التوصيل',
      'confirm_delivery': 'تأكيد التسليم',
      'delivery_error': 'خطأ في التسليم',
      'call_via_phone': 'اتصال عبر الهاتف',
      'call_via_whatsapp': 'اتصال عبر واتساب',
      'whatsapp_message': 'رسالة واتساب',
      'customer_label_colon': 'العميل: ',
      'merchant_label_colon': 'التاجر: ',
      'address_label': 'العنوان: ',
      'close': 'إغلاق',
      'understood': 'تم الفهم',
      'map_updated': 'تم الفهم - تم تحديث الخريطة',
      'photo_uploaded_success': 'تم رفع الصورة بنجاح',
      'error_colon': 'خطأ: ',
      'retake_photo': 'إعادة التقاط',
      
      // Merchant Order Actions
      'order_not_found': 'الطلب غير موجود. قد يكون قد تم حذفه.',
      'location_unavailable': 'تعذّر تحديث موقع السائق',
      'discard_changes_title': 'تجاهل التغييرات؟',
      'discard_changes_message': 'لديك بيانات غير محفوظة. هل تريد الخروج؟',
      'discard_button': 'تجاهل',
      'load_more_transactions': 'تحميل المزيد',
      'retry_action': 'إعادة المحاولة',
      'cancel_order_action': 'إلغاء الطلب',
      'repost_order': 'إعادة نشر (+500 د.ع)',
      'cancel_order_title': 'إلغاء الطلب',
      'cancel_order_confirm': 'هل أنت متأكد من إلغاء هذا الطلب؟',
      'go_back': 'رجوع',
      'no_drivers_available_title': 'لا يوجد سائقون متاحون',
      'repost_order_title': 'إعادة نشر الطلب',
      'repost_order_message': 'سيتم زيادة رسوم التوصيل بمقدار 500 د.ع',
      'current_fees': 'الرسوم الحالية:',
      'new_fees': 'الرسوم الجديدة:',
      'repost_action': 'إعادة نشر',
      'repost_order_new_fee': 'سيتم رفع رسوم التوصيل إلى {fee} د.ع (+500 د.ع)',
      'repost_button': 'إعادة النشر',

      // Driver Rank
      'driver_rank_title': 'رتبتي',
      'current_rank': 'رتبتك الحالية',
      'commission_label': 'عمولة',
      'active_hours_notice': 'ساعات النشاط تحتسب فقط بين الساعة 08:00 صباحاً و 12:00 منتصف الليل.',
      'wallet_balance': 'رصيد المحفظة',
      'details': 'التفاصيل',
      'rank_benefits': 'فوائد الرتب',
      'current_badge': 'الحالية',
      'trial_rank': 'تجريبي',
      'bronze_rank': 'برونزي',
      'silver_rank': 'فضي',
      'gold_rank': 'ذهبي',
      'trial_requirement': 'الشهر الأول فقط',
      'bronze_requirement': 'الرتبة الافتراضية',
      'silver_requirement': '150 ساعة شهرياً',
      'gold_requirement': '240 ساعة شهرياً',
      'trial_period_title': 'أنت في الفترة التجريبية',
      'trial_period_message':
          'في الشهر الأول من التسجيل، لا يتم خصم أي عمولة منك. بعد انتهاء الشهر الأول، سيتم تحويلك تلقائياً إلى الرتبة البرونزية.',
      'top_rank_title': 'أنت في أعلى رتبة!',
      'progress_to_rank': 'التقدم للرتبة {rank}',
      'hours_value': '{hours} ساعة',
      'hours_required': '{hours} ساعة مطلوبة',
      'progress_completed': '{percent}% مكتمل',
      'ranks_apply_monthly': 'الرتب الجديدة تُطبق كل شهر',
      
      // Sidebar Missing Keys
      'driver_orders': 'طلباتي',
      'driver_earnings': 'أرباحي',
      'help_support': 'المساعدة والدعم',
      
      // Merchant Dashboard Missing Keys
      'no_past_orders': 'لا توجد طلبات سابقة',
      'no_current_orders': 'لا توجد طلبات حالية',
      
      // Merchant Analytics
      'stats_title': 'الإحصائيات',
      'revenue_stats_title': 'إحصائيات الإيرادات',
      'total_orders_title': 'إجمالي الطلبات',
      'delivery_fees': 'رسوم التوصيل',
      'avg_order_value': 'متوسط قيمة الطلب',
      'performance_metrics': 'مقاييس الأداء',
      'avg_delivery_time': 'متوسط وقت التوصيل',
      'completion_rate': 'معدل الإكمال',
      'cancellation_rate': 'معدل الإلغاء',
      'active_orders_label': 'طلبات نشطة',
      
      // Driver Dashboard Missing Keys
      'not_available_short': 'غير متوفر',
      'merchant_info_unavailable': 'معلومات التاجر غير متوفرة في النظام',
      'cannot_make_call': 'لا يمكن إجراء المكالمة',
      'cannot_open_whatsapp': 'لا يمكن فتح واتساب',
      'invalid_coordinates': 'إحداثيات غير صالحة',
      'cannot_open_google_maps': 'لا يمكن فتح خرائط جوجل',
      'failed_open_google_maps': 'فشل فتح خرائط جوجل',
      'cannot_open_waze': 'لا يمكن فتح تطبيق ويز',
      'failed_open_waze': 'فشل فتح تطبيق ويز',
      'waiting_location_permission': 'في انتظار إذن الموقع...',
      'determining_location': 'جاري تحديد الموقع...',
      'current_location_status': 'موقعك الحالي',
      'last_known_location': 'آخر موقع معروف',
      'uploading_progress': 'جاري الرفع...',
      'confirm_and_finish': 'تأكيد وإنهاء',
      'your_location_button': 'موقعك',
      'accept_order_button': 'قبول الطلب',
      'time_remaining_label': 'الوقت المتبقي: ',

      // Delivery Timer - Late popup & info
      'delivery_late_title': 'الطلب متأخر',
      'delivery_late_message':
          'هذا الطلب أصبح متأخراً.\n\nإذا تم رفضه، فلن يتم تعويضك عن أجرة الطلب وأجرة التوصيل من التاجر أو من التطبيق.',
      'delivery_late_ack': 'فهمت',
      'delivery_timer_info_title': 'عن مؤقت التوصيل',
      'delivery_timer_info_message':
          'هذا المؤقت يوضح الحد الأقصى للوقت المخصص لتوصيل هذا الطلب. هذا الوقت يحتوي على هامش أمان إضافي، لذلك هو أكثر من كافٍ للتوصيل في الظروف الطبيعية.\n\nإذا تجاوزت هذا الوقت وتم رفض الطلب من قبل الزبون، قد تكون مسؤولاً عن أجرة الطلب وأجرة التوصيل وقد لا يتم تعويضك عنهما من التاجر أو من التطبيق.',
      'late_duration_label': 'متأخر: ',
      'delivery_duration_title': 'مدة التوصيل',
      'delivery_duration_not_available': 'غير متوفر',
      'delivery_duration_on_time': 'ضمن الوقت',
      'delivery_duration_late': 'متأخر',

      // Global Error Manager
      'err_network_title': 'لا يوجد إنترنت',
      'err_network_body': 'تحقق من اتصالك بالإنترنت ثم أعد المحاولة.',
      'err_timeout_title': 'انتهت المهلة',
      'err_timeout_body': 'الاتصال بطيء جداً. يرجى المحاولة مرة أخرى.',
      'err_server_conn_title': 'فشل الاتصال',
      'err_server_conn_body': 'فشل الاتصال بالخادم، يتم إعادة المحاولة تلقائياً.',
      'err_auth_expired_title': 'انتهت الجلسة',
      'err_auth_expired_body': 'يُرجى تسجيل الدخول مرة أخرى للمتابعة.',
      'err_auth_invalid_title': 'بيانات غير صحيحة',
      'err_auth_invalid_body': 'تحقق من بيانات الدخول وأعد المحاولة.',
      'err_server_title': 'خطأ في الخادم',
      'err_server_body': 'حدث خطأ في الخادم. يرجى المحاولة لاحقاً.',
      'err_rate_limit_title': 'طلبات كثيرة',
      'err_rate_limit_body': 'انتظر لحظة ثم أعد المحاولة.',
      'err_not_found_title': 'غير موجود',
      'err_not_found_body': 'المحتوى المطلوب غير موجود.',
      'err_permission_title': 'غير مصرح',
      'err_permission_body': 'ليس لديك صلاحية للوصول إلى هذا المحتوى.',
      'err_unknown_title': 'خطأ',
      'err_unknown_body': 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.',
      'err_retry': 'إعادة المحاولة',
      'err_dismiss': 'إغلاق',
    },
    'en': {
      'app_title': 'Hur Delivery',
      'ok': 'OK',
      'cancel': 'Cancel',
      'back': 'Back',
      'retry': 'Retry',
      'loading': 'Loading...',
      'error_generic': 'An unexpected error occurred',
      'no_internet_title': 'No Internet Connection',
      'login': 'Login',
      'logout': 'Logout',
      'phone_number': 'Phone Number',
      'enter_phone_number': 'Enter your phone number',
      'enter_iraqi_phone_login': 'Enter your Iraqi phone number to login',
      'enter_iraqi_phone_otp': 'Enter your Iraqi phone number to receive OTP via WhatsApp',
      'send_code': 'Send Code',
      'verify_code': 'Verify Code',
      'resend_code': 'Resend Code',
      'continue': 'Continue',
      'driver': 'Driver',
      'merchant': 'Merchant',
      'customer': 'Customer',
      'user': 'User',
      'select_role': 'Select Account Type',
      'welcome_to_hur': 'Welcome to Hur Delivery',
      'fast_delivery_service': 'Fast Delivery Service',
      'platform_for_drivers_merchants': 'Delivery Platform for Drivers and Merchants',
      'have_account': 'Have an account?',
      'no_account': 'No account?',
      'create_account': 'Create Account',
      'try_app': 'Try App',
      'demo_mode_title': 'Try App',
      'demo_mode_info': 'In demo mode, you can explore the app but cannot create orders or go online',
      'demo_merchant': 'Demo Merchant',
      'demo_merchant_desc': 'Explore merchant dashboard',
      'demo_driver': 'Demo Driver',
      'demo_driver_desc': 'Explore driver dashboard',
      'change_phone': 'Change Phone Number',
      'enter_otp': 'Enter OTP',
      'otp_sent_to': 'OTP sent to',
      'test_number_hint': '🧪 Test Number: Use 000000',
      'sent_via_whatsapp': 'Sent via WhatsApp',
      'confirm_otp': 'Confirm OTP',
      'resend_otp': 'Resend OTP',
      'resend_in_seconds': 'Resend in {seconds} seconds',
      'otp_failed_identity': 'Identity verification failed',
      'otp_invalid': 'Invalid OTP',
      'otp_resent_via': 'OTP resent via {method}',
      'otp_send_error': 'Error sending OTP',
      'no_account_title': 'No Account',
      'error_selecting_image': 'Error selecting image: ',
      'phone_required': 'Phone number required',
      'phone_must_be_10_digits': 'Phone number must be 10 digits',
      'dashboard_driver_title': 'Driver Dashboard',
      'dashboard_merchant_title': 'Merchant Dashboard',
      'dashboard_admin_title': 'Admin Dashboard',
      'home': 'Home',
      'wallet': 'Wallet',
      'support': 'Support',
      'voice': 'Voice',
      'stats': 'Stats',
      'overview': 'Overview',
      'users': 'Users',
      'orders': 'Orders',
      'analytics': 'Analytics',
      'driver_online': 'Online',
      'driver_offline': 'Offline',
      'unregistered': 'Unregistered',
      'must_login_first': 'Must login first',
      'accepted': 'Accepted',
      'accept_success': 'Order accepted successfully',
      'rejected': 'Rejected',
      'reject_success': 'Order rejected',
      'error': 'Error',
      'operation_error': 'Operation error',
      'accept_error': 'Error accepting order',
      'reject_error': 'Error rejecting order',
      'order_number': 'Order #',
      'delivery_fee': 'Delivery Fee',
      'order_value': 'Order Value',
      'distance_label': 'Distance',
      'now': 'Now',
      'merchant_label': 'Merchant',
      'customer_label': 'Customer',
      'location_label': 'Location',
      'confirm': 'Confirm',
      'confirm_go_offline_title': 'Confirm Go Offline',
      'confirm_go_offline_message': 'Are you sure you want to stop receiving orders? Your location tracking and order notifications will be stopped.',
      'order_ready_now': 'Order Ready Now',
      'status_pending': 'Pending',
      'status_assigned': 'Assigned',
      'status_accepted': 'Accepted',
      'status_on_the_way': 'On the Way',
      'status_delivered': 'Delivered',
      'status_cancelled': 'Cancelled',
      'status_unassigned': 'Unassigned',
      'status_rejected': 'Rejected',
      'status_scheduled': 'Scheduled',
      'status_unknown': 'Unknown',
      'in_progress_title': 'In Progress',
      'in_progress_message': 'Delivery started',
      'delivery_confirm_title': 'Confirm Delivery',
      'delivery_error_title': 'Delivery Error',
      'delivery_error_unknown': 'Unknown Error',
      'delivery_success_title': 'Delivered',
      'delivery_success_message': 'Order delivered successfully',
      'warning_title': 'Warning',
      'merchant_info_missing': 'Merchant info missing',
      'call_merchant_title': 'Call Merchant',
      'call_customer_title': 'Call Customer',
      'call_title': 'Call',
      'privacy_policy': 'Privacy Policy',
      'terms_and_conditions': 'Terms & Conditions',
      'no_orders_yet': 'No orders yet',
      'error_label': 'Error: ',
      'not_available': 'Not available',
      'call_error_message': 'Cannot make call',
      'whatsapp_call': 'WhatsApp Call',
      'whatsapp_message': 'WhatsApp Message',
      'whatsapp_open_error': 'Cannot open WhatsApp',
      'invalid_coordinates': 'Invalid coordinates',
      'maps_open_error': 'Cannot open Google Maps',
      'maps_launch_failed': 'Failed to launch Google Maps',
      'waze_open_error': 'Cannot open Waze',
      'waze_launch_failed': 'Failed to launch Waze',
      'location_permission_required_title': 'Location Permission Required',
      'open_settings': 'Open Settings',
      'orders_active': 'Active Orders',
      'orders_completed': 'Completed Orders',
      'no_active_orders': 'No active orders',
      'no_completed_orders': 'No completed orders',
      'order_details': 'Order Details',
      'create_order': 'Create Order',
      'create_new_order': 'Create New Order',
      'scheduled_order': 'Scheduled Order',
      'bulk_order': 'Bulk Order',
      'voice_order': 'Voice Order',
      'order_number_prefix': 'Order #',
      'party_info': 'Party Info',
      'customer_phone': 'Customer Phone',
      'driver_phone': 'Driver Phone',
      'searching_driver': 'Searching for driver...',
      'created_at': 'Created At',
      'assigned_at': 'Assigned At',
      'rejected_at': 'Rejected At',
      'delivery_locations': 'Delivery Locations',
      'from': 'From',
      'to': 'To',
      'delivery_proof': 'Delivery Proof',
      'order_items': 'Order Items',
      'financial_summary': 'Financial Summary',
      'order_price_no_delivery': 'Order Price (excl. delivery)',
      'grand_total': 'Grand Total',
      'total_amount': 'Total Amount',
      'notes': 'Notes',
      'cancel_order': 'Cancel Order',
      'cancel_order_confirm': 'Are you sure you want to cancel this order?',
      'order_cancelled': 'Order Cancelled',
      'order_cancel_failed': 'Failed to cancel order',
      'all_drivers_rejected': 'All available drivers rejected this order',
      'repost_order': 'Repost Order (+500 IQD)',
      'reject_order': 'Reject Order',
      'accept_order': 'Accept Order',
      'picked_up': 'Picked Up',
      'on_the_way': 'On the Way',
      'delivered': 'Delivered',
      'track_driver': 'Track Driver',
      'contact_support': 'Contact Support',
      'insufficient_balance_repost': 'Insufficient balance to repost order. Please top up.',
      'merchant_data_error': 'Merchant data error. Please try again.',
      'no_drivers_available': 'No drivers available',
      'repost_order_title': 'Repost Order',
      'repost_order_message': 'Order will be reposted with increased delivery fee:',
      'current_delivery_fee': 'Current Delivery Fee:',
      'new_delivery_fee': 'New Delivery Fee:',
      'repost_order_hint': 'Order will be assigned to drivers again.',
      'repost_success': 'Order reposted successfully.',
      'repost_error': 'Error reposting order',
      'driver_assigned_soon': 'Driver will be assigned soon',
      'order_accepted': 'Order Accepted',
      'reject_order_confirm': 'Are you sure you want to reject this order?',
      'order_rejected': 'Order Rejected',
      'pickup_confirmed': 'Pickup Confirmed',
      'delivery_started': 'Delivery Started',
      'delivery_confirmed': 'Delivery Confirmed',
      'support_message_template': 'Hi, I need help with Order #',
      'whatsapp_open_failed': 'Cannot open WhatsApp',
      'whatsapp_error': 'Error opening WhatsApp',
      'am': 'AM',
      'pm': 'PM',
      'status_created': 'Created',
      'no_delivery_proof': 'No delivery proof yet',
      'currency_symbol': 'IQD',
      'insufficient_balance_create': 'Please top up to create new order',
      'form_filled_from_voice': '✅ Form filled from voice',
      'store_location': 'Store Location',
      'location_selected': 'Location Selected',
      'pick_location_pickup': 'Pick Pickup Location',
      'pick_location_delivery': 'Pick Delivery Location',
      'location_success': 'Success',
      'location_success_message': 'Location selected successfully',
      'location_not_found': 'Location not found in Najaf',
      'location_error': 'Error selecting location',
      'checking_drivers': 'Checking available drivers...',
      'no_drivers_online': 'No drivers online',
      'cannot_create_order': 'Cannot create order right now. Please try again later.',
      'all_drivers_busy': 'All drivers are busy',
      'drivers_online': 'Driver online and available',
      'drivers_available_now': 'Drivers available now',
      'refresh': 'Refresh',
      'free_driver_available': 'Drivers are available.',
      'same_merchant_driver_available': 'Order will be assigned to a driver serving you.',
      'no_driver_available': 'No drivers available.',
      'fallback_no_online_drivers': 'No drivers online. Try again later.',
      'fallback_exception': 'Cannot check driver availability.',
      'unknown_availability': 'Unknown driver availability.',
      'customer_info': 'Customer Info',
      'customer_name_optional': 'Customer Name (Optional)',
      'enter_customer_name': 'Enter customer name',
      'locations': 'Locations',
      'pickup_location': 'Pickup Location',
      'pickup_location_hint': 'Enter address or pick from map',
      'advanced_settings': 'Advanced Settings',
      'delivery_location': 'Delivery Location',
      'delivery_location_hint': 'Enter address or pick from map',
      'prices': 'Prices',
      'delivery_fee_required': 'Delivery fee required',
      'low_delivery_fee_warning': 'The fee is too low. It may be difficult to get a driver with this amount. Recommended fee',
      'enter_valid_number': 'Enter valid number',
      'amount_required': 'Amount required',
      'vehicle_type': 'Vehicle Type',
      'select_vehicle_type': 'Select Vehicle Type',
      'any_vehicle': 'Any Vehicle',
      'default': 'Default',
      'any_vehicle_hint': 'Assign nearest driver with any vehicle',
      'motorbike': 'Motorbike',
      'car': 'Car',
      'truck': 'Truck',
      'motorbike_hint': 'Order sent to motorbikes',
      'car_hint': 'Order sent to cars',
      'truck_hint': 'Order sent to trucks',
      'order_driver_for_day': 'Order Driver for Full Day',
      'bulk_order_description': 'Book a driver for a full day to deliver orders in specified neighborhoods',
      'order_date': 'Order Date',
      'delivery_neighborhoods': 'Delivery Neighborhoods',
      'minimum_three': 'Minimum 3',
      'add_neighborhood': 'Add Neighborhood',
      'select_neighborhood': 'Select Neighborhood',
      'minimum_three_neighborhoods': 'Must select at least 3 neighborhoods',
      'per_delivery_fee': 'Per Delivery Fee',
      'bulk_order_fee': 'Driver Booking Fee',
      'bulk_order_fee_description': 'Fixed fee for booking a driver for a full day',
      'create_bulk_order': 'Create Driver Order',
      'bulk_order_created_success': 'Driver order created successfully',
      'bulk_order_accepted_success': 'Driver order accepted successfully',
      'bulk_order_active': 'Driver order accepted - ready for deliveries',
      'notes_optional': 'Notes (Optional)',
      'additional_notes': 'Additional Notes',
      'add_notes_hint': 'Add notes here...',
      'when_ready': 'When will it be ready?',
      'ready_now': 'Ready Now',
      'ready_after_minutes': 'Ready after {minutes} minutes',
      'minutes': 'minutes',
      'sixty_minutes': '60 minutes',
      'grand_total_label': 'Grand Total',
      'creating_order': 'Creating...',
      'order_created': 'Order Created',
      'order_created_success': 'Order created successfully',
      'order_created_ready_after': 'Ready after {minutes} minutes',
      'order_create_error': 'Error creating order',
      'customer_phone_label': 'Customer Phone',
      'phone_invalid_format': 'Enter valid Iraqi number starting with 7 (10 digits)',
      'open_map': 'Open Map',
      'search_address': 'Search Address',
      'view_details': 'View Details',
      'order_display_error': 'Order display error',
      'ago_minutes': '{minutes} min ago',
      'ago_hours': '{hours} hr ago',
      'ago_days': '{days} days ago',
      'days_short': 'd',
      'hours_short': 'h',
      'status_waiting': 'Waiting',
      'customer_name_fallback': 'Customer',
      'phone_not_available': 'N/A',
      'pickup_address_fallback': 'Pickup Address',
      'delivery_address_fallback': 'Delivery Address',
      'grand_total_with_delivery': 'Grand Total (Order + Delivery)',
      'assigned_status': 'Assigned',
      'required': 'Required',
      'microphone_permission_required': 'Microphone permission required',
      'recording': 'Recording...',
      'processing_audio': 'Processing Audio...',
      'click_to_start': 'Click to Start',
      'extracting_data': 'Extracting data...',
      'speak_order_details': 'Speak order details clearly',
      'how_to_use': 'How to Use',
      'say_customer_name': 'Say Customer Name',
      'say_phone': 'Say Phone',
      'say_pickup': 'Say Pickup',
      'say_delivery': 'Say Delivery',
      'say_amount': 'Say Amount',
      'voice_library': 'Voice Library',
      'stop_recording': 'Stop Recording',
      'processing': 'Processing...',
      'start_voice_recording': 'Start Voice Recording',
      'extracted_data': 'Extracted Data',
      'customer_name_label': 'Customer Name',
      'phone_label': 'Phone',
      'pickup_label': 'Pickup',
      'delivery_label': 'Delivery',
      'amount_label': 'Amount',
      'confirm_create_order': 'Confirm & Create',
      'transcription': 'Transcription',
      'extraction_accuracy': 'Accuracy: ',
      'missing_fields': 'Missing fields: ',
      'no_drivers_available_now': 'No drivers available now.',
      'error_starting_recording': 'Error starting recording: ',
      'error_stopping_recording': 'Error stopping recording: ',
      'recording_loaded_success': 'Recording loaded',
      'recording_load_failed': 'Failed to load recording: ',
      'audio_processing_failed': 'Audio processing failed: ',
      'incomplete_data': 'Incomplete data. Please ensure Name, Phone, and Addresses.',
      'alert': 'Alert',
      'low_confidence': 'Low confidence ({percent}%). Please verify data.',
      'continue_action': 'Continue',
      'customer_phone_required': 'Customer phone required',
      'customer_phone_required_for_pickup': 'Customer phone number is required before confirming pickup',
      'customer_phone_optional': 'Customer Phone (Optional)',
      'assign_to_same_driver': 'Assign to Same Driver',
      'current_driver': 'Current Driver',
      'contact_driver': 'Contact Driver',
      'call_via_whatsapp': 'WhatsApp',
      'driver_info_not_available': 'Driver information not available',
      'driver_phone_not_available': 'Phone number not available',
      'hello_driver': 'Hello',
      'close': 'Close',
      'multiple_orders': 'Multiple Orders',
      'multiple_orders_description': 'Create multiple orders for delivery to different neighborhoods',
      'create_multiple_orders': 'Create Multiple Orders',
      'pickup_address_required': 'Pickup address required',
      'delivery_address_required': 'Delivery address required',
      'order_created_success_voice': '✅ Order created successfully',
      'order_create_error_voice': 'Error creating order: ',
      'my_wallet': 'My Wallet',
      'please_top_up': 'Please Top Up',
      'balance_low': 'Low Balance',
      'balance_good': 'Good Balance',
      'current_balance': 'Current Balance',
      'credit_limit': 'Credit Limit: ',
      'top_up_wallet': 'Top Up Wallet',
      'fee_exempt_banner': 'You are exempt from fees',
      'fee_exempt_message': 'Since you registered less than a month ago, no fees will be deducted from your wallet',
      'fee_exempt_until': 'Exemption until',
      'total_orders': 'Total Orders',
      'total_fees': 'Total Fees',
      'no_transactions': 'No transactions',
      'recent_transactions': 'Recent Transactions',
      'balance': 'Balance: ',
      'notifications_enabled': 'Notifications Enabled',
      'notifications_denied': 'Notifications Denied',
      'notification_settings': 'Notification Settings',
      'notification_settings_hint': 'Change notification settings in system settings.',
      'notifications': 'Notifications',
      'general': 'General',
      'instant_notifications': 'Instant Notifications',
      'receive_notifications': 'Receive order notifications',
      'notifications_disabled': 'Notifications disabled',
      'sound': 'Sound',
      'sound_subtitle': 'Play sound for notifications',
      'vibration': 'Vibration',
      'vibration_subtitle': 'Vibrate for notifications',
      'app': 'App',
      'about_app': 'About App',
      'app_description': 'Advanced delivery app',
      'app_description_driver': 'Advanced delivery app for drivers',
      'version': 'Version ',
      'location': 'Location',
      'location_permission': 'Location Permission',
      'location_permission_subtitle': '\'Always\' permission required for orders',
      'check': 'Check',
      'location_permission_required_driver': 'Always location permission required for driver mode.',
      'receive_order_notifications': 'Receive new order notifications',
      'edit_profile': 'Edit Profile',
      'profile_updated_success': 'Profile updated successfully',
      'error_occurred': 'Error occurred: ',
      'feature_coming_soon': 'Feature coming soon',
      'name': 'Name',
      'name_required': 'Name required',
      'store_name': 'Store Name',
      'store_name_required': 'Store Name Required',
      'phone_number_label': 'Phone Number',
      'address': 'Address',
      'save_changes': 'Save Changes',
      'profile': 'Profile',
      'profile_saved_success': 'Profile saved successfully',
      'error_saving_profile': 'Error saving profile',
      'no_user_data': 'No user data',
      'account_info': 'Account Info',
      'name_required_field': 'Name is required',
      'phone_cannot_change': 'Cannot change phone number',
      'account_status': 'Account Status',
      'verification_status': 'Verification Status',
      'verified': 'Verified',
      'not_verified': 'Not Verified',
      'status': 'Status',
      'registration_date': 'Registration Date',
      'enter_label': 'Enter ',
      'pick_store_location': 'Pick Store Location',
      'pick_on_map': 'Pick on Map',
      'store_location_placeholder': 'Tap the map icon to set exact location',
      'address_required': 'Address is required',
      'location_saved_on_map': 'Location saved on map',
      // Messaging
      'failed_open_support': 'Failed to open support chat.',
      'open_messages_list': 'Open Messages',
      'failed_select_image': 'Failed to select image.',
      'failed_send_message': 'Failed to send message.',
      'conversation': 'Conversation',
      'order': 'Order: ',
      'reply': 'Reply',
      'type_message': 'Type a message...',
      'messages': 'Messages',
      'no_conversations': 'No conversations yet',
      'technical_support': 'Technical Support',
      'conversation_label': 'Conversation',
      'support_order': 'Support ',
      'error_loading_privacy': 'Error loading Privacy Policy',
      'error_loading_terms': 'Error loading Terms',
      'login_with_password': 'Login with Password',
      'welcome_back': 'Welcome Back',
      'enter_phone_password': 'Enter phone and password',
      'invalid_phone': 'Invalid Phone',
      'password': 'Password',
      'password_required': 'Password required',
      'invalid_credentials': 'Invalid credentials',
      'forgot_password': 'Forgot Password?',
      'my_orders': 'My Orders',
      'all': 'All',
      'pending': 'Pending',
      'completed': 'Completed',
      'cancelled': 'Cancelled',
      'no_pending_orders': 'No pending orders',
      'no_accepted_orders': 'No accepted orders',
      'no_cancelled_orders': 'No completed orders',
      'no_orders': 'No orders',
      'order_price': 'Order Price',
      'order_time': 'Order Time: ',
      'reject': 'Reject',
      'complete_order': 'Complete Order',
      'in_transit': 'In Transit',
      'unknown': 'Unknown',
      'earnings': 'Earnings',
      'driver_id_not_found': 'Driver ID not found',
      'classify_orders_by_status': 'Orders by status',
      'recent_orders': 'Recent Orders',
      'no_orders_in_period': 'No orders in this period',
      'error_loading_stats': 'Error loading stats',
      'today': 'Today',
      'week': 'Week',
      'month': 'Month',
      'active_orders': 'Active Orders',
      'acceptance_rate': 'Acceptance Rate',
      'cancelled_rejected': 'Cancelled/Rejected',
      'hour': 'hour',
      'minute': 'minute',
      'average_delivery_time': 'Avg Delivery Time',
      'from_acceptance_to_delivery': 'From acceptance to delivery',
      'based_on_completed': 'Based on ',
      'completed_orders': ' completed orders',
      'earnings_summary': 'Earnings Summary',
      'total_earnings': 'Total Earnings',
      'average_earnings_per_order': 'Avg earning per order',
      'notification_deleted': 'Notification deleted',
      'all_marked_read': 'All marked read',
      'no_order_linked': 'No order linked',
      'unread': ' unread',
      'mark_all_read': 'Mark all as read',
      'no_notifications': 'No notifications',
      'schedule_order_later': 'Schedule Order Later',
      'date_time': 'Date & Time',
      'date': 'Date',
      'time': 'Time',
      'recurring_order': 'Recurring Order',
      'will_repeat_automatically': 'Will repeat automatically',
      'one_time_order': 'One-time Order',
      'recurrence_pattern': 'Recurrence Pattern',
      'daily': 'Daily',
      'weekly': 'Weekly',
      'monthly': 'Monthly',
      'recurrence_end_date': 'End Date (Optional)',
      'no_end': 'No End',
      'customer_name': 'Customer Name',
      'total_amount_iqd': 'Total Amount (IQD)',
      'delivery_fee_iqd': 'Delivery Fee (IQD)',
      'scheduling_summary': 'Scheduling Summary',
      'will_be_published_at': 'Published at: ',
      'recurrence': 'Recurrence: ',
      'until': 'Until: ',
      'bulk_orders': 'Bulk Orders',
      'multiple_orders_same_pickup': 'Multiple orders, same pickup',
      'shared_details': 'Shared Details',
      'general_notes_optional': 'General Notes',
      'when_need_drivers': 'When do you need drivers?',
      'now_immediately': 'Immediately',
      'after_minutes': 'After ',
      'scheduled_orders': 'Scheduled Orders',
      'delivery_addresses': 'Delivery Addresses (',
      'add_address': 'Add Address',
      'no_delivery_addresses': 'No delivery addresses added',
      'create_bulk_orders': 'Create Bulk Orders (',
      'please_select': 'Please Select ',
      'motorcycle': 'Motorcycle',
      'order_price_label': 'Order Price: ',
      'please_select_pickup': 'Please select pickup location',
      'please_add_delivery': 'Please add at least one delivery',
      'continue_at_own_risk': 'Continue at own risk',
      'confirm_bulk_orders': 'Confirm Bulk Orders',
      'confirm_bulk_orders_question': 'Create {count} orders?',
      'scheduled_bulk_orders_message': 'Orders scheduled after {minutes} min',
      'publish_orders_immediately': 'Publish immediately',
      'bulk_orders_scheduled_success': '{count} orders scheduled',
      'bulk_orders_created_success': '{count} orders created',
      'bulk_orders_failed': 'Failed: {error}',
      'add_delivery_address': 'Add Delivery Address',
      'order_amount': 'Amount',
      'add': 'Add',
      'failed': 'Failed',
      'move_map_select_location': 'Move map to select location',
      'getting_address': 'Getting address...',
      'cannot_get_current_location': 'Cannot get current location',
      'move_map_to_select': 'Move map to select',
      'my_location': 'My Location',
      'confirm_location': 'Confirm Location',
      'error_loading_recordings': 'Error loading recordings',
      'no_voice_recordings': 'No voice recordings',
      'record_first_order': 'Record your first order',
      'record_new_order': 'Record New Order',
      'delete_recording': 'Delete Recording',
      'confirm_delete_recording': 'Delete this recording?',
      'delete': 'Delete',
      'recording_deleted_success': 'Recording deleted',
      'please_select_payment_method': 'Select Payment Method',
      'please_enter_valid_amount': 'Enter valid amount',
      'minimum_amount_is': 'Minimum amount is ',
      'amount_must_be_greater': 'Amount must be greater than ',
      'plus_fee': ' + ',
      'fee': ' fee',
      'top_up_via_wayl': 'Top Up via Wayl',
      'payment_success': 'Payment Successful',
      'payment_cancelled': 'Payment Cancelled',
      'error_loading_payment': 'Error loading payment',
      'failed_create_payment_link': 'Failed to create payment link: ',
      'top_up_via_rep': 'Top Up via Representative',
      'top_up_request_sent': 'Top up request sent for ',
      'note_fee_deducted': 'Note: Fee deducted ',
      'as_service_fee': ' IQD',
      'rep_will_contact_soon': 'Representative will contact you soon.',
      'amount_iqd': 'Amount (IQD)',
      'please_enter_amount': 'Please enter amount',
      'please_enter_valid_number': 'Enter valid number',
      'minimum_amount': 'Minimum ',
      'select_payment_method': 'Select Payment Method',
      'online_checkout': 'Online Checkout',
      'zain_cash_qi_visa_mastercard': 'Zain Cash, Qi Card, Visa, Mastercard',
      'hur_rep': 'Hur Representative',
      'fee_label': 'Fee ',
      'got_it': 'Got it',
      'skip': 'Skip',
      'next': 'Next',
      'start_now': 'Start Now',
      'update_required': 'Update Required',
      'must_update_app': 'Must update app to continue',
      'current_version': 'Current Version:',
      'required_version': 'Required Version:',
      'update_app': 'Update App',
      'maintenance_title': 'Maintenance Mode',
      'maintenance_message_driver': 'System under maintenance.',
      'maintenance_message_merchant': 'System under maintenance.',
      'maintenance_message_default': 'System under maintenance.',
      'maintenance_info': 'Browsing only, no orders.',
      'maintenance_banner': 'Maintenance Mode',
      'understood': 'Understood',
      'driver_welcome_title1': 'Welcome to Hur',
      'driver_welcome_desc1': 'Join Hur Delivery',
      'driver_welcome_title2': 'Freedom',
      'driver_welcome_desc2': 'No commissions from you.',
      'driver_welcome_title3': 'Help us',
      'driver_welcome_desc3': 'Report suspicious activity.',
      'merchant_welcome_title1': 'How it works?',
      'merchant_welcome_desc1': 'Hur provides independent drivers.',
      // Merchant Walkthrough
      'merchant_walkthrough_title1': 'Find a Driver',
      'merchant_walkthrough_desc1': 'The app finds you a freelance delivery driver that\'s close to you',
      'merchant_walkthrough_title2': 'Driver Pays Order Fee',
      'merchant_walkthrough_desc2': 'The driver arrives and will pay the order fee for you. Make sure drivers pay for orders before you hand them out',
      'merchant_walkthrough_title3': 'Delivery & Earnings',
      'merchant_walkthrough_desc3': 'Drivers would then deliver the order, obtain the fee, and in addition gain the delivery fee',
      // Driver Walkthrough
      'driver_walkthrough_title1': 'Find Orders',
      'driver_walkthrough_desc1': 'The app finds you delivery orders that are close to your location',
      'driver_walkthrough_title2': 'Accept & Pay Yourself',
      'driver_walkthrough_desc2': 'When you accept an order, you will go to the merchant and you must pay the order fee yourself using your own money. Make sure to pay before receiving the order',
      'driver_walkthrough_title3': 'Deliver & Earn',
      'driver_walkthrough_desc3': 'After delivery, you will collect the order amount back from the customer plus the delivery fee. If the order is later rejected in the app even though you delivered it on time, the app or the merchant will cover the order cost',
      'i_agree_to_the': 'I agree to the ',
      'complete': 'Complete',
      'merchant_welcome_title2': 'Safety First',
      'merchant_welcome_desc2': 'Check driver ID.',
      'merchant_welcome_title3': 'Questions?',
      'merchant_welcome_desc3': 'Contact support.',
      'ends_in_days': 'Ends in ',
      'days': ' days',
      'ends_in_hours': 'Ends in ',
      'hours': ' hours',
      'ends_in_minutes': 'Ends in ',
      'ends_in_seconds': 'Ends in ',
      'seconds': ' seconds',
      'january': 'January',
      'february': 'February',
      'march': 'March',
      'april': 'April',
      'may': 'May',
      'june': 'June',
      'july': 'July',
      'august': 'August',
      'september': 'September',
      'october': 'October',
      'november': 'November',
      'december': 'December',
      'reset_password': 'Reset Password',
      'enter_code_new_password': 'Enter code and new password',
      'verification_code': 'Verification Code',
      'enter_6_digit_code': 'Enter 6-digit code',
      'new_password': 'New Password',
      'password_updated_success': 'Password updated',
      'password_update_failed': 'Failed to update password',
      'update_password': 'Update Password',
      'create_password': 'Create Password',
      'choose_strong_password': 'Choose strong password',
      'letters_numbers_only_8_min': 'Letters and numbers, min 8 chars',
      'account_creation_failed': 'Account creation failed',
      'verification_pending': 'Verification Pending',
      'verification_rejected': 'Rejected',
      'verification_under_review': 'Under Review',
      'verification_review_message': 'Your data is being reviewed.',
      'verification_rejected_message': 'Verification rejected. Please check data.',
      'resubmit_verification': 'Resubmit',
      'please_upload_id_front_back': 'Upload ID Front & Back',
      'please_upload_selfie_with_id': 'Upload Selfie with ID',
      'id_verification_failed': 'ID Verification Failed',
      'connection_failed': 'Connection Failed: ',
      'you_are_blocked': 'You Are Blocked',
      'account_blocked_message': 'Your account has been blocked. Please contact the app owner for assistance.',
      'contact_app_owner': 'Contact App Owner',
      'please_reupload_ids': 'Please Re-upload Your IDs',
      'reupload_ids_message': 'Your verification status is pending. Please re-upload your ID images to update your information.',
      'select_image_source': 'Select Image Source',
      'take_photo': 'Take Photo',
      'choose_from_gallery': 'Choose from Gallery',
      'select_store_location': 'Select Store Location',
      'please_upload_document': 'Upload Document',
      'please_upload_document_back': 'Upload Document Back',
      'please_upload_selfie': 'Upload Selfie',
      'please_select_store_location': 'Select Store Location',
      'id_verification_failed_reason': 'ID Verification Failed',
      'map': 'Map',
      'mapbox_integration_progress': 'Mapbox integration...',
      'select_this_location': 'Select this location',
      'tap_map_select_location': 'Tap map to select',
      'my_current_location': 'My Location',
      'your_current_location': 'Your Location',
      'selected_location': 'Selected Location',
      'verifying': 'Verifying...',
      'please_upload_clear_id_images': 'Upload clear ID images',
      'what_happens_now': 'What happens now?',
      'verification_process_steps': 'AI verification...',
      'refresh_status': 'Refresh Status',
      'upload_new_documents': 'Upload New Documents',
      'please_upload_clear_id': 'Upload clear ID',
      'id_upload_requirements': 'Clear, valid, readable',
      'registration_sent_successfully': 'Registration sent',
      'review_by_ai_system': 'Review by AI',
      'documents_not_accepted': 'Documents not accepted',
      'id_card_front': 'ID Card Front',
      'id_card_back': 'ID Card Back',
      'selfie_with_id': 'Selfie with ID',
      'upload': 'Upload',
      'uploaded': 'Uploaded',
      'registration_error': 'Registration Error',
      'registering_as': 'Registering as ',
      'complete_data': 'Complete Data',
      'please_fill_all_required': 'Fill all required',
      'how_did_you_hear': 'How did you hear about us?',
      'required_documents': 'Required Documents',
      'registering': 'Registering...',
      'complete_registration': 'Complete Registration',
      'name_extracted_automatically': 'Name extracted automatically',
      'store_information': 'Store Info',
      'enter_store_name': 'Enter Store Name',
      'store_address': 'Store Address',
      'select_store_location_map': 'Select Store Location',
      'city': 'City',
      'select_city': 'Select City',
      'city_required': 'City Required',
      'najaf': 'Najaf',
      'mosul': 'Mosul',
      'full_name_extracted_automatically': 'Full Name extracted automatically',
      'vehicle_information': 'Vehicle Info',
      'do_you_have_license': 'Do you have license?',
      'do_you_own_vehicle': 'Do you own vehicle?',
      'profile_photo_optional': 'Profile Photo (Optional)',
      'add_clear_profile_photo': 'Add profile photo',
      'normal_order': 'Normal Order',
      'bulk_orders_title': 'Bulk Orders',
      'scheduled_orders_title': 'Scheduled Orders',
      'voice_order_title': 'Voice Order',
      'no_account_registered_this_number': 'No account registered',
      'register': 'Register',
      'user_data_error_contact_support': 'User data error',
      'account_already_registered': 'Account already registered',
      'no_account_registered': 'No account registered',
      'merchant_description': 'Manage orders easily',
      'driver_description': 'Deliver and earn',
      'schedule_recurring_order': 'Schedule Recurring',
      'schedule_order': 'Schedule Order',
      'vehicle_type_label': 'Vehicle Type',
      'daily_label': 'Daily',
      'weekly_label': 'Weekly',
      'monthly_label': 'Monthly',
      'please_select_pickup_location': 'Select Pickup Location',
      'please_select_delivery_location': 'Select Delivery Location',
      'merchant_data_error_login_again': 'Merchant data error. Login again.',
      'am_short': 'AM',
      'pm_short': 'PM',
      'no_images_uploaded_order': 'No images uploaded',
      'voice_order_note': 'Voice Order - ',
      'can_continue_scheduled_order': 'Continue scheduled order',
      'order_scheduled_success': 'Order Scheduled',
      'completed_orders_label': 'Completed Orders',
      'delivered_status': 'Delivered',
      'cancelled_status': 'Cancelled',
      'rejected_status': 'Rejected',
      'active_status': 'Active',
      'order_hash': 'Order #',
      'delivery_fees_label': 'Delivery Fees',
      'order_accepted_success': 'Order Accepted',
      'order_rejected_success': 'Order Rejected',
      'order_completed_success': 'Order Completed',
      'my_balance': 'My Balance',
      'balance_needs_top_up': 'Balance needs top up',
      'cannot_create_orders_until_top_up': 'Cannot create orders until top up',
      'zain_cash_ki': 'Zain Cash / Qi',
      'error_loading_payment_page': 'Error loading payment page',
      'failed_to_load_recording': 'Failed to load recording',
      'error_playing_recording': 'Error playing recording',
      'please_allow_location_access': 'Allow location access',
      'failed_to_send_location': 'Failed to send location',
      'error_getting_location': 'Error getting location',
      'location_sent_successfully': 'Location sent',
      'location_received_auto_update': 'Location received',
      'location_ready_no_call_needed': 'Location Ready',
      'error_checking_location_updates': 'Error checking location',
      'maintenance_mode': 'Maintenance Mode',
      'connected': 'Connected',
      'not_logged_in': 'Not Logged In',
      'order_accepted_success_message': 'Order Accepted',
      'error_accepting_order': 'Error Accepting',
      'error_in_operation': 'Error in Operation',
      'error_rejecting_order': 'Error Rejecting',
      'order_rejected_success_message': 'Order Rejected',
      'motorbike_label': 'Motorbike',
      'your_current_location_label': 'Your Current Location',
      'show_route': 'Show Route',
      'store': 'Store',
      'delivery': 'Delivery',
      'your_location': 'Your Location',
      'error_saving_data': 'Error saving data',
      'review_id_data': 'Review ID Data',
      'extracted_info_message': 'Extracted info',
      'full_name_section': 'Full Name',
      'first_name': 'First Name',
      'enter_name': 'Enter Name',
      'father_name': 'Father Name',
      'enter_father_name': 'Enter Father Name',
      'father_name_required': 'Father Name Required',
      'grandfather_name': 'Grandfather Name',
      'enter_grandfather_name': 'Enter Grandfather Name',
      'grandfather_name_required': 'Grandfather Name Required',
      'family_name': 'Family Name',
      'enter_family_name': 'Enter Family Name',
      'family_name_required': 'Family Name Required',
      'card_information': 'Card Info',
      'national_id_number': 'National ID Number',
      'id_number_hint': 'ID Number',
      'id_number_required': 'ID Number Required',
      'remove_image': 'Remove Image',
      'location_selected_checkmark': 'Location Selected',
      'how_did_you_hear_hur': 'How did you hear about Hur?',
      'optional': 'Optional',
      'document_type': 'Document Type',
      'select_document_type': 'Select Doc Info',
      'not_specified': 'Not Specified',
      'expiry_date': 'Expiry Date',
      'birth_date': 'Birth Date',
      'arabic_char': 'AR',
      'recent_activity': 'Recent Activity',
      'total_sales': 'Total Sales',
      'merchants_label': 'Merchants',
      'drivers_label': 'Drivers',
      'customers_label': 'Customers',
      'analytics_title': 'Analytics',
      'all_filter': 'All',
      'today_filter': 'Today',
      'week_filter': 'Week',
      'month_filter': 'Month',
      'total_orders_stat': 'Total Orders',
      'completed_orders_stat': 'Completed Orders',
      'cancelled_orders_stat': 'Cancelled Orders',
      'rejected_orders_stat': 'Rejected Orders',
      'wallet_balance': 'Wallet Balance',
      'wallet_top_up': 'Top Up',
      'support_chat': 'Support Chat',
      'settings': 'Settings',
      'language': 'Language',
      'language_arabic': 'Arabic',
      'language_english': 'English',
      'dark_mode': 'Dark Mode',
      'dark_mode_enabled': 'Dark Mode Enabled',
      'light_mode_enabled': 'Light Mode Enabled',
      'appearance': 'Appearance',
      'system_maintenance_title': 'System Maintenance',
      'past_orders': 'Past Orders',
      'pending_status': 'Pending',
      'accepted_status': 'Accepted',
      'on_the_way_status': 'On the Way',
      'scheduled_status': 'Scheduled',
      'unknown_status': 'Unknown',
      'delivered_label': 'Delivered',
      'cancelled_rejected_label': 'Cancelled/Rejected',
      'agree': 'Agree',
      'cancel_and_close': 'Cancel & Close',
      'driver_whatsapp_message': 'Hello {name}, I am Hur driver',
      'location_permission_driver_long': 'Always location permission required',
      'location_permission_explanation': 'For tracking and notifications',
      'background_location_permission_title': 'Background Location Permission',
      'background_location_explanation': 'When you go "Online", the app collects your location in the background and shows a persistent notification to keep you available for delivery orders.\n\nThis is used only for core app functionality (driver tracking, new order notifications, and order delivery).',
      'start_delivery': 'Start Delivery',
      'mark_delivered': 'Mark Delivered',
      'merchant_button': 'Merchant',
      'customer_button': 'Customer',
      'map_button': 'Map',
      'picked_up_start_delivery': 'Picked Up - Start Delivery',
      'confirm_delivery': 'Confirm Delivery',
      'delivery_error': 'Delivery Error',
      'call_via_phone': 'Call via Phone',
      'call_via_whatsapp': 'Call via WhatsApp',
      'customer_label_colon': 'Customer: ',
      'merchant_label_colon': 'Merchant: ',
      'address_label': 'Address: ',
      'close': 'Close',
      'map_updated': 'Map Updated',
      'photo_uploaded_success': 'Photo Uploaded',
      'error_colon': 'Error: ',
      'retake_photo': 'Retake',
      'order_not_found': 'Order not found. It may have been deleted.',
      'location_unavailable': 'Could not update driver location',
      'discard_changes_title': 'Discard changes?',
      'discard_changes_message': 'You have unsaved data. Are you sure you want to leave?',
      'discard_button': 'Discard',
      'load_more_transactions': 'Load more',
      'retry_action': 'Retry',
      'cancel_order_action': 'Cancel Order',
      'cancel_order_title': 'Cancel Order',
      'go_back': 'Go Back',
      'no_drivers_available_title': 'No Drivers Available',
      'current_fees': 'Current Fees: ',
      'new_fees': 'New Fees: ',
      'repost_action': 'Repost',
      'repost_order_new_fee': 'New Fee: {fee}',
      'repost_button': 'Repost',
      'driver_rank_title': 'My Rank',
      'current_rank': 'Your current rank',
      'commission_label': 'Commission',
      'active_hours_notice': 'Active hours count only between 08:00 AM and 12:00 AM.',
      'details': 'Details',
      'rank_benefits': 'Rank benefits',
      'current_badge': 'Current',
      'trial_rank': 'Trial',
      'bronze_rank': 'Bronze',
      'silver_rank': 'Silver',
      'gold_rank': 'Gold',
      'trial_requirement': 'First month only',
      'bronze_requirement': 'Default rank',
      'silver_requirement': '150 hours per month',
      'gold_requirement': '240 hours per month',
      'trial_period_title': 'You are in the trial period',
      'top_rank_title': 'You are at the highest rank!',
      'progress_to_rank': 'Progress to {rank}',
      'hours_value': '{hours} hours',
      'hours_required': '{hours} hours required',
      'progress_completed': '{percent}% complete',
      'ranks_apply_monthly': 'New ranks are applied monthly',

      // Sidebar Missing Keys
      'driver_orders': 'Driver Orders',
      'driver_earnings': 'Driver Earnings',
      'help_support': 'Help & Support',

      // Merchant Dashboard Missing Keys
      'no_past_orders': 'No past orders',
      'no_current_orders': 'No current orders',

      // Merchant Analytics
      'stats_title': 'Statistics',
      'revenue_stats_title': 'Revenue Statistics',
      'total_orders_title': 'Total Orders',
      'delivery_fees': 'Delivery Fees',
      'avg_order_value': 'Avg Order Value',
      'performance_metrics': 'Performance Metrics',
      'avg_delivery_time': 'Avg Delivery Time',
      'completion_rate': 'Completion Rate',
      'cancellation_rate': 'Cancellation Rate',
      'active_orders_label': 'Active Orders',

      // Driver Dashboard Missing Keys
      'not_available_short': 'N/A',
      'merchant_info_unavailable': 'Merchant info unavailable',
      'cannot_make_call': 'Cannot make call',
      'cannot_open_whatsapp': 'Cannot open WhatsApp',
      'invalid_coordinates': 'Invalid coordinates',
      'cannot_open_google_maps': 'Cannot open Google Maps',
      'failed_open_google_maps': 'Failed to open Google Maps',
      'cannot_open_waze': 'Cannot open Waze',
      'failed_open_waze': 'Failed to open Waze',
      'waiting_location_permission': 'Waiting for location permission...',
      'determining_location': 'Determining location...',
      'current_location_status': 'Your current location',
      'last_known_location': 'Last known location',
      'uploading_progress': 'Uploading...',
      'confirm_and_finish': 'Confirm & Finish',
      'your_location_button': 'Your Location',
      'accept_order_button': 'Accept Order',
      'time_remaining_label': 'Time remaining: ',

      // Delivery Timer - Late popup & info
      'delivery_late_title': 'Order is late',
      'delivery_late_message':
          'This order is now late.\n\nIf it is rejected, you will not be compensated for the order fee and delivery fee by the merchant or the app.',
      'delivery_late_ack': 'I understand',
      'delivery_timer_info_title': 'About the delivery timer',
      'delivery_timer_info_message':
          'This timer shows the maximum time allocated to deliver this order. The time already includes a safety buffer, so it is more than enough for normal delivery.\n\nIf you go over this time and the order is rejected by the customer, you may be responsible for the order fee and delivery fee, and you will not be compensated for either by the merchant or the app.',
      'late_duration_label': 'Late: ',
      'delivery_duration_title': 'Delivery duration',
      'delivery_duration_not_available': 'Not available',
      'delivery_duration_on_time': 'On time',
      'delivery_duration_late': 'Late',

      // Global Error Manager
      'err_network_title': 'No Internet',
      'err_network_body': 'Check your connection and try again.',
      'err_timeout_title': 'Connection Timed Out',
      'err_timeout_body': 'The network is too slow. Please try again.',
      'err_server_conn_title': 'Connection Failed',
      'err_server_conn_body': 'Could not reach the server. Retrying automatically.',
      'err_auth_expired_title': 'Session Expired',
      'err_auth_expired_body': 'Please sign in again to continue.',
      'err_auth_invalid_title': 'Invalid Credentials',
      'err_auth_invalid_body': 'Check your login details and try again.',
      'err_server_title': 'Server Error',
      'err_server_body': 'Something went wrong on our end. Try again later.',
      'err_rate_limit_title': 'Too Many Requests',
      'err_rate_limit_body': 'Wait a moment, then try again.',
      'err_not_found_title': 'Not Found',
      'err_not_found_body': 'The requested content could not be found.',
      'err_permission_title': 'Access Denied',
      'err_permission_body': 'You do not have permission to access this.',
      'err_unknown_title': 'Error',
      'err_unknown_body': 'Something unexpected went wrong. Please try again.',
      'err_retry': 'Retry',
      'err_dismiss': 'Dismiss',
    },
  };

  String _get(String key) {
    final lang = locale.languageCode;
    final values = _localizedValues[lang] ?? _localizedValues['en']!;
    return values[key] ?? _localizedValues['en']![key] ?? key;
  }

  // Public getters (add more as you migrate strings)
  String get appTitle => _get('app_title');
  String get ok => _get('ok');
  String get cancel => _get('cancel');
  String get back => _get('back');
  String get retry => _get('retry');
  String get loading => _get('loading');
  String get errorGeneric => _get('error_generic');

  // Global Error Manager
  String get errNetworkTitle => _get('err_network_title');
  String get errNetworkBody => _get('err_network_body');
  String get errTimeoutTitle => _get('err_timeout_title');
  String get errTimeoutBody => _get('err_timeout_body');
  String get errServerConnTitle => _get('err_server_conn_title');
  String get errServerConnBody => _get('err_server_conn_body');
  String get errAuthExpiredTitle => _get('err_auth_expired_title');
  String get errAuthExpiredBody => _get('err_auth_expired_body');
  String get errAuthInvalidTitle => _get('err_auth_invalid_title');
  String get errAuthInvalidBody => _get('err_auth_invalid_body');
  String get errServerTitle => _get('err_server_title');
  String get errServerBody => _get('err_server_body');
  String get errRateLimitTitle => _get('err_rate_limit_title');
  String get errRateLimitBody => _get('err_rate_limit_body');
  String get errNotFoundTitle => _get('err_not_found_title');
  String get errNotFoundBody => _get('err_not_found_body');
  String get errPermissionTitle => _get('err_permission_title');
  String get errPermissionBody => _get('err_permission_body');
  String get errUnknownTitle => _get('err_unknown_title');
  String get errUnknownBody => _get('err_unknown_body');
  String get errRetry => _get('err_retry');
  String get errDismiss => _get('err_dismiss');

  String get noInternetTitle => _get('no_internet_title');
  String get noInternetMessage => _get('no_internet_message');

  String get login => _get('login');
  String get logout => _get('logout');
  String get phoneNumber => _get('phone_number');
  String get enterPhoneNumber => _get('enter_phone_number');
  String get sendCode => _get('send_code');
  String get verifyCode => _get('verify_code');
  String get resendCode => _get('resend_code');
  String get continueText => _get('continue');
  String get driver => _get('driver');
  String get merchant => _get('merchant');
  String get selectRole => _get('select_role');
  String get user => _get('user');
  String get welcomeToHur => _get('welcome_to_hur');
  String get platformForDriversMerchants => _get('platform_for_drivers_merchants');
  String get haveAccount => _get('have_account');
  String get noAccount => _get('no_account');
  String get enterIraqiPhoneLogin => _get('enter_iraqi_phone_login');
  String get enterIraqiPhoneOtp => _get('enter_iraqi_phone_otp');
  String get phoneMustBe10Digits => _get('phone_must_be_10_digits');
  String get phoneMustStartWithPattern => _get('phone_must_start_with_pattern');
  String get otpFailedIdentity => _get('otp_failed_identity');
  String get confirmGoOfflineTitle => _get('confirm_go_offline_title');
  String get confirmGoOfflineMessage => _get('confirm_go_offline_message');
  String get error => _get('error');
  String get overview => _get('overview');
  String get users => _get('users');
  String get orders => _get('orders');
  String get enterOtp => _get('enter_otp');
  String get otpSentTo => _get('otp_sent_to');
  String get testNumberHint => _get('test_number_hint');
  String get sentViaWhatsapp => _get('sent_via_whatsapp');
  String get confirmOtp => _get('confirm_otp');
  String get resendOtp => _get('resend_otp');
  String resendInSeconds(int seconds) => _get('resend_in_seconds').replaceAll('{seconds}', seconds.toString());
  String get changePhone => _get('change_phone');
  String get otpInvalid => _get('otp_invalid');
  String otpResentVia(String method) => _get('otp_resent_via').replaceAll('{method}', method);
  String get otpSendError => _get('otp_send_error');
  String get phoneRequired => _get('phone_required');
  String get userDataError => _get('user_data_error');
  String get privacyPolicy => _get('privacy_policy');
  String get termsAndConditions => _get('terms_and_conditions');
  String get analytics => _get('analytics');
  String get completedOrders => _get('completed_orders');
  String get noOrdersYet => _get('no_orders_yet');
  String get callTitle => _get('call_title');
  String get online => _get('driver_online');
  String get offline => _get('driver_offline');
  String get orderNumber => _get('order_number');
  String get deliveryFee => _get('delivery_fee');
  String get now => _get('now');
  String get minutes => _get('minutes');
  String get statusUnassigned => _get('status_unassigned');
  String customerLabel(String name) => '${_get('customer_label')}: $name';
  String errorLabel(String error) => '${_get('error_label')}$error';

  String get dashboardDriverTitle => _get('dashboard_driver_title');
  String get dashboardMerchantTitle => _get('dashboard_merchant_title');
  String get dashboardAdminTitle => _get('dashboard_admin_title');
  String get home => _get('home');
  String get wallet => _get('wallet');
  String get support => _get('support');
  String get voice => _get('voice');
  String get stats => _get('stats');

  String get ordersActive => _get('orders_active');
  String get ordersCompleted => _get('orders_completed');
  String get noActiveOrders => _get('no_active_orders');
  String get noCompletedOrders => _get('no_completed_orders');
  String get orderDetails => _get('order_details');
  String get createOrder => _get('create_order');
  String get createNewOrder => _get('create_new_order');
  String get scheduledOrder => _get('scheduled_order');
  String get bulkOrder => _get('bulk_order');
  String get voiceOrder => _get('voice_order');
  String get orderNumberPrefix => _get('order_number_prefix');
  String get partyInfo => _get('party_info');
  String get customerPhone => _get('customer_phone');
  String get driverPhone => _get('driver_phone');
  String get searchingDriver => _get('searching_driver');
  String get createdAt => _get('created_at');
  String get assignedAt => _get('assigned_at');
  String get rejectedAt => _get('rejected_at');
  String get deliveryLocations => _get('delivery_locations');
  String get from => _get('from');
  String get to => _get('to');
  String get deliveryProof => _get('delivery_proof');
  String get orderItems => _get('order_items');
  String get financialSummary => _get('financial_summary');
  String get orderPriceNoDelivery => _get('order_price_no_delivery');
  String get grandTotal => _get('grand_total');
  String get totalAmount => _get('total_amount');
  String get notes => _get('notes');
  String get cancelOrder => _get('cancel_order');
  String get cancelOrderConfirm => _get('cancel_order_confirm');
  String get orderCancelled => _get('order_cancelled');
  String get orderCancelFailed => _get('order_cancel_failed');
  String get allDriversRejected => _get('all_drivers_rejected');
  String get repostOrder => _get('repost_order');
  String get rejectOrder => _get('reject_order');
  String get acceptOrder => _get('accept_order');
  String get pickedUp => _get('picked_up');
  String get onTheWay => _get('on_the_way');
  String get delivered => _get('delivered');
  String get trackDriver => _get('track_driver');
  String get contactSupport => _get('contact_support');
  String get insufficientBalanceRepost => _get('insufficient_balance_repost');
  String get merchantDataError => _get('merchant_data_error');
  String get noDriversAvailable => _get('no_drivers_available');
  String get repostOrderTitle => _get('repost_order_title');
  String get repostOrderMessage => _get('repost_order_message');
  String get currentDeliveryFee => _get('current_delivery_fee');
  String get newDeliveryFee => _get('new_delivery_fee');
  String get repostOrderHint => _get('repost_order_hint');
  String get repostSuccess => _get('repost_success');
  String get repostError => _get('repost_error');
  String get driverAssignedSoon => _get('driver_assigned_soon');
  String get orderAccepted => _get('order_accepted');
  String get rejectOrderConfirm => _get('reject_order_confirm');
  String get orderRejected => _get('order_rejected');
  String get pickupConfirmed => _get('pickup_confirmed');
  String get deliveryStarted => _get('delivery_started');
  String get deliveryConfirmed => _get('delivery_confirmed');
  String get supportMessageTemplate => _get('support_message_template');
  String get whatsappOpenFailed => _get('whatsapp_open_failed');
  String get whatsappError => _get('whatsapp_error');
  String get am => _get('am');
  String get pm => _get('pm');
  String get statusCreated => _get('status_created');
  String get noDeliveryProof => _get('no_delivery_proof');
  String get currencySymbol => _get('currency_symbol');
  String get insufficientBalanceCreate => _get('insufficient_balance_create');
  String get formFilledFromVoice => _get('form_filled_from_voice');
  String get storeLocation => _get('store_location');
  String get locationSelected => _get('location_selected');
  String get pickLocationPickup => _get('pick_location_pickup');
  String get pickLocationDelivery => _get('pick_location_delivery');
  String get locationSuccess => _get('location_success');
  String get locationSuccessMessage => _get('location_success_message');
  String get locationNotFound => _get('location_not_found');
  String get locationError => _get('location_error');
  String get checkingDrivers => _get('checking_drivers');
  String get noDriversOnline => _get('no_drivers_online');
  String get cannotCreateOrder => _get('cannot_create_order');
  String get allDriversBusy => _get('all_drivers_busy');
  String get driversOnline => _get('drivers_online');
  String get driversAvailableNow => _get('drivers_available_now');
  String get refresh => _get('refresh');
  String get freeDriverAvailable => _get('free_driver_available');
  String get sameMerchantDriverAvailable => _get('same_merchant_driver_available');
  String get noDriverAvailable => _get('no_driver_available');
  String get fallbackNoOnlineDrivers => _get('fallback_no_online_drivers');
  String get fallbackException => _get('fallback_exception');
  String get unknownAvailability => _get('unknown_availability');
  String get customerInfo => _get('customer_info');
  String get customerNameOptional => _get('customer_name_optional');
  String get enterCustomerName => _get('enter_customer_name');
  String get locations => _get('locations');
  String get pickupLocation => _get('pickup_location');
  String get pickupLocationHint => _get('pickup_location_hint');
  String get advancedSettings => _get('advanced_settings');
  String get deliveryLocation => _get('delivery_location');
  String get deliveryLocationHint => _get('delivery_location_hint');
  String get prices => _get('prices');
  String get deliveryFeeRequired => _get('delivery_fee_required');
  String get lowDeliveryFeeWarning => _get('low_delivery_fee_warning');
  String get enterValidNumber => _get('enter_valid_number');
  String get amountRequired => _get('amount_required');
  String get vehicleType => _get('vehicle_type');
  String get selectVehicleType => _get('select_vehicle_type');
  String get anyVehicle => _get('any_vehicle');
  String get defaultText => _get('default');
  String get anyVehicleHint => _get('any_vehicle_hint');
  String get motorbike => _get('motorbike');
  String get car => _get('car');
  String get truck => _get('truck');
  String get motorbikeHint => _get('motorbike_hint');
  String get carHint => _get('car_hint');
  String get truckHint => _get('truck_hint');
  String get orderDriverForDay => _get('order_driver_for_day');
  String get bulkOrderDescription => _get('bulk_order_description');
  String get orderDate => _get('order_date');
  String get deliveryNeighborhoods => _get('delivery_neighborhoods');
  String get minimumThree => _get('minimum_three');
  String get addNeighborhood => _get('add_neighborhood');
  String get selectNeighborhood => _get('select_neighborhood');
  String get minimumThreeNeighborhoods => _get('minimum_three_neighborhoods');
  String get perDeliveryFee => _get('per_delivery_fee');
  String get bulkOrderFee => _get('bulk_order_fee');
  String get bulkOrderFeeDescription => _get('bulk_order_fee_description');
  String get createBulkOrder => _get('create_bulk_order');
  String get bulkOrderCreatedSuccess => _get('bulk_order_created_success');
  String get bulkOrderAcceptedSuccess => _get('bulk_order_accepted_success');
  String get bulkOrderActive => _get('bulk_order_active');
  String get notesOptional => _get('notes_optional');
  String get additionalNotes => _get('additional_notes');
  String get addNotesHint => _get('add_notes_hint');
  String get whenReady => _get('when_ready');
  String get readyNow => _get('ready_now');
  String readyAfterMinutes(int minutes) => _get('ready_after_minutes').replaceAll('{minutes}', minutes.toString());
  String get nowText => _get('now');
  String get minutesText => _get('minutes');
  String get sixtyMinutes => _get('sixty_minutes');
  String get grandTotalLabel => _get('grand_total_label');
  String get creatingOrder => _get('creating_order');
  String get orderCreated => _get('order_created');
  String get orderCreatedSuccess => _get('order_created_success');
  String orderCreatedReadyAfter(int minutes) => _get('order_created_ready_after').replaceAll('{minutes}', minutes.toString());
  String get orderCreateError => _get('order_create_error');
  String get customerPhoneLabel => _get('customer_phone_label');
  String get phoneInvalidFormat => _get('phone_invalid_format');
  String get openMap => _get('open_map');
  String get searchAddress => _get('search_address');
  String get viewDetails => _get('view_details');
  String get orderDisplayError => _get('order_display_error');
  String agoMinutes(int minutes) => _get('ago_minutes').replaceAll('{minutes}', minutes.toString());
  String agoHours(int hours) => _get('ago_hours').replaceAll('{hours}', hours.toString());
  String agoDays(int days) => _get('ago_days').replaceAll('{days}', days.toString());
  String get daysShort => _get('days_short');
  String get hoursShort => _get('hours_short');
  String get statusWaiting => _get('status_waiting');
  String get customerNameFallback => _get('customer_name_fallback');
  String get phoneNotAvailable => _get('phone_not_available');
  String get pickupAddressFallback => _get('pickup_address_fallback');
  String get deliveryAddressFallback => _get('delivery_address_fallback');
  String get grandTotalWithDelivery => _get('grand_total_with_delivery');
  String get assignedStatus => _get('assigned_status');
  String get customer => _get('customer');
  String get confirm => _get('confirm');
  String get required => _get('required');
  // Voice Order
  String get microphonePermissionRequired => _get('microphone_permission_required');
  String get recording => _get('recording');
  String get processingAudio => _get('processing_audio');
  String get clickToStart => _get('click_to_start');
  String get extractingData => _get('extracting_data');
  String get speakOrderDetails => _get('speak_order_details');
  String get howToUse => _get('how_to_use');
  String get sayCustomerName => _get('say_customer_name');
  String get sayPhone => _get('say_phone');
  String get sayPickup => _get('say_pickup');
  String get sayDelivery => _get('say_delivery');
  String get sayAmount => _get('say_amount');
  String get voiceLibrary => _get('voice_library');
  String get stopRecording => _get('stop_recording');
  String get processing => _get('processing');
  String get startVoiceRecording => _get('start_voice_recording');
  String get extractedData => _get('extracted_data');
  String get customerNameLabel => _get('customer_name_label');
  String get phoneLabel => _get('phone_label');
  String get pickupLabel => _get('pickup_label');
  String get deliveryLabel => _get('delivery_label');
  String get amountLabel => _get('amount_label');
  String get confirmCreateOrder => _get('confirm_create_order');
  String get transcription => _get('transcription');
  String get extractionAccuracy => _get('extraction_accuracy');
  String missingFields(String fields) => '${_get('missing_fields')}$fields';
  String get noDriversAvailableNow => _get('no_drivers_available_now');
  String errorStartingRecording(String error) => '${_get('error_starting_recording')}$error';
  String errorStoppingRecording(String error) => '${_get('error_stopping_recording')}$error';
  String get recordingLoadedSuccess => _get('recording_loaded_success');
  String recordingLoadFailed(String error) => '${_get('recording_load_failed')}$error';
  String audioProcessingFailed(int statusCode) => '${_get('audio_processing_failed')}$statusCode';
  String errorText(String error) => '${_get('error')}$error';
  String get incompleteData => _get('incomplete_data');
  String get alert => _get('alert');
  String lowConfidence(int percent) => _get('low_confidence').replaceAll('{percent}', percent.toString());
  String get continueAction => _get('continue_action');
  String get customerPhoneRequired => _get('customer_phone_required');
  String get customerPhoneRequiredForPickup => _get('customer_phone_required_for_pickup');
  String get customerPhoneOptional => _get('customer_phone_optional');
  String get multipleOrders => _get('multiple_orders');
  String get multipleOrdersDescription => _get('multiple_orders_description');
  String get createMultipleOrders => _get('create_multiple_orders');
  String get bulkOrderStatusPending => _get('bulk_order_status_pending');
  String get bulkOrderStatusAssigned => _get('bulk_order_status_assigned');
  String get bulkOrderStatusAccepted => _get('bulk_order_status_accepted');
  String get bulkOrderStatusActive => _get('bulk_order_status_active');
  String get bulkOrderStatusCompleted => _get('bulk_order_status_completed');
  String get bulkOrderStatusCancelled => _get('bulk_order_status_cancelled');
  String get bulkOrderStatusRejected => _get('bulk_order_status_rejected');
  String get assignedDriver => _get('assigned_driver');
  String get assignToSameDriver => _get('assign_to_same_driver');
  String get currentDriver => _get('current_driver');
  String get contactDriver => _get('contact_driver');
  String get callViaWhatsApp => _get('call_via_whatsapp');
  String get driverInfoNotAvailable => _get('driver_info_not_available');
  String get driverPhoneNotAvailable => _get('driver_phone_not_available');
  String get helloDriver => _get('hello_driver');
  String get close => _get('close');
  String get pickupAddressRequired => _get('pickup_address_required');
  String get deliveryAddressRequired => _get('delivery_address_required');
  String get orderCreatedSuccessVoice => _get('order_created_success_voice');
  String orderCreateErrorVoice(String error) => '${_get('order_create_error_voice')}$error';
  // Wallet
  String get myWallet => _get('my_wallet');
  String get pleaseTopUp => _get('please_top_up');
  String get balanceLow => _get('balance_low');
  String get balanceGood => _get('balance_good');
  String get currentBalance => _get('current_balance');
  String creditLimit(double limit) => '${_get('credit_limit')}${limit.toStringAsFixed(0)} IQD';
  String get topUpWallet => _get('top_up_wallet');
  String get feeExemptBanner => _get('fee_exempt_banner');
  String get feeExemptMessage => _get('fee_exempt_message');
  String get feeExemptUntil => _get('fee_exempt_until');
  String get totalOrders => _get('total_orders');
  String get totalFees => _get('total_fees');
  String get noTransactions => _get('no_transactions');
  String get recentTransactions => _get('recent_transactions');
  String balance(double amount) => '${_get('balance')}${amount.toStringAsFixed(0)} IQD';
  // Settings
  String get notificationsEnabled => _get('notifications_enabled');
  String get notificationsDenied => _get('notifications_denied');
  String get notificationSettings => _get('notification_settings');
  String get notificationSettingsHint => _get('notification_settings_hint');
  String get openSettings => _get('open_settings');
  String get notifications => _get('notifications');
  String get general => _get('general');
  String get instantNotifications => _get('instant_notifications');
  String get receiveNotifications => _get('receive_notifications');
  String get notificationsDisabled => _get('notifications_disabled');
  String get sound => _get('sound');
  String get soundSubtitle => _get('sound_subtitle');
  String get vibration => _get('vibration');
  String get vibrationSubtitle => _get('vibration_subtitle');
  String get app => _get('app');
  String get aboutApp => _get('about_app');
  String get appDescription => _get('app_description');
  String get appDescriptionDriver => _get('app_description_driver');
  String version(String version) => '${_get('version')}$version';
  String get location => _get('location');
  String get locationPermission => _get('location_permission');
  String get locationPermissionSubtitle => _get('location_permission_subtitle');
  String get check => _get('check');
  String get locationPermissionRequiredDriver => _get('location_permission_required_driver');
  String get locationPermissionRequiredTitle => _get('location_permission_required_title');
  String get receiveOrderNotifications => _get('receive_order_notifications');
  // Profile
  String get editProfile => _get('edit_profile');
  String get profileUpdatedSuccess => _get('profile_updated_success');
  String errorOccurred(String error) => '${_get('error_occurred')}$error';
  String get featureComingSoon => _get('feature_coming_soon');
  String get name => _get('name');
  String get nameRequired => _get('name_required');
  String get storeName => _get('store_name');
  String get storeNameRequired => _get('store_name_required');
  String get phoneNumberLabel => _get('phone_number_label');
  String get address => _get('address');
  String get saveChanges => _get('save_changes');
  String get profile => _get('profile');
  String get profileSavedSuccess => _get('profile_saved_success');
  String get errorSavingProfile => _get('error_saving_profile');
  String get noUserData => _get('no_user_data');
  String get accountInfo => _get('account_info');
  String get nameRequiredField => _get('name_required_field');
  String get phoneCannotChange => _get('phone_cannot_change');
  String get accountStatus => _get('account_status');
  String get verificationStatus => _get('verification_status');
  String get verified => _get('verified');
  String get notVerified => _get('not_verified');
  String get status => _get('status');
  String get registrationDate => _get('registration_date');
  String enterLabel(String label) => '${_get('enter_label')}$label';
  // Messaging
  String get failedOpenSupport => _get('failed_open_support');
  String get openMessagesList => _get('open_messages_list');
  String get failedSelectImage => _get('failed_select_image');
  String get failedSendMessage => _get('failed_send_message');
  String get conversation => _get('conversation');
  String orderLabel(String orderId) => '${_get('order')}$orderId';
  String get reply => _get('reply');
  String get typeMessage => _get('type_message');
  String get messages => _get('messages');
  String get noConversations => _get('no_conversations');
  String get technicalSupport => _get('technical_support');
  String get conversationLabel => _get('conversation_label');
  String supportOrder(String orderId) => '${_get('support_order')}$orderId';
  // Legal
  String get errorLoadingPrivacy => _get('error_loading_privacy');
  String get errorLoadingTerms => _get('error_loading_terms');
  // Login with Password
  String get loginWithPassword => _get('login_with_password');
  String get welcomeBack => _get('welcome_back');
  String get enterPhonePassword => _get('enter_phone_password');
  String get invalidPhone => _get('invalid_phone');
  String get password => _get('password');
  String get passwordRequired => _get('password_required');
  String get invalidCredentials => _get('invalid_credentials');
  String get forgotPassword => _get('forgot_password');
  // Driver Orders
  String get myOrders => _get('my_orders');
  String get all => _get('all');
  String get pending => _get('pending');
  String get accepted => _get('accepted');
  String get completed => _get('completed');
  String get cancelled => _get('cancelled');
  String get noPendingOrders => _get('no_pending_orders');
  String get noAcceptedOrders => _get('no_accepted_orders');
  String get noCancelledOrders => _get('no_cancelled_orders');
  String get noOrders => _get('no_orders');
  String get orderPrice => _get('order_price');
  String fromLabel(String address) => '${_get('from')}$address';
  String toLabel(String address) => '${_get('to')}$address';
  String orderTimeLabel(String time) => '${_get('order_time')}$time';
  String get notesLabel => _get('notes');
  String get reject => _get('reject');
  String get completeOrder => _get('complete_order');
  String get inTransit => _get('in_transit');
  String get rejected => _get('rejected');
  String get unknown => _get('unknown');
  // Driver Earnings
  String get earnings => _get('earnings');
  String get driverIdNotFound => _get('driver_id_not_found');
  String get classifyOrdersByStatus => _get('classify_orders_by_status');
  String get recentOrders => _get('recent_orders');
  String get noOrdersInPeriod => _get('no_orders_in_period');
  String get errorLoadingStats => _get('error_loading_stats');
  String get today => _get('today');
  String get week => _get('week');
  String get month => _get('month');
  String get activeOrders => _get('active_orders');
  String get acceptanceRate => _get('acceptance_rate');
  String get cancelledRejected => _get('cancelled_rejected');
  String get hour => _get('hour');
  String get minute => _get('minute');
  String get averageDeliveryTime => _get('average_delivery_time');
  String get fromAcceptanceToDelivery => _get('from_acceptance_to_delivery');
  String basedOnCompleted(int count) => '${_get('based_on_completed')}$count${_get('completed_orders')}';
  String get earningsSummary => _get('earnings_summary');
  String get totalEarnings => _get('total_earnings');
  String get averageEarningsPerOrder => _get('average_earnings_per_order');
  // Notifications
  String get notificationDeleted => _get('notification_deleted');
  String get allMarkedRead => _get('all_marked_read');
  String get noOrderLinked => _get('no_order_linked');
  String unreadCount(int count) => '$count${_get('unread')}';
  String get markAllRead => _get('mark_all_read');
  String get noNotifications => _get('no_notifications');
  // Scheduled Order
  String get scheduleOrderLater => _get('schedule_order_later');
  String get dateTime => _get('date_time');
  String get date => _get('date');
  String get time => _get('time');
  String get recurringOrder => _get('recurring_order');
  String get willRepeatAutomatically => _get('will_repeat_automatically');
  String get oneTimeOrder => _get('one_time_order');
  String get recurrencePattern => _get('recurrence_pattern');
  String get daily => _get('daily');
  String get weekly => _get('weekly');
  String get monthly => _get('monthly');
  String get recurrenceEndDate => _get('recurrence_end_date');
  String get noEnd => _get('no_end');
  String get totalAmountIqd => _get('total_amount_iqd');
  String get deliveryFeeIqd => _get('delivery_fee_iqd');
  String get schedulingSummary => _get('scheduling_summary');
  String willBePublishedAt(String dateTime) => '${_get('will_be_published_at')}$dateTime';
  String recurrenceLabel(String pattern) => '${_get('recurrence')}$pattern';
  String get until => _get('until');
  // Bulk Order
  String get bulkOrders => _get('bulk_orders');
  String get multipleOrdersSamePickup => _get('multiple_orders_same_pickup');
  String get sharedDetails => _get('shared_details');
  String get generalNotesOptional => _get('general_notes_optional');
  String get whenNeedDrivers => _get('when_need_drivers');
  String get nowImmediately => _get('now_immediately');
  String afterMinutes(int minutes) => '${_get('after_minutes')}$minutes${_get('minutes')}';
  String get scheduledOrders => _get('scheduled_orders');
  String deliveryAddresses(int count) => '${_get('delivery_addresses')}$count)';
  String get addAddress => _get('add_address');
  String get noDeliveryAddresses => _get('no_delivery_addresses');
  String createBulkOrders(int count) => '${_get('create_bulk_orders')}$count)';
  String orderPriceLabel(double amount) => '${_get('order_price_label')}${amount.toStringAsFixed(0)} IQD';
  String get pleaseSelectPickup => _get('please_select_pickup');
  String get pleaseAddDelivery => _get('please_add_delivery');
  String get continueAtOwnRisk => _get('continue_at_own_risk');
  String get confirmBulkOrders => _get('confirm_bulk_orders');
  String confirmBulkOrdersQuestion(int count) => _get('confirm_bulk_orders_question').replaceAll('{count}', count.toString());
  String scheduledBulkOrdersMessage(int minutes) => _get('scheduled_bulk_orders_message').replaceAll('{minutes}', minutes.toString());
  String get publishOrdersImmediately => _get('publish_orders_immediately');
  String bulkOrdersScheduledSuccess(int count, int minutes) => _get('bulk_orders_scheduled_success').replaceAll('{count}', count.toString()).replaceAll('{minutes}', minutes.toString());
  String bulkOrdersCreatedSuccess(int count) => _get('bulk_orders_created_success').replaceAll('{count}', count.toString());
  String bulkOrdersFailed(String error) => _get('bulk_orders_failed').replaceAll('{error}', error);
  String get addDeliveryAddress => _get('add_delivery_address');
  String get orderAmount => _get('order_amount');
  String get add => _get('add');
  String get failed => _get('failed');
  // Location Picker
  String get moveMapSelectLocation => _get('move_map_select_location');
  String get gettingAddress => _get('getting_address');
  String get cannotGetCurrentLocation => _get('cannot_get_current_location');
  String get moveMapToSelect => _get('move_map_to_select');
  String get myLocation => _get('my_location');
  // Voice Library
  String get errorLoadingRecordings => _get('error_loading_recordings');
  String get noVoiceRecordings => _get('no_voice_recordings');
  String get recordFirstOrder => _get('record_first_order');
  String get recordNewOrder => _get('record_new_order');
  String get recordingDeletedSuccess => _get('recording_deleted_success');
  // Top Up Dialog
  String get pleaseSelectPaymentMethod => _get('please_select_payment_method');
  String get pleaseEnterValidAmount => _get('please_enter_valid_amount');
  String minimumAmountIs(double amount) => '${_get('minimum_amount_is')}${amount.toStringAsFixed(0)} IQD';
  String amountMustBeGreater(double amount, double fee) => '${_get('amount_must_be_greater')}${amount.toStringAsFixed(0)} IQD (${amount.toStringAsFixed(0)}${_get('plus_fee')}${fee.toStringAsFixed(0)}${_get('fee')})';
  String get mustLoginFirst => _get('must_login_first');
  String get topUpViaWayl => _get('top_up_via_wayl');
  String get paymentSuccess => _get('payment_success');
  String get paymentCancelled => _get('payment_cancelled');
  String get errorLoadingPayment => _get('error_loading_payment');
  String failedCreatePaymentLink(String error) => '${_get('failed_create_payment_link')}$error';
  String get topUpViaRep => _get('top_up_via_rep');
  String topUpRequestSent(double amount) => '${_get('top_up_request_sent')}${amount.toStringAsFixed(0)} IQD';
  String noteFeeDeducted(double fee) => '${_get('note_fee_deducted')}${fee.toStringAsFixed(0)}${_get('as_service_fee')}';
  String get repWillContactSoon => _get('rep_will_contact_soon');
  String get amountIqd => _get('amount_iqd');
  String get pleaseEnterAmount => _get('please_enter_amount');
  String get pleaseEnterValidNumber => _get('please_enter_valid_number');
  String minimumAmount(double amount) => '${_get('minimum_amount')}${amount.toStringAsFixed(0)} IQD';
  String get selectPaymentMethod => _get('select_payment_method');
  String get onlineCheckout => _get('online_checkout');
  String get zainCashQiVisaMastercard => _get('zain_cash_qi_visa_mastercard');
  String feeLabel(double fee) => '${_get('fee_label')}${fee.toStringAsFixed(0)} IQD';
  // Announcement Dialog
  String get gotIt => _get('got_it');
  String endsInDays(int days) => '${_get('ends_in_days')}$days${_get('days')}';
  String endsInHours(int hours) => '${_get('ends_in_hours')}$hours${_get('hours')}';
  String endsInMinutes(int minutes) => '${_get('ends_in_minutes')}$minutes${_get('minutes')}';
  String endsInSeconds(int seconds) => '${_get('ends_in_seconds')}$seconds${_get('seconds')}';
  // Password Reset
  String get resetPassword => _get('reset_password');
  String get enterCodeNewPassword => _get('enter_code_new_password');
  String get verificationCode => _get('verification_code');
  String get enter6DigitCode => _get('enter_6_digit_code');
  String get newPassword => _get('new_password');
  String get passwordUpdatedSuccess => _get('password_updated_success');
  String get passwordUpdateFailed => _get('password_update_failed');
  String get updatePassword => _get('update_password');
  // Create Password
  String get createPassword => _get('create_password');
  String get chooseStrongPassword => _get('choose_strong_password');
  String get lettersNumbersOnly8Min => _get('letters_numbers_only_8_min');
  String get createAccount => _get('create_account');
  String get tryApp => _get('try_app');
  String get demoModeTitle => _get('demo_mode_title');
  String get demoModeInfo => _get('demo_mode_info');
  String get demoMerchant => _get('demo_merchant');
  String get demoMerchantDesc => _get('demo_merchant_desc');
  String get demoDriver => _get('demo_driver');
  String get demoDriverDesc => _get('demo_driver_desc');
  String get accountCreationFailed => _get('account_creation_failed');
  // Verification Pending
  String get verificationPending => _get('verification_pending');
  String get verificationRejected => _get('verification_rejected');
  String get verificationUnderReview => _get('verification_under_review');
  String get verificationReviewMessage => _get('verification_review_message');
  String get verificationRejectedMessage => _get('verification_rejected_message');
  String get resubmitVerification => _get('resubmit_verification');
  String get pleaseUploadIdFrontBack => _get('please_upload_id_front_back');
  String get pleaseUploadSelfieWithId => _get('please_upload_selfie_with_id');
  String get idVerificationFailed => _get('id_verification_failed');
  String connectionFailed(String error) => '${_get('connection_failed')}$error';
  // User Registration
  String get selectImageSource => _get('select_image_source');
  String get takePhoto => _get('take_photo');
  String get chooseFromGallery => _get('choose_from_gallery');
  String get selectStoreLocation => _get('select_store_location');
  String get pleaseUploadDocument => _get('please_upload_document');
  String get pleaseUploadDocumentBack => _get('please_upload_document_back');
  String get pleaseUploadSelfie => _get('please_upload_selfie');
  String get pleaseSelectStoreLocation => _get('please_select_store_location');
  String get idVerificationFailedReason => _get('id_verification_failed_reason');
  // Map Screen
  String get map => _get('map');
  String get mapboxIntegrationProgress => _get('mapbox_integration_progress');
  String get selectThisLocation => _get('select_this_location');
  String get tapMapSelectLocation => _get('tap_map_select_location');
  String get myCurrentLocation => _get('my_current_location');
  String get yourCurrentLocation => _get('your_current_location');
  String get selectedLocation => _get('selected_location');
  String get verifying => _get('verifying');
  String get pleaseUploadClearIdImages => _get('please_upload_clear_id_images');
  String get whatHappensNow => _get('what_happens_now');
  String get verificationProcessSteps => _get('verification_process_steps');
  String get refreshStatus => _get('refresh_status');
  String get uploadNewDocuments => _get('upload_new_documents');
  String get pleaseUploadClearId => _get('please_upload_clear_id');
  String get youAreBlocked => _get('you_are_blocked');
  String get accountBlockedMessage => _get('account_blocked_message');
  String get contactAppOwner => _get('contact_app_owner');
  String get pleaseReuploadIds => _get('please_reupload_ids');
  String get reuploadIdsMessage => _get('reupload_ids_message');
  String get fullNameExtractedAutomatically => _get('full_name_extracted_automatically');
  String get idUploadRequirements => _get('id_upload_requirements');
  String get registrationSentSuccessfully => _get('registration_sent_successfully');
  String get reviewByAiSystem => _get('review_by_ai_system');
  String get documentsNotAccepted => _get('documents_not_accepted');
  String get idCardFront => _get('id_card_front');
  String get idCardBack => _get('id_card_back');
  String get selfieWithId => _get('selfie_with_id');
  String get upload => _get('upload');
  String get uploaded => _get('uploaded');
  String get registrationError => _get('registration_error');
  String registeringAs(String role) => '${_get('registering_as')}$role';
  String completeData(String role) => '${_get('complete_data')}$role';
  String get pleaseFillAllRequired => _get('please_fill_all_required');
  String get howDidYouHear => _get('how_did_you_hear');
  String get requiredDocuments => _get('required_documents');
  String get registering => _get('registering');
  String get completeRegistration => _get('complete_registration');
  String get nameExtractedAutomatically => _get('name_extracted_automatically');
  String get storeInformation => _get('store_information');
  String get enterStoreName => _get('enter_store_name');
  String get storeAddress => _get('store_address');
  String get selectStoreLocationMap => _get('select_store_location_map');
  String get city => _get('city');
  String get selectCity => _get('select_city');
  String get cityRequired => _get('city_required');
  String get najaf => _get('najaf');
  String get mosul => _get('mosul');
  String get vehicleInformation => _get('vehicle_information');
  String get defaultLabel => _get('default');
  String get doYouHaveLicense => _get('do_you_have_license');
  String get doYouOwnVehicle => _get('do_you_own_vehicle');
  String get profilePhotoOptional => _get('profile_photo_optional');
  String get addClearProfilePhoto => _get('add_clear_profile_photo');
  // Order Creation Carousel
  String get normalOrder => _get('normal_order');
  String get bulkOrdersTitle => _get('bulk_orders_title');
  String get scheduledOrdersTitle => _get('scheduled_orders_title');
  String get voiceOrderTitle => _get('voice_order_title');
  String get noAccountRegisteredThisNumber => _get('no_account_registered_this_number');
  String get register => _get('register');
  String get userDataErrorContactSupport => _get('user_data_error_contact_support');
  String get accountAlreadyRegistered => _get('account_already_registered');
  String get noAccountRegistered => _get('no_account_registered');
  String get noAccountTitle => _get('no_account_title');
  String errorSelectingImage(String error) => '${_get('error_selecting_image')}$error';
  String get fastDeliveryService => _get('fast_delivery_service');
  String pleaseSelect(String label) => '${_get('please_select')}$label';
  String get motorcycle => _get('motorcycle');
  String get customerName => _get('customer_name');
  String get confirmLocation => _get('confirm_location');
  String get deleteRecording => _get('delete_recording');
  String get confirmDeleteRecording => _get('confirm_delete_recording');
  String get delete => _get('delete');
  String get merchantDescription => _get('merchant_description');
  String get driverDescription => _get('driver_description');
  // Scheduled Order Additional
  String get scheduleRecurringOrder => _get('schedule_recurring_order');
  String get scheduleOrder => _get('schedule_order');
  String get vehicleTypeLabel => _get('vehicle_type_label');
  String get dailyLabel => _get('daily_label');
  String get weeklyLabel => _get('weekly_label');
  String get monthlyLabel => _get('monthly_label');
  String get pleaseSelectPickupLocation => _get('please_select_pickup_location');
  String get pleaseSelectDeliveryLocation => _get('please_select_delivery_location');
  String get merchantDataErrorLoginAgain => _get('merchant_data_error_login_again');
  // Order Details
  String get amShort => _get('am_short');
  String get pmShort => _get('pm_short');
  String get noImagesUploadedOrder => _get('no_images_uploaded_order');
  // Voice Order
  String voiceOrderNote(String transcription) => '${_get('voice_order_note')}$transcription';
  String get canContinueScheduledOrder => _get('can_continue_scheduled_order');
  String get orderScheduledSuccess => _get('order_scheduled_success');
  // Driver Earnings
  String get completedOrdersLabel => _get('completed_orders_label');
  String get deliveredStatus => _get('delivered_status');
  String get cancelledStatus => _get('cancelled_status');
  String get rejectedStatus => _get('rejected_status');
  String get activeStatus => _get('active_status');
  String orderHash(String id) => '${_get('order_hash')}${id.substring(0, 8)}';
  String get deliveryFeesLabel => _get('delivery_fees_label');
  String get statusPending => _get('status_pending');
  String get statusAssigned => _get('status_assigned');
  String get statusAccepted => _get('status_accepted');
  String get statusOnTheWay => _get('status_on_the_way');
  String get statusDelivered => _get('status_delivered');
  String get statusCancelled => _get('status_cancelled');
  String get statusRejected => _get('status_rejected');
  String get statusScheduled => _get('status_scheduled');
  String get statusUnknown => _get('status_unknown');
  // Driver Orders
  String get orderAcceptedSuccess => _get('order_accepted_success');
  String get orderRejectedSuccess => _get('order_rejected_success');
  String get orderCompletedSuccess => _get('order_completed_success');
  // Wallet Widgets
  String get myBalance => _get('my_balance');
  String get balanceNeedsTopUp => _get('balance_needs_top_up');
  String get cannotCreateOrdersUntilTopUp => _get('cannot_create_orders_until_top_up');
  String get zainCashKi => _get('zain_cash_ki');
  String hurRep(double fee) => _get('hur_rep');
  // Payment WebView
  String errorLoadingPaymentPage(String error) => '${_get('error_loading_payment_page')}$error';
  // Voice Recording Card
  String get failedToLoadRecording => _get('failed_to_load_recording');
  String errorPlayingRecording(String error) => '${_get('error_playing_recording')}$error';
  // Customer Location Sharing
  String get pleaseAllowLocationAccess => _get('please_allow_location_access');
  String get failedToSendLocation => _get('failed_to_send_location');
  String errorGettingLocation(String error) => '${_get('error_getting_location')}$error';
  String get locationSentSuccessfully => _get('location_sent_successfully');
  String get locationReceivedAutoUpdate => _get('location_received_auto_update');
  String get locationReadyNoCallNeeded => _get('location_ready_no_call_needed');
  // Location Update Widget
  String errorCheckingLocationUpdates(String error) => '${_get('error_checking_location_updates')}$error';
  // Dashboard
  String get maintenanceMode => _get('maintenance_mode');
  String get connected => _get('connected');
  String get notAvailable => _get('not_available');
  String get notLoggedIn => _get('not_logged_in');
  String get orderAcceptedSuccessMessage => _get('order_accepted_success_message');
  String get errorAcceptingOrder => _get('error_accepting_order');
  String get errorInOperation => _get('error_in_operation');
  String get errorRejectingOrder => _get('error_rejecting_order');
  String get orderRejectedSuccessMessage => _get('order_rejected_success_message');
  String get motorbikeLabel => _get('motorbike_label');
  // Map Widget
  String get yourCurrentLocationLabel => _get('your_current_location_label');
  String get showRoute => _get('show_route');
  String get store => _get('store');
  String get delivery => _get('delivery');
  String get yourLocation => _get('your_location');
  // ID Verification Review
  String errorSavingData(String error) => '${_get('error_saving_data')}$error';
  String get reviewIdData => _get('review_id_data');
  String get extractedInfoMessage => _get('extracted_info_message');
  String get fullNameSection => _get('full_name_section');
  String get firstName => _get('first_name');
  String get enterName => _get('enter_name');
  String get fatherName => _get('father_name');
  String get enterFatherName => _get('enter_father_name');
  String get fatherNameRequired => _get('father_name_required');
  String get grandfatherName => _get('grandfather_name');
  String get enterGrandfatherName => _get('enter_grandfather_name');
  String get grandfatherNameRequired => _get('grandfather_name_required');
  String get familyName => _get('family_name');
  String get enterFamilyName => _get('enter_family_name');
  String get familyNameRequired => _get('family_name_required');
  String get cardInformation => _get('card_information');
  String get nationalIdNumber => _get('national_id_number');
  String get idNumberHint => _get('id_number_hint');
  String get idNumberRequired => _get('id_number_required');
  // User Registration Additional
  String get removeImage => _get('remove_image');
  String get locationSelectedCheckmark => _get('location_selected_checkmark');
  String get howDidYouHearHur => _get('how_did_you_hear_hur');
  String get optional => _get('optional');
  String get documentType => _get('document_type');
  String get selectDocumentType => _get('select_document_type');
  String get notSpecified => _get('not_specified');
  String get merchantLabel => _get('merchant_label');
  String get expiryDate => _get('expiry_date');
  String get birthDate => _get('birth_date');
  String get arabicChar => _get('arabic_char');
  String get recentActivity => _get('recent_activity');
  String get totalSales => _get('total_sales');
  String get merchantsLabel => _get('merchants_label');
  String get driversLabel => _get('drivers_label');
  String get customersLabel => _get('customers_label');
  String get analyticsTitle => _get('analytics_title');
  String get allFilter => _get('all_filter');
  String get todayFilter => _get('today_filter');
  String get weekFilter => _get('week_filter');
  String get monthFilter => _get('month_filter');
  String get totalOrdersStat => _get('total_orders_stat');
  String get completedOrdersStat => _get('completed_orders_stat');
  String get cancelledOrdersStat => _get('cancelled_orders_stat');
  String get rejectedOrdersStat => _get('rejected_orders_stat');
  String get pendingApprovalLabel => _get('pending_approval_label');

  String get walletBalance => _get('wallet_balance');
  String get walletTopUp => _get('wallet_top_up');

  String get supportChat => _get('support_chat');

  String get settings => _get('settings');
  String get language => _get('language');
  String get languageArabic => _get('language_arabic');
  String get languageEnglish => _get('language_english');
  String get darkMode => _get('dark_mode');
  String get darkModeEnabled => _get('dark_mode_enabled');
  String get lightModeEnabled => _get('light_mode_enabled');
  String get appearance => _get('appearance');

  String get systemMaintenanceTitle => _get('system_maintenance_title');
  String get systemMaintenanceMessage => _get('system_maintenance_message');
  
  // Welcome & Navigation
  String get skip => _get('skip');
  String get next => _get('next');
  String get startNow => _get('start_now');
  
  // Update Required
  String get updateRequired => _get('update_required');
  String get mustUpdateApp => _get('must_update_app');
  String get currentVersion => _get('current_version');
  String get requiredVersion => _get('required_version');
  String get updateApp => _get('update_app');
  
  // Maintenance Mode
  String get maintenanceTitle => _get('maintenance_title');
  String get maintenanceMessageDriver => _get('maintenance_message_driver');
  String get maintenanceMessageMerchant => _get('maintenance_message_merchant');
  String get maintenanceMessageDefault => _get('maintenance_message_default');
  String get maintenanceInfo => _get('maintenance_info');
  String get maintenanceBanner => _get('maintenance_banner');
  String get understood => _get('understood');
  
  // Driver Welcome
  String get driverWelcomeTitle1 => _get('driver_welcome_title1');
  String get driverWelcomeDesc1 => _get('driver_welcome_desc1');
  String get driverWelcomeTitle2 => _get('driver_welcome_title2');
  String get driverWelcomeDesc2 => _get('driver_welcome_desc2');
  String get driverWelcomeTitle3 => _get('driver_welcome_title3');
  String get driverWelcomeDesc3 => _get('driver_welcome_desc3');
  
  // Merchant Welcome
  String get merchantWelcomeTitle1 => _get('merchant_welcome_title1');
  String get merchantWelcomeDesc1 => _get('merchant_welcome_desc1');
  String get merchantWelcomeTitle2 => _get('merchant_welcome_title2');
  String get merchantWelcomeDesc2 => _get('merchant_welcome_desc2');
  String get merchantWelcomeTitle3 => _get('merchant_welcome_title3');
  String get merchantWelcomeDesc3 => _get('merchant_welcome_desc3');
  
  // Merchant Walkthrough
  String get merchantWalkthroughTitle1 => _get('merchant_walkthrough_title1');
  String get merchantWalkthroughDesc1 => _get('merchant_walkthrough_desc1');
  String get merchantWalkthroughTitle2 => _get('merchant_walkthrough_title2');
  String get merchantWalkthroughDesc2 => _get('merchant_walkthrough_desc2');
  String get merchantWalkthroughTitle3 => _get('merchant_walkthrough_title3');
  String get merchantWalkthroughDesc3 => _get('merchant_walkthrough_desc3');
  
  // Driver Walkthrough
  String get driverWalkthroughTitle1 => _get('driver_walkthrough_title1');
  String get driverWalkthroughDesc1 => _get('driver_walkthrough_desc1');
  String get driverWalkthroughTitle2 => _get('driver_walkthrough_title2');
  String get driverWalkthroughDesc2 => _get('driver_walkthrough_desc2');
  String get driverWalkthroughTitle3 => _get('driver_walkthrough_title3');
  String get driverWalkthroughDesc3 => _get('driver_walkthrough_desc3');
  
  String get iAgreeToThe => _get('i_agree_to_the');
  String get complete => _get('complete');
  
  // Month Names
  String get january => _get('january');
  String get february => _get('february');
  String get march => _get('march');
  String get april => _get('april');
  String get may => _get('may');
  String get june => _get('june');
  String get july => _get('july');
  String get august => _get('august');
  String get september => _get('september');
  String get october => _get('october');
  String get november => _get('november');
  String get december => _get('december');
  
  // Additional getters for new translations
  String get startDelivery => _get('start_delivery');
  String get markDelivered => _get('mark_delivered');
  String get merchantButton => _get('merchant_button');
  String get customerButton => _get('customer_button');
  String get mapButton => _get('map_button');
  String get pickedUpStartDelivery => _get('picked_up_start_delivery');
  String get confirmDelivery => _get('confirm_delivery');
  String get deliveryError => _get('delivery_error');
  String get callViaPhone => _get('call_via_phone');
  String get callViaWhatsapp => _get('call_via_whatsapp');
  String get whatsappMessage => _get('whatsapp_message');
  String get customerLabelColon => _get('customer_label_colon');
  String get merchantLabelColon => _get('merchant_label_colon');
  String get addressLabel => _get('address_label');
  String get mapUpdated => _get('map_updated');
  String get photoUploadedSuccess => _get('photo_uploaded_success');
  String get pickStoreLocation => _get('pick_store_location');
  String get pickOnMap => _get('pick_on_map');
  String get storeLocationPlaceholder => _get('store_location_placeholder');
  String get addressRequired => _get('address_required');
  String get locationSavedOnMap => _get('location_saved_on_map');
  String get errorColon => _get('error_colon');
  String get retakePhoto => _get('retake_photo');
  String get orderNotFound => _get('order_not_found');
  String get locationUnavailable => _get('location_unavailable');
  String get discardChangesTitle => _get('discard_changes_title');
  String get discardChangesMessage => _get('discard_changes_message');
  String get discardButton => _get('discard_button');
  String get loadMoreTransactions => _get('load_more_transactions');
  String get retryAction => _get('retry_action');
  String get cancelOrderAction => _get('cancel_order_action');
  String get goBack => _get('go_back');
  String get noDriversAvailableTitle => _get('no_drivers_available_title');
  String get currentFees => _get('current_fees');
  String get newFees => _get('new_fees');
  String get repostAction => _get('repost_action');
  String repostOrderNewFee(String fee) => _get('repost_order_new_fee').replaceAll('{fee}', fee);
  String get repostButton => _get('repost_button');
  String get agree => _get('agree');
  String get cancelAndClose => _get('cancel_and_close');
  String driverWhatsappMessage(String name) => _get('driver_whatsapp_message').replaceAll('{name}', name);
  String get locationPermissionDriverLong => _get('location_permission_driver_long');
  String get locationPermissionExplanation => _get('location_permission_explanation');
  String get backgroundLocationExplanation => _get('background_location_explanation');
  String get deliveredLabel => _get('delivered_label');
  String get cancelledRejectedLabel => _get('cancelled_rejected_label');
  String get cancelOrderTitle => _get('cancel_order_title');
  String get pendingStatus => _get('pending_status');
  String get acceptedStatus => _get('accepted_status');
  String get onTheWayStatus => _get('on_the_way_status');
  String get scheduledStatus => _get('scheduled_status');
  String get unknownStatus => _get('unknown_status');
  String get helpSupport => _get('help_support');
  String get driverOrders => _get('driver_orders');
  String get driverEarnings => _get('driver_earnings');
  
  // Merchant Dashboard Getters
  String get noPastOrders => _get('no_past_orders');
  String get noCurrentOrders => _get('no_current_orders');
  String get statsTitle => _get('stats_title');
  String get revenueStatsTitle => _get('revenue_stats_title');
  String get totalOrdersTitle => _get('total_orders_title');
  String get deliveryFees => _get('delivery_fees');
  String get avgOrderValue => _get('avg_order_value');
  String get performanceMetrics => _get('performance_metrics');
  String get avgDeliveryTime => _get('avg_delivery_time');
  String get completionRate => _get('completion_rate');
  String get cancellationRate => _get('cancellation_rate');
  String get activeOrdersLabel => _get('active_orders_label');

  // Driver Rank
  String get driverRankTitle => _get('driver_rank_title');
  String get currentRank => _get('current_rank');
  String get commissionLabel => _get('commission_label');
  String get activeHoursNotice => _get('active_hours_notice');
  String get details => _get('details');
  String get rankBenefits => _get('rank_benefits');
  String get currentBadge => _get('current_badge');
  String get trialRank => _get('trial_rank');
  String get bronzeRank => _get('bronze_rank');
  String get silverRank => _get('silver_rank');
  String get goldRank => _get('gold_rank');
  String get trialRequirement => _get('trial_requirement');
  String get bronzeRequirement => _get('bronze_requirement');
  String get silverRequirement => _get('silver_requirement');
  String get goldRequirement => _get('gold_requirement');
  String get trialPeriodTitle => _get('trial_period_title');
  String get trialPeriodMessage => _get('trial_period_message');
  String get topRankTitle => _get('top_rank_title');
  String progressToRank(String rank) => _get('progress_to_rank').replaceAll('{rank}', rank);
  String hoursValue(String hours) => _get('hours_value').replaceAll('{hours}', hours);
  String hoursRequired(String hours) => _get('hours_required').replaceAll('{hours}', hours);
  String progressCompleted(String percent) => _get('progress_completed').replaceAll('{percent}', percent);
  String get ranksApplyMonthly => _get('ranks_apply_monthly');
  String get backgroundLocationPermissionTitle => _get('background_location_permission_title');
  String get pleaseAllowAlways => _get('please_allow_always');

  String get ordersByStatus => _get('orders_by_status');

  // Driver Dashboard Getters
  String get notAvailableShort => _get('not_available_short');
  String get merchantInfoUnavailable => _get('merchant_info_unavailable');
  String get cannotMakeCall => _get('cannot_make_call');
  String get cannotOpenWhatsapp => _get('cannot_open_whatsapp');
  String get invalidCoordinates => _get('invalid_coordinates');
  String get cannotOpenGoogleMaps => _get('cannot_open_google_maps');
  String get failedOpenGoogleMaps => _get('failed_open_google_maps');
  String get cannotOpenWaze => _get('cannot_open_waze');
  String get failedOpenWaze => _get('failed_open_waze');
  String get waitingLocationPermission => _get('waiting_location_permission');
  String get determiningLocation => _get('determining_location');
  String get currentLocationStatus => _get('current_location_status');
  String get lastKnownLocation => _get('last_known_location');
  String get uploadingProgress => _get('uploading_progress');
  String get confirmAndFinish => _get('confirm_and_finish');
  String get yourLocationButton => _get('your_location_button');
  String get acceptOrderButton => _get('accept_order_button');
  String get timeRemainingLabel => _get('time_remaining_label');

  // Delivery Timer - Late popup
  String get deliveryLateTitle => _get('delivery_late_title');
  String get deliveryLateMessage => _get('delivery_late_message');
  String get deliveryLateAck => _get('delivery_late_ack');
  String get deliveryTimerInfoTitle => _get('delivery_timer_info_title');
  String get deliveryTimerInfoMessage => _get('delivery_timer_info_message');
  String get lateDurationLabel => _get('late_duration_label');
  String get deliveryDurationTitle => _get('delivery_duration_title');
  String get deliveryDurationNotAvailable => _get('delivery_duration_not_available');
  String get deliveryDurationOnTime => _get('delivery_duration_on_time');
  String get deliveryDurationLate => _get('delivery_duration_late');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['ar', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}


