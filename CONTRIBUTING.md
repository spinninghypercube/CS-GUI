# Contributing to CS-GUI

Thanks for helping improve CS-GUI.

## Scope

CS-GUI is an add-on interface for cross-seed. Contributions should preserve that scope:

- Keep business logic and API compatibility with cross-seed behavior
- Prefer small, auditable commits
- Preserve accessibility attributes and semantic HTML

## Development Setup

1. Clone the repo.
2. Install dependencies:

```bash
npm install
```

3. Create local env config:

```bash
cp .env.example .env.local
```

4. Start locally:

```bash
npm start
```

## Coding Guidelines

- Keep changes focused and minimal.
- Do not commit secrets (`.env.local` is ignored).
- Keep UI behavior responsive on desktop and mobile.
- If you touch styling, check both light and dark mode.

## Pull Requests

- Use clear, descriptive PR titles.
- Explain what changed and why.
- Include manual test notes (what you clicked/verified).
- Link related issues where applicable.

## Commit Messages

Use concise, imperative messages, for example:

- `fix: preserve scroll behavior in config editor`
- `docs: expand installation and dependency guide`
- `style: align log filter button text color`

## Reporting Bugs

Open a GitHub issue and include:

- Environment (OS, Node version)
- Steps to reproduce
- Expected behavior
- Actual behavior
- Logs or screenshots if relevant
