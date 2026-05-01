import { useState, useEffect, useRef, type FormEvent } from 'react';
import { flushSync } from 'react-dom';
import { useAuthStore } from '../store/authStore';
import { useNavigate } from 'react-router-dom';

export default function Login() {
  // Persist step in sessionStorage to survive remounts
  const getInitialStep = (): 'phone' | 'otp' => {
    const saved = sessionStorage.getItem('login_step');
    return (saved === 'otp' || saved === 'phone') ? saved : 'phone';
  };
  
  const [phoneNumber, setPhoneNumber] = useState(() => {
    return sessionStorage.getItem('login_phone') || '';
  });
  const [otpCode, setOtpCode] = useState('');
  const [step, setStep] = useState<'phone' | 'otp'>(getInitialStep);
  const [error, setError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');
  const [, setForceUpdate] = useState(0); // Force re-render trigger
  const [isSendingOtp, setIsSendingOtp] = useState(false); // Local loading state for OTP send
  const [isVerifyingOtp, setIsVerifyingOtp] = useState(false); // Local loading state for OTP verify
  const { sendOtp, verifyOtp, loading } = useAuthStore();
  const navigate = useNavigate();
  const otpInputRef = useRef<HTMLInputElement>(null);
  const stepRef = useRef(step);
  const renderCountRef = useRef(0);
  const otpSendTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null); // Debounce timeout
  
  // Sync step to sessionStorage whenever it changes
  useEffect(() => {
    sessionStorage.setItem('login_step', step);
    stepRef.current = step;
  }, [step]);
  
  // Sync phone number to sessionStorage
  useEffect(() => {
    if (phoneNumber) {
      sessionStorage.setItem('login_phone', phoneNumber);
    }
  }, [phoneNumber]);

  // Track component mount/unmount and restore step from sessionStorage
  useEffect(() => {
    renderCountRef.current = 0;
    
    // Check sessionStorage and restore step if needed
    const savedStep = sessionStorage.getItem('login_step');
    const savedPhone = sessionStorage.getItem('login_phone');
    
    if (savedStep === 'otp') {
      if (step !== 'otp') {
        setStep('otp');
        stepRef.current = 'otp';
      }
      if (savedPhone && phoneNumber !== savedPhone) {
        setPhoneNumber(savedPhone);
      }
      if (!successMessage) {
        setSuccessMessage('تم إرسال رمز التحقق / OTP sent successfully');
      }
      // Force a re-render
      setForceUpdate(prev => prev + 1);
    }
  }, []); // Only run on mount

  // Track step changes
  useEffect(() => {
    renderCountRef.current++;
    stepRef.current = step;
    
    // Auto-focus OTP input when step changes to 'otp'
    if (step === 'otp') {
      if (otpInputRef.current) {
        setTimeout(() => {
          otpInputRef.current?.focus();
        }, 100);
      }
    }
  }, [step]);

  const handlePhoneSubmit = async (e?: React.MouseEvent | FormEvent) => {
    if (e) {
      e.preventDefault();
      e.stopPropagation();
    }
    
    // Prevent multiple simultaneous clicks
    if (isSendingOtp || loading) {
      return;
    }
    
    // Don't proceed if phone number is empty
    if (!phoneNumber.trim()) {
      setError('يرجى إدخال رقم الهاتف / Please enter phone number');
      return;
    }
    
    // Clear any existing timeout
    if (otpSendTimeoutRef.current) {
      clearTimeout(otpSendTimeoutRef.current);
    }
    
    setError('');
    setSuccessMessage('');
    setIsSendingOtp(true);

    try {
      // Send OTP
      await sendOtp(phoneNumber);
      
      // Wait a tiny bit for loading state to settle
      await new Promise(resolve => setTimeout(resolve, 10));
      
      // CRITICAL: Update step and persist to sessionStorage
      // Save to sessionStorage first (survives remounts) - do this BEFORE any async operations
      sessionStorage.setItem('login_step', 'otp');
      sessionStorage.setItem('login_phone', phoneNumber);
      
      // Update state - this will trigger re-render
      setSuccessMessage('تم إرسال رمز التحقق / OTP sent successfully');
      setError('');
      
      // Use flushSync to force React to update synchronously
      flushSync(() => {
        setStep('otp');
        stepRef.current = 'otp';
        setForceUpdate(prev => prev + 1); // Force re-render
      });
      
      // Double-check after a brief delay to ensure UI updates even if component remounts
      setTimeout(() => {
        const currentStep = sessionStorage.getItem('login_step');
        const currentStepState = step;
        if (currentStep === 'otp') {
          if (currentStepState !== 'otp') {
            setStep('otp');
            setForceUpdate(prev => prev + 1);
          }
        }
      }, 100);
      
    } catch (err: any) {
      console.error('[Login] ===== ERROR IN OTP SEND =====');
      console.error('[Login] Error:', err);
      console.error('[Login] Error message:', err?.message);
      console.error('[Login] Error details:', JSON.stringify(err, null, 2));
      const errorMessage = err?.message || err?.error || 'فشل إرسال رمز التحقق / Failed to send OTP';
      setError(errorMessage);
      setSuccessMessage('');
      setStep('phone'); // Stay on phone step if error
    } finally {
      setIsSendingOtp(false);
    }
  };

  const handleOtpSubmit = async (e?: React.MouseEvent | FormEvent) => {
    if (e) {
      e.preventDefault();
      e.stopPropagation();
    }
    
    // Prevent multiple simultaneous clicks
    if (isVerifyingOtp || loading) {
      return;
    }
    
    setError('');
    setIsVerifyingOtp(true);

    try {
      await verifyOtp(phoneNumber, otpCode);
      handleSuccessfulLogin();
    } catch (err: any) {
      setError(err.message || 'رمز التحقق غير صحيح / Invalid OTP code');
      // If access denied, show message and reset
      if (err.message?.includes('Access denied') || err.message?.includes('Admin role required')) {
        setTimeout(() => {
          setStep('phone');
          setOtpCode('');
        }, 2000);
      }
    } finally {
      setIsVerifyingOtp(false);
    }
  };

  const handleBack = () => {
    sessionStorage.setItem('login_step', 'phone');
    setStep('phone');
    setOtpCode('');
    setError('');
    setSuccessMessage('');
  };
  
  // Clean up sessionStorage on successful login
  const handleSuccessfulLogin = () => {
    sessionStorage.removeItem('login_step');
    sessionStorage.removeItem('login_phone');
    // Clear any pending timeouts
    if (otpSendTimeoutRef.current) {
      clearTimeout(otpSendTimeoutRef.current);
    }
    navigate('/');
  };
  
  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (otpSendTimeoutRef.current) {
        clearTimeout(otpSendTimeoutRef.current);
      }
    };
  }, []);

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-8 animate-slide-in">
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-primary-500 rounded-full mb-4">
            <svg className="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
            </svg>
          </div>
          <h1 className="text-3xl font-bold text-gray-900 mb-2">حر - لوحة التحكم الإدارية</h1>
          <p className="text-gray-600">Hur Delivery Admin Panel</p>
        </div>

        {/* Phone form - only show when step is 'phone' */}
        {step === 'phone' && (
          <div key={`phone-form-${step}`} className="space-y-6">
            <div>
              <label htmlFor="phoneNumber" className="block text-sm font-medium text-gray-700 mb-2">
                رقم الهاتف / Phone Number
              </label>
              <input
                id="phoneNumber"
                type="tel"
                value={phoneNumber}
                onChange={(e) => setPhoneNumber(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault();
                    handlePhoneSubmit();
                  }
                }}
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none transition"
                placeholder="9647812345678"
              />
              <p className="text-xs text-gray-500 mt-1">
                أدخل رقم الهاتف مع رمز الدولة / Enter phone number with country code
              </p>
            </div>

            {error && (
              <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-sm">
                {error}
              </div>
            )}

            <button
              type="button"
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
                handlePhoneSubmit(e);
              }}
              disabled={isSendingOtp || loading || !phoneNumber.trim()}
              className="w-full bg-primary-500 hover:bg-primary-600 text-white font-semibold py-3 px-4 rounded-lg transition duration-200 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              {isSendingOtp || loading ? (
                <>
                  <svg className="animate-spin h-5 w-5" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                  </svg>
                  <span>جاري الإرسال...</span>
                </>
              ) : (
                <>
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z" />
                  </svg>
                  <span>إرسال رمز التحقق / Send OTP</span>
                </>
              )}
            </button>
          </div>
        )}
        
        {/* OTP form - only show when step is 'otp' */}
        {step === 'otp' && (
          <div key={`otp-form-${step}`} className="space-y-6">
            <div>
              <label htmlFor="otpCode" className="block text-sm font-medium text-gray-700 mb-2">
                رمز التحقق / Verification Code
              </label>
              <input
                ref={otpInputRef}
                id="otpCode"
                type="text"
                inputMode="numeric"
                value={otpCode}
                onChange={(e) => setOtpCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' && otpCode.length === 6) {
                    e.preventDefault();
                    handleOtpSubmit(e);
                  }
                }}
                maxLength={6}
                autoFocus
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none transition text-center text-2xl tracking-widest"
                placeholder="000000"
              />
              <p className="text-xs text-gray-500 mt-1 text-center">
                أدخل الرمز المكون من 6 أرقام / Enter the 6-digit code
              </p>
            </div>

            {successMessage && (
              <div className="bg-green-50 border border-green-200 text-green-700 px-4 py-3 rounded-lg text-sm">
                {successMessage}
              </div>
            )}

            {error && (
              <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-sm">
                {error}
              </div>
            )}

            <div className="flex gap-3">
              <button
                type="button"
                onClick={handleBack}
                disabled={isVerifyingOtp || loading}
                className="flex-1 bg-gray-200 hover:bg-gray-300 text-gray-700 font-semibold py-3 px-4 rounded-lg transition duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                رجوع / Back
              </button>
              <button
                type="button"
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  handleOtpSubmit(e);
                }}
                disabled={isVerifyingOtp || loading || otpCode.length !== 6}
                className="flex-1 bg-primary-500 hover:bg-primary-600 text-white font-semibold py-3 px-4 rounded-lg transition duration-200 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
              >
                {isVerifyingOtp || loading ? (
                  <>
                    <svg className="animate-spin h-5 w-5" viewBox="0 0 24 24">
                      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
                      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                    </svg>
                    <span>جاري التحقق...</span>
                  </>
                ) : (
                  <>
                    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 16l-4-4m0 0l4-4m-4 4h14m-5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h7a3 3 0 013 3v1" />
                    </svg>
                    <span>تسجيل الدخول / Login</span>
                  </>
                )}
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

