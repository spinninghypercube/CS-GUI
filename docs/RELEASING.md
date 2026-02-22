# Releasing

## Recommended Release Flow

1. Pull latest `main`
2. Run `scripts/doctor.sh`
3. Run `npm run check`
4. Update `CHANGELOG.md`
5. Create a tag (for example `v0.1.0`)
6. Push commits and tags
7. Create a GitHub Release using the changelog notes

## Tag Example

```bash
git tag -a v0.1.0 -m "CS-GUI v0.1.0"
git push origin main --tags
```

## GitHub Release Notes (Suggested Sections)

- Highlights
- Fixes
- UI changes
- Compatibility notes
- Upgrade notes / breaking changes (if any)
