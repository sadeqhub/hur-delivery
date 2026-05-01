import { useEffect, useState, useRef } from 'react';
import { supabaseAdmin, type User } from '../lib/supabase-admin';
import { config } from '../lib/config';

export default function Verification() {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | 'pending' | 'approved' | 'rejected'>('all');
  const [roleFilter, setRoleFilter] = useState<'all' | 'driver' | 'merchant'>('all');
  const [showImageModal, setShowImageModal] = useState(false);
  const [selectedImage, setSelectedImage] = useState<string | null>(null);
  const [imageType, setImageType] = useState<'front' | 'back' | 'selfie'>('front');
  const [previewImageUser, setPreviewImageUser] = useState<User | null>(null); // Store user for retry
  const [updatingUserId, setUpdatingUserId] = useState<string | null>(null); // Track which user is being updated
  const [dismissedUserIds, setDismissedUserIds] = useState<Set<string>>(new Set()); // Track dismissed users
  const [usersWithPhotos, setUsersWithPhotos] = useState<Set<string>>(new Set()); // Track users who have photos in their folder
  const [selectedUser, setSelectedUser] = useState<User | null>(null); // Track which user's details modal is open
  const [isEditing, setIsEditing] = useState(false); // Track if we're in edit mode
  const [editedUser, setEditedUser] = useState<Partial<User>>({}); // Track edited user data
  const [imageRotations, setImageRotations] = useState<{front: number, back: number, selfie: number}>({
    front: 0,
    back: 0,
    selfie: 0
  }); // Track rotation for each image type
  
  // Cache for image URLs to prevent reloading
  const imageUrlCache = useRef<Map<string, string | null>>(new Map());

  useEffect(() => {
    loadUsers();
  }, []);

  // Function to mark user as having photos
  const markUserHasPhotos = (userId: string) => {
    setUsersWithPhotos(prev => {
      const newSet = new Set(prev);
      newSet.add(userId);
      return newSet;
    });
  };
  
  // Check which users have photos in their folders (optimized with debouncing and batching)
  useEffect(() => {
    if (users.length === 0) return;
    
    const timeoutId = setTimeout(async () => {
      const photosSet = new Set<string>();
      // Batch check in chunks of 10 to avoid overwhelming the API
      const chunkSize = 10;
      for (let i = 0; i < users.length; i += chunkSize) {
        const chunk = users.slice(i, i + chunkSize);
        await Promise.all(
          chunk.map(async (user) => {
            const folderPath = `documents/${user.id}`;
            try {
              const { data: files, error } = await supabaseAdmin.storage
                .from('files')
                .list(folderPath, { limit: 1 });
              if (!error && files && files.length > 0) {
                photosSet.add(user.id);
              }
            } catch {
              // Continue to next user
            }
          })
        );
      }
      setUsersWithPhotos(photosSet);
    }, 500); // Debounce by 500ms

    return () => clearTimeout(timeoutId);
  }, [users]);

  const loadUsers = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabaseAdmin
        .from('users')
        .select('*')
        .in('role', ['driver', 'merchant'])
        .or('admin_reviewed.is.null,admin_reviewed.eq.false') // Only show users that haven't been reviewed
        .order('created_at', { ascending: false });

      if (error) throw error;
      setUsers(data || []);
    } catch (error) {
      console.error('Error loading users:', error);
    } finally {
      setLoading(false);
    }
  };

  const updateVerificationStatus = async (userId: string, status: 'pending' | 'approved' | 'blocked') => {
    // Prevent multiple clicks
    if (updatingUserId) {
      return;
    }
    
    setUpdatingUserId(userId);
    try {
      if (status === 'blocked') {
        // Block user: delete from database and send WhatsApp message
        await blockUser(userId);
      } else {
        // Approve or Pending
        const updateData: any = { 
          verification_status: status === 'approved' ? 'approved' : 'pending',
          is_active: status === 'approved' ? true : undefined
        };
        
        // When admin approves, mark as reviewed so user is hidden from verification page
        if (status === 'approved') {
          updateData.admin_reviewed = true;
        }
        
      const { error } = await supabaseAdmin
        .from('users')
          .update(updateData)
        .eq('id', userId);

      if (error) throw error;
      
      await loadUsers();
        // Close modal if user was approved (they'll be filtered out)
        if (status === 'approved' && selectedUser && selectedUser.id === userId) {
          setSelectedUser(null);
        }
        // Success - no popup notification
      }
    } catch (error: any) {
      console.error('Error updating verification status:', error);
      // Error logged to console only
    } finally {
      setUpdatingUserId(null);
    }
  };

  const blockUser = async (userId: string) => {
    // Get user info before deletion
    const user = users.find(u => u.id === userId);
    if (!user) {
      throw new Error('User not found');
    }

    const userName = user.name || 'المستخدم';

    // Confirm deletion
    if (!confirm(`⚠️ هل أنت متأكد من حظر هذا المستخدم؟\nسيتم حذف المستخدم من قاعدة البيانات وإرسال رسالة واتساب له.\n\n⚠️ Are you sure you want to block this user?\nThe user will be deleted from the database and a WhatsApp message will be sent.`)) {
      setUpdatingUserId(null);
      return;
    }

    try {
      // Send WhatsApp message first (before deletion)
      const whatsappMessage = `مرحباً ${userName},\n\nنعتذر، لكن حسابك تم حظره من قبل الإدارة. يرجى التسجيل مرة أخرى.\n\nHello ${userName},\n\nWe apologize, but your account has been blocked by the administration. Please register again.\n\nشكراً / Thank you`;

      // Send WhatsApp message via edge function (before deletion so we have the user ID)
      const { data: sessionData } = await supabaseAdmin.auth.getSession();
      if (sessionData?.session) {
        try {
          // Send WhatsApp message using userIds (non-blocking - don't fail if this fails)
          await fetch(`${config.supabaseUrl}/functions/v1/mass-whatsapp-announcement`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${sessionData.session.access_token}`,
              'apikey': config.supabaseAnonKey,
            },
            body: JSON.stringify({
              message: whatsappMessage,
              userIds: [userId], // Send to specific user ID
              delayBetweenMessages: 0,
            }),
          }).catch((err) => {
            console.warn('Failed to send WhatsApp message:', err);
            // Continue with deletion even if WhatsApp fails
          });
        } catch (whatsappError) {
          console.warn('WhatsApp message error:', whatsappError);
          // Continue with deletion even if WhatsApp fails
        }
      }

      // Delete user from database
      const { error: deleteError } = await supabaseAdmin
        .from('users')
        .delete()
        .eq('id', userId);

      if (deleteError) throw deleteError;

      // Also try to delete from auth (optional - may fail if user doesn't exist in auth)
      try {
        const { data: sessionData } = await supabaseAdmin.auth.getSession();
        if (sessionData?.session) {
          await fetch(`${config.supabaseUrl}/auth/v1/admin/users/${userId}`, {
            method: 'DELETE',
            headers: {
              'apikey': config.supabaseAnonKey,
              'Authorization': `Bearer ${sessionData.session.access_token}`,
            },
          }).catch(() => {
            // Ignore auth deletion errors - user may not exist in auth
          });
        }
      } catch (authError) {
        console.warn('Auth deletion error (non-critical):', authError);
      }

      await loadUsers();
      // Close modal since user is deleted
      if (selectedUser && selectedUser.id === userId) {
        setSelectedUser(null);
      }
      // Success - no popup notification
    } catch (error: any) {
      console.error('Error blocking user:', error);
      throw error;
    }
  };

  const toggleManualVerified = async (userId: string, currentStatus: boolean) => {
    // Prevent multiple clicks
    if (updatingUserId) {
      return;
    }
    
    setUpdatingUserId(userId);
    try {
      const { error } = await supabaseAdmin
        .from('users')
        .update({ manual_verified: !currentStatus })
        .eq('id', userId);

      if (error) throw error;
      
      await loadUsers();
      // Update selectedUser if it's the same user
      if (selectedUser && selectedUser.id === userId) {
        setSelectedUser({ ...selectedUser, manual_verified: !currentStatus });
      }
      // Success - no popup notification
    } catch (error: any) {
      console.error('Error updating manual verification:', error);
      // Error logged to console only
    } finally {
      setUpdatingUserId(null);
    }
  };

  const handleEditUser = () => {
    if (selectedUser) {
      setEditedUser({
        name: selectedUser.name || '',
        phone: selectedUser.phone || '',
        id_number: selectedUser.id_number || '',
        legal_first_name: selectedUser.legal_first_name || '',
        legal_father_name: selectedUser.legal_father_name || '',
        legal_grandfather_name: selectedUser.legal_grandfather_name || '',
        legal_family_name: selectedUser.legal_family_name || '',
        id_verification_notes: selectedUser.id_verification_notes || '',
        city: selectedUser.city || null,
      });
      setIsEditing(true);
    }
  };

  const handleCancelEdit = () => {
    setIsEditing(false);
    setEditedUser({});
  };

  const handleSaveUser = async () => {
    if (!selectedUser || updatingUserId) {
      return;
    }

    setUpdatingUserId(selectedUser.id);
    try {
      // Clean the update data: convert empty strings to null, and only include changed fields
      const cleanedUpdate: any = {};
      
      for (const [key, value] of Object.entries(editedUser)) {
        // Convert empty strings to null for optional fields
        const cleanedValue = value === '' ? null : value;
        
        // Only include fields that have actually changed
        if (cleanedValue !== (selectedUser as any)[key]) {
          cleanedUpdate[key] = cleanedValue;
        }
      }
      
      // If nothing changed, just exit
      if (Object.keys(cleanedUpdate).length === 0) {
        setIsEditing(false);
        setEditedUser({});
        setUpdatingUserId(null);
        return;
      }
      
      const { error, data } = await supabaseAdmin
        .from('users')
        .update(cleanedUpdate)
        .eq('id', selectedUser.id)
        .select()
        .single();

      if (error) {
        console.error('Error updating user:', error);
        console.error('Update data:', cleanedUpdate);
        throw error;
      }
      
      await loadUsers();
      // Update selectedUser with new data
      if (data) {
        setSelectedUser(data);
      } else {
        const updatedUser = { ...selectedUser, ...cleanedUpdate };
        setSelectedUser(updatedUser);
      }
      setIsEditing(false);
      setEditedUser({});
      // Success - no popup notification
    } catch (error: any) {
      console.error('Error updating user:', error);
      console.error('Error details:', error.message, error.details, error.hint);
      // Error logged to console only
    } finally {
      setUpdatingUserId(null);
    }
  };

  const handleFieldChange = (field: keyof User, value: string | null) => {
    setEditedUser(prev => ({
      ...prev,
      [field]: value || null,
    }));
  };

  const reVerifyIdCards = async () => {
    if (!selectedUser || updatingUserId) {
      return;
    }

    setUpdatingUserId(selectedUser.id);
    try {
      // Fetch images from storage
      const fetchImageAsBlob = async (url: string | null | undefined): Promise<Blob | null> => {
        if (!url) return null;
        try {
          const response = await fetch(url);
          if (!response.ok) return null;
          return await response.blob();
        } catch (error) {
          console.error('Error fetching image:', error);
          return null;
        }
      };

      // Get image URLs
      const frontUrl = await loadImageFromFolder(selectedUser.id, 'front');
      const backUrl = await loadImageFromFolder(selectedUser.id, 'back');
      const selfieUrl = selectedUser.role === 'driver' 
        ? await loadImageFromFolder(selectedUser.id, 'selfie')
        : null;

      if (!frontUrl) {
        console.error('Front image not found');
        return;
      }

      if (!backUrl && selectedUser.role !== 'merchant') {
        console.error('Back image not found');
        return;
      }

      // Fetch images as blobs and convert to Files
      const frontBlob = await fetchImageAsBlob(frontUrl);
      const backBlob = await fetchImageAsBlob(backUrl);
      const selfieBlob = selectedUser.role === 'driver' 
        ? await fetchImageAsBlob(selfieUrl)
        : null;

      if (!frontBlob) {
        console.error('Failed to fetch front image');
        return;
      }

      // Convert Blobs to Files (required by FormData)
      const frontFile = new File([frontBlob], 'front.jpg', { type: frontBlob.type || 'image/jpeg' });
      const backFile = backBlob ? new File([backBlob], 'back.jpg', { type: backBlob.type || 'image/jpeg' }) : null;
      const selfieFile = selfieBlob ? new File([selfieBlob], 'selfie.jpg', { type: selfieBlob.type || 'image/jpeg' }) : null;

      // Create FormData
      const formData = new FormData();
      formData.append('id_front', frontFile);
      if (backFile) {
        formData.append('id_back', backFile);
      }
      if (selfieFile) {
        formData.append('selfie', selfieFile);
      }
      formData.append('role', selectedUser.role);
      formData.append('user_id', selectedUser.id);
      formData.append('document_type', 'national_id'); // Default, could be made dynamic

      // Get session for auth
      const { data: sessionData } = await supabaseAdmin.auth.getSession();
      if (!sessionData?.session) {
        console.error('Not authenticated');
        return;
      }

      // Call verify-id-card edge function
      const response = await fetch(`${config.supabaseUrl}/functions/v1/verify-id-card`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${sessionData.session.access_token}`,
          'apikey': config.supabaseAnonKey,
        },
        body: formData,
      });

      const result = await response.json();

      if (!result.success || !result.authenticated) {
        console.error('Verification failed:', result.reason);
        return;
      }

      // Update user with extracted data
      const updateData: any = {};
      
      if (result.legal_name) {
        updateData.legal_first_name = result.legal_name.first || null;
        updateData.legal_father_name = result.legal_name.father || null;
        updateData.legal_grandfather_name = result.legal_name.grandfather || null;
        updateData.legal_family_name = result.legal_name.family || null;
      }
      
      if (result.id_number) {
        updateData.id_number = result.id_number;
      }
      
      if (result.id_expiry_date) {
        updateData.id_expiry_date = result.id_expiry_date;
      }
      
      if (result.id_birth_date) {
        updateData.id_birth_date = result.id_birth_date;
      }

      // Add verification note
      if (result.reason) {
        updateData.id_verification_notes = result.reason;
      }

      // Update user in database
      const { error: updateError } = await supabaseAdmin
        .from('users')
        .update(updateData)
        .eq('id', selectedUser.id);

      if (updateError) {
        console.error('Error updating user:', updateError);
        return;
      }

      // Reload users and update selected user
      await loadUsers();
      const updatedUser = { ...selectedUser, ...updateData };
      setSelectedUser(updatedUser);
      
      // Success - no popup notification
    } catch (error: any) {
      console.error('Error re-verifying ID cards:', error);
      // Error logged to console only
    } finally {
      setUpdatingUserId(null);
    }
  };

  
  // Get image URL from database path (with caching)
  const getImageUrl = async (path: string | undefined, userId?: string): Promise<string | null> => {
    if (!path) return null;
    
    const cacheKey = `url-${path}`;
    
    // Check cache first
    if (imageUrlCache.current.has(cacheKey)) {
      const cachedUrl = imageUrlCache.current.get(cacheKey);
      return cachedUrl || null;
    }
    
    // If path already contains full URL, return as is
    if (path.startsWith('http://') || path.startsWith('https://')) {
      imageUrlCache.current.set(cacheKey, path);
      return path;
    }
    
    // Extract bucket and path from storage API format
    const storageApiMatch = path.match(/storage\/v1\/object\/(?:sign|public)\/(.+)$/i);
    if (storageApiMatch) {
      const fullPath = storageApiMatch[1];
      const segments = fullPath.split('/').filter(Boolean);
      if (segments.length > 1) {
        const bucket = segments[0];
        const filePath = segments.slice(1).join('/');
        
        // Try public URL first
        const { data: publicData } = supabaseAdmin.storage.from(bucket).getPublicUrl(filePath);
        if (publicData?.publicUrl) {
          imageUrlCache.current.set(cacheKey, publicData.publicUrl);
          return publicData.publicUrl;
        }
        
        // Fallback to signed URL
        const { data: signedData, error: signedError } = await supabaseAdmin.storage
          .from(bucket)
          .createSignedUrl(filePath, 3600); // 1 hour expiry
        
        if (!signedError && signedData?.signedUrl) {
          imageUrlCache.current.set(cacheKey, signedData.signedUrl);
          return signedData.signedUrl;
        }
      }
    }
    
    // Try documents/{userId}/{filename} structure
    if (userId) {
      const pathSegments = path.split('/').filter(Boolean);
      const filename = pathSegments[pathSegments.length - 1] || path;
      const filenameBase = filename.replace(/\.(jpg|jpeg|png|webp)$/i, '');
      
      const documentPaths = [
        `documents/${userId}/${filename}`,
        `documents/${userId}/${filenameBase}.jpg`,
        `documents/${userId}/${filenameBase}.jpeg`,
        `documents/${userId}/${filenameBase}.png`,
        path,
      ];
      
      for (const documentPath of documentPaths) {
        try {
          // Try public URL first (this doesn't verify existence, but is fast)
          const { data: publicData } = supabaseAdmin.storage.from('files').getPublicUrl(documentPath);
          if (publicData?.publicUrl) {
            // Try to verify the file exists by attempting to create a signed URL
            // If this fails, the file doesn't exist and we should skip this path
            const { error: verifyError } = await supabaseAdmin.storage
              .from('files')
              .createSignedUrl(documentPath, 60); // Short expiry just for verification
            
            // If verification succeeds, use the public URL
            if (!verifyError) {
              imageUrlCache.current.set(cacheKey, publicData.publicUrl);
              return publicData.publicUrl;
            }
            // If verification fails, file doesn't exist, skip to next path
            continue;
          }
          
          // If public URL method didn't work, try signed URL directly
          const { data: signedData, error: signedError } = await supabaseAdmin.storage
            .from('files')
            .createSignedUrl(documentPath, 3600); // 1 hour expiry
          
          if (!signedError && signedData?.signedUrl) {
            imageUrlCache.current.set(cacheKey, signedData.signedUrl);
            return signedData.signedUrl;
          }
        } catch (error) {
          // File doesn't exist or other error, skip this path
          continue;
        }
      }
    }
    
    // Last resort: try path as-is in files bucket
    try {
      // Try public URL first
      const { data: publicData } = supabaseAdmin.storage.from('files').getPublicUrl(path);
      if (publicData?.publicUrl) {
        imageUrlCache.current.set(cacheKey, publicData.publicUrl);
        return publicData.publicUrl;
      }
      
      // Fallback to signed URL
      const { data: signedData, error: signedError } = await supabaseAdmin.storage
        .from('files')
        .createSignedUrl(path, 3600); // 1 hour expiry
      
      if (!signedError && signedData?.signedUrl) {
        imageUrlCache.current.set(cacheKey, signedData.signedUrl);
        return signedData.signedUrl;
      }
    } catch (error) {
      // Continue
    }
    
    // Cache null result
    imageUrlCache.current.set(cacheKey, null);
    return null;
  };
  
  // Load image directly from folder based on userId and imageType (with caching) - FALLBACK ONLY
  const loadImageFromFolder = async (userId: string, imageType: 'front' | 'back' | 'selfie'): Promise<string | null> => {
    const cacheKey = `${userId}-${imageType}`;
    
    // Check cache first
    if (imageUrlCache.current.has(cacheKey)) {
      const cachedUrl = imageUrlCache.current.get(cacheKey);
      if (cachedUrl) {
        markUserHasPhotos(userId);
      }
      return cachedUrl || null;
    }
    
    const folderPath = `documents/${userId}`;
    
    try {
      // List all files in the folder
      const { data: files, error } = await supabaseAdmin.storage
        .from('files')
        .list(folderPath, {
          limit: 100,
          sortBy: { column: 'name', order: 'desc' }
        });
      
      if (error || !files || files.length === 0) {
        imageUrlCache.current.set(cacheKey, null);
        return null;
      }
      
      // Define search patterns for each image type
      const searchPatterns: string[] = [];
      if (imageType === 'front') {
        searchPatterns.push('id_front', 'front', 'idfront');
      } else if (imageType === 'back') {
        searchPatterns.push('id_back', 'back', 'idback');
      } else if (imageType === 'selfie') {
        searchPatterns.push('selfie', 'selfie_with_id');
      }
      
      // Find the first file matching the pattern (sorted by name desc, so newest first)
      for (const file of files) {
        const fileName = file.name.toLowerCase();
        for (const pattern of searchPatterns) {
          if (fileName.includes(pattern.toLowerCase())) {
            const fullPath = `${folderPath}/${file.name}`;
            
            // Try public URL first
            const { data: urlData } = supabaseAdmin.storage
              .from('files')
              .getPublicUrl(fullPath);
            if (urlData?.publicUrl) {
              // Cache the URL
              imageUrlCache.current.set(cacheKey, urlData.publicUrl);
              markUserHasPhotos(userId);
              return urlData.publicUrl;
            }
            
            // Fallback to signed URL
            const { data: signedData, error: signedError } = await supabaseAdmin.storage
              .from('files')
              .createSignedUrl(fullPath, 3600); // 1 hour expiry
            
            if (!signedError && signedData?.signedUrl) {
              imageUrlCache.current.set(cacheKey, signedData.signedUrl);
              markUserHasPhotos(userId);
              return signedData.signedUrl;
            }
          }
        }
      }
      
      // Cache null result
      imageUrlCache.current.set(cacheKey, null);
      return null;
    } catch (error) {
      console.error('Error loading image from folder:', error);
      imageUrlCache.current.set(cacheKey, null);
      return null;
    }
  };
  
  
  // Component for async image loading - only loads when shouldLoad is true (lazy loading)
  const AsyncImage = ({ path, userId, imageType, alt, className, onError, onLoad, shouldLoad = true, style }: {
    path: string | undefined;
    userId: string;
    imageType: 'front' | 'back' | 'selfie';
    alt: string;
    className?: string;
    onError?: (e: React.SyntheticEvent<HTMLImageElement>) => void;
    onLoad?: (e: React.SyntheticEvent<HTMLImageElement>) => void;
    shouldLoad?: boolean;
    style?: React.CSSProperties;
  }) => {
    const cacheKey = `${userId}-${imageType}`;
    const [imageUrl, setImageUrl] = useState<string | null>(() => {
      // Initialize from cache if available
      return imageUrlCache.current.get(cacheKey) || null;
    });
    const [loading, setLoading] = useState(() => !imageUrl && shouldLoad);
    const [error, setError] = useState(false);
    
    useEffect(() => {
      // Don't load if shouldLoad is false
      if (!shouldLoad) {
        return;
      }
      
      // If we have a cached URL, use it immediately
      const cachedUrl = imageUrlCache.current.get(cacheKey);
      if (cachedUrl !== undefined && cachedUrl !== null) {
        setImageUrl(cachedUrl);
        setLoading(false);
        markUserHasPhotos(userId);
        return;
      }
      
      // Prioritize folder-based search since database paths may be incorrect
      // (e.g., edge function sets id_cards/... but files are in documents/...)
      loadImageFromFolder(userId, imageType).then(folderUrl => {
        if (folderUrl) {
          imageUrlCache.current.set(cacheKey, folderUrl);
          setImageUrl(folderUrl);
          setLoading(false);
          markUserHasPhotos(userId);
          return;
        }
        
        // Folder method failed, try database path as fallback
        if (path) {
          getImageUrl(path, userId).then(url => {
            if (url) {
              // Found via URL, cache and use it
              imageUrlCache.current.set(cacheKey, url);
              setImageUrl(url);
              setLoading(false);
              markUserHasPhotos(userId);
            } else {
              // Both methods failed
              imageUrlCache.current.set(cacheKey, null);
              setImageUrl(null);
              setLoading(false);
              setError(true);
            }
          }).catch(() => {
            setLoading(false);
            setError(true);
          });
        } else {
          // No path and folder method failed
          imageUrlCache.current.set(cacheKey, null);
          setImageUrl(null);
          setLoading(false);
          setError(true);
        }
      }).catch(() => {
        // Folder method error, try database path as fallback
        if (path) {
          getImageUrl(path, userId).then(url => {
            if (url) {
              imageUrlCache.current.set(cacheKey, url);
              setImageUrl(url);
              setLoading(false);
              markUserHasPhotos(userId);
            } else {
              setLoading(false);
              setError(true);
            }
          }).catch(() => {
            setLoading(false);
            setError(true);
          });
        } else {
          setLoading(false);
          setError(true);
        }
      });
    }, [path, userId, imageType, cacheKey, shouldLoad]);
    
    if (!shouldLoad) {
      return (
        <div className={`${className} flex items-center justify-center bg-gray-200`}>
          <i className={`fas ${imageType === 'selfie' ? 'fa-user' : 'fa-id-card'} text-gray-400 text-2xl`}></i>
        </div>
      );
    }
    
    if (loading) {
      return (
        <div className={`${className} flex items-center justify-center bg-gray-200`}>
          <i className="fas fa-spinner fa-spin text-gray-400"></i>
        </div>
      );
    }
    
    if (error || !imageUrl) {
      return (
        <div className={`${className} flex items-center justify-center bg-gray-200`}>
          <i className={`fas ${imageType === 'selfie' ? 'fa-user' : 'fa-id-card'} text-gray-400 text-2xl`}></i>
        </div>
      );
    }
    
    return (
      <img
        src={imageUrl}
        alt={alt}
        className={className}
        style={style || {}}
        onError={(e) => {
          setError(true);
          if (onError) onError(e);
        }}
        onLoad={(e) => {
          markUserHasPhotos(userId);
          if (onLoad) onLoad(e);
        }}
      />
    );
  };

  const viewImage = async (user: User, type: 'front' | 'back' | 'selfie') => {
    // Try to get image URL from database path first (signed URL)
    let imageUrl: string | null = null;
    
    if (type === 'front' && user.id_front_url) {
      imageUrl = await getImageUrl(user.id_front_url, user.id);
    } else if (type === 'back' && user.id_back_url) {
      imageUrl = await getImageUrl(user.id_back_url, user.id);
    } else if (type === 'selfie' && user.selfie_url) {
      imageUrl = await getImageUrl(user.selfie_url, user.id);
    }
    
    // If URL method failed, try folder method
    if (!imageUrl) {
      imageUrl = await loadImageFromFolder(user.id, type);
    }

    if (imageUrl) {
      setSelectedImage(imageUrl);
      setImageType(type);
      setPreviewImageUser(user); // Store user for retry
      setShowImageModal(true);
    } else {
      // Image not available - silently fail (no popup)
      console.warn('Image not available for user:', user.id, 'type:', type);
    }
  };

  // Retry loading image with signed URL when public URL fails
  const retryImageWithSignedUrl = async (user: User, type: 'front' | 'back' | 'selfie') => {
    try {
      // Try to get the file path from folder
      const folderPath = `documents/${user.id}`;
      const { data: files } = await supabaseAdmin.storage
        .from('files')
        .list(folderPath, { limit: 100 });

      if (!files || files.length === 0) return null;

      // Find the matching file
      const searchPatterns: string[] = [];
      if (type === 'front') {
        searchPatterns.push('id_front', 'front', 'idfront');
      } else if (type === 'back') {
        searchPatterns.push('id_back', 'back', 'idback');
      } else if (type === 'selfie') {
        searchPatterns.push('selfie', 'selfie_with_id');
      }

      for (const file of files) {
        const fileName = file.name.toLowerCase();
        for (const pattern of searchPatterns) {
          if (fileName.includes(pattern.toLowerCase())) {
            const fullPath = `${folderPath}/${file.name}`;
            // Try signed URL
            const { data: signedData, error: signedError } = await supabaseAdmin.storage
              .from('files')
              .createSignedUrl(fullPath, 3600);
            
            if (!signedError && signedData?.signedUrl) {
              return signedData.signedUrl;
            }
          }
        }
      }
    } catch (error) {
      console.error('Error retrying with signed URL:', error);
    }
    return null;
  };

  // Reset rotations when a new user is selected
  useEffect(() => {
    if (selectedUser) {
      setImageRotations({ front: 0, back: 0, selfie: 0 });
    }
  }, [selectedUser?.id]);
  
  const dismissUser = (userId: string) => {
    // Add user to dismissed list
    setDismissedUserIds(prev => new Set([...prev, userId]));
  };

  const filteredUsers = users.filter(user => {
    // Exclude dismissed users
    if (dismissedUserIds.has(user.id)) {
      return false;
    }
    
    // Only show users with approved verification status
    if (user.verification_status !== 'approved') {
      return false;
    }
    
    const matchesSearch = !searchTerm || 
      user.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      user.phone?.includes(searchTerm) ||
      user.id_number?.includes(searchTerm);
    
    // Since we only show approved users, statusFilter is always 'approved' or 'all'
    const matchesStatus = statusFilter === 'all' || statusFilter === 'approved';
    
    const matchesRole = roleFilter === 'all' || user.role === roleFilter;

    return matchesSearch && matchesStatus && matchesRole;
  });
  
  // Separate users with and without IDs (based on folder contents)
  const usersWithoutIds = filteredUsers.filter(user => !usersWithPhotos.has(user.id));
  const usersWithIds = filteredUsers.filter(user => usersWithPhotos.has(user.id));
  
  // Sort: users without IDs first, then users with IDs
  const sortedUsers = [...usersWithoutIds, ...usersWithIds];

  const getStatusBadgeColor = (status: string | null | undefined) => {
    switch (status) {
      case 'approved':
        return 'bg-green-100 text-green-800';
      case 'rejected':
        return 'bg-red-100 text-red-800';
      case 'pending':
      default:
        return 'bg-yellow-100 text-yellow-800';
    }
  };

  const getStatusText = (status: string | null | undefined) => {
    switch (status) {
      case 'approved':
        return 'موافق';
      case 'rejected':
        return 'مرفوض';
      case 'pending':
      default:
        return 'معلق';
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-500"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-gray-900">التحقق / Verification</h2>
        <p className="text-gray-600 text-sm mt-1">إدارة التحقق من السائقين والتجار / Manage driver and merchant verification</p>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-xl shadow-sm p-4">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">بحث / Search</label>
            <input
              type="text"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="الاسم، الهاتف، أو رقم الهوية..."
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">حالة التحقق / Status</label>
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value as any)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
            >
              <option value="all">الكل / All</option>
              <option value="pending">معلق / Pending</option>
              <option value="approved">موافق / Approved</option>
              <option value="rejected">مرفوض / Rejected</option>
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">النوع / Role</label>
            <select
              value={roleFilter}
              onChange={(e) => setRoleFilter(e.target.value as any)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
            >
              <option value="all">الكل / All</option>
              <option value="driver">سائق / Driver</option>
              <option value="merchant">تاجر / Merchant</option>
            </select>
          </div>
          <div className="flex items-end">
            <button
              onClick={loadUsers}
              className="w-full px-4 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-lg font-medium"
            >
              <i className="fas fa-sync-alt mr-2"></i>
              تحديث / Refresh
            </button>
          </div>
        </div>
      </div>

      {/* Warning for users without IDs */}
      {usersWithoutIds.length > 0 && (
        <div className="bg-yellow-50 border-l-4 border-yellow-400 p-4 rounded-lg">
          <div className="flex items-start">
            <div className="flex-shrink-0">
              <i className="fas fa-exclamation-triangle text-yellow-400 text-xl"></i>
            </div>
            <div className="mr-3 flex-1">
              <h3 className="text-sm font-medium text-yellow-800">
                تحذير: {usersWithoutIds.length} مستخدم بدون صور هوية / Warning: {usersWithoutIds.length} users without ID photos
              </h3>
              <p className="mt-1 text-sm text-yellow-700">
                هؤلاء المستخدمون لا يملكون صور هوية مرفوعة. يرجى مراجعة حساباتهم / These users don't have uploaded ID photos. Please review their accounts.
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Users List - Minimal View */}
      <div className="space-y-2">
        {sortedUsers.map(user => (
          <div 
            key={user.id} 
            className={`bg-white rounded-lg shadow-sm p-4 flex items-center justify-between hover:shadow-md transition-shadow ${
              !usersWithPhotos.has(user.id) ? 'border-l-4 border-yellow-400' : ''
            }`}
          >
            {/* Left: Name and Registration Date */}
            <div className="flex items-center gap-4 flex-1">
              <div className={`w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 ${
                user.role === 'driver' ? 'bg-blue-100' : 'bg-purple-100'
              }`}>
                <i className={`fas ${
                  user.role === 'driver' ? 'fa-motorcycle' : 'fa-store'
                } ${user.role === 'driver' ? 'text-blue-600' : 'text-purple-600'}`}></i>
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-medium text-gray-900 truncate">{user.name || 'بدون اسم / No name'}</p>
                <p className="text-sm text-gray-500">
                  تاريخ التسجيل: {new Date(user.created_at).toLocaleDateString('ar-IQ', { 
                    year: 'numeric', 
                    month: 'short', 
                    day: 'numeric' 
                  })}
                </p>
              </div>
            </div>
            
            {/* Right: Details Button */}
            <button
              onClick={() => setSelectedUser(user)}
              className="px-4 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-lg font-medium transition-colors flex-shrink-0"
            >
              <i className="fas fa-eye mr-2"></i>
              التفاصيل / Details
            </button>
          </div>
        ))}
      </div>

      {sortedUsers.length === 0 && (
        <div className="bg-white rounded-xl shadow-sm p-12 text-center text-gray-500">
          <i className="fas fa-search text-4xl mb-2"></i>
          <p className="text-lg font-medium mb-1">لا توجد نتائج</p>
          <p className="text-sm">No results found</p>
        </div>
      )}

      {/* User Details Modal */}
      {selectedUser && (
        <div 
          className="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-40 p-4 overflow-y-auto"
          onClick={() => setSelectedUser(null)}
        >
          <div 
            className="bg-white rounded-xl shadow-xl max-w-5xl w-full max-h-[90vh] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Modal Header */}
            <div className="sticky top-0 bg-white border-b border-gray-200 p-6 flex items-center justify-between z-10">
              <div className="flex items-center gap-4">
                <div className={`w-16 h-16 rounded-full flex items-center justify-center ${
                  selectedUser.role === 'driver' ? 'bg-blue-100' : 'bg-purple-100'
                }`}>
                  <i className={`fas ${
                    selectedUser.role === 'driver' ? 'fa-motorcycle' : 'fa-store'
                  } ${selectedUser.role === 'driver' ? 'text-blue-600' : 'text-purple-600'} text-2xl`}></i>
                </div>
                <div>
                  {isEditing ? (
                    <input
                      type="text"
                      value={editedUser.name || ''}
                      onChange={(e) => handleFieldChange('name', e.target.value)}
                      className="text-2xl font-bold text-gray-900 border border-gray-300 rounded-lg px-3 py-1 mb-2 w-full"
                      placeholder="الاسم / Name"
                    />
                  ) : (
                    <h3 className="text-2xl font-bold text-gray-900">{selectedUser.name}</h3>
                  )}
                  {isEditing ? (
                    <input
                      type="text"
                      value={editedUser.phone || ''}
                      onChange={(e) => handleFieldChange('phone', e.target.value)}
                      className="text-gray-600 border border-gray-300 rounded-lg px-3 py-1 mb-2 w-full"
                      placeholder="الهاتف / Phone"
                    />
                  ) : (
                    <p className="text-gray-600">{selectedUser.phone}</p>
                  )}
                  <div className="flex gap-2 mt-2">
                    <span className={`inline-block px-3 py-1 text-sm rounded-full ${
                      selectedUser.role === 'driver' ? 'bg-blue-100 text-blue-800' : 'bg-purple-100 text-purple-800'
                    }`}>
                      {selectedUser.role === 'driver' ? 'سائق' : 'تاجر'}
                  </span>
                    <span className={`inline-block px-3 py-1 text-sm rounded-full ${getStatusBadgeColor(selectedUser.verification_status)}`}>
                      {getStatusText(selectedUser.verification_status)}
                  </span>
                </div>
                </div>
              </div>
              <div className="flex items-center gap-2">
                {isEditing ? (
                  <>
                    <button
                      onClick={handleSaveUser}
                      disabled={updatingUserId === selectedUser.id}
                      className="px-4 py-2 bg-green-500 hover:bg-green-600 text-white rounded-lg font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      <i className="fas fa-save mr-1"></i>
                      {updatingUserId === selectedUser.id ? 'جاري الحفظ...' : 'حفظ / Save'}
                    </button>
                    <button
                      onClick={handleCancelEdit}
                      disabled={updatingUserId === selectedUser.id}
                      className="px-4 py-2 bg-gray-500 hover:bg-gray-600 text-white rounded-lg font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      <i className="fas fa-times mr-1"></i>
                      إلغاء / Cancel
                    </button>
                  </>
                ) : (
                  <button
                    onClick={handleEditUser}
                    className="px-4 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg font-medium transition-colors"
                  >
                    <i className="fas fa-edit mr-1"></i>
                    تعديل / Edit
                  </button>
                )}
                <button
                  onClick={() => {
                    setIsEditing(false);
                    setEditedUser({});
                    setSelectedUser(null);
                  }}
                  className="text-gray-400 hover:text-gray-600 text-2xl"
                >
                  <i className="fas fa-times"></i>
                </button>
              </div>
            </div>

            {/* Modal Content */}
            <div className="p-6 space-y-6">
              {/* User Information */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="p-4 bg-gray-50 rounded-lg">
                <p className="text-xs text-gray-600 mb-1">رقم الهوية / ID Number</p>
                  {isEditing ? (
                    <input
                      type="text"
                      value={editedUser.id_number || ''}
                      onChange={(e) => handleFieldChange('id_number', e.target.value)}
                      className="font-mono text-sm font-medium w-full border border-gray-300 rounded-lg px-3 py-2"
                      placeholder="رقم الهوية / ID Number"
                    />
                  ) : (
                    <p className="font-mono text-sm font-medium">{selectedUser.id_number || 'غير متوفر / N/A'}</p>
                  )}
              </div>
                <div className="p-4 bg-blue-50 rounded-lg">
              <p className="text-xs text-gray-600 mb-1">معرّف المستخدم / User ID</p>
                  <p className="font-mono text-xs font-medium break-all">{selectedUser.id}</p>
            </div>
                <div className="p-4 bg-gray-50 rounded-lg">
                  <p className="text-xs text-gray-600 mb-1">المدينة / City</p>
                  {isEditing ? (
                    <select
                      value={editedUser.city || ''}
                      onChange={(e) => handleFieldChange('city', e.target.value || null)}
                      className="text-sm font-medium w-full border border-gray-300 rounded-lg px-3 py-2"
                    >
                      <option value="">اختر المدينة / Select City</option>
                      <option value="najaf">النجف / Najaf</option>
                      <option value="mosul">الموصل / Mosul</option>
                    </select>
                  ) : (
                <p className="text-sm font-medium">
                      {selectedUser.city === 'najaf' ? 'النجف / Najaf' : selectedUser.city === 'mosul' ? 'الموصل / Mosul' : 'غير محدد / Not set'}
                </p>
                  )}
              </div>
                {/* Legal Name Fields */}
                <div className="p-4 bg-gray-50 rounded-lg">
                  <p className="text-xs text-gray-600 mb-1">الاسم الأول القانوني / Legal First Name</p>
                  {isEditing ? (
                    <input
                      type="text"
                      value={editedUser.legal_first_name || ''}
                      onChange={(e) => handleFieldChange('legal_first_name', e.target.value)}
                      className="text-sm font-medium w-full border border-gray-300 rounded-lg px-3 py-2"
                      placeholder="الاسم الأول / First Name"
                    />
                  ) : (
                    <p className="text-sm font-medium">{selectedUser.legal_first_name || 'غير متوفر / N/A'}</p>
                  )}
                </div>
                <div className="p-4 bg-gray-50 rounded-lg">
                  <p className="text-xs text-gray-600 mb-1">اسم الأب / Father Name</p>
                  {isEditing ? (
                    <input
                      type="text"
                      value={editedUser.legal_father_name || ''}
                      onChange={(e) => handleFieldChange('legal_father_name', e.target.value)}
                      className="text-sm font-medium w-full border border-gray-300 rounded-lg px-3 py-2"
                      placeholder="اسم الأب / Father Name"
                    />
                  ) : (
                    <p className="text-sm font-medium">{selectedUser.legal_father_name || 'غير متوفر / N/A'}</p>
                  )}
                </div>
                <div className="p-4 bg-gray-50 rounded-lg">
                  <p className="text-xs text-gray-600 mb-1">اسم الجد / Grandfather Name</p>
                  {isEditing ? (
                    <input
                      type="text"
                      value={editedUser.legal_grandfather_name || ''}
                      onChange={(e) => handleFieldChange('legal_grandfather_name', e.target.value)}
                      className="text-sm font-medium w-full border border-gray-300 rounded-lg px-3 py-2"
                      placeholder="اسم الجد / Grandfather Name"
                    />
                  ) : (
                    <p className="text-sm font-medium">{selectedUser.legal_grandfather_name || 'غير متوفر / N/A'}</p>
                  )}
                </div>
                <div className="p-4 bg-gray-50 rounded-lg">
                  <p className="text-xs text-gray-600 mb-1">اسم العائلة / Family Name</p>
                  {isEditing ? (
                    <input
                      type="text"
                      value={editedUser.legal_family_name || ''}
                      onChange={(e) => handleFieldChange('legal_family_name', e.target.value)}
                      className="text-sm font-medium w-full border border-gray-300 rounded-lg px-3 py-2"
                      placeholder="اسم العائلة / Family Name"
                    />
                  ) : (
                    <p className="text-sm font-medium">{selectedUser.legal_family_name || 'غير متوفر / N/A'}</p>
                  )}
                </div>
              </div>
                
              {/* ID Images - Load only when modal is open */}
              <div>
                <div className="flex items-center justify-between mb-4">
                  <p className="text-lg font-semibold text-gray-900">صور الهوية / ID Documents</p>
                  <button
                    onClick={reVerifyIdCards}
                    disabled={updatingUserId === selectedUser.id}
                    className="px-4 py-2 bg-purple-500 hover:bg-purple-600 text-white rounded-lg font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                  >
                    <i className="fas fa-sync-alt"></i>
                    {updatingUserId === selectedUser.id ? 'جاري التحقق...' : 'إعادة التحقق / Re-verify'}
                  </button>
                </div>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    {/* Front ID */}
                    <div className="space-y-2">
                      <div 
                        className="relative aspect-[3/2] bg-gray-100 rounded-lg overflow-hidden cursor-pointer hover:opacity-90 transition-opacity"
                        onClick={(e) => {
                          e.stopPropagation();
                          viewImage(selectedUser, 'front');
                        }}
                  >
                    <div className="absolute inset-0 flex items-center justify-center">
                    <AsyncImage
                          path={selectedUser.id_front_url}
                          userId={selectedUser.id}
                      imageType="front"
                      alt="Front"
                          className="max-w-full max-h-full object-contain pointer-events-none transition-transform duration-300"
                          style={{ transform: `rotate(${imageRotations.front}deg)` }}
                          shouldLoad={true}
                        />
                    </div>
                        <div className="absolute bottom-0 left-0 right-0 bg-black bg-opacity-50 text-white text-xs p-2 text-center pointer-events-none z-10">
                          أمامي / Front
                    </div>
                    </div>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          setImageRotations(prev => ({ ...prev, front: (prev.front + 90) % 360 }));
                        }}
                        className="w-full px-2 py-1 bg-gray-200 hover:bg-gray-300 text-gray-700 rounded text-xs font-medium transition-colors flex items-center justify-center gap-1"
                        title="Rotate 90°"
                      >
                        <i className="fas fa-redo text-xs"></i>
                        <span>دوران / Rotate</span>
                  </button>
                </div>
                
                {/* Back ID */}
                    <div className="space-y-2">
                      <div 
                        className="relative aspect-[3/2] bg-gray-100 rounded-lg overflow-hidden cursor-pointer hover:opacity-90 transition-opacity"
                        onClick={(e) => {
                          e.stopPropagation();
                          viewImage(selectedUser, 'back');
                        }}
                  >
                    <div className="absolute inset-0 flex items-center justify-center">
                    <AsyncImage
                          path={selectedUser.id_back_url}
                          userId={selectedUser.id}
                      imageType="back"
                      alt="Back"
                          className="max-w-full max-h-full object-contain pointer-events-none transition-transform duration-300"
                          style={{ transform: `rotate(${imageRotations.back}deg)` }}
                          shouldLoad={true}
                        />
                    </div>
                        <div className="absolute bottom-0 left-0 right-0 bg-black bg-opacity-50 text-white text-xs p-2 text-center pointer-events-none z-10">
                          خلفي / Back
                    </div>
                    </div>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          setImageRotations(prev => ({ ...prev, back: (prev.back + 90) % 360 }));
                        }}
                        className="w-full px-2 py-1 bg-gray-200 hover:bg-gray-300 text-gray-700 rounded text-xs font-medium transition-colors flex items-center justify-center gap-1"
                        title="Rotate 90°"
                      >
                        <i className="fas fa-redo text-xs"></i>
                        <span>دوران / Rotate</span>
                  </button>
                </div>
                
                {/* Selfie */}
                    <div className="space-y-2">
                      <div 
                        className="relative aspect-[3/2] bg-gray-100 rounded-lg overflow-hidden cursor-pointer hover:opacity-90 transition-opacity"
                        onClick={(e) => {
                          e.stopPropagation();
                          viewImage(selectedUser, 'selfie');
                        }}
                  >
                    <div className="absolute inset-0 flex items-center justify-center">
                    <AsyncImage
                          path={selectedUser.selfie_url}
                          userId={selectedUser.id}
                      imageType="selfie"
                      alt="Selfie"
                          className="max-w-full max-h-full object-contain pointer-events-none transition-transform duration-300"
                          style={{ transform: `rotate(${imageRotations.selfie}deg)` }}
                          shouldLoad={true}
                        />
                    </div>
                        <div className="absolute bottom-0 left-0 right-0 bg-black bg-opacity-50 text-white text-xs p-2 text-center pointer-events-none z-10">
                          سيلفي / Selfie
                    </div>
                    </div>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          setImageRotations(prev => ({ ...prev, selfie: (prev.selfie + 90) % 360 }));
                        }}
                        className="w-full px-2 py-1 bg-gray-200 hover:bg-gray-300 text-gray-700 rounded text-xs font-medium transition-colors flex items-center justify-center gap-1"
                        title="Rotate 90°"
                      >
                        <i className="fas fa-redo text-xs"></i>
                        <span>دوران / Rotate</span>
                  </button>
                  </div>
              </div>
            </div>

            {/* Verification Notes */}
              <div className="p-4 bg-blue-50 rounded-lg">
                <p className="text-xs text-gray-600 mb-1">ملاحظات التحقق / Verification Notes</p>
                {isEditing ? (
                  <textarea
                    value={editedUser.id_verification_notes || ''}
                    onChange={(e) => handleFieldChange('id_verification_notes', e.target.value)}
                    className="text-sm text-gray-700 w-full border border-gray-300 rounded-lg px-3 py-2 min-h-[100px]"
                    placeholder="أضف ملاحظات التحقق / Add verification notes"
                  />
                ) : (
                  <p className="text-sm text-gray-700">{selectedUser.id_verification_notes || 'لا توجد ملاحظات / No notes'}</p>
                )}
              </div>

            {/* Verification Status Controls */}
              <div className="space-y-3 border-t border-gray-200 pt-6">
                <p className="text-lg font-semibold text-gray-900 mb-4">إجراءات التحقق / Verification Actions</p>
                
                {/* Three Main Actions */}
                <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                  {/* Approve Button */}
                <button
                    onClick={() => {
                      updateVerificationStatus(selectedUser.id, 'approved');
                    }}
                    disabled={updatingUserId === selectedUser.id}
                    className={`px-6 py-3 rounded-lg text-base font-semibold transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 ${
                      selectedUser.verification_status === 'approved'
                        ? 'bg-green-600 text-white shadow-lg'
                        : 'bg-green-500 text-white hover:bg-green-600 shadow-md hover:shadow-lg'
                    }`}
                  >
                    <i className="fas fa-check-circle text-xl"></i>
                    <span>{updatingUserId === selectedUser.id ? 'جاري...' : 'موافق / Approve'}</span>
                </button>
                  
                  {/* Pending Button */}
                <button
                    onClick={() => {
                      updateVerificationStatus(selectedUser.id, 'pending');
                    }}
                    disabled={updatingUserId === selectedUser.id}
                    className={`px-6 py-3 rounded-lg text-base font-semibold transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 ${
                      selectedUser.verification_status === 'pending' || !selectedUser.verification_status
                        ? 'bg-yellow-600 text-white shadow-lg'
                        : 'bg-yellow-500 text-white hover:bg-yellow-600 shadow-md hover:shadow-lg'
                    }`}
                  >
                    <i className="fas fa-clock text-xl"></i>
                    <span>{updatingUserId === selectedUser.id ? 'جاري...' : 'معلق / Pending'}</span>
                </button>
                  
                  {/* Blocked Button */}
              <button
                    onClick={() => {
                      updateVerificationStatus(selectedUser.id, 'blocked');
                    }}
                    disabled={updatingUserId === selectedUser.id}
                    className={`px-6 py-3 rounded-lg text-base font-semibold transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 ${
                      'bg-red-600 text-white hover:bg-red-700 shadow-md hover:shadow-lg'
                    }`}
                  >
                    <i className="fas fa-ban text-xl"></i>
                    <span>{updatingUserId === selectedUser.id ? 'جاري...' : 'حظر / Block'}</span>
              </button>
            </div>

                {/* Action Descriptions */}
                <div className="grid grid-cols-1 md:grid-cols-3 gap-3 mt-2">
                  <div className="p-3 bg-green-50 rounded-lg">
                    <p className="text-xs font-medium text-green-800 mb-1">
                      <i className="fas fa-check-circle mr-1"></i>
                      موافق / Approve
                    </p>
                    <p className="text-xs text-green-700">
                      المستخدم لا يحتاج للتحقق بعد الآن / User no longer needs verification
                    </p>
            </div>
                  <div className="p-3 bg-yellow-50 rounded-lg">
                    <p className="text-xs font-medium text-yellow-800 mb-1">
                      <i className="fas fa-clock mr-1"></i>
                      معلق / Pending
                    </p>
                    <p className="text-xs text-yellow-700">
                      يطلب من المستخدم إعادة رفع الهوية / User will be asked to reupload IDs
                    </p>
          </div>
                  <div className="p-3 bg-red-50 rounded-lg">
                    <p className="text-xs font-medium text-red-800 mb-1">
                      <i className="fas fa-ban mr-1"></i>
                      حظر / Block
                    </p>
                    <p className="text-xs text-red-700">
                      حذف المستخدم وإرسال رسالة واتساب / Delete user and send WhatsApp message
                        </p>
                      </div>
                  </div>
                  
                {/* Dismiss Button (Secondary Action) */}
                <div className="pt-3 border-t border-gray-200">
                      <button
                    onClick={() => dismissUser(selectedUser.id)}
                    disabled={dismissedUserIds.has(selectedUser.id)}
                    className={`w-full px-4 py-2 rounded-lg text-sm font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed ${
                      dismissedUserIds.has(selectedUser.id)
                            ? 'bg-gray-400 text-white'
                        : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                    }`}
                  >
                    <i className="fas fa-eye-slash mr-1"></i>
                    {dismissedUserIds.has(selectedUser.id) ? 'تم الإخفاء / Dismissed' : 'إخفاء مؤقت / Temporarily Dismiss'}
                      </button>
                </div>
                
                {/* Manual/AI Verification Toggle */}
                      <button
                  onClick={() => toggleManualVerified(selectedUser.id, selectedUser.manual_verified || false)}
                  disabled={updatingUserId === selectedUser.id}
                  className={`w-full px-4 py-2 rounded-lg text-sm font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed ${
                    selectedUser.manual_verified
                      ? 'bg-blue-500 text-white'
                      : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                  }`}
                >
                  <i className={`fas ${selectedUser.manual_verified ? 'fa-check-circle' : 'fa-circle'} mr-1`}></i>
                  {selectedUser.manual_verified ? 'تحقق يدوي مفعّل' : 'تحقق يدوي معطّل'} / Manual Verification {selectedUser.manual_verified ? 'ON' : 'OFF'}
                      </button>
                    </div>
                    
              {/* Metadata */}
              <div className="pt-4 border-t border-gray-200">
                <p className="text-xs text-gray-500">
                  تاريخ التسجيل: {new Date(selectedUser.created_at).toLocaleDateString('ar-IQ')}
                </p>
                {selectedUser.id_verified_at && (
                  <p className="text-xs text-gray-500">
                    تاريخ التحقق: {new Date(selectedUser.id_verified_at).toLocaleDateString('ar-IQ')}
                  </p>
                )}
                        </div>
                        </div>
                    </div>
        </div>
      )}

      {/* Image Modal */}
      {showImageModal && selectedImage && (
        <div 
          className="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50"
          onClick={() => setShowImageModal(false)}
        >
          <div className="relative max-w-4xl max-h-[90vh] p-4">
            <button
              onClick={() => setShowImageModal(false)}
              className="absolute top-4 right-4 text-white bg-black bg-opacity-50 rounded-full w-10 h-10 flex items-center justify-center hover:bg-opacity-75 z-10"
            >
              <i className="fas fa-times"></i>
            </button>
            <img
              src={selectedImage}
              alt={imageType}
              className="max-w-full max-h-[90vh] object-contain rounded-lg"
              onClick={(e) => e.stopPropagation()}
              onError={async (e) => {
                console.error('Failed to load image in preview:', selectedImage);
                const target = e.target as HTMLImageElement;
                
                // Retry with signed URL if we have user info
                if (previewImageUser) {
                  const signedUrl = await retryImageWithSignedUrl(previewImageUser, imageType);
                  if (signedUrl) {
                    console.log('Retrying with signed URL:', signedUrl);
                    target.src = signedUrl;
                    return;
                  }
                }
                
                // If retry failed, hide the image
                target.style.display = 'none';
              }}
              onLoad={() => {
                console.log('Image loaded successfully in preview');
              }}
            />
            <div className="absolute bottom-4 left-4 right-4 bg-black bg-opacity-50 text-white px-4 py-2 rounded-lg text-center">
              {imageType === 'front' ? 'الهوية - الوجه الأمامي' : imageType === 'back' ? 'الهوية - الوجه الخلفي' : 'صورة سيلفي مع الهوية'}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
