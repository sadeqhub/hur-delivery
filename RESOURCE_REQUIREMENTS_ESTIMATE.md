# Resource Requirements Estimate
## For 100 Daily Users & 50 Orders/Day

### Assumptions
- **Daily Active Users:** 100
- **Daily Orders:** 50
- **Peak Concurrent Users:** ~30 (30% of daily users active simultaneously)
- **Average Order Lifecycle:** 30-60 minutes
- **Active Drivers:** ~20 (20% of users are drivers)
- **Active Merchants:** ~30 (30% of users are merchants)

---

## 📊 Database Size Estimates

### Table Sizes (Monthly Growth)

| Table | Records/Day | Size per Record | Monthly Growth | Index Overhead |
|-------|-------------|-----------------|----------------|----------------|
| **orders** | 50 | ~2 KB | ~3 MB | +50% = 4.5 MB |
| **order_items** | 150 (3 items/order) | ~500 bytes | ~2.25 MB | +50% = 3.4 MB |
| **notifications** | 200 (4/order) | ~1 KB | ~6 MB | +50% = 9 MB |
| **order_assignments** | 75 (1.5/order) | ~1 KB | ~2.25 MB | +50% = 3.4 MB |
| **driver_locations** | 2,880 (1 per 30s for active drivers) | ~500 bytes | ~43 MB | +50% = 65 MB |
| **users** | 100 (one-time) | ~2 KB | ~6 MB | +50% = 9 MB |
| **order_timeout_state** | 50 (temporary) | ~500 bytes | ~0.75 MB | +50% = 1.1 MB |
| **whatsapp_location_requests** | 50 | ~1 KB | ~1.5 MB | +50% = 2.3 MB |

**Total Database Size (Month 1):** ~98 MB  
**Total Database Size (Month 6):** ~600 MB (with historical data)  
**Total Database Size (Month 12):** ~1.2 GB

### Indexes Size
- Estimated at 50% of table size
- **Total Indexes:** ~500 MB (after 6 months)

---

## 💾 Memory Requirements

### Database Memory (PostgreSQL)

**Base PostgreSQL:** ~100 MB  
**Active Connections:** 30 concurrent × 5 MB = 150 MB  
**Query Cache:** ~50 MB  
**Index Cache:** ~100 MB (frequently used indexes)  
**Real-time Subscriptions:** 30 × 2 MB = 60 MB  
**Background Processes:** ~50 MB

**Total Database Memory:** ~510 MB

### Application Memory (Supabase Edge Functions)

**Wasso Webhook Function:** ~50 MB (when active)  
**Other Edge Functions:** ~30 MB  
**API Gateway:** ~20 MB

**Total Application Memory:** ~100 MB

### **Total Memory Required: ~610 MB**

**Recommended:** **1 GB** (with 40% headroom for growth)

---

## 🖥️ CPU Requirements

### Database CPU Load

**Per User Operation:**
- Order creation: ~10ms CPU time
- Order query: ~5ms CPU time
- Real-time subscription: ~2ms CPU time per event
- Location update: ~5ms CPU time

**Daily Operations:**
- 50 orders × 10ms = 500ms
- 1,000 queries × 5ms = 5,000ms (5 seconds)
- 200 notifications × 2ms = 400ms
- 2,880 location updates × 5ms = 14,400ms (14.4 seconds)

**Total Daily CPU Time:** ~20 seconds of CPU time

**Peak Load (30 concurrent users):**
- 30 queries/second × 5ms = 150ms/second
- 5 real-time events/second × 2ms = 10ms/second
- 1 location update/second × 5ms = 5ms/second

**Peak CPU Usage:** ~165ms/second = **~16.5% of 1 CPU core**

### **Recommended CPU: 0.25-0.5 vCPU** (shared CPU is fine)

---

## 🔌 Connection & Subscription Limits

### Database Connections

**Active Connections:**
- 30 concurrent users × 1 connection = 30 connections
- Background processes: 5 connections
- Edge functions: 5 connections

**Total:** ~40 connections  
**Recommended Limit:** 100 connections (2.5x headroom)

### Real-time Subscriptions

**Per User:**
- Orders subscription: 1
- Notifications subscription: 1
- Timeout states (drivers only): 1

**Total Active Subscriptions:**
- 30 concurrent users × 2 = 60 subscriptions
- 10 drivers × 1 timeout subscription = 10 subscriptions

**Total:** ~70 subscriptions  
**Recommended Limit:** 200 subscriptions (2.8x headroom)

---

## 📈 Performance Metrics

### Query Performance (with optimizations)

| Operation | Target | With Current Setup |
|-----------|--------|-------------------|
| Order creation | <100ms | ~50ms ✅ |
| Order query | <50ms | ~20ms ✅ |
| Real-time update | <200ms | ~100ms ✅ |
| Location update | <100ms | ~50ms ✅ |

### Polling Frequency (Optimized)

| Operation | Frequency | Daily Calls |
|-----------|-----------|-------------|
| Timeout state updater | 15s | 5,760 |
| Auto-reject check | 30s | 2,880 |
| Status check | 15s | 5,760 |
| Notification polling | 30s | 2,880 |

**Total Daily Polling Calls:** ~17,280  
**Average per second:** ~0.2 calls/second (very low)

---

## 💰 Supabase Plan Recommendation

### Current Plan Analysis
- **Memory:** 0.5 GB (currently at limit)
- **CPU:** Shared (adequate for this load)
- **Database Size:** Should be fine for 6-12 months

### Recommended Plan: **Pro Plan** ($25/month)

**Why:**
- **2 GB RAM** (4x current, plenty of headroom)
- **Dedicated CPU** (optional, but shared is fine)
- **8 GB Database** (enough for 2+ years)
- **200 Connections** (5x current needs)
- **Unlimited API requests**

### Alternative: **Free Plan** (if budget constrained)

**Limitations:**
- 500 MB database (will fill up in ~6 months)
- 2 GB bandwidth (should be fine)
- 50,000 monthly API requests (plenty)

**Can work if:**
- You archive old data regularly
- You optimize storage (delete old location records)
- You monitor database size closely

---

## 🎯 Optimization Recommendations

### For Current 0.5GB Memory Limit

1. ✅ **Already Done:**
   - Reduced polling frequency (15-30s)
   - Reduced query result sizes (50 orders max)
   - Added database indexes
   - Optimized real-time subscriptions

2. **Additional Optimizations:**
   - **Archive old data:** Delete orders >90 days old
   - **Clean location history:** Keep only last 7 days of driver_locations
   - **Compress notifications:** Mark old notifications as archived
   - **Database maintenance:** Run VACUUM weekly

3. **Storage Optimization:**
   - Delete old order proofs after 30 days
   - Archive voice recordings after 90 days
   - Compress JSONB columns if large

---

## 📊 Growth Projections

### Scaling Estimates

| Metric | 100 Users | 500 Users | 1,000 Users |
|--------|-----------|-----------|-------------|
| **Daily Orders** | 50 | 250 | 500 |
| **Database Size (6mo)** | 600 MB | 3 GB | 6 GB |
| **Memory Needed** | 1 GB | 2 GB | 4 GB |
| **CPU Needed** | 0.25 vCPU | 0.5 vCPU | 1 vCPU |
| **Connections** | 40 | 200 | 400 |
| **Subscriptions** | 70 | 350 | 700 |

### When to Upgrade

**Upgrade to Pro ($25/month) when:**
- Database > 1 GB
- Memory usage > 80%
- Connection errors occur
- Query performance degrades

**Upgrade to Team ($599/month) when:**
- >500 daily users
- >250 daily orders
- Need dedicated CPU
- Need advanced features

---

## ✅ Final Recommendation

### For 100 Daily Users & 50 Orders/Day:

**Minimum Requirements:**
- **Memory:** 1 GB (currently 0.5 GB - **needs upgrade**)
- **CPU:** 0.25 vCPU (shared is fine)
- **Database:** 1 GB (currently adequate)
- **Connections:** 100 (currently adequate)

**Recommended Plan:**
- **Supabase Pro** ($25/month)
  - 2 GB RAM ✅
  - 8 GB Database ✅
  - 200 Connections ✅
  - Dedicated CPU (optional) ✅

**Current Plan Status:**
- ⚠️ **Memory is the bottleneck** (0.5 GB is too low)
- ✅ CPU is adequate (shared is fine)
- ✅ Database size is adequate (for now)
- ✅ Connections are adequate

### Action Items

1. **Immediate:** Upgrade to at least 1 GB memory (Pro plan)
2. **Short-term:** Monitor database size, archive old data
3. **Long-term:** Plan for growth, consider Team plan at 500+ users

---

## 📝 Notes

- All estimates assume optimized queries and indexes (already implemented)
- Real-time subscriptions are efficient (filtered by user_id)
- Polling frequency is already optimized (15-30s intervals)
- Database indexes reduce query load significantly
- Growth projections assume linear scaling (may vary)

**Bottom Line:** With current optimizations, you need **at least 1 GB memory** (preferably 2 GB) for comfortable operation. The 0.5 GB limit is too restrictive and will cause performance issues as data grows.



