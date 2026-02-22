# Known Limitations

## Early-stage Project

CS-GUI is still early-stage and optimized for practical local/self-hosted use. Expect occasional rough edges.

## Cross-seed Version Variations

- `cross-seed` template comments/options can change between versions.
- The structured editor may not perfectly map every future/new option immediately.

## Remote File Editing Limitations

- API actions can work against a remote `cross-seed` host.
- Config and logs features still depend on file paths readable by the CS-GUI runtime host/container.

## Large Log Volumes

- Very large log histories can still be heavy when requesting `all time` / `all lines`.
- Prefer filtered views (`success`, `error`) or recent ranges for best performance.

## Security Model

- CS-GUI includes its own login, but it is not a full IAM solution.
- For internet exposure, use a reverse proxy with TLS and additional access controls.
