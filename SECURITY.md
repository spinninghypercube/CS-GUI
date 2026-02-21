# Security Policy

## Supported Versions

This project is early-stage. Security fixes are applied to the latest `main` branch.

## Reporting a Vulnerability

Please do not open public issues for sensitive vulnerabilities.

Use one of these paths:

1. Open a private security advisory on GitHub for this repository.
2. If private advisory is unavailable, open an issue with minimal details and request private contact.

Include:

- Affected version/commit
- Impact summary
- Reproduction steps
- Suggested mitigation (if known)

## Handling Secrets

- Never commit `.env.local`
- Rotate secrets immediately if exposed
- Use a strong `CROSS_SEED_UI_SESSION_SECRET`
- Keep API and admin endpoints restricted to trusted networks where possible
