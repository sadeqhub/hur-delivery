/**
 * Admin Permission System
 * Defines what each authority level can access
 */

export type AdminAuthority = 'super_admin' | 'admin' | 'manager' | 'support' | 'viewer';

export interface PermissionConfig {
  canViewDashboard: boolean;
  canViewOrders: boolean;
  canEditOrders: boolean;
  canViewUsers: boolean;
  canEditUsers: boolean;
  canViewDrivers: boolean;
  canEditDrivers: boolean;
  canViewMerchants: boolean;
  canEditMerchants: boolean;
  canViewWallets: boolean;
  canEditWallets: boolean;
  canViewEarnings: boolean;
  canEditEarnings: boolean;
  canViewMessaging: boolean;
  canSendMessages: boolean;
  canViewTracking: boolean;
  canViewVerification: boolean;
  canApproveVerification: boolean;
  canViewNotifications: boolean;
  canSendNotifications: boolean;
  canViewAnnouncements: boolean;
  canEditAnnouncements: boolean;
  canViewEmergency: boolean;
  canHandleEmergency: boolean;
  canViewSettings: boolean;
  canEditSettings: boolean;
  canViewCitySettings: boolean;
  canEditCitySettings: boolean;
}

const permissions: Record<AdminAuthority, PermissionConfig> = {
  super_admin: {
    canViewDashboard: true,
    canViewOrders: true,
    canEditOrders: true,
    canViewUsers: true,
    canEditUsers: true,
    canViewDrivers: true,
    canEditDrivers: true,
    canViewMerchants: true,
    canEditMerchants: true,
    canViewWallets: true,
    canEditWallets: true,
    canViewEarnings: true,
    canEditEarnings: true,
    canViewMessaging: true,
    canSendMessages: true,
    canViewTracking: true,
    canViewVerification: true,
    canApproveVerification: true,
    canViewNotifications: true,
    canSendNotifications: true,
    canViewAnnouncements: true,
    canEditAnnouncements: true,
    canViewEmergency: true,
    canHandleEmergency: true,
    canViewSettings: true,
    canEditSettings: true,
    canViewCitySettings: true,
    canEditCitySettings: true,
  },
  admin: {
    canViewDashboard: true,
    canViewOrders: true,
    canEditOrders: true,
    canViewUsers: true,
    canEditUsers: true,
    canViewDrivers: true,
    canEditDrivers: true,
    canViewMerchants: true,
    canEditMerchants: true,
    canViewWallets: true,
    canEditWallets: true,
    canViewEarnings: false, // Only super_admin can view earnings
    canEditEarnings: false,
    canViewMessaging: true,
    canSendMessages: true,
    canViewTracking: true,
    canViewVerification: true,
    canApproveVerification: true,
    canViewNotifications: true,
    canSendNotifications: true,
    canViewAnnouncements: true,
    canEditAnnouncements: true,
    canViewEmergency: true,
    canHandleEmergency: true,
    canViewSettings: false, // Cannot access system settings
    canEditSettings: false,
    canViewCitySettings: true,
    canEditCitySettings: true,
  },
  manager: {
    canViewDashboard: true,
    canViewOrders: true,
    canEditOrders: true,
    canViewUsers: true,
    canEditUsers: true,
    canViewDrivers: true,
    canEditDrivers: true,
    canViewMerchants: true,
    canEditMerchants: true,
    canViewWallets: true,
    canEditWallets: false, // View only
    canViewEarnings: false, // Only super_admin can view earnings
    canEditEarnings: false,
    canViewMessaging: true,
    canSendMessages: true,
    canViewTracking: true,
    canViewVerification: true,
    canApproveVerification: true,
    canViewNotifications: false, // Only super_admin and admin
    canSendNotifications: false, // Only super_admin and admin
    canViewAnnouncements: false, // Only super_admin and admin
    canEditAnnouncements: false, // Only super_admin and admin
    canViewEmergency: true,
    canHandleEmergency: true,
    canViewSettings: false,
    canEditSettings: false,
    canViewCitySettings: false,
    canEditCitySettings: false,
  },
  support: {
    canViewDashboard: true,
    canViewOrders: true,
    canEditOrders: true, // Can update order status
    canViewUsers: true,
    canEditUsers: false,
    canViewDrivers: true,
    canEditDrivers: false,
    canViewMerchants: true,
    canEditMerchants: false,
    canViewWallets: true,
    canEditWallets: false,
    canViewEarnings: false, // Only super_admin can view earnings
    canEditEarnings: false,
    canViewMessaging: true,
    canSendMessages: true,
    canViewTracking: true,
    canViewVerification: true,
    canApproveVerification: false,
    canViewNotifications: false, // Only super_admin and admin
    canSendNotifications: false, // Only super_admin and admin
    canViewAnnouncements: false, // Only super_admin and admin
    canEditAnnouncements: false, // Only super_admin and admin
    canViewEmergency: true,
    canHandleEmergency: false,
    canViewSettings: false,
    canEditSettings: false,
    canViewCitySettings: false,
    canEditCitySettings: false,
  },
  viewer: {
    canViewDashboard: true,
    canViewOrders: true,
    canEditOrders: false, // Read-only
    canViewUsers: true,
    canEditUsers: false,
    canViewDrivers: true,
    canEditDrivers: false,
    canViewMerchants: true,
    canEditMerchants: false,
    canViewWallets: true,
    canEditWallets: false,
    canViewEarnings: false, // Only super_admin can view earnings
    canEditEarnings: false,
    canViewMessaging: true,
    canSendMessages: false, // Read-only
    canViewTracking: true,
    canViewVerification: true,
    canApproveVerification: false,
    canViewNotifications: false, // Only super_admin and admin
    canSendNotifications: false, // Only super_admin and admin
    canViewAnnouncements: false, // Only super_admin and admin
    canEditAnnouncements: false, // Only super_admin and admin
    canViewEmergency: true,
    canHandleEmergency: false,
    canViewSettings: false,
    canEditSettings: false,
    canViewCitySettings: false,
    canEditCitySettings: false,
  },
};

export function getPermissions(authority: AdminAuthority | null | undefined): PermissionConfig {
  if (!authority) {
    // Default to viewer if no authority set
    return permissions.viewer;
  }
  return permissions[authority] || permissions.viewer;
}

export function hasPermission(
  authority: AdminAuthority | null | undefined,
  permission: keyof PermissionConfig
): boolean {
  const userPermissions = getPermissions(authority);
  return userPermissions[permission] || false;
}

