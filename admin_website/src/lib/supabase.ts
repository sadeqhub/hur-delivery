// Database Types
export interface User {
  id: string;
  email?: string;
  phone?: string;
  name?: string;
  role: 'driver' | 'merchant' | 'admin' | 'customer';
  is_active: boolean;
  verification_status?: 'pending' | 'approved' | 'rejected' | null;
  manual_verified?: boolean; // Manual/AI verification status
  is_online: boolean;
  is_available?: boolean;
  created_at: string;
  updated_at: string;
  wallet_balance?: number;
  vehicle_type?: string;
  latitude?: number;
  longitude?: number;
  current_latitude?: number; // Deprecated - use latitude instead
  current_longitude?: number; // Deprecated - use longitude instead
  last_location_update?: string;
  city?: 'najaf' | 'mosul' | null;
  admin_authority?: 'super_admin' | 'admin' | 'manager' | 'support' | 'viewer' | null;
  // ID Verification fields
  id_number?: string;
  id_front_url?: string;
  id_back_url?: string;
  selfie_url?: string;
  legal_first_name?: string;
  legal_father_name?: string;
  legal_grandfather_name?: string;
  legal_family_name?: string;
  id_expiry_date?: string;
  id_birth_date?: string;
  id_verified_at?: string;
  id_verification_notes?: string;
  admin_reviewed?: boolean; // Internal flag: true if admin has reviewed this user in verification page
}

export interface Order {
  id: string;
  user_friendly_code?: string;
  customer_name: string;
  customer_phone: string;
  customer_address?: string;
  customer_latitude?: number;
  customer_longitude?: number;
  merchant_id: string;
  merchant_name?: string;
  merchant_phone?: string;
  merchant_address?: string;
  merchant_latitude?: number;
  merchant_longitude?: number;
  driver_id?: string;
  pickup_address: string;
  pickup_latitude: number;
  pickup_longitude: number;
  delivery_address: string;
  delivery_latitude: number;
  delivery_longitude: number;
  status: 'pending' | 'assigned' | 'accepted' | 'on_the_way' | 'delivered' | 'cancelled' | 'rejected';
  total_amount?: number;
  delivery_fee: number;
  notes?: string;
  cancellation_reason?: string;
  rejection_reason?: string;
  items?: any;
  vehicle_type?: string;
  bulk_order_id?: string;
  is_bulk_order?: boolean;
  ready_at?: string;
  ready_countdown?: number;
  customer_location_provided?: boolean;
  driver_notified_location?: boolean;
  coordinates_auto_updated?: boolean;
  created_at: string;
  updated_at: string;
  assigned_at?: string;
  accepted_at?: string;
  picked_up_at?: string;
  delivered_at?: string;
  cancelled_at?: string;
  rejected_at?: string;
  delivery_time_limit_seconds?: number;
  delivery_timer_started_at?: string;
  delivery_timer_stopped_at?: string;
  delivery_timer_expires_at?: string;
}

export interface Conversation {
  id: string;
  title?: string;
  order_id?: string;
  is_support: boolean;
  created_at: string;
  created_by: string;
}

export interface Message {
  id: string;
  conversation_id: string;
  sender_id: string;
  body: string;
  kind: 'text' | 'image' | 'file' | 'media';
  order_id?: string;
  created_at: string;
  reply_to_message_id?: string;
  attachment_url?: string | null;
  attachment_type?: string | null;
}

export interface Wallet {
  id: string;
  user_id: string;
  balance: number;
  credit_limit: number;
  created_at: string;
  updated_at: string;
}

export interface Transaction {
  id: string;
  wallet_id: string;
  amount: number;
  type: 'credit' | 'debit';
  description?: string;
  order_id?: string;
  created_at: string;
}

