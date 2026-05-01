# Security Hardening Documentation

## Overview

This document describes the security measures implemented in the Hur Delivery application following OWASP best practices and industry standards.

## Table of Contents

1. [Rate Limiting](#rate-limiting)
2. [Input Validation & Sanitization](#input-validation--sanitization)
3. [API Key Management](#api-key-management)
4. [Security Headers](#security-headers)
5. [Authentication & Authorization](#authentication--authorization)
6. [Data Protection](#data-protection)
7. [Monitoring & Logging](#monitoring--logging)
8. [Incident Response](#incident-response)

---

## Rate Limiting

### Implementation

All public API endpoints implement rate limiting to prevent:
- Brute force attacks
- Denial of Service (DoS) attacks
- API abuse
- Credential stuffing

### Rate Limit Tiers

| Tier | Requests/Minute | Use Case |
|------|----------------|----------|
| **STRICT** | 5 | OTP, login, account deletion |
| **MODERATE** | 30 | Standard API endpoints |
| **RELAXED** | 100 | Read-only operations |
| **WEBHOOK** | 1000 | External webhook integrations |

### Configuration

Rate limits are applied per IP address with a sliding window algorithm. When limits are exceeded:
- HTTP 429 (Too Many Requests) is returned
- `Retry-After` header indicates when to retry
- Security events are logged for monitoring

### Example Response

```json
{
  "error": "Too many requests. Please try again later.",
  "retryAfter": 60,
  "success": false
}
```

---

## Input Validation & Sanitization

### Validation Rules

All user inputs are validated before processing:

#### Phone Numbers
- Format: `964XXXXXXXXXX` (Iraqi format)
- Length: Exactly 13 digits
- Validation: Country code + 10-digit number
- Normalization: Automatic formatting from various input formats

#### UUIDs
- Format: RFC 4122 compliant
- Pattern: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
- Case: Normalized to lowercase

#### Numbers
- Type checking: Must be valid number
- Range validation: Min/max bounds enforced
- Integer validation: Optional integer-only mode
- Overflow protection: Maximum values enforced

#### Strings
- Length limits: Enforced per field
- Null byte removal: Prevents injection attacks
- Control character filtering: Removes dangerous characters
- Whitespace normalization: Trim and clean

#### Enums
- Strict validation: Only allowed values accepted
- Type checking: Must be string type
- Case sensitivity: Enforced

### Sanitization

All string inputs are sanitized to prevent:
- SQL Injection
- XSS (Cross-Site Scripting)
- Command Injection
- Path Traversal

### Request Size Limits

| Endpoint Type | Max Size | Reason |
|--------------|----------|--------|
| OTP/Login | 10 KB | Small payloads expected |
| Standard API | 512 KB | Reasonable for most operations |
| File Upload | 10 MB | Image/document uploads |

---

## API Key Management

### Security Principles

1. **Never hardcode API keys** in source code
2. **Use environment variables** for all secrets
3. **Rotate keys regularly** (every 90 days minimum)
4. **Separate keys** for dev/staging/production
5. **Monitor usage** and set up alerts

### Key Types

#### Client-Side Safe Keys
These can be exposed in client applications:
- `SUPABASE_ANON_KEY` - Respects Row Level Security (RLS)
- `MAPBOX_ACCESS_TOKEN` - Public token for maps

#### Server-Side Only Keys
These must NEVER be exposed to clients:
- `SUPABASE_SERVICE_ROLE_KEY` - Bypasses RLS
- `WAYL_MERCHANT_TOKEN` - Payment gateway
- `WASSO_API_KEY` - WhatsApp integration
- `OTPIQ_API_KEY` - OTP service
- `OPENAI_API_KEY` - AI services

### Setting Secrets in Supabase Edge Functions

```bash
# Set a secret
supabase secrets set WAYL_MERCHANT_TOKEN=your-token-here

# List all secrets (values are hidden)
supabase secrets list

# Remove a secret
supabase secrets unset WAYL_MERCHANT_TOKEN
```

### Key Rotation Procedure

1. Generate new API key from provider
2. Set new key in environment/secrets
3. Keep old key active for 24-48 hours
4. Monitor for errors
5. Remove old key
6. Update documentation

### Compromised Key Response

If a key is compromised:
1. **Immediately** rotate the key
2. Review access logs for suspicious activity
3. Notify affected users if data was accessed
4. Document the incident
5. Review security procedures

---

## Security Headers

### Implemented Headers

All API responses include security headers:

```http
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
X-Frame-Options: DENY
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Security-Policy: default-src 'self'; script-src 'self'; object-src 'none'
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: geolocation=(), microphone=(), camera=()
```

### Header Descriptions

| Header | Purpose |
|--------|---------|
| `X-Content-Type-Options` | Prevents MIME type sniffing |
| `X-XSS-Protection` | Enables browser XSS protection |
| `X-Frame-Options` | Prevents clickjacking attacks |
| `Strict-Transport-Security` | Enforces HTTPS connections |
| `Content-Security-Policy` | Restricts resource loading |
| `Referrer-Policy` | Controls referrer information |
| `Permissions-Policy` | Restricts browser features |

### CORS Configuration

CORS is configured with security in mind:
- Default: Wildcard (`*`) for public APIs
- Production: Should be restricted to specific origins
- Methods: Limited to required HTTP methods
- Headers: Explicit allowlist of headers
- Credentials: Not allowed by default

---

## Authentication & Authorization

### Authentication Methods

1. **Phone-based OTP** (Primary)
   - 6-digit codes
   - 10-minute expiration
   - Single-use tokens
   - Rate limited to prevent brute force

2. **Admin Login** (Admin Panel)
   - Username/password authentication
   - Timing-safe comparison
   - Failed attempt delays (1 second)
   - Rate limited (5 attempts/minute)

### Authorization

#### Row Level Security (RLS)

All database tables have RLS enabled with policies:

**Users Table:**
- Users can view/update their own profile
- Admins can view/update all users
- Drivers can view other online drivers

**Orders Table:**
- Merchants can view their own orders
- Drivers can view assigned orders
- Customers can view their orders
- Admins can view all orders

**Notifications Table:**
- Users can view their own notifications
- System can insert notifications

### Admin Authority Levels

| Level | Permissions |
|-------|-------------|
| `super_admin` | Full system access |
| `admin` | Full access except system settings |
| `manager` | Manage orders, users, drivers, merchants |
| `support` | View/update orders, send messages |
| `viewer` | Read-only access |

---

## Data Protection

### Encryption

#### In Transit
- All API calls use HTTPS/TLS 1.2+
- Certificate pinning recommended for mobile apps
- No sensitive data in URL parameters

#### At Rest
- Database encryption enabled (Supabase default)
- File storage encryption enabled
- Backup encryption enabled

### Sensitive Data Handling

#### Personal Information
- Phone numbers: Partially masked in logs (`964781****`)
- Names: Never logged in error messages
- Locations: Validated and sanitized

#### Payment Information
- No credit card storage
- Payment gateway handles PCI compliance
- Only transaction references stored

#### Passwords
- SHA-256 hashed
- Timing-safe comparison
- Never logged or exposed

### Data Retention

- User data: Retained until account deletion
- Logs: 90 days retention
- Backups: 30 days retention
- Audit trail: 1 year retention

---

## Monitoring & Logging

### Security Event Logging

All security-relevant events are logged:

```typescript
logSecurityEvent('event_name', {
  // Event details
}, 'severity_level');
```

### Severity Levels

| Level | Description | Examples |
|-------|-------------|----------|
| `low` | Informational | Successful login, validation errors |
| `medium` | Potential issues | Rate limit exceeded, invalid tokens |
| `high` | Security concerns | Failed login attempts, suspicious activity |
| `critical` | Immediate action needed | Missing credentials, system compromise |

### Monitored Events

- Failed authentication attempts
- Rate limit violations
- Invalid input patterns
- Suspicious location data
- API key usage
- Account deletions
- Admin actions

### Alerting

Set up alerts for:
- Multiple failed login attempts (>5 in 5 minutes)
- Rate limit violations (>10 in 1 minute)
- Missing environment variables
- Unusual API usage patterns
- Critical security events

---

## Incident Response

### Incident Types

1. **Data Breach**
2. **API Key Compromise**
3. **DDoS Attack**
4. **Unauthorized Access**
5. **System Vulnerability**

### Response Procedure

#### 1. Detection & Analysis (0-1 hour)
- Identify the incident type
- Assess the scope and impact
- Document initial findings
- Activate incident response team

#### 2. Containment (1-4 hours)
- Isolate affected systems
- Rotate compromised credentials
- Block malicious IPs
- Enable additional monitoring

#### 3. Eradication (4-24 hours)
- Remove malicious code/access
- Patch vulnerabilities
- Update security rules
- Verify system integrity

#### 4. Recovery (24-72 hours)
- Restore normal operations
- Monitor for recurrence
- Validate security controls
- Update documentation

#### 5. Post-Incident (1-2 weeks)
- Conduct post-mortem
- Update security procedures
- Train team on lessons learned
- Implement preventive measures

### Contact Information

**Security Team:**
- Email: security@hur.delivery
- Emergency: [Emergency contact]
- On-call: [On-call rotation]

**External Resources:**
- Supabase Support: https://supabase.com/support
- CERT: https://www.cert.org/
- Local authorities: [Local contact]

---

## Security Checklist

### Development

- [ ] No hardcoded secrets in code
- [ ] All inputs validated and sanitized
- [ ] Rate limiting on all endpoints
- [ ] Security headers on all responses
- [ ] Error messages don't leak sensitive info
- [ ] Dependencies regularly updated
- [ ] Code reviewed for security issues

### Deployment

- [ ] Environment variables configured
- [ ] HTTPS/TLS enabled
- [ ] Database RLS policies active
- [ ] Backup system configured
- [ ] Monitoring and alerting active
- [ ] Incident response plan documented
- [ ] Security audit completed

### Maintenance

- [ ] API keys rotated (every 90 days)
- [ ] Security logs reviewed (weekly)
- [ ] Dependencies updated (monthly)
- [ ] Security patches applied (immediately)
- [ ] Backup tested (monthly)
- [ ] Incident response drills (quarterly)
- [ ] Security training (annually)

---

## Compliance

### Standards

- **OWASP Top 10** - Addressed all major risks
- **GDPR** - Data protection and privacy
- **PCI DSS** - Payment card security (via gateway)
- **ISO 27001** - Information security management

### Data Privacy

- Privacy policy: `/legal/privacy_policy_en.md`
- Terms of service: `/legal/terms_and_conditions_en.md`
- Data processing agreement: Available on request
- User rights: Access, rectification, deletion, portability

---

## Resources

### Documentation
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Supabase Security](https://supabase.com/docs/guides/platform/security)
- [Deno Security](https://deno.land/manual/runtime/security)

### Tools
- [Supabase CLI](https://supabase.com/docs/guides/cli)
- [OWASP ZAP](https://www.zaproxy.org/)
- [Snyk](https://snyk.io/)

### Training
- [OWASP Security Training](https://owasp.org/www-project-security-knowledge-framework/)
- [Supabase University](https://supabase.com/docs)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-01-06 | Initial security hardening implementation |

---

## Contact

For security concerns or to report vulnerabilities:
- Email: security@hur.delivery
- Encrypted: [PGP Key]
- Bug Bounty: [Program details]

**Please do not disclose security vulnerabilities publicly until they have been addressed.**

