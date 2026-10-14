# Error Handling & Monitoring

## Sentry (Error Tracking)

### Setup (`app/app.tsx`)

Sentry is initialized at app startup with:
- `SENTRY_DSN` — project DSN
- `SENTRY_ENV` — environment label (dev, staging, production)
- `VERSION` — injected from `package.json` at build time

The entire app is wrapped in `<Sentry.ErrorBoundary fallback={ErrorPage}>`.

### Scope linking

Sentry sessions are linked to LogRocket sessions so you can replay the exact user session that caused an error:

```js
Sentry.configureScope((scope) => {
  scope.addEventProcessor(async (event) => {
    event.extra.sessionURL = LogRocket.sessionURL;
    return event;
  });
});
```

### Manual error capture

```js
import * as Sentry from '@sentry/react';
Sentry.captureException(error);
```

Used sparingly in utilities like `useAudioHelper` for non-fatal errors.

---

## LogRocket (Session Replay)

### Setup (`app/app.tsx`)

Initialized with the `LOGROCKET_ENV` environment variable. Key privacy configuration:

- **Request sanitization**: Strips `Access-Token`, `Uid`, `Client` from request headers
- **Response sanitization**: Strips auth headers from response headers
- **Network body sanitization**: Uses `logrocket-fuzzy-search-sanitizer` to redact sensitive fields (emails, passwords, tokens)

### Privacy fields redacted

```js
const privateFieldNames = [
  'password', 'Access-Token', 'access-token', 'first_name', 'last_name',
  'phone', 'full_name', 'current_password', 'password_confirmation',
  'token', 'verification_code', 'email', 'iso', 'prefix', 'avatar_url',
  'id', 'uid',
];
```

---

## Toast Notifications (react-toastify)

### In sagas

```js
import { toast } from 'react-toastify';
import { formatMessage } from 'utils/intlOutsideReact';
import { formatApiErrorMessage } from 'utils/formatApiErrorMessage';

// Success
yield call(toast.success, formatMessage(messages.saved), {
  toastId: SAVE_SUCCESS_TOAST_ID,  // prevent duplicates
});

// Error — with API message fallback
yield call(
  toast.error,
  formatApiErrorMessage(error, messages.defaultError),
);
```

### `formatApiErrorMessage` (`app/utils/formatApiErrorMessage.ts`)

Returns `error.response.data.message` if the API provided one, otherwise falls back to a translated default message:

```typescript
formatApiErrorMessage(error, defaultMessageDescriptor, defaultMessageValues?)
```

### Toast styling

Custom styled in `app/components/ReactToastify/` with theme colors. Types: `info`, `success`, `warning`, `error`.

### `toastId` for deduplication

Always pass a `toastId` (typically the success/error constant name) to prevent duplicate toasts when the same action is dispatched rapidly.

---

## Global Error/Loader State Pattern

Every Redux module tracks errors and loaders with named keys:

```js
// Pattern A (actionBuilder, JS modules)
initialState = {
  loaders: {
    fetchUsersLoading: false,
    createUserLoading: false,
  },
  errors: {
    fetchUsersError: null,
    createUserError: null,
  },
};

// Pattern B (typesafe-actions, TS modules)
initialState = {
  loaders: {
    fetchAnswers: false,
  },
  errors: {
    fetchAnswers: null,
  },
};
```

### Standard reducer flow

```
REQUEST → set loader true, clear error
SUCCESS → set loader false, update data
ERROR   → set loader false, set error
```

---

## Axios-Level Error Handling

The axios response interceptor handles global HTTP errors automatically (see `api-and-auth.md`):
- 401 → logout
- 403 → forbidden page
- 404 → not found page

Saga-level `try/catch` handles feature-specific errors (toasts, state updates).

---

## Key Rules

- **Always wrap saga API calls in try/catch** — dispatch error actions and show toast notifications
- **Use `formatApiErrorMessage`** — it prefers the API's error message over generic i18n defaults
- **Pass `toastId`** — prevents duplicate toasts from rapid dispatches
- **Never `console.error` in production code** — use Sentry for error tracking
- **Sensitive data must be sanitized** — if adding new fields that contain PII, add them to LogRocket's sanitizer list
