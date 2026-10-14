# Real-Time Communication — WebSockets (AnyCable)

## Architecture

The app uses **AnyCable** (`@anycable/web`) for real-time WebSocket communication. The WebSocket URL is configured via `process.env.WEBSOCKET_URL` (default: `ws://localhost:3000/cable`).

```
SocketProvider (top-level, wraps entire app)
  └── creates Cable instance via createCable()
        └── channels subscribe/unsubscribe per feature
```

## SocketProvider (`app/components/ActionCable/SocketProvider.tsx`)

Provides the `Cable` instance via React context (`SocketContext`).

- Reads auth headers from localStorage via `useLocalStorage(HEADERS)`
- Constructs the cable URL with query params: `access_token`, `uid`, `client`
- Automatically reconnects when the user identity (`uid`) changes
- Closes the cable on logout (when headers are cleared)

```tsx
// Already wrapped at the app level in app.tsx
<SocketProvider>
  <App />
</SocketProvider>
```

## useSocket Hook (`app/utils/useSocket/useSocket.ts`)

Generic TypeScript hook for subscribing to a channel:

```typescript
const socket = useSocket<TMessage, TAction, TConnectionParams>(
  channelName,       // e.g. 'InterventionChannel'
  messageListener,   // callback for incoming messages
  {
    socketConnectionParams,  // channel-specific params
    suspend,                 // skip subscription when true
    onUnsubscribe,           // cleanup callback
  },
);

// Returns:
socket?.perform(action)   // send an action to the server
socket?.isConnected       // boolean connection state
```

### Critical caveat

**Message listeners are NOT updated after subscription creation.** Any Redux state or closure values captured at subscription time will be stale if they change later. This is documented in the hook itself:

> "Message listeners are attached to the socket at the time when subscription is created and are NOT updated during the life of a subscription."

If you need current state inside a listener, read it from the store directly or use a ref.

## Channel Hooks

Each real-time feature has a dedicated hook wrapping `useSocket`:

| Hook | Location | Channel | Purpose |
|---|---|---|---|
| `useInterventionChannel` | `app/utils/useInterventionChannel/` | InterventionChannel | Intervention edit mode, collaborator updates |
| `useConversationChannel` | `app/utils/useConversationChannel/` | ConversationChannel | Live chat messages between navigator and participant |
| `useNotificationChannel` | `app/utils/useNotificationChannel/` | NotificationChannel | System notifications |

Each channel hook is typically paired with a React context provider (e.g. `InterventionChannelContext`, `NotificationChannelContext`) that wraps the relevant portion of the app.

## Cable URL Construction (`app/components/ActionCable/utils.ts`)

```typescript
// Builds: ws://localhost:3000/cable?access_token=...&uid=...&client=...
createCableUrl(headers) → string | null

// Extracts uid from cable URL for identity comparison
getUidFromCableUrl(url) → string
```

Returns `null` if headers are missing (user not authenticated), which causes the SocketProvider to close the cable.

## Message & Action Types

Channel messages and actions are typed:

```typescript
// Incoming message
interface SocketMessage<TType, TData> {
  type: TType;
  data: TData;
}

// Outgoing action
interface SocketAction<TName, TData> {
  name: TName;
  data: TData;
}
```

## Key Rules

- **Never create Cable instances directly** — use the `SocketContext` from `SocketProvider`
- **Use the dedicated channel hooks** — don't call `useSocket` directly for existing channels
- **Beware stale closures in listeners** — message listeners capture state at subscription time
- **Channel params must be stable** — the hook uses `useDeepObjectMemo` to avoid unnecessary resubscriptions; if params change, it will unsubscribe and resubscribe

## Dependency note — `@anycable/web` is held at 0.3.x

Don't merge a bump to `@anycable/web` ≥ 0.4 (Dependabot proposes it regularly). cias-api channels call
`ensure_confirmation_sent` inside `subscribed`, and Rails 7.2 occasionally sends a **duplicate**
`confirm_subscription`. 0.3.x only logs it; 1.x answers with `unsubscribe`, which runs
`InterventionChannel#unsubscribed` — the edit lock drops and streams stop, silently breaking
collaborative editing, notifications and live chat. The backend must confirm exactly once (and be
deployed) before the frontend upgrade can go in.
