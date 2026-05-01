import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../shared/models/user_model.dart';
import '../constants/app_constants.dart';
import '../services/device_manager.dart';
import '../services/flutterfire_notification_service.dart';
import '../services/whatsapp_service.dart';
import '../services/response_cache_service.dart';
import '../services/network_quality_service.dart';

class AuthProvider extends ChangeNotifier with WidgetsBindingObserver {
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;
  String? _deviceId;
  StreamSubscription? _sessionSubscription;
  Timer? _sessionCheckTimer;
  StreamSubscription? _userRowSubscription;
  bool _isDemoMode = false; // Demo mode flag

  // PERFORMANCE: Cache service for 4G optimization (selective caching for auth flows)
  final _responseCache = ResponseCacheService();
  final _networkQuality = NetworkQualityService();

  // WhatsApp OTP integration
  String? _currentOTP;
  String? _currentPhone;
  String? _verifiedPhone; // Store the verified phone number for registration
  String? _lastVerifiedCode;
  int? _otpRetryAfterSeconds;
  String? _lastServerComputedPassword;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _user != null || _isDemoMode;
  bool get isDemoMode => _isDemoMode;
  bool get isVerified => _user?.isVerified ?? false;
  String? get verifiedPhone => _verifiedPhone;
  String? get lastVerifiedCode => _lastVerifiedCode;
  int? get otpRetryAfterSeconds => _otpRetryAfterSeconds;

  AuthProvider() {
    // Listen to auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      // Use Future to prevent setState during build
      Future.microtask(() {
        final session = data.session;
        if (session != null) {
          // User signed in, load profile
          _loadUserProfile();
        } else {
          // User signed out
          _user = null;
          _isDemoMode = false;
          notifyListeners();
        }
      });
    });
    
    // Listen to app lifecycle
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionSubscription?.cancel();
    _sessionCheckTimer?.cancel();
    _userRowSubscription?.cancel();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - immediately check session
      _checkSessionStatusDirectly();
    }
  }

  // Initialize auth state
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      // Get device ID
      _deviceId = await DeviceManager.getDeviceId();
      print('Device ID: $_deviceId');
      
      // Get current session (Supabase auto-loads from secure storage)
      var session = Supabase.instance.client.auth.currentSession;
      
      // If session exists but is expired, try to refresh it first
      if (session != null && session.expiresAt != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final expiresAt = session.expiresAt!;
        
        // If session is expired or will expire soon (within 1 minute), try to refresh
        if (now >= expiresAt - 60000) {
          // Refresh if expires in less than 1 minute
          print('🔄 Session expired or expiring soon, attempting refresh...');
          try {
            // Try to refresh the session using the refresh token
            final refreshedSession =
                await Supabase.instance.client.auth.refreshSession();
            if (refreshedSession.session != null) {
              session = refreshedSession.session;
              print('✅ Session refreshed successfully');
            } else {
              print('⚠️ Session refresh failed - no new session returned');
              // Try to sign out and clear
              try {
                await Supabase.instance.client.auth.signOut();
              } catch (e) {
                print('⚠️ Error during signOut: $e');
              }
              _user = null;
              _error = null;
              _verifiedPhone = null;
              _currentOTP = null;
              _currentPhone = null;
              await _clearUserFromPrefs();
              return;
            }
          } catch (e) {
            print('⚠️ Failed to refresh session: $e');
            final errorString = e.toString().toLowerCase();
            
            // Check for specific refresh token errors that require immediate sign out
            final isRefreshTokenError = errorString.contains('refresh_token_not_found') ||
                errorString.contains('refresh token not found') ||
                errorString.contains('invalid refresh token') ||
                errorString.contains('session_expired') ||
                errorString.contains('revoked by newer login');
            
            // If refresh token is invalid/missing, sign out immediately
            if (isRefreshTokenError || now > expiresAt) {
              print('⚠️ Refresh token invalid or session expired, signing out');
              try {
                await Supabase.instance.client.auth.signOut();
              } catch (signOutError) {
                print('⚠️ Error during signOut: $signOutError');
              }
              _user = null;
              _error = null;
              _verifiedPhone = null;
              _currentOTP = null;
              _currentPhone = null;
              await _clearUserFromPrefs();
              return;
            }
            // For other errors, try to continue with existing session (might still work)
          }
        }
      }
      
      if (session != null) {
        print('✅ Valid session found, loading user profile...');
        await _loadUserProfile();
        
        // Register this device session
        if (_user != null) {
          await _registerDeviceSession();
          _monitorDeviceSessions();
          
          // Force refresh FCM token on app startup
          try {
            print('🔄 Refreshing FCM token on app startup...');
            await FlutterFireNotificationService.refreshFCMToken();
            print('✅ FCM token refreshed on startup');
          } catch (e) {
            print('❌ Failed to refresh FCM token on startup: $e');
          }
        }
      }
    } catch (e) {
      _error = e.toString();
      print('Auth initialization error: $e');
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }
  
  // Register device session and logout other devices
  Future<void> _registerDeviceSession() async {
    if (_user == null || _deviceId == null) return;
    
    try {
      final deviceInfo = await DeviceManager.getDeviceInfo();
      
      await Supabase.instance.client.rpc(
        'register_device_session',
        params: {
          'p_user_id': _user!.id,
          'p_device_id': _deviceId,
          'p_device_info': deviceInfo,
        },
      );
    } catch (e) {
      print('Error registering device session: $e');
      
      // Check for 401 errors (session expired)
      if (e is PostgrestException && e.code == '401') {
        print(
            '🔐 Session expired during device registration - attempting refresh...');
        final refreshed = await _attemptSessionRefresh();
        if (refreshed) {
          print('✅ Session refreshed, retrying device registration...');
          // Retry registration after refresh
          Future.delayed(const Duration(milliseconds: 300), () {
            _registerDeviceSession();
          });
        } else {
          print('🔐 Session refresh failed - forcing logout');
          _forceLogout('انتهت صلاحية الجلسة');
        }
      } else if (e.toString().contains('401') ||
          e.toString().contains('Unauthorized')) {
        print(
            '🔐 Unauthorized access during device registration - attempting refresh...');
        final refreshed = await _attemptSessionRefresh();
        if (!refreshed) {
          print('🔐 Session refresh failed - forcing logout');
          _forceLogout('انتهت صلاحية الجلسة');
        }
      }
    }
  }
  
  // Monitor for other device logins (will force logout this device)
  // PERFORMANCE FIX: Removed real-time subscription - using polling only
  // This reduces ~30 subscriptions (one per user) and WAL polling overhead
  // Polling every 2 seconds is sufficient for session monitoring
  void _monitorDeviceSessions() {
    if (_user == null || _deviceId == null) return;
    
    // Cancel existing subscriptions
    _sessionSubscription?.cancel();
    _sessionCheckTimer?.cancel();
    
    // PERFORMANCE FIX: Removed real-time stream - using polling only
    // Real-time subscription was redundant since we're already polling every 2 seconds
    // This reduces subscription overhead by ~30 subscriptions
    
    // Polling (every 15 seconds) - sufficient for session monitoring
    // 2s was 1,800 DB queries/hour per user; 15s reduces this to 240.
    _sessionCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkSessionStatusDirectly();
    });
    
    // Immediate check after registration
    Future.delayed(const Duration(milliseconds: 500), () {
      _checkSessionStatusDirectly();
    });
  }
  
  // Check session status from stream data
  void _checkSessionStatus(List<Map<String, dynamic>> data) {
    if (_user == null || _deviceId == null) return;
    
    final ourSession = data.firstWhere(
      (session) => session['device_id'] == _deviceId,
      orElse: () => {},
    );
    
    // Check if session is inactive - handle both boolean and null cases
    if (ourSession.isNotEmpty) {
      final isActive = ourSession['is_active'];
      if (isActive == false || isActive == null) {
        _forceLogout('تم تسجيل الدخول من جهاز آخر');
      }
    }
  }
  
  // Check session status directly from database (fallback)
  Future<void> _checkSessionStatusDirectly() async {
    if (_user == null || _deviceId == null) return;
    
    try {
      final userId = _user!.id;
      final deviceId = _deviceId!;
      
      final result = await Supabase.instance.client
          .from('device_sessions')
          .select('is_active')
          .eq('user_id', userId)
          .eq('device_id', deviceId)
          .maybeSingle();
      
      // If session not found or is_active is false, force logout
      if (result == null) {
        // Session was deleted - logout
        _forceLogout('تم تسجيل الدخول من جهاز آخر');
      } else {
        final isActive = result['is_active'];
        if (isActive == false || isActive == null) {
          _forceLogout('تم تسجيل الدخول من جهاز آخر');
        }
      }
    } catch (e) {
      // Check if this is a 401 error (session expired)
      if (e is PostgrestException && e.code == '401') {
        print('🔐 Session expired (401) - attempting refresh before logout...');
        // Try to refresh session before logging out
        final refreshed = await _attemptSessionRefresh();
        if (!refreshed) {
          print('🔐 Session refresh failed - forcing logout');
          _forceLogout('انتهت صلاحية الجلسة');
        } else {
          print('✅ Session refreshed, retrying session check...');
          // Retry the check after refresh
          Future.delayed(const Duration(milliseconds: 500), () {
            _checkSessionStatusDirectly();
          });
        }
      } else if (e.toString().contains('401') ||
          e.toString().contains('Unauthorized')) {
        print(
            '🔐 Unauthorized access (401) - attempting refresh before logout...');
        final refreshed = await _attemptSessionRefresh();
        if (!refreshed) {
          print('🔐 Session refresh failed - forcing logout');
          _forceLogout('انتهت صلاحية الجلسة');
        }
      }
      // For other errors, silent fail to not disrupt user experience
    }
  }
  
  bool _isLoggingOut = false; // Prevent multiple simultaneous logout calls
  
  // Attempt to refresh the current session
  Future<bool> _attemptSessionRefresh() async {
    try {
      final currentSession = Supabase.instance.client.auth.currentSession;
      if (currentSession == null) {
        print('⚠️ No current session to refresh');
        return false;
      }
      
      print('🔄 Attempting to refresh session...');
      final refreshedSession =
          await Supabase.instance.client.auth.refreshSession();
      
      if (refreshedSession.session != null) {
        print('✅ Session refreshed successfully');
        return true;
      } else {
        print('⚠️ Session refresh returned null');
        return false;
      }
    } catch (e) {
      print('❌ Failed to refresh session: $e');
      final errorString = e.toString().toLowerCase();
      
      // Check for refresh token errors that indicate the token is invalid
      final isRefreshTokenError = errorString.contains('refresh_token_not_found') ||
          errorString.contains('refresh token not found') ||
          errorString.contains('invalid refresh token') ||
          errorString.contains('session_expired') ||
          errorString.contains('revoked by newer login');
      
      if (isRefreshTokenError) {
        print('⚠️ Refresh token is invalid, clearing session');
        try {
          await Supabase.instance.client.auth.signOut();
        } catch (signOutError) {
          print('⚠️ Error during signOut: $signOutError');
        }
      }
      
      return false;
    }
  }
  
  // Force logout (called when another device logs in)
  Future<void> _forceLogout(String reason) async {
    // Prevent multiple logout calls
    if (_user == null || _isLoggingOut) return;
    
    _isLoggingOut = true;
    print('==================================================');
    print('🚪 FORCE LOGOUT TRIGGERED');
    print('   Reason: $reason');
    print('   Time: ${DateTime.now()}');
    print('==================================================');
    
    // Cancel monitoring
    _sessionSubscription?.cancel();
    _sessionCheckTimer?.cancel();
    
    // Clear local data
    final userId = _user!.id;
    _user = null;
    _error = reason;
    await _clearUserFromPrefs();
    
    // Mark device session as logged out in database
    try {
      if (_deviceId != null) {
        await Supabase.instance.client.rpc(
          'logout_device_session',
          params: {
            'p_user_id': userId,
            'p_device_id': _deviceId,
          },
        );
      }
    } catch (e) {
      // Silent fail
    }
    
    // Sign out from Supabase
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      print('⚠️ Error during force logout signOut: $e');
      // Silent fail - continue with local cleanup
    }
    
    _isDemoMode = false;
    _isLoggingOut = false;
    notifyListeners();
  }

  // Phone number login with WhatsApp
  Future<bool> loginWithPhone(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Validate phone number format
      if (!_isValidPhoneNumber(phone)) {
        _error = 'رقم الهاتف غير صحيح';
        return false;
      }

      // Generate 6-digit OTP
      final otp = _generateOTP();
      _currentOTP = otp;
      _currentPhone = phone;

      // Do not log OTP or phone in release for security

      // Send OTP via WhatsApp using Baileys
      final response = await WhatsAppService.sendOTP(
        phoneNumber: phone,
        otp: otp,
      );

      if (response.success) {
        print('✅ OTP sent successfully via WhatsApp');
        return true;
      } else {
        print('❌ WhatsApp failed: ${response.message}');
        _error = response.message;
        return false;
      }
    } catch (e) {
      print('❌ Login error: $e');
      _error = _getErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Generate 6-digit OTP
  String _generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // =============== WhatsApp OTP Flow (server delivers, local verify) ===============
  Future<bool> sendOtpViaOtpiq(String phone,
      {String purpose = 'signup'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // Clean and normalize phone number (remove +, ensure 964 format)
      final cleaned = _cleanPhoneNumber(phone).replaceAll('+', '');
      
      // CLIENT-SIDE VALIDATION: Check if user exists before sending OTP
      // This provides immediate feedback without wasting an OTP
      // NOTE: This is a best-effort check - if it fails, we continue with OTP flow
      try {
        // Try multiple phone number formats to ensure we find the user
        // Phone numbers might be stored with or without +, with or without leading zeros
        final phoneVariations = [
          cleaned,                    // 9647812345678
          '+$cleaned',               // +9647812345678
          cleaned.replaceFirst('964', '0'), // 07812345678 (if applicable)
        ];
        
        // Remove duplicates
        final uniqueVariations = phoneVariations.toSet().toList();
        
        print('🔍 [VALIDATION] Checking user existence with phone variations: $uniqueVariations');
        
        // Try to find user with any of the phone variations
        Map<String, dynamic>? existingProfile;
        for (final phoneVar in uniqueVariations) {
          try {
            final result = await Supabase.instance.client
                .from('users')
                .select('id, role, name')
                .eq('phone', phoneVar)
                .maybeSingle();
            
            if (result != null) {
              existingProfile = result;
              print('✅ [VALIDATION] Found user with phone format: $phoneVar');
              break;
            }
          } catch (e) {
            print('⚠️ [VALIDATION] Error checking phone format $phoneVar: $e');
            continue; // Try next format
          }
        }
        
        // If still not found, try OR query as fallback
        if (existingProfile == null && uniqueVariations.length > 1) {
          try {
            final orQuery = uniqueVariations
                .map((v) => 'phone.eq.$v')
                .join(',');
            final result = await Supabase.instance.client
                .from('users')
                .select('id, role, name')
                .or(orQuery)
                .maybeSingle();
            
            if (result != null) {
              existingProfile = result;
              print('✅ [VALIDATION] Found user with OR query');
            }
          } catch (e) {
            print('⚠️ [VALIDATION] Error with OR query: $e');
          }
        }
        
        // Only show warning for signup if we're confident user exists
        // For login, never block - let backend handle validation
        if (purpose == 'signup' && existingProfile != null) {
          // Double-check: make sure we have valid user data
          final userId = existingProfile['id'] as String?;
          final userName = existingProfile['name'] as String?;
          
          // Only block if we have a valid user ID and name
          if (userId != null && userId.isNotEmpty && userName != null && userName.isNotEmpty) {
            final userRole = existingProfile['role'] as String? ?? 'غير معروف';
            String roleArabic = userRole == 'merchant' ? 'تاجر' : 
                               userRole == 'driver' ? 'سائق' : 
                               userRole == 'customer' ? 'عميل' : userRole;
            
            print('❌ [VALIDATION] User already exists for phone: $cleaned');
            print('   User name: $userName, Role: $roleArabic');
            
            _error = 'يوجد حساب مسجل مسبقاً بهذا الرقم.\nاسم المستخدم: $userName\nنوع الحساب: $roleArabic\n\nيرجى تسجيل الدخول بدلاً من إنشاء حساب جديد.';
            return false;
          } else {
            // Invalid data - don't trust this result, continue with signup
            print('⚠️ [VALIDATION] Found profile but data seems invalid - continuing with signup');
          }
        }
        
        // For login (reset_password), never block based on client-side check
        // Let the backend OTP handler determine if user exists
        if (purpose == 'reset_password') {
          if (existingProfile == null) {
            print('ℹ️ [VALIDATION] No account found in client check for phone: $cleaned');
            print('   Continuing with OTP - backend will validate');
          } else {
            print('✅ [VALIDATION] Account found - proceeding with login OTP');
          }
          // Always continue - don't block login attempts
        }
        
        if (existingProfile != null) {
          print('✅ [VALIDATION] User exists for login/password reset');
        } else {
          print('✅ [VALIDATION] No existing user - proceeding with signup');
        }
      } catch (validationError) {
        print('⚠️ [VALIDATION] Error checking user existence: $validationError');
        print('⚠️ [VALIDATION] Continuing with OTP flow despite validation error');
        // Continue with OTP flow even if validation fails - don't block the user
        // This ensures users aren't blocked by client-side validation errors
      }
      
      // Call Supabase Edge Function
      print('📤 [DEBUG] Sending OTP via Edge Function');
      print('📤 [DEBUG] Phone: $cleaned, Purpose: $purpose');
      
      FunctionResponse? response;
      try {
        response = await Supabase.instance.client.functions.invoke(
          'otp-handler-clean',  // ✅ Updated to use new optimized function
          body: {
            'action': 'send',
            'phoneNumber': cleaned,
            'purpose': purpose,
          },
        ).timeout(const Duration(seconds: 30));
      } catch (invokeError) {
        print('❌ [ERROR] Function invoke failed: $invokeError');
        print('❌ [ERROR] Error type: ${invokeError.runtimeType}');
        // Check if function doesn't exist or isn't deployed
        if (invokeError.toString().contains('404') || 
            invokeError.toString().contains('not found') ||
            invokeError.toString().contains('Function not found')) {
          _error =
              'الدالة غير متاحة. الرجاء التأكد من نشر الدالة على Supabase.';
          return false;
        }
        rethrow;
      }

      print('✅ [DEBUG] OTP send response status: ${response.status}');
      print('✅ [DEBUG] OTP send response data: ${response.data}');
      
      _otpRetryAfterSeconds = null;
      
      if (response.status != 200) {
        try {
          final data = response.data as Map<String, dynamic>?;
          print('❌ [ERROR] Edge Function error response: $data');
          
          final errorMsg = data?['error'] as String?;
          
          // Handle rate limit (429) - prioritize error message from edge function
          if (response.status == 429) {
            final retry = (data?['retry_after'] is num)
                ? (data!['retry_after'] as num).toInt()
                : null;
            
            // If there's a retry_after, show countdown message
            if (retry != null && retry > 0) {
              _otpRetryAfterSeconds = retry;
              _error = 'الرجاء الانتظار $retry ثانية قبل إعادة الإرسال';
            } else if (errorMsg != null && errorMsg.isNotEmpty) {
              // Use the Arabic error message from edge function (IP rate limit)
              _error = errorMsg;
            } else {
              // Fallback message
              _error = 'عذرًا لقد تجاوزت الحد المسموح من المحاولات. يرجى اعادة المحاولة لاحقًا.';
            }
          } else {
            // For other errors, use the error message from response or fallback
            _error = errorMsg?.isNotEmpty == true
                ? errorMsg!
                : 'فشل إرسال رمز التحقق، الرجاء المحاولة لاحقاً';
          }
        } catch (_) {
          _error = 'فشل إرسال رمز التحقق، الرجاء المحاولة لاحقاً';
        }
        return false;
      }
      
      // Store current phone for verification step
      _currentPhone = phone;
      print('✅ [SUCCESS] OTP sent successfully via Edge Function');
      return true;
    } catch (e, stackTrace) {
      print('❌ [ERROR] sendOtpViaOtpiq error: $e');
      print('❌ [ERROR] Error type: ${e.runtimeType}');
      print('❌ [ERROR] Stack trace: $stackTrace');
      
      // Check if it's a network error
      if (e.toString().contains('timeout') ||
          e.toString().contains('TimeoutException')) {
        _error =
            'انتهت مهلة الطلب. يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى';
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('network')) {
        _error =
            'خطأ في الاتصال بالإنترنت. يرجى التحقق من الاتصال والمحاولة مرة أخرى';
      } else if (e.toString().contains('404') ||
          e.toString().contains('not found')) {
        _error = 'الدالة غير متاحة. الرجاء التأكد من نشر الدالة على Supabase.';
      } else {
        _error = _getErrorMessage(e);
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyOtpViaOtpiq(String phone, String code,
      {String purpose = 'signup'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final cleaned = _cleanPhoneNumber(phone).replaceAll('+', '');
      
      // Use unified authenticate action - verifies OTP and creates/updates auth account
      print(
          '📤 [DEBUG] Authenticating via Edge Function (unified login/signup)');
      final response = await Supabase.instance.client.functions.invoke(
        'otp-handler-clean',  // ✅ Updated to use new optimized function
        body: {
          'action': 'authenticate',
          'phoneNumber': cleaned,
          'code': code,
        },
      );

      print('✅ [DEBUG] authenticate response status: ${response.status}');
      print('✅ [DEBUG] authenticate response data: ${response.data}');
      
      if (response.status != 200) {
        final data = response.data as Map<String, dynamic>?;
        _error = (data?['error'] as String?) ?? 'فشل التحقق من رمز التحقق';
        return false;
      }
      
      final data = response.data as Map<String, dynamic>?;
      final success = data?['success'] as bool? ?? false;
      
      if (!success) {
        _error = (data?['error'] as String?) ?? 'رمز التحقق غير صحيح';
        return false;
      }
      
      // NEW: Extract session tokens directly from response (otp-handler-clean returns session)
      final sessionData = data?['session'] as Map<String, dynamic>?;
      
      if (sessionData != null && 
          sessionData['access_token'] != null && 
          sessionData['refresh_token'] != null) {
        // Use the session tokens directly (new optimized handler)
        print('🔐 [DEBUG] Using session tokens from Edge Function (otp-handler-clean)');
        
        try {
          // CRITICAL: Use setSession to directly set the session from the Edge Function
          // This avoids the need to sign in again
          print('🔑 [DEBUG] Setting session from Edge Function tokens');
          
          final refreshToken = sessionData['refresh_token'] as String;
          
          // Set the session directly using only the refresh token
          // Supabase Flutter will automatically fetch and validate the access token
          final authResponse = await Supabase.instance.client.auth.setSession(
            refreshToken,
          );
          
          // Verify session was set successfully
          if (authResponse.session == null || authResponse.user == null) {
            print('❌ [DEBUG] Failed to set session - no user or session returned');
            _error = 'فشل تسجيل الدخول';
            return false;
          }
          
          print('✅ [DEBUG] Session set successfully');
          print('   User ID: ${authResponse.user?.id}');
          print('   Session expires at: ${authResponse.session?.expiresAt}');
          
          // Verify the session is actually active
          final currentUser = Supabase.instance.client.auth.currentUser;
          if (currentUser == null) {
            print('❌ [DEBUG] Session was set but currentUser is still null!');
            _error = 'فشل تسجيل الدخول';
            return false;
          }
          print('✅ [DEBUG] Current user confirmed: ${currentUser.id}');
          
          // Load user profile
          print('📥 [DEBUG] Loading user profile...');
          await _loadUserProfile();
          print('✅ [DEBUG] Profile loading complete');
          
          _verifiedPhone = phone;
          _lastVerifiedCode = code;
          
          print('✅ [DEBUG] User profile loaded, authentication complete');
          return true;
        } catch (sessionError) {
          print('❌ [DEBUG] Failed to set session: $sessionError');
          print('   Error type: ${sessionError.runtimeType}');
          print('   Error details: ${sessionError.toString()}');
          _error = 'فشل تسجيل الدخول. يرجى المحاولة مرة أخرى.';
          return false;
        }
      }
      
      // FALLBACK: Old handler format (email/password)
      print('🔐 [DEBUG] Using email/password format (legacy otp-handler)');
      final email = data?['email'] as String?;
      final password = data?['password'] as String?;
      
      if (email == null || password == null) {
        _error = 'تعذر الحصول على بيانات الحساب من الخادم';
        return false;
      }
      
      print('🔐 [DEBUG] Signing in with credentials from Edge Function');
      
      // Sign in with the credentials returned by Edge Function
      try {
        final signInRes =
            await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        
        if (signInRes.user == null) {
          _error = 'فشل تسجيل الدخول';
          return false;
        }
        
        print('✅ [DEBUG] Auth sign-in successful for $email');
        
        // Load user profile
        await _loadUserProfile();
        
        _verifiedPhone = phone;
        _lastVerifiedCode = code;
        
        return true;
      } catch (signInError) {
        print('❌ [DEBUG] Sign-in failed: $signInError');

        final legacyEmail = email.endsWith('@hur.delivery')
            ? email.replaceFirst('@hur.delivery', '@hurdelivery.com')
            : null;

        if (legacyEmail != null) {
          try {
            print(
                '🔐 [DEBUG] Retrying sign-in with legacy domain: $legacyEmail');
            final legacyRes =
                await Supabase.instance.client.auth.signInWithPassword(
              email: legacyEmail,
              password: password,
            );

            if (legacyRes.user != null) {
              print('✅ [DEBUG] Auth sign-in successful for $legacyEmail');
              await _loadUserProfile();
              _verifiedPhone = phone;
              _lastVerifiedCode = code;
              return true;
            }
          } catch (legacyError) {
            print('❌ [DEBUG] Legacy sign-in also failed: $legacyError');
          }
        }

        _error = 'فشل تسجيل الدخول. يرجى المحاولة مرة أخرى.';
        return false;
      }
    } catch (e) {
      print('❌ authenticate error: $e');
      _error = _getErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _emailFromPhoneE164(String phoneE164) {
    final noPlus = phoneE164.replaceAll('+', '');
    return '$noPlus@hur.delivery';
  }

  bool isValidNewPassword(String password) {
    final regex = RegExp(r'^[A-Za-z0-9@]{8,}$');
    return regex.hasMatch(password);
  }

  String _generateSecurePassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(16, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<bool> signUpWithPassword(String phoneE164, String password,
      {String? otpCode}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      if (!isValidNewPassword(password)) {
        _error = 'كلمة المرور ضعيفة. استخدم 8 أحرف أو أرقام على الأقل';
        return false;
      }
      
      // CRITICAL FIX: Generate UNIQUE email for new auth accounts
      // Cannot reuse emails based on phone alone - each auth account MUST be unique
      final cleanedPhone = _cleanPhoneNumber(phoneE164).replaceAll('+', '');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final email = '${cleanedPhone}_$timestamp@hur.delivery';
      
      print('🔐 Creating unique auth account with email: $email');
      
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'phone': cleanedPhone,
          'created_at': timestamp,
        },
      );
      if (res.user == null) {
        _error = 'فشل إنشاء الحساب';
        return false;
      }
      _verifiedPhone = phoneE164;
      await _loadUserProfile();
      return true;
    } catch (e) {
      final message = e.toString();
      print('❌ signUpWithPassword error: $e');
      // Handle user already exists (422)
      if (message.contains('user_already_exists') ||
          message.contains('already registered') ||
          message.contains('422')) {
        print('⚠️ User already exists, checking if we can sign in...');
        // If OTP was already verified (consumed), try login with deterministic password
        // Don't try to reset password again - OTP is already consumed
        final cleaned = _cleanPhoneNumber(phoneE164).replaceAll('+', '');
        
        // Derive deterministic password via SECURITY DEFINER RPC.
        // The RPC returns the password string only; id_number is never sent
        // to the client.
        try {
          final deterministicPassword = await Supabase.instance.client
              .rpc('derive_legacy_password', params: {'p_phone': cleaned});

          if (deterministicPassword is String && deterministicPassword.isNotEmpty) {
            print(
                '🔐 Attempting login with deterministic password (phone@idNumber)');
            final loginOk =
                await loginWithPassword(phoneE164, deterministicPassword);
            if (loginOk) {
              print('✅ Logged in with deterministic password');
              return true;
            }
          }
        } catch (_) {}
        
        // If login fails, that's okay - we'll proceed to registration
        // The auth account exists
        print(
            '⚠️ Could not login automatically, but auth account exists - proceed to registration');
        // Return true to allow proceeding to registration
        // Navigation will be handled by the caller based on user role
        return true;
      }
      _error = _getErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithPassword(String phoneE164, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final cleaned = _cleanPhoneNumber(phoneE164);
      final noPlus = cleaned.replaceAll('+', '');
      final emailLegacy = '$noPlus@hurdelivery.com';
      final emailCanon = '$noPlus@hur.delivery';
      // Try legacy then canonical. Ensure a matching profile row exists; otherwise sign out and try next.
      for (final em in [emailLegacy, emailCanon]) {
        try {
          print('🔐 [DEBUG] Attempting login with email: $em');
          final res = await Supabase.instance.client.auth.signInWithPassword(
            email: em,
            password: password,
          );
          if (res.user != null) {
            print('✅ [DEBUG] Auth sign-in successful for $em');
            await _loadUserProfile();
            if (_user != null) {
              print('✅ [DEBUG] Profile loaded successfully');
              return true;
            }
            print(
                '⚠️ [DEBUG] Auth successful but no profile found, attempting repair...');
            // Attempt to repair profile linkage by phone and retry once
            final repaired = await _attemptRelinkProfileByPhone();
            if (repaired) {
              await _loadUserProfile();
              if (_user != null) {
                print('✅ [DEBUG] Profile relinked and loaded');
                return true;
              }
            }
            // No profile attached to this auth user; sign out and try next candidate
            await Supabase.instance.client.auth.signOut();
            print(
                '⚠️ [DEBUG] No profile found after repair, trying next email domain...');
          }
        } catch (e) {
          print('❌ [DEBUG] Login failed for $em: $e');
          print('❌ [DEBUG] Error type: ${e.runtimeType}');
          print('❌ [DEBUG] Error string: ${e.toString()}');
          // Log password format for debugging (first 5 chars only)
          if (password.length > 5) {
            print(
                '❌ [DEBUG] Password format: ${password.substring(0, 5)}...${password.substring(password.length - 3)}');
          }
          // Check if it's an invalid credentials error
          if (e.toString().contains('Invalid login credentials') || 
              e.toString().contains('400') ||
              e.toString().contains('invalid_credentials')) {
            print(
                '⚠️ [DEBUG] Invalid credentials - email format or password mismatch');
            print('⚠️ [DEBUG] Tried email: $em');
            print('⚠️ [DEBUG] Password length: ${password.length}');
          }
        }
      }
      _error = 'بيانات الدخول غير صحيحة';
      return false;
    } catch (e) {
      _error = _getErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _ensureProfileForCurrentAuthUser() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return false;
      // Derive phone in both forms
      String? phone = currentUser.phone;
      if (phone == null || phone.isEmpty) {
        final email = currentUser.email ?? '';
        final local = email.split('@').first;
        if (RegExp(r'^\d{11,15}$').hasMatch(local)) {
          phone = '+$local';
        }
      }
      if (phone == null || phone.isEmpty) return false;
      final cleaned = _cleanPhoneNumber(phone);
      final noPlus = cleaned.replaceAll('+', '');
      // Find an existing user row by phone
      final candidates = await Supabase.instance.client
          .from('users')
          .select()
          .or('phone.eq.$cleaned,phone.eq.$noPlus')
          .limit(1);
      if (candidates.isNotEmpty) {
        final row = Map<String, dynamic>.from(candidates.first as Map);
        final oldId = row['id'] as String?;
        if (oldId == null || oldId == currentUser.id) return false;
        // Update the primary key id to the current auth user id
        final updated = await Supabase.instance.client.from('users').update({
          'id': currentUser.id,
          'updated_at': DateTime.now().toIso8601String()
        }).eq('id', oldId);
        return updated != null;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _attemptRelinkProfileByPhone() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return false;
      String? phone = currentUser.phone;
      if (phone == null || phone.isEmpty) {
        final email = currentUser.email ?? '';
        final local = email.split('@').first;
        if (RegExp(r'^\d{11,15}$').hasMatch(local)) {
          phone = '+$local';
        }
      }
      if (phone == null || phone.isEmpty) return false;
      final cleaned = _cleanPhoneNumber(phone);
      final url =
          Uri.parse('${AppConstants.whatsappServerUrl}/admin/relink-user');
      final body =
          jsonEncode({'phoneNumber': cleaned, 'authUserId': currentUser.id});
      final resp = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return resp.body.contains('true');
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPasswordReset(String phoneE164) async {
    return await sendOtpViaOtpiq(phoneE164, purpose: 'reset_password');
  }

  Future<bool> resetPasswordWithOtp({
    required String phoneE164,
    required String code,
    required String newPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // Edge Function will compute secure random password; provided newPassword is ignored
      final cleaned = _cleanPhoneNumber(phoneE164).replaceAll('+', '');
      print('📤 [DEBUG] Resetting password via OTP (Edge Function)');
      
      final response = await Supabase.instance.client.functions.invoke(
        'otp-handler-clean',  // ✅ Updated to use new optimized function
        body: {
          'action': 'authenticate',  // ✅ Changed from 'reset_password' to 'authenticate' (unified action)
          'phoneNumber': cleaned,
          'code': code,
        },
      );

      print('✅ [DEBUG] reset-password response status: ${response.status}');
      print('✅ [DEBUG] reset-password response data: ${response.data}');
      
      if (response.status != 200) {
        final data = response.data as Map<String, dynamic>?;
        final errorMsg = (data?['error'] as String?) ??
            'فشل تحديث كلمة المرور، الرجاء المحاولة لاحقاً';
        print('❌ [DEBUG] reset-password error: $errorMsg');
        _error = errorMsg.contains('OTP')
            ? errorMsg
            : 'فشل تحديث كلمة المرور: $errorMsg';
        return false;
      }
      
      // Extract the computed password from response
      final data = response.data as Map<String, dynamic>?;
      final computed = data?['newPassword'] as String?;
      if (computed != null && computed.isNotEmpty) {
        _lastServerComputedPassword = computed;
        print(
            '✅ [DEBUG] Edge Function computed password received (length: ${computed.length})');
      } else {
        print(
            '⚠️ [DEBUG] Edge Function response missing newPassword field. Response: $data');
        _error = 'تعذر الحصول على كلمة المرور من الخادم';
        return false;
      }
      
      return true;
    } catch (e) {
      print('❌ reset-password-otpiq error: $e');
      _error = _getErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Verify OTP with WhatsApp and create Supabase session
  Future<bool> verifyOTP(String phone, String otp) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Verify OTP locally (WhatsApp doesn't require API verification)
      if (_currentOTP != null && _currentPhone == phone && _currentOTP == otp) {
        print('✅ OTP verified');
      } else {
        print('❌ OTP verification failed');
        _error = 'رمز التحقق غير صحيح';
        return false;
      }

      // Now create or get Supabase user
      await _createOrGetSupabaseUser(phone);

      // Store verified phone for later use in registration
      _verifiedPhone = phone;

      // Load user profile
      await _loadUserProfile();
      
      // Clear OTP data
      _currentOTP = null;
      _currentPhone = null;

      return true;
    } catch (e) {
      print('❌ Verify OTP error: $e');
      _error = _getErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create or get Supabase user for phone authentication
  // CRITICAL FIX: Each user must have a UNIQUE auth account
  // We cannot reuse auth accounts based on phone number alone
  Future<void> _createOrGetSupabaseUser(String phone) async {
    try {
      // Clean and validate phone number
      final cleanedPhone = _cleanPhoneNumber(phone);
      print(
          '🔍 Creating/authenticating user with phone: $phone (cleaned: $cleanedPhone)');
      
      // Validate phone number format
      if (!_isValidPhoneFormat(cleanedPhone)) {
        throw Exception('رقم الهاتف غير صحيح. يجب أن يبدأ بـ +964');
      }
      
      // CRITICAL: Check if an auth account already exists for this phone number
      // by looking up in the users table (profile), not by email
      try {
        final existingProfile = await Supabase.instance.client
            .from('users')
            .select('id')
            .eq('phone', cleanedPhone)
            .maybeSingle();
        
        if (existingProfile != null) {
          final existingUserId = existingProfile['id'] as String;
          print('✅ Found existing profile for phone, user ID: $existingUserId');
          
          // Try to sign in with this user's credentials
          // Use deterministic password based on phone
          final password = _generatePasswordForPhone(cleanedPhone);
          final emailNoPlus = cleanedPhone.replaceAll('+', '');
          final email = '$emailNoPlus@hur.delivery';
          
          try {
            final signInResponse =
                await Supabase.instance.client.auth.signInWithPassword(
              email: email,
              password: password,
            );
            
            if (signInResponse.user != null) {
              print('✅ Signed in to existing account');
              return;
            }
          } catch (signInError) {
            // Try legacy email format
            try {
              final legacyEmail = '$emailNoPlus@hurdelivery.com';
              final legacyResponse =
                  await Supabase.instance.client.auth.signInWithPassword(
                email: legacyEmail,
                password: password,
              );
              
              if (legacyResponse.user != null) {
                print('✅ Signed in to existing account (legacy)');
                return;
              }
            } catch (_) {}
            
            print('⚠️ Could not sign in to existing account: $signInError');
            throw Exception(
                'حسابك موجود ولكن حدث خطأ في تسجيل الدخول. يرجى التواصل مع الدعم الفني.');
          }
        }
      } catch (e) {
        if (e.toString().contains('حسابك موجود')) {
          rethrow;
        }
        print('⚠️ Error checking for existing profile: $e');
        // Continue to create new account
      }
      
      // No existing profile found - create new auth account
      // CRITICAL: Generate UNIQUE credentials for this new user
      // Use timestamp + phone to ensure uniqueness
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final password = _generatePasswordForPhone(cleanedPhone);
      final emailNoPlus = cleanedPhone.replaceAll('+', '');
      
      // Create unique email using timestamp to prevent collisions
      // Format: {phone}_{timestamp}@hur.delivery
      final email = '${emailNoPlus}_$timestamp@hur.delivery';
      
      print('🔐 Creating NEW auth account with unique email');
      print('   Phone: $cleanedPhone');
      // Do not log email/password in production
      
      try {
        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {
            'phone': cleanedPhone,
            'created_at': timestamp,
          },
        );
        
        if (response.user != null) {
          print('✅ Created new unique auth account: ${response.user!.id}');
          print('   This account is unique and will not be shared with other users');
        } else {
          throw Exception('فشل إنشاء الحساب');
        }
      } catch (signUpError) {
        print('❌ Sign up failed: $signUpError');
        print('❌ Sign up error type: ${signUpError.runtimeType}');
        
        // Check for specific errors
        if (signUpError.toString().contains('400') || 
            signUpError.toString().contains('Bad Request')) {
          throw Exception('خطأ في تنسيق البيانات. يرجى المحاولة مرة أخرى.');
        }
        
        if (signUpError.toString().contains('already registered') || 
            signUpError.toString().contains('User already registered')) {
          throw Exception(
              'حسابك موجود بالفعل. يرجى تسجيل الدخول بدلاً من التسجيل.');
        }
        
        throw Exception('فشل في إنشاء الحساب. يرجى المحاولة مرة أخرى.');
      }
    } catch (e) {
      print('❌ Supabase user creation error: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to authenticate with Supabase: $e');
    }
  }

  // Validate phone number format (E.164)
  bool _isValidPhoneFormat(String phone) {
    // Check if phone starts with +964 and has reasonable length (10-11 digits after country code)
    if (!phone.startsWith('+964')) return false;
    
    final digitsAfterCountryCode = phone.substring(4); // Remove '+964'
    return digitsAfterCountryCode.length >= 10 &&
        digitsAfterCountryCode.length <= 11;
  }

  // Clean phone number for consistent formatting
  String _cleanPhoneNumber(String phone) {
    // Remove all non-digit characters
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Remove leading zeros
    cleaned = cleaned.replaceFirst(RegExp(r'^0+'), '');
    
    // Ensure it starts with country code if it doesn't already
    if (!cleaned.startsWith('964')) {
      cleaned = '964$cleaned';
    }
    
    // Return in E.164 format for Supabase auth
    return '+$cleaned';
  }


  // Generate deterministic password for Supabase based on phone
  String _generatePasswordForPhone(String phone) {
    // Use a deterministic password based on phone number
    // This allows us to use the same password for the same phone
    // Remove the + sign and use a simple but consistent hash
    final cleanPhone = phone.replaceAll('+', '');
    
    // Create a simple hash by summing the digits
    int hash = 0;
    for (int i = 0; i < cleanPhone.length; i++) {
      hash += cleanPhone.codeUnitAt(i);
    }
    
    // Ensure positive and reasonable length
    final String basePassword = 'whatsapp_auth_${hash.abs()}';
    // Do not log generated passwords or phone numbers
    return basePassword;
  }

  // Load user profile (public method for external calls)
  Future<void> loadUserProfile() async {
    await _loadUserProfile();
    notifyListeners();
  }

  // Load user profile
  // PERFORMANCE: Cache for 3 minutes (only on slow connections, keep auth flows fresh)
  Future<void> _loadUserProfile() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        print('⚠️ No current auth user found');
        return;
      }

      final cacheKey = 'user_profile_${currentUser.id}';

      // Only use cache on slow connections to keep auth fresh
      if (_networkQuality.isSlowConnection) {
        final cached = _responseCache.get<Map<String, dynamic>>(cacheKey);
        if (cached != null) {
          print('✅ Using cached user profile (slow connection)');
          _user = UserModel.fromJson(cached);
          await _saveUserToPrefs();
          notifyListeners();
          return; // Return cached, don't refresh on slow connection
        }
      }

      print('🔍 Loading user profile for: ${currentUser.id}');

      // First try to find by auth user ID
      var response = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', currentUser.id)
          .maybeSingle();

      print('📦 User profile response (by ID): $response');

      // If not found by ID, try to find by phone and relink
      if (response == null) {
        print(
            '⚠️ Profile not found by auth ID, attempting to find by phone...');
        String? phone = currentUser.phone;
        if (phone == null || phone.isEmpty) {
          final email = currentUser.email ?? '';
          final local = email.split('@').first;
          if (RegExp(r'^\d{11,15}$').hasMatch(local)) {
            phone = local;
          }
        }
        
        if (phone != null && phone.isNotEmpty) {
          // Normalize phone number format
          String cleanedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
          // Remove leading zeros
          cleanedPhone = cleanedPhone.replaceFirst(RegExp(r'^0+'), '');
          
          // The database stores phone as +9649990000002, so we need to match both formats
          // Try multiple formats: +9649990000002, 9649990000002, +9649990000002
          final phoneWithPlus = '+$cleanedPhone';
          
          print(
              '🔍 Searching for profile with phone: $cleanedPhone or $phoneWithPlus');
          print('🔍 Original phone from auth: $phone');
          
          // Try to find user by phone (try both formats)
          Map<String, dynamic>? phoneResponse;
          try {
            phoneResponse = await Supabase.instance.client
                .from('users')
                .select()
                .or('phone.eq.$cleanedPhone,phone.eq.$phoneWithPlus')
                .maybeSingle();
          } catch (e) {
            print('⚠️ Error querying by phone: $e');
            // Try single format queries as fallback
            try {
              phoneResponse = await Supabase.instance.client
                  .from('users')
                  .select()
                  .eq('phone', phoneWithPlus)
                  .maybeSingle();
            } catch (e2) {
              print('⚠️ Error querying by phone with +: $e2');
              try {
                phoneResponse = await Supabase.instance.client
                    .from('users')
                    .select()
                    .eq('phone', cleanedPhone)
                    .maybeSingle();
              } catch (e3) {
                print('⚠️ Error querying by phone without +: $e3');
              }
            }
          }
          
          print('📦 User profile response (by phone): $phoneResponse');
          
          if (phoneResponse != null) {
            final foundProfileId = phoneResponse['id'] as String;
            final foundProfilePhone = phoneResponse['phone'] as String? ?? '';
            
            print('🔍 Found profile by phone:');
            print('   Profile ID: $foundProfileId');
            print('   Profile Phone: $foundProfilePhone');
            print('   Auth User ID: ${currentUser.id}');
            print('   Auth Phone: $phone');
            
            // Check if profile ID matches auth user ID
            if (foundProfileId != currentUser.id) {
              print('⚠️ Profile ID mismatch detected (found by phone)');
              print('   Found profile ID: $foundProfileId');
              print('   Current auth user ID: ${currentUser.id}');
              print('   Profile phone: $foundProfilePhone');
              print('   Auth phone: $phone');
              print('   This usually means the profile needs to be relinked');
              
              // Try server-side relink to connect the profile to the current auth user
              print('🔄 Attempting server-side relink...');
              final relinked = await _attemptRelinkProfileByPhone();
              
              if (relinked) {
                // Reload profile with correct ID after relink
                final reloaded = await Supabase.instance.client
                  .from('users')
                  .select()
                  .eq('id', currentUser.id)
                  .maybeSingle();
              
                if (reloaded != null && reloaded['id'] == currentUser.id) {
                  response = reloaded;
                  print('✅ Profile relinked and loaded successfully');
                } else {
                  // Relink succeeded but profile not found - use the found profile anyway
                  // This is safe because the phone number matches
                  print('⚠️ Relink succeeded but profile not reloaded - using found profile');
                  response = phoneResponse;
                }
              } else {
                // Relink failed - but if phone matches, it's likely the same user
                // Use the profile but log the mismatch for investigation
                print('⚠️ Relink failed - using profile found by phone (phone matches)');
                print('   This profile will be used but ID mismatch will be logged');
                response = phoneResponse;
              }
            } else {
              // Profile ID matches - safe to use
              print('✅ Profile ID matches auth user ID - safe to use');
              response = phoneResponse;
            }
          } else {
            print(
                '⚠️ No profile found with phone: $cleanedPhone or $phoneWithPlus');
          }
        } else {
          print('⚠️ Could not extract phone number from auth user');
        }
      }

      if (response != null) {
        // CRITICAL: Validate profile ID matches auth user ID
        final profileId = response['id'] as String?;
        if (profileId != null && profileId != currentUser.id) {
          print('⚠️ Profile ID mismatch in final check');
          print('   Profile ID: $profileId');
          print('   Auth User ID: ${currentUser.id}');
          print('   This profile was found by phone number match');
          print('   Attempting relink to fix ID mismatch...');
          
          // Try relink attempt - this should update the profile ID to match auth user ID
          final relinked = await _attemptRelinkProfileByPhone();
          if (relinked) {
            // Reload profile with correct ID after relink
            final reloaded = await Supabase.instance.client
                .from('users')
                .select()
                .eq('id', currentUser.id)
                .maybeSingle();
            if (reloaded != null) {
              final reloadedId = reloaded['id'] as String?;
              if (reloadedId == currentUser.id) {
              response = reloaded;
              print('✅ Profile relinked successfully on final attempt');
            } else {
                print('⚠️ Relink succeeded but ID still mismatched');
                print('   Reloaded ID: $reloadedId');
                print('   Expected ID: ${currentUser.id}');
                // Force logout for security - ID mismatch is critical
                await _forceLogout('خطأ في التحقق من الهوية. يرجى تسجيل الدخول مرة أخرى.');
                return;
            }
          } else {
              print('⚠️ Relink succeeded but profile not found after reload');
              // Force logout - profile should exist after relink
              await _forceLogout('خطأ في تحميل الملف الشخصي. يرجى تسجيل الدخول مرة أخرى.');
              return;
            }
          } else {
            // Relink failed - this is a critical error
            print('❌ Relink failed - ID mismatch cannot be resolved');
            print('   Profile ID: $profileId');
            print('   Auth User ID: ${currentUser.id}');
            // Force logout for security
            await _forceLogout('خطأ في التحقق من الهوية. يرجى تسجيل الدخول مرة أخرى.');
            return;
          }
        }
        
        print('✅ User profile loaded successfully');
        print('📋 Role: ${response['role']}, Verified: ${response['manual_verified']}');
        print('📋 User ID: ${response['id']}, Phone: ${response['phone']}');
        print('📋 Auth User ID: ${currentUser.id}');
        print('✅ Security check passed: Profile ID matches auth user ID');
        
        // CRITICAL: Validate role is valid and matches database constraint
        final role = response['role'] as String?;
        if (role != null && role.isNotEmpty) {
          final normalizedRole = role.trim().toLowerCase();
          if (!['driver', 'merchant', 'admin', 'customer'].contains(normalizedRole)) {
            print('❌ CRITICAL: Invalid role detected: $role');
            print('   This violates database constraint - user profile is corrupted');
            // Force logout - invalid role means profile is corrupted
            await _forceLogout('خطأ في بيانات المستخدم. يرجى التواصل مع الدعم الفني.');
            return;
          } else {
            print('✅ Role validation passed: $normalizedRole');
          }
        } else {
          print('❌ CRITICAL: User profile has no role!');
          print('   Role is required by database constraint');
          // Force logout - missing role means profile is incomplete
          await _forceLogout('ملف المستخدم غير مكتمل. يرجى إكمال التسجيل.');
          return;
        }
        
        _user = UserModel.fromJson(response);
        await _saveUserToPrefs();

        // PERFORMANCE: Cache profile for 3 minutes (on slow connections only)
        final cacheKey = 'user_profile_${currentUser.id}';
        _responseCache.set(cacheKey, response, const Duration(minutes: 3));
        print('💾 Cached user profile');

        // Register device session and start monitoring (logout other devices)
        await _registerDeviceSession();
        _monitorDeviceSessions();

        // Subscribe to user row for live is_online sync
        _subscribeToUserRow();
        
        // Force immediate session check after registration
        await Future.delayed(const Duration(milliseconds: 500));
        await _checkSessionStatusDirectly();
        await Future.delayed(const Duration(milliseconds: 1000));
        await _checkSessionStatusDirectly();
        
        // Initialize FCM with token generation after successful login
        try {
          print('🔄 Initializing FCM with token after login...');
          await FlutterFireNotificationService.initializeWithToken();
          print('✅ FCM token initialized');
        } catch (e) {
          print('❌ Failed to initialize FCM token: $e');
        }
      } else {
        // Attempt server-side relink by phone, then retry once
        print('⚠️ No user profile found in database (new user)');
        final relinked = await _attemptRelinkProfileByPhone();
        if (relinked) {
          print(
              '✅ Relinked users row to current auth id. Retrying profile load...');
          final retry = await Supabase.instance.client
              .from('users')
              .select()
              .eq('id', currentUser.id)
              .maybeSingle();
          if (retry != null) {
            // CRITICAL SECURITY CHECK: Verify the retried profile ID matches
            final retryId = retry['id'] as String?;
            if (retryId != currentUser.id) {
              print('🚨 CRITICAL: Retried profile ID does not match auth user ID!');
              print('   Retry ID: $retryId');
              print('   Expected ID: ${currentUser.id}');
              print('   Forcing logout for security...');
              await _forceLogout('خطأ في التحقق من الهوية. يرجى تسجيل الدخول مرة أخرى.');
              return;
            }
            _user = UserModel.fromJson(retry);
            await _saveUserToPrefs();
          } else {
            _user = null;
          }
        } else {
          _user = null;
        }
      }
    } catch (e) {
      _error = _getErrorMessage(e);
      print('❌ Error loading user profile: $e');
      print('❌ Error type: ${e.runtimeType}');
      if (e is PostgrestException) {
        print('❌ Postgrest error code: ${e.code}');
        print('❌ Postgrest error message: ${e.message}');
        print('❌ Postgrest error details: ${e.details}');
        
        // Check for 401 errors (session expired)
        if (e.code == '401') {
          print(
              '🔐 Session expired during profile load - attempting refresh...');
          final refreshed = await _attemptSessionRefresh();
          if (refreshed) {
            print('✅ Session refreshed, retrying profile load...');
            // Retry loading profile after refresh
            try {
              final currentUser = Supabase.instance.client.auth.currentUser;
              if (currentUser != null) {
                final retry = await Supabase.instance.client
                    .from('users')
                    .select()
                    .eq('id', currentUser.id)
                    .maybeSingle();
                if (retry != null) {
                  _user = UserModel.fromJson(retry);
                  await _saveUserToPrefs();
                  notifyListeners();
                  return;
                }
              }
            } catch (retryError) {
              print('⚠️ Retry after refresh failed: $retryError');
              _forceLogout('انتهت صلاحية الجلسة');
              return;
            }
          } else {
            print('🔐 Session refresh failed - forcing logout');
            _forceLogout('انتهت صلاحية الجلسة');
            return;
          }
        }
      } else if (e.toString().contains('401') ||
          e.toString().contains('Unauthorized')) {
        print(
            '🔐 Unauthorized access during profile load - attempting refresh...');
        final refreshed = await _attemptSessionRefresh();
        if (!refreshed) {
          print('🔐 Session refresh failed - forcing logout');
          _forceLogout('انتهت صلاحية الجلسة');
          return;
        }
      }
      // Don't set _user to null here - keep any existing cached user
      // This prevents logged-in users from being kicked out due to RLS errors
    }
  }

  void _subscribeToUserRow() {
    _userRowSubscription?.cancel();
    final current = _user;
    if (current == null) return;

    _userRowSubscription = Supabase.instance.client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', current.id)
        .listen((rows) {
      if (rows.isEmpty) return;
      final row = rows.first;
      final isOnline = row['is_online'] as bool?;
          if (isOnline != null &&
              _user != null &&
              _user!.isOnline != isOnline) {
            _user =
                _user!.copyWith(isOnline: isOnline, updatedAt: DateTime.now());
        notifyListeners();
      }
    }, onError: (e) {
      // Silent
    });
  }

  // Register user with documents
  Future<bool> registerUser({
    required Map<String, dynamic> userData,
    required File idCardFront,
    required File idCardBack,
    File? selfieWithId,
    File? driverProfilePhoto,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _error = 'المستخدم غير مسجل الدخول';
        print('❌ Registration failed: No current user found');
        return false;
      }

      final userId = currentUser.id;
      print('✅ Current user ID: $userId');
      print('✅ Verified phone: $_verifiedPhone');
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Upload ID card front
      final idFrontPath = 'documents/$userId/id_front_$timestamp.jpg';
      await Supabase.instance.client.storage.from('files').upload(
            idFrontPath,
            idCardFront,
            fileOptions: const FileOptions(
              upsert: true,
              cacheControl: '3600',
            ),
          );
      final idFrontUrl = Supabase.instance.client.storage
          .from('files')
          .getPublicUrl(idFrontPath);

      // Upload ID card back
      final idBackPath = 'documents/$userId/id_back_$timestamp.jpg';
      await Supabase.instance.client.storage.from('files').upload(
            idBackPath,
            idCardBack,
            fileOptions: const FileOptions(
              upsert: true,
              cacheControl: '3600',
            ),
          );
      final idBackUrl = Supabase.instance.client.storage
          .from('files')
          .getPublicUrl(idBackPath);

      // Upload selfie (if driver)
      String? selfieUrl;
      if (selfieWithId != null) {
        final selfiePath = 'documents/$userId/selfie_$timestamp.jpg';
        await Supabase.instance.client.storage.from('files').upload(
              selfiePath,
              selfieWithId,
              fileOptions: const FileOptions(
                upsert: true,
                cacheControl: '3600',
              ),
            );
        selfieUrl = Supabase.instance.client.storage
            .from('files')
            .getPublicUrl(selfiePath);
      }

      // Upload driver profile photo (if provided)
      String? profilePhotoUrl;
      if (driverProfilePhoto != null) {
        final profilePath = 'profiles/$userId/avatar_$timestamp.jpg';
        await Supabase.instance.client.storage.from('files').upload(
              profilePath,
              driverProfilePhoto,
              fileOptions: const FileOptions(
                upsert: true,
                cacheControl: '3600',
              ),
            );
        profilePhotoUrl = Supabase.instance.client.storage
            .from('files')
            .getPublicUrl(profilePath);
      }

      // Ensure phone is in correct format
      final phoneForUser = _verifiedPhone ?? currentUser.phone ?? '';
      final cleanedPhone =
          phoneForUser.isNotEmpty ? _cleanPhoneNumber(phoneForUser) : '';
      if (cleanedPhone.isEmpty) {
        _error = 'رقم الهاتف غير موجود';
        print('❌ Registration failed: No phone number available');
        return false;
      }
      
      String? normalizeRole(String? value) {
        if (value == null) return null;
        final normalized = value.trim().toLowerCase();
        const allowed = {'driver', 'merchant', 'customer', 'admin'};
        if (!allowed.contains(normalized)) {
          print('⚠️ Invalid role detected: $value, normalized: $normalized');
          return null;
      }
        return normalized;
      }

      // Validate and normalize role from userData
      final desiredRole = normalizeRole(userData['role'] as String?);
      
      // Fallback role priority: widget role > existing user role > default
      final fallbackRole = normalizeRole(_user?.role) ??
          normalizeRole(currentUser.userMetadata?['role'] as String?) ??
          'merchant'; // Default to merchant instead of driver for safety

      // Get existing user data to only update missing fields
      final existingUser = await Supabase.instance.client
          .from('users')
          .select('*')
          .eq('id', userId)
          .maybeSingle();
      
      // Build update data - only include fields that are missing or being updated
      final upsertData = <String, dynamic>{
        'id': userId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Only add phone if it doesn't exist or is different
      if (existingUser == null || existingUser['phone'] == null || existingUser['phone'] != cleanedPhone) {
        upsertData['phone'] = cleanedPhone;
      }
      
      // Add user data fields only if they're missing
      for (final entry in userData.entries) {
        // Skip role - handle it separately to ensure it's always set correctly
        if (entry.key == 'role') continue;
        
        if (existingUser == null || existingUser[entry.key] == null || existingUser[entry.key] == '') {
          upsertData[entry.key] = entry.value;
        }
      }
      
      // Add document URLs if provided
      upsertData['id_card_front_url'] = idFrontUrl;
      upsertData['id_card_back_url'] = idBackUrl;
      if (selfieUrl != null) upsertData['selfie_with_id_url'] = selfieUrl;
      
      // CRITICAL: Always set role from userData if provided (registration flow)
      // This ensures the role matches what the user selected during registration
      if (desiredRole != null) {
        print('✅ Setting role from registration: $desiredRole');
        print('   Existing user role: ${existingUser?['role']}');
        upsertData['role'] = desiredRole;
      } else if (existingUser == null) {
        // New user - must have a role, use fallback
        print('⚠️ New user - using fallback role: $fallbackRole');
      upsertData['role'] = fallbackRole;
            } else if (existingUser['role'] == null || (existingUser['role'] as String).trim().isEmpty) {
        // Existing user without role - use fallback
        print('⚠️ Existing user without role - using fallback: $fallbackRole');
        upsertData['role'] = fallbackRole;
            } else {
        // Keep existing role if no new role is provided
        final existingRole = (existingUser['role'] as String).trim().toLowerCase();
        if (['driver', 'merchant', 'customer', 'admin'].contains(existingRole)) {
          print('✅ Keeping existing valid role: $existingRole');
        } else {
          // Invalid role in database - fix it
          print('⚠️ Invalid role in database: $existingRole, fixing to fallback: $fallbackRole');
          upsertData['role'] = fallbackRole;
                }
      }
      
      // Final validation: ensure role is set before insert/update
      if (!upsertData.containsKey('role') || upsertData['role'] == null) {
        print('❌ CRITICAL: Role not set in upsertData!');
        _error = 'خطأ في تحديد نوع المستخدم. يرجى المحاولة مرة أخرى.';
        return false;
      }
      
      // Validate role matches database constraint
      final finalRole = (upsertData['role'] as String).trim().toLowerCase();
      if (!['driver', 'merchant', 'customer', 'admin'].contains(finalRole)) {
        print('❌ CRITICAL: Invalid role after normalization: $finalRole');
        _error = 'نوع المستخدم غير صحيح. يرجى المحاولة مرة أخرى.';
        return false;
      }
      
      // Add other required fields if missing
      if (existingUser == null) {
        upsertData['manual_verified'] = false;
        upsertData['is_online'] = false;
        upsertData['created_at'] = DateTime.now().toIso8601String();
      }

      print('📝 Updating user data...');
      print('📝 User data keys: ${upsertData.keys.toList()}');
      print('📝 Phone: ${upsertData['phone']}');
      print('📝 ID Number: ${upsertData['id_number']}');
      
      // Validate ID number format if document_type is national_id
      if (upsertData.containsKey('id_number') && upsertData['id_number'] != null) {
        final documentType = upsertData['document_type'] as String? ?? 
                            existingUser?['document_type'] as String?;
        if (documentType == 'national_id') {
          final idNumber = upsertData['id_number'] as String;
          final cleanedIdNumber = idNumber.replaceAll(RegExp(r'[^0-9]'), '');
          if (cleanedIdNumber.length != 12) {
            print('❌ ID number must be exactly 12 digits for national_id. Got: ${cleanedIdNumber.length} digits');
            _error = 'رقم الهوية الوطني يجب أن يكون 12 رقمًا بالضبط عندما يكون نوع الوثيقة هو البطاقة الوطنية';
            return false;
          }
          // Use cleaned version
          upsertData['id_number'] = cleanedIdNumber;
        }
      }
      
      Map<String, dynamic> response;
      
      if (existingUser != null) {
        // User exists - use UPDATE to only update missing fields
        print('✅ User profile already exists, updating missing fields...');
        
        // Check ID number uniqueness if it's being updated
        if (upsertData.containsKey('id_number') && upsertData['id_number'] != existingUser['id_number']) {
          final taken = await Supabase.instance.client.rpc(
            'is_id_number_taken',
            params: {
              'p_id_number': upsertData['id_number'],
              'p_excluding': userId,
            },
          );

          if (taken == true) {
            print('❌ ID number already registered to a different user');
            _error = 'رقم الهوية الوطني مسجل بالفعل لحساب آخر. لا يمكن استخدام نفس الهوية لأكثر من حساب.';
            return false;
          }
        }
        
          response = await Supabase.instance.client
              .from('users')
              .update(upsertData)
              .eq('id', userId)
              .select()
              .single();
          print('✅ User data updated successfully');
        } else {
        // New user - check ID number uniqueness before insert
        if (upsertData.containsKey('id_number')) {
          final taken = await Supabase.instance.client.rpc(
            'is_id_number_taken',
            params: {
              'p_id_number': upsertData['id_number'],
              'p_excluding': null,
            },
          );

          if (taken == true) {
            print('❌ ID number already registered to another user');
            _error = 'رقم الهوية الوطني مسجل بالفعل لحساب آخر. لا يمكن استخدام نفس الهوية لأكثر من حساب.';
            return false;
          }
        }
        
        // Insert new user
        response = await Supabase.instance.client
            .from('users')
            .insert(upsertData)
            .select()
            .single();
        
        print('✅ User data inserted successfully');
      }
      
      _user = UserModel.fromJson(response);
      await _saveUserToPrefs();
      
      // CRITICAL: After registration, ensure password format matches Edge Function format
      // Format: phone@id_number (or phone@last6digits if id_number not available)
      try {
        final idNumber =
            (userData['id_number'] ?? response['id_number'])?.toString();
        final phoneForPass = _verifiedPhone ?? currentUser.phone ?? '';
        if (phoneForPass.isNotEmpty) {
          final noPlus = _cleanPhoneNumber(phoneForPass).replaceAll('+', '');
          
          // Use id_number if available, otherwise use last 6 digits of phone (matches Edge Function logic)
          String idPart;
          if (idNumber != null && idNumber.trim().isNotEmpty) {
            idPart = idNumber.trim().replaceAll(RegExp(r'\s+'), '');
          } else {
            // Fallback to last 6 digits of phone (matches Edge Function)
            idPart = noPlus.length >= 6 ? noPlus.substring(noPlus.length - 6) : noPlus;
          }
          
          final deterministicPassword = '$noPlus@$idPart';
          print('🔐 Updating password to deterministic format: $noPlus@***');
          
          await Supabase.instance.client.auth
              .updateUser(UserAttributes(password: deterministicPassword));
          
          print('✅ Password updated to deterministic format');
        }
      } catch (e) {
        print('⚠️ Failed to update password to deterministic format: $e');
        // Don't fail registration if password update fails - user can still login with OTP
      }
      
      // Register device session after successful registration
      await _registerDeviceSession();
      _monitorDeviceSessions();
      
      // Initialize FCM with token generation after successful registration
      try {
        print('🔄 Initializing FCM with token after registration...');
        await FlutterFireNotificationService.initializeWithToken();
        print('✅ FCM token initialized');
      } catch (e) {
        print('❌ Failed to initialize FCM token: $e');
      }
      
      return true;
    } catch (e, stackTrace) {
      print('❌ Registration error: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: $stackTrace');
      
      // Check for specific error types
      if (e.toString().contains('duplicate key') ||
          e.toString().contains('unique constraint')) {
        if (e.toString().contains('id_number')) {
          _error =
              'رقم الهوية الوطني مسجل بالفعل في النظام. لا يمكن استخدام نفس الهوية لأكثر من حساب.';
        } else {
          _error = 'البيانات المدخلة مسجلة بالفعل في النظام';
        }
      } else {
        _error = _getErrorMessage(e);
      }
      
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user profile
  Future<bool> updateProfile({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? fcmToken,
  }) async {
    if (_user == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (address != null) updateData['address'] = address;
      if (latitude != null) updateData['latitude'] = latitude;
      if (longitude != null) updateData['longitude'] = longitude;
      if (fcmToken != null) updateData['fcm_token'] = fcmToken;
      updateData['updated_at'] = DateTime.now().toIso8601String();

      final response = await Supabase.instance.client
          .from('users')
          .update(updateData)
          .eq('id', _user!.id)
          .select()
          .single();

      _user = UserModel.fromJson(response);
      await _saveUserToPrefs();
      
      // Initialize FCM with token generation after successful update
      try {
        print('🔄 Initializing FCM with token after profile update...');
        await FlutterFireNotificationService.initializeWithToken();
        print('✅ FCM token initialized');
      } catch (e) {
        print('❌ Failed to initialize FCM token: $e');
      }
      
      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Set online status
  Future<void> setOnlineStatus(bool isOnline) async {
    if (_user == null) return;
    
    // Prevent going online in demo mode
    if (_isDemoMode) {
      print('⚠️ Cannot set online status in demo mode');
      return;
    }

    try {
      // If going offline, auto-reject any pending orders assigned to this driver
      if (!isOnline && _user!.role == 'driver') {
        print('🚫 Driver going offline - auto-rejecting pending orders');
        
        // Get pending orders for this driver
        final pendingOrders = await Supabase.instance.client
            .from('orders')
            .select('id')
            .eq('driver_id', _user!.id)
            .eq('status', 'pending');
        
        // Reject each pending order
        for (var order in pendingOrders) {
          final orderId = order['id'] as String;
          print('   Rejecting order: $orderId');
          
          await Supabase.instance.client.from('orders').update({
                'status': 'rejected',
                'driver_id': null,
                'driver_assigned_at': null,
                'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', orderId);
        }
        
        if (pendingOrders.isNotEmpty) {
          print('✅ Auto-rejected ${pendingOrders.length} pending order(s)');
        }
      }
      
      // Update online status
      await Supabase.instance.client.from('users').update({
            'is_online': isOnline,
            'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _user!.id);

      // Read-back to confirm and sync
      final readback = await Supabase.instance.client
          .from('users')
          .select('is_online')
          .eq('id', _user!.id)
          .maybeSingle();
      final confirmed =
          (readback != null ? (readback['is_online'] as bool?) : null) ??
              isOnline;
      _user = _user!.copyWith(isOnline: confirmed, updatedAt: DateTime.now());
      notifyListeners();
    } catch (e) {
      _error = _getErrorMessage(e);
      if (_getErrorMessage(e).contains('DRIVER_WALLET_NEGATIVE')) {
        throw Exception('DRIVER_WALLET_NEGATIVE');
      }
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // If in demo mode, just clear demo state
      if (_isDemoMode) {
        exitDemoMode();
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Set offline status
      if (_user != null) {
        await setOnlineStatus(false);
        
        // Dispose FlutterFire notification service
        await FlutterFireNotificationService.dispose();
        
        // Logout device session
        if (_deviceId != null) {
          await Supabase.instance.client.rpc(
            'logout_device_session',
            params: {
              'p_user_id': _user!.id,
              'p_device_id': _deviceId,
            },
          );
        }
      }

      // Cancel session monitoring
      _sessionSubscription?.cancel();
      _sessionCheckTimer?.cancel();

      // Sign out from Supabase
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (e) {
        print('⚠️ Error during logout signOut: $e');
        // Continue with local cleanup even if signOut fails
      }
      
      // Clear local data
      _user = null;
      _error = null;
      _verifiedPhone = null;
      _currentOTP = null;
      _currentPhone = null;
      _isDemoMode = false;
      await _clearUserFromPrefs();
    } catch (e) {
      _error = _getErrorMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save user to preferences
  Future<void> _saveUserToPrefs() async {
    if (_user == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', _user!.toJson().toString());
  }

  // Clear user from preferences
  Future<void> _clearUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
  }

  // Validate phone number
  bool _isValidPhoneNumber(String phone) {
    final regex = RegExp(AppConstants.phonePattern);
    return regex.hasMatch(phone);
  }

  // Get error message
  String _getErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Authentication errors
    if (errorString.contains('invalid login credentials') || 
        errorString.contains('invalid_credentials') ||
        errorString.contains('wrong password')) {
      return 'بيانات الدخول غير صحيحة. يرجى التحقق من رقم الهاتف وكلمة المرور.';
    } 
    
    // User not found errors
    else if (errorString.contains('user not found') || 
             errorString.contains('user_not_found') ||
             errorString.contains('no user found')) {
      return 'لا يوجد حساب مسجل بهذا الرقم.\n\nيرجى إنشاء حساب جديد أولاً.';
    } 
    
    // User already exists errors
    else if (errorString.contains('user already exists') || 
             errorString.contains('user_already_exists') ||
             errorString.contains('already registered') ||
             errorString.contains('phone number already registered') ||
             errorString.contains('422')) {
      return 'يوجد حساب مسجل مسبقاً بهذا الرقم.\n\nيرجى تسجيل الدخول بدلاً من إنشاء حساب جديد.';
    } 
    
    // OTP errors
    else if (errorString.contains('invalid otp') || 
             errorString.contains('incorrect otp') ||
             errorString.contains('wrong otp')) {
      return 'رمز التحقق غير صحيح. يرجى التحقق من الرمز والمحاولة مرة أخرى.';
    } 
    else if (errorString.contains('otp expired') || 
             errorString.contains('code expired')) {
      return 'انتهت صلاحية رمز التحقق. يرجى طلب رمز جديد.';
    }
    
    // Network errors
    else if (errorString.contains('network') || 
             errorString.contains('connection') ||
             errorString.contains('timeout')) {
      return 'خطأ في الاتصال بالإنترنت. يرجى التحقق من اتصالك والمحاولة مرة أخرى.';
    }
    
    // Generic fallback
    else {
      print('⚠️ Unhandled error type: $error');
      return 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Update user location
  Future<bool> updateUserLocation(
    double latitude, 
    double longitude, {
    double? accuracy,
    double? heading,
    double? speed,
  }) async {
    if (_user == null) {
      print('❌ updateUserLocation: No user logged in');
      return false;
    }

    try {
      print(
          '🔄 updateUserLocation: Updating location for ${_user!.name} (${_user!.id})');
      print('   📍 Coordinates: $latitude, $longitude');
      print('   🎯 Accuracy: $accuracy, Heading: $heading, Speed: $speed');
      
      // For drivers, use the comprehensive location function
      // which saves to both users table AND driver_locations table
      if (_user!.isDriver) {
        print('   🚗 Driver detected - using update_driver_location RPC');
        try {
          final result = await Supabase.instance.client
              .rpc('update_driver_location', params: {
            'p_driver_id': _user!.id,
            'p_latitude': latitude,
            'p_longitude': longitude,
            'p_accuracy': accuracy,
            'p_heading': heading,
            'p_speed': speed,
          });
          print('   ✅ RPC result: $result');
          // Check if result indicates success (handles both JSON and boolean returns)
          if (result is Map &&
              (result['success'] == true || result['success'] == 'true')) {
            print('   ✅ Location updated successfully');
          } else if (result == true || result == 'true') {
            // Handle legacy boolean return (backward compatibility)
            print('   ✅ Location updated successfully (boolean response)');
          }
        } catch (rpcError) {
          print('   ❌ RPC call failed: $rpcError');
          // Don't fail the entire update - location tracking should be resilient
          if (rpcError is PostgrestException) {
            print('   ❌ Postgrest error code: ${rpcError.code}');
            print('   ❌ Postgrest error message: ${rpcError.message}');
            // If it's a 300 error, the function might need to be updated
            if (rpcError.code == '300' || rpcError.message.contains('300')) {
              print(
                  '   ⚠️ 300 status detected - function may need JSON return type');
            }
          }
          // Continue anyway - local update will still work
        }
      } else {
        print('   👤 Non-driver - updating users table directly');
        // For non-drivers (merchants), just update users table
        await Supabase.instance.client.from('users').update({
              'latitude': latitude,
              'longitude': longitude,
              'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', _user!.id);
        print('   ✅ Users table updated');
      }

      // Update local user model
      _user = _user!.copyWith(
        latitude: latitude,
        longitude: longitude,
        updatedAt: DateTime.now(),
      );

      print('   ✅ Local user model updated');
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ updateUserLocation error: $e');
      print('❌ Error type: ${e.runtimeType}');
      if (e is PostgrestException) {
        print('❌ Postgrest error code: ${e.code}');
        print('❌ Postgrest error message: ${e.message}');
        print('❌ Postgrest error details: ${e.details}');
      }
      _error = 'Failed to update location: $e';
      notifyListeners();
      return false;
    }
  }

  // Refresh user data from database
  Future<void> refreshUser() async {
    if (_user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', _user!.id)
          .single();

      _user = UserModel.fromJson(response);
      notifyListeners();
        } catch (e) {
      print('Error refreshing user: $e');
    }
  }

  // Enter demo mode with a demo user
  Future<void> enterDemoMode(String role) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Create a demo user model
      _user = UserModel(
        id: 'demo_${role}_${DateTime.now().millisecondsSinceEpoch}',
        name: role == 'merchant' ? 'تاجر تجريبي' : 'سائق تجريبي',
        phone: '+964000000000',
        role: role,
        isOnline: false,
        manualVerified: true,
        verificationStatus: 'approved',
        address: 'عنوان تجريبي',
        latitude: 33.3152, // Default to Najaf coordinates
        longitude: 44.3661,
        city: 'najaf',
        storeName: role == 'merchant' ? 'متجر تجريبي' : null,
        vehicleType: role == 'driver' ? 'motorbike' : null,
        merchantWalkthroughCompleted: true,
        driverWalkthroughCompleted: true,
        createdAt: DateTime.now(),
      );

      _isDemoMode = true;
      _isLoading = false;
      notifyListeners();
      print('✅ Demo mode activated for role: $role');
    } catch (e) {
      _error = 'Failed to enter demo mode: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Exit demo mode
  void exitDemoMode() {
    _isDemoMode = false;
    _user = null;
    notifyListeners();
    print('✅ Demo mode exited');
  }
}
