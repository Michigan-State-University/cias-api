# CIAS Web — Claude Code Instructions

Frontend SPA for the CIAS platform. Lives at `cias-web/` in this workspace; this file is loaded when working on frontend tasks (see workspace [CLAUDE.md](../../CLAUDE.md)).

**Repo root:** `cias-web/` (separate git repo — run `git`/`npm` commands from inside that directory).

## Project Overview

React 17 + TypeScript SPA for the CIAS (Computerized Intervention Authoring System) platform.
State is managed via Redux + Redux Saga. Styling is Styled Components. i18n via React Intl.

---

## Tech Stack Quick Reference

| Concern | Library |
|---|---|
| UI | React 17, TypeScript 5.7 |
| Routing | React Router DOM 5 |
| State | Redux 4 + React Redux 7 |
| Side effects | Redux Saga 1.3 |
| Selectors | Reselect 5 |
| Immutable updates | Immer 9 |
| Typed actions | typesafe-actions 4 |
| Styling | Styled Components 5 |
| Forms | Formik 2 + Yup |
| i18n | React Intl 6 |
| HTTP | Axios (configured in `app/utils/axios.js`) |
| Testing | Jest 29 + React Testing Library + Redux Saga Test Plan |
| E2E | Cypress 13, Playwright |
| Linting | ESLint (Airbnb + TypeScript), Prettier, Stylelint |

---

## Project Structure

```
app/
  components/          # Reusable, stateless UI components
  containers/          # Page-level components connected to Redux
  global/
    reducers/          # Redux modules (actions, reducer, selectors, sagas, types)
  models/              # TypeScript interfaces and enums for domain entities
  theme/               # Design tokens (colors, fontWeights, boxShadows, etc.)
  translations/        # i18n translation JSON files
  utils/               # Shared utilities (axios.js, jsonApiMapper, validators, etc.)
internals/webpack/     # Webpack configs (base, dev, prod, cypress)
e2e/                   # Playwright tests
cypress/               # Cypress tests
```

---

## Redux Module Pattern

Every Redux feature lives in `app/global/reducers/<feature>/` with this structure:

```
<feature>/
  constants.ts   — action type string constants
  actions.ts     — createAction() definitions
  types.ts       — ActionType union + State type
  reducer.ts     — Immer-based reducer using getType()
  selectors.ts   — Reselect selectors
  index.ts       — barrel export
  sagas/
    index.ts     — root saga (forks all watchers)
    <action>.ts  — one file per saga worker
```

### constants.ts

```typescript
export const FETCH_ANSWERS_REQUEST = 'app/answers/FETCH_ANSWERS_REQUEST';
export const FETCH_ANSWERS_SUCCESS = 'app/answers/FETCH_ANSWERS_SUCCESS';
export const FETCH_ANSWERS_ERROR   = 'app/answers/FETCH_ANSWERS_ERROR';
```

### actions.ts

Use `createAction` from `typesafe-actions`. Payload is always wrapped in an object.

```typescript
import { createAction } from 'typesafe-actions';
import { Answer } from 'models/Answer';
import { ApiError } from 'models/Api';
import { FETCH_ANSWERS_REQUEST, FETCH_ANSWERS_SUCCESS, FETCH_ANSWERS_ERROR } from './constants';

export const fetchAnswersRequest = createAction(
  FETCH_ANSWERS_REQUEST,
  (action) => (userSessionId: string) => action({ userSessionId }),
);
export const fetchAnswersSuccess = createAction(
  FETCH_ANSWERS_SUCCESS,
  (action) => (answers: Answer[]) => action({ answers }),
);
export const fetchAnswersError = createAction(
  FETCH_ANSWERS_ERROR,
  (action) => (error: ApiError) => action({ error }),
);
```

### types.ts

```typescript
import { ActionType } from 'typesafe-actions';
import { Answer } from 'models/Answer';
import { ApiError } from 'models/Api';
import * as actions from './actions';

export type AnswersAction = ActionType<typeof actions>;

export type AnswersState = {
  answers: Answer[];
  loaders: Record<string, boolean>;
  errors: Record<string, Nullable<ApiError>>;
};
```

### reducer.ts

Use `produce` from Immer and `getType` from typesafe-actions. State always has `loaders` and `errors` records keyed by operation name.

```typescript
import produce from 'immer';
import { getType } from 'typesafe-actions';
import { fetchAnswersRequest, fetchAnswersSuccess, fetchAnswersError } from './actions';
import { AnswersAction, AnswersState } from './types';

export const answersReducerKey = 'answers';

export const initialState: AnswersState = {
  answers: [],
  loaders: { fetchAnswers: false },
  errors:  { fetchAnswers: null },
};

/* eslint-disable default-case, no-param-reassign, @typescript-eslint/default-param-last */
export const answersReducer = (
  state: AnswersState = initialState,
  action: AnswersAction,
) =>
  produce(state, (draft) => {
    switch (action.type) {
      case getType(fetchAnswersRequest):
        draft.loaders.fetchAnswers = true;
        draft.errors.fetchAnswers = null;
        break;
      case getType(fetchAnswersSuccess):
        draft.answers = action.payload.answers;
        draft.loaders.fetchAnswers = false;
        break;
      case getType(fetchAnswersError):
        draft.errors.fetchAnswers = action.payload.error;
        draft.answers = [];
        draft.loaders.fetchAnswers = false;
        break;
    }
  });
```

### selectors.ts

Use factory functions (`makeSelect*`) that return new `createSelector` instances — this ensures each connected component gets its own memoized selector.

```typescript
import { createSelector } from 'reselect';
import { RootState } from 'global/reducers';
import { answersReducerKey, initialState } from './reducer';
import { AnswersState } from './types';

const selectAnswers = (rootState: RootState): AnswersState =>
  rootState[answersReducerKey] || initialState;

export const makeSelectAnswers = () =>
  createSelector(selectAnswers, ({ answers }) => answers);

export const makeSelectAnswersLoader = (name: string) =>
  createSelector(selectAnswers, ({ loaders }) => loaders[name]);

export const makeSelectAnswersError = (name: string) =>
  createSelector(selectAnswers, ({ errors }) => errors[name]);
```

---

## Redux Saga Pattern

Each saga file exports a worker and a watcher. Use `takeLatest` unless ordering requires `takeEvery`.

```typescript
import axios from 'axios';
import { call, put, takeLatest } from 'redux-saga/effects';
import { jsonApiToArray } from 'utils/jsonApiMapper';
import { ApiError } from 'models/Api';
import { Answer } from 'models/Answer';
import { FETCH_ANSWERS_REQUEST } from '../constants';
import { fetchAnswersRequest, fetchAnswersSuccess, fetchAnswersError } from '../actions';

export function* fetchAnswers({
  payload: { userSessionId },
}: ReturnType<typeof fetchAnswersRequest>) {
  const url = `/v1/user_sessions/${userSessionId}/answers`;
  try {
    const { data } = yield call(axios.get, url);
    const answers = jsonApiToArray(data, 'answer') as Answer[];
    yield put(fetchAnswersSuccess(answers));
  } catch (error) {
    yield put(fetchAnswersError(error as ApiError));
  }
}

export function* fetchAnswersSaga() {
  yield takeLatest(FETCH_ANSWERS_REQUEST, fetchAnswers);
}
```

- Always use `yield call(axios.get, url)` — never `await` inside sagas.
- Always normalize JSON API responses with `jsonApiToArray` / `jsonApiToObject` from `utils/jsonApiMapper`.
- Destructure `payload` directly in the worker function signature using `ReturnType<typeof actionCreator>`.

---

## TypeScript Conventions

### Models (`app/models/`)

Prefer `interface` for object shapes that may be extended; use `type` for unions, aliases, and state shapes.

```typescript
// Enum for finite domain values
export enum InterventionStatus {
  DRAFT     = 'draft',
  PUBLISHED = 'published',
  PAUSED    = 'paused',
}

// Interface for extendable entities
export interface SimpleIntervention {
  id: string;
  name: string;
  status: InterventionStatus;
  organizationId: Nullable<string>;
}

export interface Intervention extends SimpleIntervention {
  languageCode: string;
  logo: Nullable<InterventionLogo>;
}
```

- Use the global `Nullable<T>` type alias (already declared globally) instead of `T | null`.
- Place domain model files in `app/models/<Entity>/`.

---

## Styled Components Conventions

- Place styled components in a `styled.tsx` (or `styled.ts`) file co-located with the component, or inline for single-use styles.
- Import design tokens from `theme` (not hardcoded values): `colors`, `themeColors`, `fontWeights`, `fontFamily`, `boxShadows`, `elements`.
- Type props inline when simple; extract a `Props` type when reused.

```typescript
import styled from 'styled-components';
import { colors, themeColors, fontWeights, boxShadows } from 'theme';

type Props = {
  disabled?: boolean;
};

export const TileContainer = styled.div<Props>`
  padding: 12px 16px;
  box-shadow: ${boxShadows.selago};
  border-radius: 8px;
  color: ${themeColors.text};
  background: ${colors.white};
  cursor: ${({ disabled }) => (disabled ? 'not-allowed' : 'pointer')};
`;
```

- Do not use inline `style` props for anything that can be expressed in Styled Components.
- Stylelint enforces CSS-in-JS rules — run `npm run lint:css` to check.

---

## React Intl (i18n) Pattern

Every component/container that has user-visible strings must use React Intl — no hardcoded English strings in JSX.

### messages file

Create a `messages.ts` (or `messages.js`) file co-located with the component:

```typescript
import { defineMessages } from 'react-intl';

export const scope = 'app.containers.LoginPage';

export default defineMessages({
  header: {
    id: `${scope}.header`,
    defaultMessage: 'Sign in',
  },
  emailLabel: {
    id: `${scope}.emailLabel`,
    defaultMessage: 'Email address',
  },
});
```

### usage in components

```tsx
import { useIntl, FormattedMessage } from 'react-intl';
import messages from './messages';

const LoginForm = () => {
  const { formatMessage } = useIntl();

  return (
    <>
      <h1><FormattedMessage {...messages.header} /></h1>
      <Input placeholder={formatMessage(messages.emailLabel)} />
    </>
  );
};
```

- Use `<FormattedMessage>` for rendered text nodes.
- Use `formatMessage()` for string props (placeholder, aria-label, title, etc.).
- The `scope` prefix must be unique and match the file path convention.

---

## Forms — Formik + Yup

- Define validation schemas as factory functions that accept `formatMessage` so error strings are translated.
- Use `useMemo` to avoid recreating schemas on every render.
- Wrap the form in `<Formik>` and use `<Form>` (aliased as `FormikForm` if needed) as the form element.

```tsx
import { Formik, Form } from 'formik';
import * as Yup from 'yup';

const validationSchema = (formatMessage: FormatMessage) =>
  Yup.object({
    email: Yup.string()
      .email(formatMessage(messages.emailInvalid))
      .required(formatMessage(messages.emailRequired)),
  });

const MyForm = () => {
  const { formatMessage } = useIntl();
  const schema = useMemo(() => validationSchema(formatMessage), []);

  return (
    <Formik
      initialValues={{ email: '' }}
      validationSchema={schema}
      onSubmit={(values) => dispatch(submitRequest(values))}
    >
      {({ handleSubmit }) => (
        <Form>
          <FormikInput formikKey="email" label={formatMessage(messages.emailLabel)} />
          <Button onClick={handleSubmit} type="submit" title={formatMessage(messages.submit)} />
        </Form>
      )}
    </Formik>
  );
};
```

---

## Testing

### Unit / Component tests (Jest + React Testing Library)

- Place tests in a `tests/` folder next to the file under test.
- Name files `<ComponentName>.test.tsx` or `index.test.tsx`.
- Always check for console errors as the first test case.

```tsx
import React, { ComponentProps } from 'react';
import { render } from '@testing-library/react';
import MyComponent from '../index';

describe('<MyComponent />', () => {
  const defaultProps: ComponentProps<typeof MyComponent> = {
    id: 'test',
    onChange: jest.fn(),
  };

  it('should not log errors in console', () => {
    const spy = jest.spyOn(global.console, 'error');
    render(<MyComponent {...defaultProps} />);
    expect(spy).not.toHaveBeenCalled();
  });

  it('should match snapshot', () => {
    const { container } = render(<MyComponent {...defaultProps} />);
    expect(container).toMatchSnapshot();
  });
});
```

### Saga tests (Redux Saga Test Plan)

Use `expectSaga` for integration-style saga tests. Mock `axios` calls with `matchers.call.fn`.

```typescript
import { expectSaga } from 'redux-saga-test-plan';
import * as matchers from 'redux-saga-test-plan/matchers';
import axios from 'axios';
import { fetchAnswers } from '../sagas/fetchAnswers';
import { fetchAnswersSuccess } from '../actions';

it('should dispatch success on successful API call', () =>
  expectSaga(fetchAnswers, { payload: { userSessionId: '123' } })
    .provide([[matchers.call.fn(axios.get), { data: mockApiResponse }]])
    .put(fetchAnswersSuccess(mockAnswers))
    .run());
```

### Running tests

```bash
npm test                  # watch mode
npm run test:coverage     # with coverage
npm run cypress:open      # Cypress interactive
npm run e2e               # Playwright
```

---

## HTTP / API

- Import `axios` from `'axios'` — the interceptors in `app/utils/axios.js` handle base URL, auth headers, token refresh, and 401 logout automatically.
- Always call APIs inside sagas via `yield call(axios.get/post/put/delete, url, payload)`.
- Normalize JSON API responses: use `jsonApiToArray(data, 'resourceType')` or `jsonApiToObject(data, 'resourceType')` from `utils/jsonApiMapper`.
- API paths follow the pattern `/v1/<resource>`.

---

## Linting & Formatting

```bash
npm run lint          # ESLint
npm run lint:fix      # ESLint with autofix
npm run lint:css      # Stylelint
npm run format        # Prettier
```

- ESLint config: Airbnb + TypeScript (`eslint-config-airbnb-typescript`).
- Prettier runs automatically on staged files via `lint-staged` + `pre-commit`.
- Do not disable ESLint rules with inline comments unless absolutely necessary — prefer fixing the root cause.
- The `/* eslint-disable default-case, no-param-reassign */` comments in reducers are intentional (Immer requires direct mutation).

---

## Commands

```bash
npm start             # dev server (webpack-dev-server)
npm run build         # production build
npm test              # Jest watch
npm run generate      # Plop code generator (components, containers, reducers)
npm run extract-intl  # Extract i18n messages from source
```

---

## Deep-Dive Rules

The `.claude/cias-web/rules/` directory contains detailed reference docs for specific subsystems. **Read the relevant rule file before working on that area.**

| Rule | Read when... |
|---|---|
| [api-and-auth.md](.claude/cias-web/rules/api-and-auth.md) | Working with API calls, axios, authentication, JSON:API normalization |
| [domain-model.md](.claude/cias-web/rules/domain-model.md) | Need to understand entity relationships (Intervention → Session → Question → Answer, SMS, TLFB, orgs) |
| [user-roles-and-routing.md](.claude/cias-web/rules/user-roles-and-routing.md) | Adding routes, role-based access, AppRoute guards, layout/navigation |
| [realtime-websockets.md](.claude/cias-web/rules/realtime-websockets.md) | WebSocket channels, AnyCable, useSocket hook, real-time features |
| [error-handling-and-monitoring.md](.claude/cias-web/rules/error-handling-and-monitoring.md) | Sentry, LogRocket, toast notifications, error formatting |
| [sms-messaging-system.md](.claude/cias-web/rules/sms-messaging-system.md) | SMS plans, text message variants, formulas, SmsLink flow, ::variable:: tokens |
| [animations-and-narrator.md](.claude/cias-web/rules/animations-and-narrator.md) | Peedy character, Lottie, Google TTS, narrator blocks, Framer Motion |
| [drag-drop-and-flow-graphs.md](.claude/cias-web/rules/drag-drop-and-flow-graphs.md) | Drag-and-drop (react-beautiful-dnd, dnd-kit), React Flow session maps |
| [file-handling-and-media.md](.claude/cias-web/rules/file-handling-and-media.md) | File uploads, downloads, CSV, media playback, size limits |
| [feature-flags-and-env.md](.claude/cias-web/rules/feature-flags-and-env.md) | Environment variables, feature flags, build config, webpack aliases |
| [hotfix-flow.md](.claude/cias-web/rules/hotfix-flow.md) | Shipping an urgent fix straight to `master`, back-porting to `dev`, branch reconciliation, promotion-PR diff gotchas |

## Knowledge notes

Longer explainers in `.claude/cias-web/knowledge/`:

| Note | Read when... |
|---|---|
| [redux-async-flow.md](.claude/cias-web/knowledge/redux-async-flow.md) | New to Redux + Redux-Saga here — a walkthrough of one real request → saga → reducer → selector flow |
| [saga-registration-two-roots.md](.claude/cias-web/knowledge/saga-registration-two-roots.md) | A dispatched action does nothing — some sagas must be registered in two roots to run |

## Repo rules

- Don't edit `.github/workflows/code-quality.yml` (HTD code-quality scan), even in "bump all actions" sweeps — mention issues instead.
- `@anycable/web` stays on 0.3.x for now — see the dependency note in [realtime-websockets.md](.claude/cias-web/rules/realtime-websockets.md).
- Node 22 only (`.nvmrc`). `npx tsc --noEmit` before handing over a diff — the production build doesn't type-check.
