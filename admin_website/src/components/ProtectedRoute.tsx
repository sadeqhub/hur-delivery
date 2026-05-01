import { Navigate } from 'react-router-dom';
import { useAuthStore } from '../store/authStore';
import { hasPermission, type AdminAuthority } from '../lib/permissions';

interface ProtectedRouteProps {
  children: React.ReactNode;
  requiredPermission?: string;
  requiredAuthority?: AdminAuthority;
}

export default function ProtectedRoute({ 
  children, 
  requiredPermission,
  requiredAuthority 
}: ProtectedRouteProps) {
  const { isAdmin, adminAuthority, loading } = useAuthStore();

  // Show loading state
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

  // Must be admin
  if (!isAdmin) {
    return <Navigate to="/login" replace />;
  }

  // Check specific permission if required
  if (requiredPermission && !hasPermission(adminAuthority, requiredPermission as any)) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center bg-white p-8 rounded-lg shadow-lg max-w-md">
          <i className="fas fa-lock text-4xl text-red-500 mb-4"></i>
          <h2 className="text-2xl font-bold text-gray-900 mb-2">غير مصرح / Access Denied</h2>
          <p className="text-gray-600 mb-4">
            ليس لديك الصلاحية للوصول إلى هذه الصفحة / You don't have permission to access this page
          </p>
          <p className="text-sm text-gray-500">
            مستوى الصلاحية المطلوب: {requiredAuthority || 'غير محدد'} / Required authority level: {requiredAuthority || 'Not specified'}
          </p>
        </div>
      </div>
    );
  }

  // Check minimum authority level if required
  if (requiredAuthority) {
    const authorityHierarchy: AdminAuthority[] = ['viewer', 'support', 'manager', 'admin', 'super_admin'];
    const requiredIndex = authorityHierarchy.indexOf(requiredAuthority);
    const userIndex = authorityHierarchy.indexOf(adminAuthority || 'viewer');

    if (userIndex < requiredIndex) {
      return (
        <div className="min-h-screen flex items-center justify-center bg-gray-50">
          <div className="text-center bg-white p-8 rounded-lg shadow-lg max-w-md">
            <i className="fas fa-lock text-4xl text-red-500 mb-4"></i>
            <h2 className="text-2xl font-bold text-gray-900 mb-2">غير مصرح / Access Denied</h2>
            <p className="text-gray-600 mb-4">
              مستوى الصلاحية غير كافٍ / Insufficient authority level
            </p>
            <p className="text-sm text-gray-500">
              المطلوب: {requiredAuthority} / Required: {requiredAuthority}
            </p>
          </div>
        </div>
      );
    }
  }

  return <>{children}</>;
}

