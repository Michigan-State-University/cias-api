# Saga Registration: Two Roots, Easy to Miss

In the CIAS web app, some Redux-Saga watchers have to be registered in **two different places** for them to actually run in the feature that uses them. Miss one and the action dispatches silently with no error — the saga simply never activates.

## The two roots for the `intervention` reducer

| File | Role | Who runs it |
|---|---|---|
| `app/global/reducers/intervention/sagas/index.js` | **Module-level barrel** — imports every intervention saga and also yields them in its own `all([...])` | Anyone who imports the default export (e.g. a bootstrap sagas runner) |
| `app/containers/InterventionDetailsPage/saga.js` | **Page-level root** — yields a hand-picked subset of sagas that run only while `InterventionDetailsPage` is mounted (via `useInjectSaga` / `compose(injectSaga)`) | Injected when `InterventionDetailsPage` mounts |

Both files have their own `all([...])`. **They are independent.** A saga registered in one is not automatically registered in the other.

## Why this matters

Features that live *inside* `InterventionDetailsPage` (PDP invite modal, upload view, session list, etc.) rely on the page-level root at `containers/InterventionDetailsPage/saga.js`. Sagas added only to the barrel at `global/reducers/intervention/sagas/index.js` never get a watcher in the page-level root — so `dispatch(fooRequest())` sends an action into the void.

**The failure mode is silent.** No exception, no network request, no reducer error. Just nothing. You notice only because the data you expected in Redux never appears.

## Concrete incident (CIAS-4069 Slice 1 → Slice 3)

The plan said "register in `intervention/sagas/index.js`'s `all([...])`" — which is correct but **incomplete**. For `fetchRaSessionQuestionGroupsSaga`, we did exactly that during Slice 1. The implementation and tests passed because the tests mocked the saga with `expectSaga` directly, not through the page-level root.

In real use, the Upload view dispatched `fetchRaSessionQuestionGroupsRequest` → no watcher picked it up at the page level → `raSessionQuestionGroups` stayed `[]` → the example CSV template never got the RA variable columns. The user downloaded a CSV missing the expected dotted columns.

Diagnosis took several rounds of console.log scaffolding before we noticed saga logs never appeared. The fix was one-line:

```js
// app/containers/InterventionDetailsPage/saga.js
import fetchRaSessionQuestionGroupsSaga from 'global/reducers/intervention/sagas/fetchRaSessionQuestionGroups';

export default function* interventionDetailsPageSagas() {
  yield all([
    // ...existing...
    fetchRaSessionQuestionGroupsSaga(),
  ]);
}
```

## Rule of thumb

When adding a new saga under `app/global/reducers/intervention/sagas/`, ask:

1. **Will it be dispatched from inside `InterventionDetailsPage` or its descendants?** If yes, register it in **both** `global/reducers/intervention/sagas/index.js` AND `containers/InterventionDetailsPage/saga.js`.
2. **Will it be dispatched from elsewhere (e.g. `Dashboard`, a standalone page)?** Register it in the saga root(s) of the pages that need it. Check which roots those pages inject.
3. **Am I modifying an existing saga?** No registration change needed — the existing watcher was already wired up.

## Pattern precedent in the codebase

The codebase already follows this two-root pattern intentionally. Look at `containers/InterventionDetailsPage/saga.js`:

- Lines 29-30 import `unassignTagSaga` and `fulfillRaSessionSaga` **directly from their individual files**, not through the barrel — so they're added to the page-level `all([...])` explicitly.
- The imports from `'global/reducers/intervention/sagas'` (lines 2-28) are the named re-exports from the barrel; adding your saga's name there does NOT auto-register it page-side — it just makes the barrel-import form possible.

The page-level root is the source of truth for "what runs when a user is on the intervention details page."

## Similar roots to know about

Other containers in this codebase have their own saga roots too — most big pages do (`AnswerSessionPage`, `Dashboard`, `UserInterventionPage`, `PreviewSessionPage`, etc.). Pattern is always: `<container>/saga.js` yielding a hand-picked `all([...])`. If you're adding a saga that a specific page needs, grep for that page's `saga.js` first to confirm where registration has to land.

## Future-proofing checklist when adding a saga

- [ ] Imported into the barrel at `<reducer>/sagas/index.js` and added to its `all([...])`
- [ ] Imported into every page-level saga root that dispatches the action (directly, via `import fooSaga from 'global/reducers/<reducer>/sagas/<name>'`)
- [ ] Smoke-tested in the running app: dispatch the action and confirm either the network call fires (check devtools Network tab) or the saga logs (temporary `console.log`) are emitted. Do not rely on unit tests alone — `expectSaga` bypasses the registration layer.
