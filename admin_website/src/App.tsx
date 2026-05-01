import { useEffect, useRef } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { useAuthStore } from './store/authStore';
import Login from './pages/Login';
import MainLayout from './components/Layout/MainLayout';
import ProtectedRoute from './components/ProtectedRoute';
import Dashboard from './pages/Dashboard';

// Placeholder pages (will be built next)
import Users from './pages/Users';
import Orders from './pages/Orders';
import Drivers from './pages/Drivers';
import Merchants from './pages/Merchants';
import Wallets from './pages/Wallets';
import Earnings from './pages/Earnings';
import Notifications from './pages/Notifications';
import Verification from './pages/Verification';
import Tracking from './pages/Tracking';
import Emergency from './pages/Emergency';
import Messaging from './pages/Messaging';
import Announcements from './pages/Announcements';
import Settings from './pages/Settings';
import CitySettings from './pages/CitySettings';
import MerchantSettings from './pages/MerchantSettings';

function App() {
  const { checkAuth, loading, isAdmin } = useAuthStore();
  const hasCheckedAuth = useRef(false);
  
  const basename = '/'; // Always use root basename for admin subdomain

  useEffect(() => {
    // Only check auth once on mount
    if (!hasCheckedAuth.current) {
      hasCheckedAuth.current = true;
      checkAuth();
    }
  }, [checkAuth]);

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-16 w-16 border-b-2 border-primary-500 mx-auto mb-4"></div>
          <p className="text-gray-600">جاري التحميل... / Loading...</p>
        </div>
      </div>
    );
  }

  return (
    <BrowserRouter basename={basename}>
      <Routes>
        <Route path="/login" element={!isAdmin ? <Login /> : <Navigate to="/" replace />} />
        
        <Route element={isAdmin ? <MainLayout /> : <Navigate to="/login" replace />}>
          <Route index element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
          <Route path="users" element={<ProtectedRoute requiredPermission="canViewUsers"><Users /></ProtectedRoute>} />
          <Route path="orders" element={<ProtectedRoute requiredPermission="canViewOrders"><Orders /></ProtectedRoute>} />
          <Route path="drivers" element={<ProtectedRoute requiredPermission="canViewDrivers"><Drivers /></ProtectedRoute>} />
          <Route path="drivers/:id" element={<ProtectedRoute requiredPermission="canViewDrivers"><Drivers /></ProtectedRoute>} />
          <Route path="merchants" element={<ProtectedRoute requiredPermission="canViewMerchants"><Merchants /></ProtectedRoute>} />
          <Route path="wallets" element={<ProtectedRoute requiredPermission="canViewWallets"><Wallets /></ProtectedRoute>} />
          <Route path="earnings" element={<ProtectedRoute requiredPermission="canViewEarnings"><Earnings /></ProtectedRoute>} />
          <Route path="notifications" element={<ProtectedRoute requiredPermission="canViewNotifications"><Notifications /></ProtectedRoute>} />
          <Route path="verification" element={<ProtectedRoute requiredPermission="canViewVerification"><Verification /></ProtectedRoute>} />
          <Route path="tracking" element={<ProtectedRoute requiredPermission="canViewTracking"><Tracking /></ProtectedRoute>} />
          <Route path="emergency" element={<ProtectedRoute requiredPermission="canViewEmergency"><Emergency /></ProtectedRoute>} />
          <Route path="messaging" element={<ProtectedRoute requiredPermission="canViewMessaging"><Messaging /></ProtectedRoute>} />
          <Route path="announcements" element={<ProtectedRoute requiredPermission="canViewAnnouncements"><Announcements /></ProtectedRoute>} />
          <Route path="settings" element={<ProtectedRoute requiredPermission="canViewSettings"><Settings /></ProtectedRoute>} />
          <Route path="city-settings" element={<ProtectedRoute requiredPermission="canViewCitySettings"><CitySettings /></ProtectedRoute>} />
          <Route path="merchants/:merchantId/settings" element={<ProtectedRoute requiredPermission="canViewMerchants"><MerchantSettings /></ProtectedRoute>} />
        </Route>

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;

