# Redux Async Flow in CIAS Web — A Concrete Walkthrough

A beginner-friendly explainer of how the "classic" Redux + Redux-Saga pattern works in this codebase, using a real example: fetching an RA session's question groups.

## What Redux actually is

Redux is a **state container** with three rules:

1. There's one big JavaScript object holding all shared state (the "store").
2. You can't mutate it directly. You **dispatch an action** (a plain object describing what happened) and the store runs your **reducer** to produce a new version of the state.
3. Components **subscribe** to slices of the state via selectors; when the slice changes, they re-render.

That's it. Everything else — `actions.js`, constants, sagas — is plumbing to make rule #2 tidy.

**Where does `axios.get` fit?** It doesn't. Redux itself is synchronous and only knows about dispatched actions. HTTP calls are side effects, so we need a helper that *listens* for a "please fetch" action, runs the HTTP call, then *dispatches* a "here's the result" action when the call resolves. In this codebase that helper is **Redux-Saga**.

---

## Concrete example: the researcher opens the Upload view

Trigger: `UploadPredefinedParticipantsView` mounts with an intervention that has an RA session.

```
Component                 Redux Store               Saga                    Server
─────────                 ───────────               ────                    ──────
mount
  │
  ├─ dispatch(fetchRaSessionQuestionGroupsRequest(sessionId))
  │         │
  │         ▼
  │   reducer runs →  state.loaders.fetchRaSessionQuestionGroups = true
  │                   state.errors.fetchRaSessionQuestionGroups  = null
  │         │
  │         ▼
  │   (same action ALSO flows to every active saga watcher)
  │                                │
  │                                ├─ takeLatest matches REQUEST
  │                                │
  │                                ├─ yield call(axios.get, '/v1/sessions/:id/question_groups')
  │                                │                                       │
  │                                │                                       ▼
  │                                │                                    200 OK
  │                                │  ◄──────────────────────────────────┘
  │                                │
  │                                ├─ normalise with jsonApiToArray
  │                                │
  │                                └─ dispatch(fetchRaSessionQuestionGroupsSuccess(groups))
  │                                               │
  │                                               ▼
  │                                    reducer runs → state.loaders... = false
  │                                                   state.raSessionQuestionGroups = groups
  │                                               │
  ▼                                               ▼
  useSelector notices state changed → component re-renders with the new data
```

Five discrete events: mount → dispatch REQUEST → state update → saga runs axios → dispatch SUCCESS → state update → re-render. Redux's job is the state updates. The saga's job is bridging sync Redux and async HTTP.

---

## File-by-file breakdown

### 1. `constants.ts` — names

```ts
export const FETCH_RA_SESSION_QUESTION_GROUPS_REQUEST = 'app/Dashboard/FETCH_RA_SESSION_QUESTION_GROUPS_REQUEST';
export const FETCH_RA_SESSION_QUESTION_GROUPS_SUCCESS = 'app/Dashboard/FETCH_RA_SESSION_QUESTION_GROUPS_SUCCESS';
export const FETCH_RA_SESSION_QUESTION_GROUPS_ERROR   = 'app/Dashboard/FETCH_RA_SESSION_QUESTION_GROUPS_ERROR';
```

**Responsibility:** Pure string constants. Every action has a `type` field, and the reducer's `switch` and the saga's `takeLatest` both match on that type. If you typo `"REUEST"` in two places, no warning — you'll silently miss actions. Declaring them once as constants makes typos compile errors instead of runtime bugs.

Think of these as **event names**. `'FETCH_RA_SESSION_QUESTION_GROUPS_SUCCESS'` = "the fetch finished with data".

### 2. `actions.js` — event factories

```js
export const fetchRaSessionQuestionGroupsRequest = (sessionId) =>
  actionBuilder(FETCH_RA_SESSION_QUESTION_GROUPS_REQUEST, { sessionId });

export const fetchRaSessionQuestionGroupsSuccess = (questionGroups) =>
  actionBuilder(FETCH_RA_SESSION_QUESTION_GROUPS_SUCCESS, { questionGroups });

export const fetchRaSessionQuestionGroupsError = (error) =>
  actionBuilder(FETCH_RA_SESSION_QUESTION_GROUPS_ERROR, { error });
```

**Responsibility:** Produce the plain-object actions that get dispatched. `actionBuilder(TYPE, payload)` just returns `{ type: TYPE, payload }`.

Why not just write `dispatch({ type: FETCH_..., payload: { sessionId } })` inline in the component? Two reasons:

1. **Argument contract** — the action creator's signature tells you what payload a dispatcher needs to provide. Callers can't accidentally omit `sessionId`.
2. **Refactoring safety** — if the payload shape ever changes (say, we add a `healthClinicId` arg), you change one factory and every caller either updates or fails to compile.

At this point in the flow, nothing has happened yet. These are just pure functions that build action objects. Calling `fetchRaSessionQuestionGroupsRequest('abc')` returns `{ type: '...REQUEST', payload: { sessionId: 'abc' } }` — that's it.

### 3. `reducer.js` — state transitions

```js
case FETCH_RA_SESSION_QUESTION_GROUPS_REQUEST: {
  draft.loaders.fetchRaSessionQuestionGroups = true;
  draft.errors.fetchRaSessionQuestionGroups = null;
  break;
}
case FETCH_RA_SESSION_QUESTION_GROUPS_SUCCESS: {
  draft.loaders.fetchRaSessionQuestionGroups = false;
  draft.raSessionQuestionGroups = action.payload.questionGroups;
  break;
}
case FETCH_RA_SESSION_QUESTION_GROUPS_ERROR: {
  const { error } = action.payload;
  draft.loaders.fetchRaSessionQuestionGroups = false;
  draft.errors.fetchRaSessionQuestionGroups = error;
  draft.raSessionQuestionGroups = [];
  break;
}
```

**Responsibility:** **Given the current state and an action, produce the new state.** Nothing else. No HTTP calls, no side effects, no `setTimeout`. Pure input → output. This is Redux's non-negotiable rule.

Every dispatched action runs through the reducer. The reducer looks at the action's `type` and decides which case (if any) changes the state. For types it doesn't care about, it returns state unchanged.

Immer's `produce(state, (draft) => ...)` wrapper (already set up in `reducer.js`) lets us write what looks like mutation (`draft.loaders.x = true`) and quietly produces a new immutable object behind the scenes. Without Immer it'd be `{ ...state, loaders: { ...state.loaders, fetchRaSessionQuestionGroups: true } }` — much noisier.

After a case runs, the subscribed components see the change.

**Why three cases for one fetch?** They implement the **request lifecycle**:
- `REQUEST` — "a fetch just started" → set loader true, clear stale error.
- `SUCCESS` — "the HTTP call came back with data" → set loader false, store data.
- `ERROR` — "the HTTP call failed" → set loader false, store error, reset data to empty so stale values don't leak.

### 4. `sagas/fetchRaSessionQuestionGroups.js` — the bridge to axios

```js
function* fetchRaSessionQuestionGroups({ payload: { sessionId } }) {
  try {
    const { data } = yield call(axios.get, `/v1/sessions/${sessionId}/question_groups`);
    const groups = jsonApiToArray(data, 'questionGroup');
    yield put(fetchRaSessionQuestionGroupsSuccess(groups));
  } catch (error) {
    yield put(fetchRaSessionQuestionGroupsError(error));
  }
}

export default function* fetchRaSessionQuestionGroupsSaga() {
  yield takeLatest(FETCH_RA_SESSION_QUESTION_GROUPS_REQUEST, fetchRaSessionQuestionGroups);
}
```

**Responsibility:** The **only** place HTTP calls live. Reducers can't do HTTP (they must be pure). Components *could*, but then state would fragment across components and the Redux store wouldn't reflect reality. So anything async in this architecture lives here.

Breakdown:
- `takeLatest(TYPE, worker)` — "every time an action of TYPE is dispatched, cancel any previous run of `worker` and start a new one". Handles the race where a user clicks fast and triggers two fetches; only the latest result wins.
- `yield call(axios.get, url)` — "pause this saga, run `axios.get(url)`, resume me when it resolves with the result". The `yield` makes it look synchronous but doesn't block the UI.
- `yield put(successAction)` — dispatches the success action back into Redux. Same as `dispatch(successAction)` from a component, but from saga-land.

Notice the saga **never touches state directly**. It only dispatches more actions. That's the discipline: reducers are the only state-writers, sagas are dispatchers-with-superpowers.

### 5. `sagas/index.js` — saga bootstrap

```js
import fetchRaSessionQuestionGroupsSaga from './fetchRaSessionQuestionGroups';

export default function* allInterventionSagas() {
  yield all([
    // ...existing sagas...
    fetchRaSessionQuestionGroupsSaga(),
  ]);
}
```

**Responsibility:** Tell redux-saga's middleware "these are all the watchers you need to keep running". If you don't register a watcher here, its `takeLatest` never arms, and no `REQUEST` actions ever get handled. This is the "on" switch.

### 6. `selectors.js` — read the state in components

```js
export const makeSelectRaSessionQuestionGroups = () =>
  createSelector(
    selectIntervention,
    (substate) => substate?.raSessionQuestionGroups ?? [],
  );
```

**Responsibility:** Expose a *specific slice* of the store to components via a memoised function.

Why not just `state.intervention.raSessionQuestionGroups` directly in the component?

- **Memoisation** — if the selector involves derived work (filtering, mapping), `createSelector` caches the output and only recomputes when its inputs change.
- **Encapsulation** — components don't need to know that the key is `raSessionQuestionGroups` under `state.intervention`. If the state shape ever changes, you update the selector, not every component.

Then in the component:

```tsx
const questionGroups = useSelector(makeSelectRaSessionQuestionGroups());
```

`useSelector` subscribes the component to the store. When the store emits a new state, it re-runs the selector; if the output changed (by `===`), the component re-renders.

---

## The whole thing, one more time in plain English

1. **Component** says "fetch please" → dispatches the REQUEST action (from `actions.js`, named by a constant in `constants.ts`).
2. **Reducer** sees the REQUEST → flips `loaders.x = true`, clears `errors.x`. Component re-renders (maybe shows a spinner).
3. **Saga watcher** (registered in `sagas/index.js`) sees the REQUEST → runs the saga worker.
4. **Saga worker** calls `axios.get` → either gets data or throws.
5. **Saga worker** dispatches SUCCESS (with data) or ERROR (with error).
6. **Reducer** sees SUCCESS/ERROR → flips `loaders.x = false`, stores data or error. Component re-renders with the new data.
7. **Component** reads the fresh data via its selector and shows it.

Redux's whole job is steps **2, 6, and 7** — making sure "when something changes, every interested component knows". Everything else (`axios.get`, the saga plumbing) is just how we get data **into** Redux in the first place.

---

## Why it looks like a lot of code

For a single fetch you touch six files (~40 lines of boilerplate for one `axios.get`):

| File | What goes in it | Purpose |
|---|---|---|
| `constants.ts` | 3 action type strings | Names used in actions/reducer/saga |
| `actions.js` | 3 action creators | Factory functions that produce dispatchable objects |
| `reducer.js` | 3 case blocks + 3 state keys | State transitions |
| `sagas/<op>.js` | Saga worker + watcher | Makes the HTTP call |
| `sagas/index.js` | 1 line to register | Boot the saga |
| `selectors.js` | 1 selector | Read the data in components |

**Why we still do it this way here:** the `intervention` reducer already has ~30 other async operations wired exactly the same way. Following the same shape means:

1. **Free selectors** — `makeSelectInterventionLoader('fetchRaSessionQuestionGroups')` works the moment you name the key consistently.
2. **Readability** — seeing the same pattern 31 times is easier than seeing 30 classic + 1 ad-hoc shortcut.
3. **Testability** — `expectSaga(...).put(fetchRaSessionQuestionGroupsSuccess(...))` is mechanical.

Redux Toolkit (`createSlice` + `createAsyncThunk`) would cut this to ~10 lines, but this codebase predates that.

---

## Lighter alternatives we're NOT using (and why)

- **`useEffect` + `useState` in the component** — skips Redux entirely. Works, but the data isn't available to other components, can't be tested with the same saga tooling, and breaks convention.
- **SWR / React Query** — not in the codebase. Adding a new data-fetching library for one fetch is a bigger architectural decision than it looks.
- **`useGet` hook** — exists at `VariableChooser/Components/VariableView.tsx:79`. Lighter, but returns raw JSON without integrating with the loader/error conventions.

So: the verbosity isn't because the feature is complex — it's the tax for consistency with a codebase that chose classic Redux + Saga years ago.
