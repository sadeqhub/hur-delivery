import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { BrowserRouter as Router, Routes, Route, useLocation, useNavigate } from 'react-router-dom';
import Navbar from './components/Navbar';
import Hero from './components/Hero';
import HeroScrollAnimation from './components/HeroScrollAnimation';
import HowItWorks from './components/HowItWorks';
import Testimonials from './components/Testimonials';
import CTA from './components/CTA';
import Footer from './components/Footer';
import DeleteAccount from './components/DeleteAccount';
import OrderTracking from './components/OrderTracking';
import ParticlesBackground from './components/ParticlesBackground';
import ScrollToTop from './components/ScrollToTop';

function Home() {
  return (
    <>
      <HeroScrollAnimation />
      <Hero />
      <HowItWorks />
      {/* Testimonials removed - no fake reviews */}
      <CTA />
    </>
  );
}

function DownloadApp() {
  const { i18n } = useTranslation();
  const navigate = useNavigate();
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (typeof window === 'undefined') return;

    const ua = navigator.userAgent || navigator.vendor || window.opera || '';
    const isAndroid = /android/i.test(ua);

    if (isAndroid) {
      // Send Android users straight to Google Play
      window.location.replace('https://play.google.com/store/apps/details?id=com.hur.delivery');
    } else {
      // Show info page for iPhone and other devices
      setReady(true);
    }
  }, []);

  const isRTL = i18n.language === 'ar';

  if (!ready) {
    return (
      <section className="section">
        <div className="container" style={{ maxWidth: 600, margin: '0 auto', padding: '4rem 1.5rem' }}>
          <p style={{ textAlign: isRTL ? 'right' : 'left', color: 'var(--color-text-secondary)' }}>
            {i18n.language === 'ar' ? 'جاري التحقق من نوع جهازك...' : 'Detecting your device...'}
          </p>
        </div>
      </section>
    );
  }

  const title = i18n.language === 'ar'
    ? 'تطبيق الآيفون قادم قريباً'
    : 'iPhone app coming soon';

  const description = i18n.language === 'ar'
    ? 'حالياً يتوفر تطبيق حُر للتوصيل على أجهزة أندرويد فقط. يمكنك استخدام حُر من خلال الموقع الإلكتروني في الوقت الحالي.'
    : 'Right now, the Hur Delivery app is only available on Android. You can use Hur from the main website for now.';

  const buttonLabel = i18n.language === 'ar'
    ? 'العودة إلى الصفحة الرئيسية'
    : 'Return to main website';

  return (
    <section className="section">
      <div
        className="container"
        style={{
          maxWidth: 640,
          margin: '0 auto',
          padding: '4rem 1.5rem',
          textAlign: isRTL ? 'right' : 'left',
        }}
      >
        <h1
          style={{
            fontSize: '2rem',
            marginBottom: '1rem',
            color: 'var(--color-text-primary)',
          }}
        >
          {title}
        </h1>
        <p
          style={{
            fontSize: '1rem',
            color: 'var(--color-text-secondary)',
            lineHeight: 1.7,
          }}
        >
          {description}
        </p>
        <div
          style={{
            marginTop: '2rem',
            display: 'flex',
            justifyContent: isRTL ? 'flex-start' : 'flex-start',
          }}
        >
          <button
            type="button"
            onClick={() => navigate('/')}
            style={{
              padding: '0.75rem 1.5rem',
              borderRadius: '999px',
              border: 'none',
              cursor: 'pointer',
              background: 'var(--gradient-primary)',
              color: '#fff',
              fontSize: '0.95rem',
              fontWeight: 600,
              boxShadow: 'var(--shadow-md)',
            }}
          >
            {buttonLabel}
          </button>
        </div>
      </div>
    </section>
  );
}

function AppContent() {
  const { i18n } = useTranslation();
  const location = useLocation();
  const isDeleteAccountPage = location.pathname === '/delete-account';
  const isTrackingPage = location.pathname.startsWith('/track/');
  
  useEffect(() => {
    // Set body direction based on language
    document.body.className = i18n.language === 'ar' ? 'rtl' : 'ltr';
    document.documentElement.lang = i18n.language;
    document.documentElement.dir = i18n.language === 'ar' ? 'rtl' : 'ltr';
  }, [i18n.language]);

  useEffect(() => {
    // Smooth scroll behavior
    document.documentElement.style.scrollBehavior = 'smooth';
    
    // Handle hash links
    const handleHashClick = (e) => {
      const href = e.target.closest('a')?.getAttribute('href');
      if (href?.startsWith('#')) {
        e.preventDefault();
        const element = document.querySelector(href);
        if (element) {
          element.scrollIntoView({ behavior: 'smooth' });
        }
      }
    };

    document.addEventListener('click', handleHashClick);
    return () => document.removeEventListener('click', handleHashClick);
  }, []);

  return (
    <div className="app">
      {!isDeleteAccountPage && !isTrackingPage && <ParticlesBackground />}
      {!isDeleteAccountPage && !isTrackingPage && <Navbar />}
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/delete-account" element={<DeleteAccount />} />
        <Route path="/track/:code" element={<OrderTracking />} />
        <Route path="/downloadapp" element={<DownloadApp />} />
      </Routes>
      {!isDeleteAccountPage && !isTrackingPage && <Footer />}
      {!isDeleteAccountPage && !isTrackingPage && <ScrollToTop />}
    </div>
  );
}

function App() {
  return (
    <Router>
      <AppContent />
    </Router>
  );
}

export default App;

