import { useEffect, useState, useRef } from 'react';
import { useParams, Link } from 'react-router-dom';

const SUPABASE_URL = 'https://bvtoxmmiitznagsbubhg.supabase.co';
const PRIMARY_COLOR = '#008C95';
const PRIMARY_COLOR_DARK = '#006A72';

function OrderTracking() {
  const { code } = useParams();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [orderData, setOrderData] = useState(null);
  const mapContainerRef = useRef(null);
  const mapInstanceRef = useRef(null);
  const markersRef = useRef([]);
  const mapboxLoadedRef = useRef(false);
  const markerPositionsRef = useRef({});

  useEffect(() => {
    if (!code) {
      setError('Invalid tracking code');
      setLoading(false);
      return;
    }

    // Load Mapbox CSS and JS
    if (!mapboxLoadedRef.current) {
      const link = document.createElement('link');
      link.href = 'https://api.mapbox.com/mapbox-gl-js/v2.15.0/mapbox-gl.css';
      link.rel = 'stylesheet';
      document.head.appendChild(link);

      const script = document.createElement('script');
      script.src = 'https://api.mapbox.com/mapbox-gl-js/v2.15.0/mapbox-gl.js';
      script.onload = () => {
        mapboxLoadedRef.current = true;
        fetchOrderData();
      };
      script.onerror = () => {
        setError('Failed to load map library');
        setLoading(false);
      };
      document.body.appendChild(script);
    } else {
      fetchOrderData();
    }

    // Poll for updates every 5 seconds
    const interval = setInterval(fetchOrderData, 5000);
    return () => clearInterval(interval);
  }, [code]);

  useEffect(() => {
    if (orderData && mapboxLoadedRef.current && !mapInstanceRef.current) {
      initializeMap();
    } else if (orderData && mapInstanceRef.current) {
      updateMap();
    }
  }, [orderData, mapboxLoadedRef.current]);

  const fetchOrderData = async () => {
    try {
      const response = await fetch(
        `${SUPABASE_URL}/functions/v1/get-order-tracking?code=${code}`,
        {
          headers: {
            'Content-Type': 'application/json',
          },
        }
      );

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to fetch order data');
      }

      const data = await response.json();
      setOrderData(data.order);
      setError(null);
    } catch (err) {
      setError(err.message);
      console.error('Error fetching order data:', err);
    } finally {
      setLoading(false);
    }
  };

  const initializeMap = () => {
    if (!mapContainerRef.current || !orderData || !window.mapboxgl) return;

    const mapboxgl = window.mapboxgl;
    const token = import.meta.env.VITE_MAPBOX_ACCESS_TOKEN;

    if (!token) {
      console.error('Mapbox token not found');
      setError('Map configuration error');
      return;
    }

    mapboxgl.accessToken = token;

    try {
      const map = new mapboxgl.Map({
        container: mapContainerRef.current,
        style: 'mapbox://styles/mapbox/streets-v12',
        center: [orderData.delivery.longitude, orderData.delivery.latitude],
        zoom: 13,
      });

      map.addControl(new mapboxgl.NavigationControl());

      map.on('load', () => {
        mapInstanceRef.current = map;
        updateMap();
      });

      map.on('error', (e) => {
        console.error('Map error:', e);
      });
    } catch (error) {
      console.error('Error initializing map:', error);
      setError('Failed to initialize map');
    }
  };

  const flyToLocation = (lng, lat, zoom = 15) => {
    if (!mapInstanceRef.current) return;
    mapInstanceRef.current.flyTo({
      center: [lng, lat],
      zoom: zoom,
      duration: 1000,
    });
  };

  const showAllLocations = () => {
    if (!mapInstanceRef.current || !orderData) return;
    const bounds = new window.mapboxgl.LngLatBounds();
    bounds.extend([orderData.pickup.longitude, orderData.pickup.latitude]);
    bounds.extend([orderData.delivery.longitude, orderData.delivery.latitude]);
    if (orderData.driver_location && ['on_the_way', 'delivered'].includes(orderData.status)) {
      bounds.extend([orderData.driver_location.longitude, orderData.driver_location.latitude]);
    }
    mapInstanceRef.current.fitBounds(bounds, {
      padding: { top: 100, bottom: 100, left: 100, right: 100 },
      duration: 1000,
    });
  };

  const updateMap = () => {
    if (!mapInstanceRef.current || !orderData || !window.mapboxgl) return;

    const mapboxgl = window.mapboxgl;
    const map = mapInstanceRef.current;

    // Clear existing markers
    markersRef.current.forEach(marker => marker.remove());
    markersRef.current = [];
    markerPositionsRef.current = {};

    const bounds = new mapboxgl.LngLatBounds();

    // Add pickup marker (📍)
    const pickupEl = document.createElement('div');
    pickupEl.className = 'map-marker pickup-marker';
    pickupEl.innerHTML = '📍';
    pickupEl.style.cssText = `
      font-size: 32px;
      cursor: pointer;
      filter: drop-shadow(0 2px 4px rgba(0,0,0,0.3));
    `;
    const pickupMarker = new mapboxgl.Marker({ element: pickupEl, anchor: 'bottom' })
      .setLngLat([orderData.pickup.longitude, orderData.pickup.latitude])
      .setPopup(new mapboxgl.Popup({ offset: 25 }).setHTML('<div style="padding: 8px 12px; font-weight: 600; font-size: 14px;">📍 موقع الاستلام</div>'))
      .addTo(map);
    pickupMarker.togglePopup();
    markersRef.current.push(pickupMarker);
    markerPositionsRef.current.pickup = { lng: orderData.pickup.longitude, lat: orderData.pickup.latitude };
    bounds.extend([orderData.pickup.longitude, orderData.pickup.latitude]);

    // Add delivery marker (🏠)
    const deliveryEl = document.createElement('div');
    deliveryEl.className = 'map-marker delivery-marker';
    deliveryEl.innerHTML = '🏠';
    deliveryEl.style.cssText = `
      font-size: 32px;
      cursor: pointer;
      filter: drop-shadow(0 2px 4px rgba(0,0,0,0.3));
    `;
    const deliveryMarker = new mapboxgl.Marker({ element: deliveryEl, anchor: 'bottom' })
      .setLngLat([orderData.delivery.longitude, orderData.delivery.latitude])
      .setPopup(new mapboxgl.Popup({ offset: 25 }).setHTML('<div style="padding: 8px 12px; font-weight: 600; font-size: 14px;">🏠 موقع التسليم</div>'))
      .addTo(map);
    markersRef.current.push(deliveryMarker);
    markerPositionsRef.current.delivery = { lng: orderData.delivery.longitude, lat: orderData.delivery.latitude };
    bounds.extend([orderData.delivery.longitude, orderData.delivery.latitude]);

    // Add driver marker with motorbike emoji if location available (🏍️)
    if (orderData.driver_location && ['on_the_way', 'delivered'].includes(orderData.status)) {
      const driverEl = document.createElement('div');
      driverEl.className = 'map-marker driver-marker';
      driverEl.innerHTML = '🏍️';
      driverEl.style.cssText = `
        font-size: 32px;
        cursor: pointer;
        filter: drop-shadow(0 2px 4px rgba(0,0,0,0.3));
      `;
      const driverMarker = new mapboxgl.Marker({ element: driverEl, anchor: 'bottom' })
        .setLngLat([orderData.driver_location.longitude, orderData.driver_location.latitude])
        .setPopup(new mapboxgl.Popup({ offset: 25 }).setHTML('<div style="padding: 8px 12px; font-weight: 600; font-size: 14px;">🏍️ موقع السائق</div>'))
        .addTo(map);
      markersRef.current.push(driverMarker);
      markerPositionsRef.current.driver = { lng: orderData.driver_location.longitude, lat: orderData.driver_location.latitude };
      bounds.extend([orderData.driver_location.longitude, orderData.driver_location.latitude]);
    }

    // Fit bounds with padding
    map.fitBounds(bounds, {
      padding: { top: 100, bottom: 150, left: 100, right: 100 },
      duration: 1000,
    });
  };

  if (loading) {
    return (
      <div style={styles.container}>
        <div style={styles.loadingContainer}>
          <div style={styles.spinner}></div>
          <p style={styles.loadingText}>جاري التحميل...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div style={styles.container}>
        <div style={styles.errorCard}>
          <div style={styles.errorIcon}>⚠️</div>
          <h2 style={styles.errorTitle}>خطأ</h2>
          <p style={styles.errorText}>{error}</p>
          <Link to="/" style={styles.homeLink}>العودة إلى الصفحة الرئيسية</Link>
        </div>
      </div>
    );
  }

  if (!orderData) {
    return (
      <div style={styles.container}>
        <div style={styles.errorCard}>
          <div style={styles.errorIcon}>📦</div>
          <h2 style={styles.errorTitle}>طلب غير موجود</h2>
          <p style={styles.errorText}>لم يتم العثور على الطلب</p>
          <Link to="/" style={styles.homeLink}>العودة إلى الصفحة الرئيسية</Link>
        </div>
      </div>
    );
  }

  const statusText = orderData.status === 'on_the_way' ? 'في الطريق 🚚' : 
                     orderData.status === 'delivered' ? 'تم التوصيل ✅' : 
                     orderData.status === 'accepted' ? 'تم قبول الطلب ✓' : 'قيد المعالجة';

  const hasDriverLocation = orderData.driver_location && ['on_the_way', 'delivered'].includes(orderData.status);

  return (
    <>
      <div style={styles.container}>
        <div style={styles.header}>
          <div style={styles.headerTop}>
            <Link to="/" style={styles.logoLink}>
              <div style={styles.logoContainer}>
                <span style={styles.logoText}>حُر</span>
                <span style={styles.logoSubtitle}>للتوصيل</span>
              </div>
            </Link>
          </div>
          <div style={styles.headerContent}>
            <div>
              <h1 style={styles.title}>تتبع الطلب</h1>
              <div style={styles.codeBadge}>#{orderData.code}</div>
            </div>
            <div style={styles.statusBadge}>
              <span style={styles.statusDot}></span>
              {statusText}
            </div>
          </div>
        </div>

        {orderData.status !== 'delivered' && (
          <div style={styles.mapSection}>
            <div style={styles.mapContainer}>
              <div ref={mapContainerRef} style={styles.map}></div>
              <div style={styles.mapButtons} className="map-buttons">
                <button 
                  className="map-button"
                  style={styles.mapButton}
                  onClick={() => flyToLocation(markerPositionsRef.current.pickup.lng, markerPositionsRef.current.pickup.lat)}
                  title="موقع الاستلام"
                >
                  📍
                </button>
                {hasDriverLocation && (
                  <button 
                    className="map-button"
                    style={styles.mapButton}
                    onClick={() => flyToLocation(markerPositionsRef.current.driver.lng, markerPositionsRef.current.driver.lat)}
                    title="موقع السائق"
                  >
                    🏍️
                  </button>
                )}
                <button 
                  className="map-button"
                  style={styles.mapButton}
                  onClick={() => flyToLocation(markerPositionsRef.current.delivery.lng, markerPositionsRef.current.delivery.lat)}
                  title="موقع التسليم"
                >
                  🏠
                </button>
                <button 
                  className="map-button"
                  style={{...styles.mapButton, ...styles.mapButtonAll}}
                  onClick={showAllLocations}
                  title="عرض الكل"
                >
                  ⛶
                </button>
              </div>
            </div>
          </div>
        )}

        <div style={styles.infoContainer}>
          <div className="info-card" style={styles.infoCard}>
            <div style={styles.infoIcon}>💰</div>
            <div style={styles.infoContent}>
              <div style={styles.infoLabel}>إجمالي المبلغ</div>
              <div style={styles.infoValue}>{parseInt(orderData.total_fee).toLocaleString('ar-IQ')} دينار</div>
            </div>
          </div>

          {orderData.driver && (
            <div className="info-card" style={styles.infoCard}>
              <div style={styles.infoIcon}>📞</div>
              <div style={styles.infoContent}>
                <div style={styles.infoLabel}>رقم السائق</div>
                <a href={`tel:${orderData.driver.phone}`} style={styles.phoneLink}>
                  {orderData.driver.phone}
                </a>
              </div>
            </div>
          )}

          <div className="info-card" style={styles.infoCard}>
            <div style={styles.infoIcon}>📍</div>
            <div style={styles.infoContent}>
              <div style={styles.infoLabel}>موقع الاستلام</div>
              <div style={styles.infoValueSmall}>{orderData.pickup.address}</div>
            </div>
          </div>

          <div className="info-card" style={styles.infoCard}>
            <div style={styles.infoIcon}>🏠</div>
            <div style={styles.infoContent}>
              <div style={styles.infoLabel}>موقع التسليم</div>
              <div style={styles.infoValueSmall}>{orderData.delivery.address}</div>
            </div>
          </div>
        </div>

        <div style={styles.footer}>
          <Link to="/" className="footer-link" style={styles.footerLink}>
            <span>🚀</span>
            <span>تعرف على تطبيق حُر للتوصيل</span>
          </Link>
        </div>
      </div>
      <style>{`
        .mapboxgl-popup-content {
          border-radius: 12px;
          padding: 0;
          box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        }
        .mapboxgl-popup-tip {
          border-top-color: white;
        }
        .map-button:hover {
          background-color: #f9fafb !important;
          transform: scale(1.05);
          box-shadow: 0 6px 16px rgba(0,0,0,0.2) !important;
        }
        .info-card:hover {
          transform: translateY(-2px);
          box-shadow: 0 6px 20px rgba(0,0,0,0.15) !important;
        }
        .footer-link:hover {
          background-color: rgba(255, 255, 255, 0.3) !important;
          transform: translateY(-2px);
          box-shadow: 0 6px 20px rgba(0,0,0,0.2) !important;
        }
        .home-link:hover {
          background-color: ${PRIMARY_COLOR_DARK} !important;
          transform: translateY(-2px);
        }
        @media (max-width: 768px) {
          .mapboxgl-ctrl-top-right {
            top: 10px;
            right: 10px;
          }
          .mapboxgl-ctrl-group {
            border-radius: 8px;
          }
        }
        @media (max-width: 480px) {
          .map-buttons {
            bottom: 12px;
            left: 12px;
          }
          .map-button {
            width: 44px;
            height: 44px;
            font-size: 20px;
          }
        }
      `}</style>
    </>
  );
}

const styles = {
  container: {
    minHeight: '100vh',
    background: `linear-gradient(135deg, ${PRIMARY_COLOR} 0%, ${PRIMARY_COLOR_DARK} 100%)`,
    padding: '0',
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
    direction: 'rtl',
  },
  header: {
    background: 'white',
    padding: '16px 16px 20px',
    boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
    marginBottom: '16px',
  },
  headerTop: {
    marginBottom: '12px',
  },
  logoLink: {
    textDecoration: 'none',
    display: 'inline-block',
  },
  logoContainer: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
  },
  logoText: {
    fontSize: '24px',
    fontWeight: '900',
    background: `linear-gradient(135deg, ${PRIMARY_COLOR} 0%, ${PRIMARY_COLOR_DARK} 100%)`,
    WebkitBackgroundClip: 'text',
    WebkitTextFillColor: 'transparent',
    fontFamily: 'Tajawal, Cairo, sans-serif',
  },
  logoSubtitle: {
    fontSize: '12px',
    color: '#6b7280',
    fontWeight: '600',
  },
  headerContent: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    flexWrap: 'wrap',
    gap: '12px',
  },
  title: {
    fontSize: '24px',
    fontWeight: '800',
    color: '#1f2937',
    margin: '0 0 8px 0',
  },
  codeBadge: {
    fontSize: '14px',
    fontWeight: '600',
    color: '#6b7280',
    backgroundColor: '#f3f4f6',
    padding: '6px 12px',
    borderRadius: '16px',
    display: 'inline-block',
  },
  statusBadge: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: '8px',
    fontSize: '14px',
    fontWeight: '600',
    color: '#374151',
    backgroundColor: '#f0fdf4',
    padding: '8px 16px',
    borderRadius: '20px',
    border: '2px solid #10b981',
  },
  statusDot: {
    width: '8px',
    height: '8px',
    backgroundColor: '#10b981',
    borderRadius: '50%',
    animation: 'pulse 2s infinite',
  },
  mapSection: {
    width: '100%',
    padding: '0 16px 16px',
  },
  mapContainer: {
    width: '100%',
    maxWidth: '1400px',
    margin: '0 auto',
    borderRadius: '16px',
    overflow: 'hidden',
    boxShadow: '0 10px 40px rgba(0,0,0,0.2)',
    border: '3px solid white',
    position: 'relative',
  },
  map: {
    width: '100%',
    height: '50vh',
    minHeight: '400px',
    backgroundColor: '#e5e7eb',
  },
  mapButtons: {
    position: 'absolute',
    bottom: '16px',
    left: '16px',
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
    zIndex: 1000,
  },
  mapButton: {
    width: '48px',
    height: '48px',
    borderRadius: '12px',
    border: 'none',
    backgroundColor: 'white',
    boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
    fontSize: '24px',
    cursor: 'pointer',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    transition: 'all 0.2s',
    ':hover': {
      backgroundColor: '#f9fafb',
      transform: 'scale(1.05)',
      boxShadow: '0 6px 16px rgba(0,0,0,0.2)',
    },
  },
  mapButtonAll: {
    fontSize: '20px',
  },
  infoContainer: {
    maxWidth: '1400px',
    margin: '0 auto 24px',
    padding: '0 16px',
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
    gap: '16px',
  },
  infoCard: {
    background: 'white',
    padding: '20px',
    borderRadius: '16px',
    boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
    display: 'flex',
    alignItems: 'flex-start',
    gap: '16px',
    transition: 'transform 0.2s, box-shadow 0.2s',
  },
  infoIcon: {
    fontSize: '28px',
    lineHeight: 1,
    flexShrink: 0,
  },
  infoContent: {
    flex: 1,
    minWidth: 0,
  },
  infoLabel: {
    fontSize: '13px',
    fontWeight: '600',
    color: '#6b7280',
    marginBottom: '8px',
    textTransform: 'uppercase',
    letterSpacing: '0.5px',
  },
  infoValue: {
    fontSize: '22px',
    fontWeight: '800',
    color: '#1f2937',
  },
  infoValueSmall: {
    fontSize: '15px',
    fontWeight: '600',
    color: '#374151',
    lineHeight: 1.5,
    wordBreak: 'break-word',
  },
  phoneLink: {
    fontSize: '18px',
    fontWeight: '700',
    color: PRIMARY_COLOR,
    textDecoration: 'none',
    transition: 'color 0.2s',
  },
  footer: {
    padding: '24px 16px',
    textAlign: 'center',
  },
  footerLink: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: '8px',
    padding: '12px 24px',
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
    backdropFilter: 'blur(10px)',
    color: 'white',
    textDecoration: 'none',
    borderRadius: '25px',
    fontWeight: '600',
    fontSize: '16px',
    transition: 'all 0.2s',
    border: '2px solid rgba(255, 255, 255, 0.3)',
  },
  homeLink: {
    display: 'inline-block',
    marginTop: '20px',
    padding: '10px 20px',
    backgroundColor: PRIMARY_COLOR,
    color: 'white',
    textDecoration: 'none',
    borderRadius: '20px',
    fontWeight: '600',
    fontSize: '14px',
    transition: 'all 0.2s',
  },
  loadingContainer: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: '100vh',
    gap: '20px',
  },
  spinner: {
    width: '50px',
    height: '50px',
    border: `5px solid rgba(255,255,255,0.3)`,
    borderTopColor: 'white',
    borderRadius: '50%',
    animation: 'spin 1s linear infinite',
  },
  loadingText: {
    fontSize: '18px',
    fontWeight: '600',
    color: 'white',
  },
  errorCard: {
    background: 'white',
    maxWidth: '500px',
    margin: '100px auto',
    padding: '32px 24px',
    borderRadius: '20px',
    boxShadow: '0 10px 40px rgba(0,0,0,0.2)',
    textAlign: 'center',
  },
  errorIcon: {
    fontSize: '64px',
    marginBottom: '20px',
  },
  errorTitle: {
    fontSize: '24px',
    fontWeight: '800',
    color: '#1f2937',
    marginBottom: '12px',
  },
  errorText: {
    fontSize: '16px',
    color: '#6b7280',
    marginBottom: '20px',
  },
};

// Add keyframes for animations
if (typeof document !== 'undefined') {
  const style = document.createElement('style');
  style.textContent = `
    @keyframes spin {
      to { transform: rotate(360deg); }
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.5; }
    }
    @media (min-width: 768px) {
      .tracking-header {
        padding: 24px 20px;
      }
      .tracking-title {
        font-size: 32px;
      }
      .tracking-map {
        height: 60vh;
        min-height: 500px;
      }
      .tracking-info-container {
        grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
        gap: 20px;
        padding: 0 20px;
      }
      .tracking-info-card {
        padding: 24px;
      }
    }
    @media (min-width: 1024px) {
      .tracking-header {
        padding: 24px;
      }
      .tracking-map-container {
        padding: 0 24px 24px;
      }
    }
  `;
  document.head.appendChild(style);
}

export default OrderTracking;
