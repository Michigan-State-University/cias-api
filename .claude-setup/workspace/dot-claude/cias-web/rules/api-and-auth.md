# API Communication & Authentication

## JSON:API Format

The backend returns all responses in [JSON:API](https://jsonapi.org/) format. Never parse API responses manually — always use the normalization utilities.

### Response normalization

```js
import { jsonApiToArray } from 'utils/jsonApiMapper';  // array of objects
import { jsonApiToObject } from 'utils/jsonApiMapper';  // single object
```

These use `json-api-normalizer` + `redux-object` internally. The older `mapJsonApiToObject(json, type, config)` still exists but is deprecated — prefer the two above.

### API base URL

Set via `process.env.API_URL` (default: `http://localhost:3000`). The axios request interceptor injects it automatically — sagas should use **relative paths** like `/v1/users`, never absolute URLs.

### API path convention

All endpoints follow `/v1/<resource>` (e.g. `/v1/interventions`, `/v1/sessions/:id`, `/v1/sms_links`).

---

## Token-Based Authentication

Auth uses three headers stored in localStorage via `LocalStorageService` (`utils/localStorageService.js`):

| Header | Purpose |
|---|---|
| `Access-Token` | Bearer token for authentication |
| `Uid` | User identifier (email) |
| `Client` | Client session identifier |

These are stored under the `headers` key in localStorage. A parallel `guest-headers` key stores tokens for unauthenticated preview/fill sessions.

### How auth flows

1. Login saga calls `POST /v1/auth/sign_in`
2. Response headers contain `Access-Token`, `Uid`, `Client`
3. Axios response interceptor extracts and stores them via `LocalStorageService.setHeaders()`
4. Every subsequent request injects them via the request interceptor
5. Headers are converted to camelKebabCase before sending (`objectToCamelKebabCase`)

### Guest mode

When the current URL matches a preview/fill path (regex-based check), the interceptor uses `LocalStorageService.getGuestHeaders()` instead of `getHeaders()`. This allows participants to fill sessions without full authentication.

### Authentication check

```js
LocalStorageService.isAuthenticated()
// Returns true when Access-Token, Client, and Uid are all present
```

---

## Axios Interceptors (`app/utils/axios.js`)

### Request interceptor
- Sets `config.baseURL` from `process.env.API_URL`
- Injects auth headers (user or guest based on URL)
- Adds `Additional-Origin-Secure-Token` if configured

### Response interceptor — error handling

| Status | Action |
|---|---|
| **401 Unauthorized** | Dispatches `logOut()` (redirects to login). Excludes `sign_in` and `predefined_participants/verify` endpoints. |
| **403 Forbidden** | Dispatches `push(RoutePath.FORBIDDEN)` with redirect query param (GET requests only) |
| **404 Not Found** | Dispatches `push(RoutePath.NOT_FOUND)` (GET requests only) |

### Retry strategy

```js
axiosRetry(axios, {
  retries: 3,
  retryDelay: (retryCount) => retryCount * 250, // 250ms, 500ms, 750ms
});
```

---

## API Error Formatting

Use `formatApiErrorMessage` for toast notifications in sagas:

```js
import { formatApiErrorMessage } from 'utils/formatApiErrorMessage';

// Returns error.response.data.message if present, otherwise falls back to the i18n default
const message = formatApiErrorMessage(error, messages.defaultError);
yield call(toast.error, message);
```

---

## Key Rules

- **Never call `fetch()` directly** — always use `axios` (the interceptors handle auth, retry, and error routing)
- **Never construct auth headers manually** — `LocalStorageService` and the interceptor handle this
- **Always normalize API responses** — use `jsonApiToArray` / `jsonApiToObject`, never parse `data.attributes` manually
- **API calls only in sagas** — use `yield call(axios.get, url)`, never in components or reducers
