# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 3.x     | ✅                 |
| 2.x     | ⚠️ Limited         |
| < 2.0   | ❌                 |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via email to **security@opa-app.com**.

You should receive a response within 48 hours. If the issue is confirmed, we will release a patch as soon as possible depending on complexity.

## Security Best Practices

### For Users
- Always use the latest version
- Enable 2FA for admin accounts
- Regularly rotate API keys
- Monitor access logs

### For Developers
- Never commit secrets to repository
- Use environment variables for configuration
- Validate all user inputs
- Implement rate limiting
- Use parameterized queries (no SQL injection)
- Hash passwords with bcrypt
- Use HTTPS in production
- Implement CORS properly

## Data Protection

OPA follows GDPR and Indonesian data protection laws:
- User data is encrypted at rest
- Personal data is anonymized in logs
- Data retention: max 5 years
- Right to deletion: supported

## Encryption Standards

- **Transport**: TLS 1.2+
- **Database**: AES-256 at rest
- **Passwords**: bcrypt (cost 12)
- **JWT**: HS256 or RS256

## Vulnerability Disclosure Timeline

1. **Report received** → Acknowledgment within 48 hours
2. **Validation** → 3-5 business days
3. **Fix development** → 5-10 business days
4. **Patch release** → Announced via security advisory
5. **Public disclosure** → 30 days after patch

## Bug Bounty Program

We offer bounties for valid security vulnerabilities:

| Severity | Bounty |
|----------|--------|
| Critical | $1000 |
| High | $500 |
| Medium | $200 |
| Low | $50 |

*Eligibility: First-time reporters only, no automated tools*