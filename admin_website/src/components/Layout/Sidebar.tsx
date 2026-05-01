import { useState, useEffect } from 'react';
import { NavLink } from 'react-router-dom';
import { useAuthStore } from '../../store/authStore';
import { hasPermission } from '../../lib/permissions';

interface NavItem {
  path: string;
  icon: string;
  label: string;
  labelEn: string;
  badge?: string;
  color?: string;
  permission?: string; // Permission key to check
}

const navItems: NavItem[] = [
  { path: '/', icon: 'fa-home', label: 'لوحة التحكم', labelEn: 'Dashboard', permission: 'canViewDashboard' },
  { path: '/orders', icon: 'fa-box', label: 'الطلبات', labelEn: 'Orders', permission: 'canViewOrders' },
  { path: '/messaging', icon: 'fa-headset', label: 'غرفة الرسائل', labelEn: 'Ops Messaging', permission: 'canViewMessaging' },
  { path: '/tracking', icon: 'fa-map-marker-alt', label: 'التتبع المباشر', labelEn: 'Live Tracking', permission: 'canViewTracking' },
  { path: '/drivers', icon: 'fa-motorcycle', label: 'السائقون', labelEn: 'Drivers', permission: 'canViewDrivers' },
  { path: '/merchants', icon: 'fa-store', label: 'التجار', labelEn: 'Merchants', permission: 'canViewMerchants' },
  { path: '/users', icon: 'fa-users', label: 'المستخدمون', labelEn: 'Users', permission: 'canViewUsers' },
  { path: '/verification', icon: 'fa-user-check', label: 'التحقق', labelEn: 'Verification', permission: 'canViewVerification' },
  { path: '/wallets', icon: 'fa-wallet', label: 'المحافظ', labelEn: 'Wallets', permission: 'canViewWallets' },
  { path: '/earnings', icon: 'fa-money-bill-wave', label: 'الأرباح', labelEn: 'Earnings', permission: 'canViewEarnings' },
  { path: '/emergency', icon: 'fa-exclamation-triangle', label: 'الطوارئ', labelEn: 'Emergency', color: 'text-red-500', permission: 'canViewEmergency' },
  { path: '/announcements', icon: 'fa-bullhorn', label: 'الإعلانات', labelEn: 'Announcements', permission: 'canViewAnnouncements' },
  { path: '/notifications', icon: 'fa-bell', label: 'الإشعارات', labelEn: 'Notifications', permission: 'canViewNotifications' },
  { path: '/settings', icon: 'fa-cog', label: 'الإعدادات', labelEn: 'Settings', permission: 'canViewSettings' },
  { path: '/city-settings', icon: 'fa-city', label: 'إعدادات المدن', labelEn: 'City Settings', permission: 'canViewCitySettings' },
];

interface SidebarProps {
  isMobileOpen: boolean;
  onMobileClose: () => void;
}

export default function Sidebar({ isMobileOpen, onMobileClose }: SidebarProps) {
  const { user, signOut, adminAuthority } = useAuthStore();
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [isMobile, setIsMobile] = useState(false);

  // Detect mobile screen size
  useEffect(() => {
    const checkMobile = () => {
      setIsMobile(window.innerWidth < 1024);
      if (window.innerWidth < 1024) {
        setIsCollapsed(false); // Always show full sidebar on mobile when open
      }
    };
    
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  // Filter nav items based on permissions
  const visibleNavItems = navItems.filter((item) => {
    if (!item.permission) return true; // Show items without permission requirement
    return hasPermission(adminAuthority, item.permission as any);
  });

  // Close mobile sidebar when clicking a link
  const handleNavClick = () => {
    if (isMobile) {
      onMobileClose();
    }
  };

  return (
    <>
      {/* Mobile overlay */}
      {isMobile && isMobileOpen && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 z-40 lg:hidden"
          onClick={onMobileClose}
        />
      )}

      {/* Sidebar */}
      <aside
        className={`
          ${isMobile ? 'fixed' : 'relative'}
          ${isMobile && !isMobileOpen ? '-translate-x-full' : 'translate-x-0'}
          ${isCollapsed && !isMobile ? 'w-20' : 'w-64'}
          bg-white border-r border-gray-200 flex flex-col h-screen z-50 lg:z-30 transition-all duration-300
        `}
      >
        {/* Header */}
        <div className="p-4 lg:p-6 border-b border-gray-200">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-primary-500 rounded-lg flex items-center justify-center flex-shrink-0">
              <i className="fas fa-truck-fast text-white text-xl"></i>
            </div>
            {(!isCollapsed || isMobile) && (
              <div className="flex-1 min-w-0">
                <h2 className="text-lg lg:text-xl font-bold text-gray-900">حر Admin</h2>
                <p className="text-xs text-gray-500">Hur Delivery</p>
                {adminAuthority && (
                  <p className="text-xs text-primary-600 font-medium mt-1 capitalize">
                    {adminAuthority.replace('_', ' ')}
                  </p>
                )}
              </div>
            )}
            <div className="flex items-center gap-2">
              {isMobile && (
                <button
                  onClick={onMobileClose}
                  className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
                  title="Close"
                >
                  <i className="fas fa-times text-gray-600"></i>
                </button>
              )}
              {!isMobile && (
                <button
                  onClick={() => setIsCollapsed(!isCollapsed)}
                  className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
                  title={isCollapsed ? 'Expand' : 'Collapse'}
                >
                  <i className={`fas fa-${isCollapsed ? 'angles-right' : 'angles-left'} text-gray-600`}></i>
                </button>
              )}
            </div>
          </div>
        </div>

        {/* Navigation */}
        <nav className="flex-1 overflow-y-auto py-4 px-2 lg:px-3">
          {visibleNavItems.map((item) => (
            <NavLink
              key={item.path}
              to={item.path}
              end={item.path === '/'}
              onClick={handleNavClick}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 lg:px-4 py-2.5 lg:py-3 rounded-lg mb-1 transition-colors ${
                  isActive
                    ? 'bg-primary-50 text-primary-600 font-medium'
                    : `hover:bg-gray-50 text-gray-700 ${item.color || ''}`
                }`
              }
            >
              <i className={`fas ${item.icon} w-5 text-center flex-shrink-0`}></i>
              {(!isCollapsed || isMobile) && (
                <>
                  <div className="flex-1 min-w-0">
                    <div className="text-sm truncate">{item.label}</div>
                    <div className="text-xs text-gray-500 truncate">{item.labelEn}</div>
                  </div>
                  {item.badge && (
                    <span className="bg-red-500 text-white text-xs px-2 py-0.5 rounded-full">
                      {item.badge}
                    </span>
                  )}
                </>
              )}
            </NavLink>
          ))}
        </nav>

        {/* User Info & Logout */}
        <div className="p-3 lg:p-4 border-t border-gray-200">
          {(!isCollapsed || isMobile) && (
            <div className="flex items-center gap-3 mb-3 px-2">
              <div className="w-10 h-10 bg-gray-200 rounded-full flex items-center justify-center">
                <i className="fas fa-user text-gray-600"></i>
              </div>
              <div className="flex-1 min-w-0">
                <div className="text-sm font-medium text-gray-900 truncate">{user?.name || 'Admin'}</div>
                <div className="text-xs text-gray-500 truncate">{user?.email || user?.phone}</div>
              </div>
            </div>
          )}
          <button
            onClick={signOut}
            className={`w-full flex items-center ${(isCollapsed && !isMobile) ? 'justify-center' : 'justify-center gap-2'} px-3 lg:px-4 py-2 bg-red-50 hover:bg-red-100 text-red-600 rounded-lg transition-colors text-sm font-medium`}
            title="Logout"
          >
            <i className="fas fa-sign-out-alt"></i>
            {(!isCollapsed || isMobile) && <span>تسجيل الخروج / Logout</span>}
          </button>
        </div>
      </aside>
    </>
  );
}

