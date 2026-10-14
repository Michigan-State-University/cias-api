# Feature Flags & Environment Configuration

## Environment Variables

Defined in `.env` (local) and injected at build time via `dotenv-webpack`.

### Core URLs

| Variable | Default | Purpose |
|---|---|---|
| `API_URL` | `http://localhost:3000` | Backend API base URL (injected into axios) |
| `WEBSOCKET_URL` | `ws://localhost:3000/cable` | AnyCable WebSocket endpoint |
| `WEB_URL` | `http://localhost:4200` | Frontend URL (used in SMS link resolution) |
| `APP_STAGE` | `dev` | Deployment stage identifier |

### Monitoring

| Variable | Purpose |
|---|---|
| `SENTRY_DSN` | Sentry project DSN |
| `SENTRY_ENV` | Sentry environment label |
| `SENTRY_AUTH_TOKEN` | Sentry auth for source map upload (build-time only) |
| `LOGROCKET_ENV` | LogRocket project identifier |

### Security

| Variable | Purpose |
|---|---|
| `ADDITIONAL_ORIGIN_SECURE_TOKEN` | Extra header for cross-origin requests (optional) |

### E2E Testing

| Variable | Purpose |
|---|---|
| `E2E_ADMIN_EMAIL` | Test admin email for Playwright/Cypress |
| `E2E_ADMIN_PASSWORD` | Test admin password |
| `E2E_VERIFICATION_CODE` | 2FA bypass code for tests |
| `E2E_WORKER_COUNT` | Parallel test worker count |
| `E2E_AUTH_SETUP_DELAY_MS` | Delay for auth setup in tests |

---

## Feature Flags

### Implementation (`app/utils/env.ts`)

```typescript
export const isInterventionExportFeatureEnabled = Boolean(
  +process.env.INTERVENTION_EXPORT_FEATURE_ENABLED!,
);

export const isHfhsIntegrationFeatureEnabled = Boolean(
  +process.env.HFHS_INTEGRATION_FEATURE_ENABLED!,
);
```

The `+` operator converts the string to a number first (`"1"` → `1` → `true`, `"0"` → `0` → `false`).

### Available flags

| Flag | Env Variable | Purpose |
|---|---|---|
| Intervention Export | `INTERVENTION_EXPORT_FEATURE_ENABLED` | Enables intervention export/import functionality |
| HFHS Integration | `HFHS_INTEGRATION_FEATURE_ENABLED` | Enables Henry Ford Health System integration features |

### Usage in components

```typescript
import { isHfhsIntegrationFeatureEnabled } from 'utils/env';

if (isHfhsIntegrationFeatureEnabled) {
  // render HFHS-specific UI
}
```

---

## Build-Time Configuration

### Version injection

The app version is injected from `package.json` at build time via:
- `git-revision-webpack-plugin` — injects git revision info
- `VERSION=$npm_package_version` — passed to Sentry and runtime

### Webpack environment configs

| File | Purpose |
|---|---|
| `internals/webpack/webpack.base.babel.js` | Shared config (loaders, aliases, plugins) |
| `internals/webpack/webpack.dev.babel.js` | Dev server, HMR, source maps |
| `internals/webpack/webpack.prod.babel.js` | Minification, compression, Sentry source maps |
| `internals/webpack/webpack.cypress.babel.js` | Cypress-specific config |

### Module resolution

Webpack is configured with `modules: ['node_modules', 'app']` so imports resolve from the `app/` directory without a prefix:

```js
import { colors } from 'theme';           // resolves to app/theme/
import { RoutePath } from 'global/constants'; // resolves to app/global/constants/
import LocalStorageService from 'utils/localStorageService'; // resolves to app/utils/
```

This is module resolution (not explicit aliases). Any file or directory inside `app/` can be imported by its path relative to `app/`.

---

## Key Rules

- **Never hardcode URLs** — always use `process.env.API_URL`, `process.env.WEB_URL`, etc.
- **Feature flags are build-time** — they're baked into the bundle via `dotenv-webpack`. Changing a flag requires a rebuild.
- **Add new flags to `.env`** — and document them in this file. The `+Boolean()` pattern ensures consistent truthiness checking.
- **Never commit secrets to `.env`** — the committed `.env` has empty values for `SENTRY_AUTH_TOKEN`, `LOGROCKET_ENV`, etc. Real values go in deployment config.
- **E2E credentials are test-only** — the values in `.env` are for the local test environment, not production.
