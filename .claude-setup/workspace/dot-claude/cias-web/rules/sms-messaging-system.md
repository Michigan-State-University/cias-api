# SMS Messaging System

## Overview

SMS sessions (`Session::Sms`) contain text message plans that schedule and deliver SMS messages to participants. The system supports formula-based conditional content, trackable links, file attachments, and flexible scheduling.

## Core Models

### TextMessage (SMS Plan)

The main entity representing a scheduled SMS. Key fields:

| Field | Type | Purpose |
|---|---|---|
| `schedule` | `TextMessageScheduleOption` | When to send (after_fill, days_after, exact_date, etc.) |
| `frequency` | `TextMessageScheduleFrequency` | How often (once, daily, weekly, monthly) |
| `isUsedFormula` | boolean | Whether content uses formula-based variants |
| `noFormulaText` | string | Message body when formulas are disabled |
| `variants` | `TextMessageVariant[]` | Formula-based content alternatives |
| `smsLinks` | `SmsLink[]` | Plan-level trackable links (no-formula mode) |
| `noFormulaAttachment` | `AppFile` | File attachment (no-formula mode) |
| `smsSendTimeType` | `SmsSendTimeType` | Send timing details |
| `includeFirstName/LastName/PhoneNumber/Email` | boolean | Auto-insert participant data |

**Model**: `app/models/TextMessage/TextMessage.ts`

### TextMessageVariant

When `isUsedFormula` is true, variants provide conditional content:

| Field | Type | Purpose |
|---|---|---|
| `content` | string | Message body for this variant |
| `formulaMatch` | string | Formula condition (e.g. `< 5`, `>= 10`) |
| `originalText` | string | Original text before variable substitution |
| `attachment` | `AppFile` | Per-variant file attachment |
| `smsLinks` | `SmsLink[]` | Per-variant trackable links |

**Model**: `app/models/TextMessage/TextMessageVariant.ts`

### SmsLink

Trackable links embedded in message content via `::variable::` tokens:

| Field | Type | Purpose |
|---|---|---|
| `url` | string | Target URL |
| `variable` | string | Token name (used as `::variable::` in content) |
| `type` | `website` \| `video` | Link type (affects frontend display on click) |
| `variantId` | `Nullable<string>` | `null` for plan-level, variant ID for variant-level |

**Model**: `app/models/SmsLink/SmsLink.ts`

## Two Content Modes

### No-formula mode (`isUsedFormula: false`)
- Content lives in `textMessage.noFormulaText`
- Links in `textMessage.smsLinks[]`
- Attachment in `textMessage.noFormulaAttachment`
- Single message body for all participants

### Formula mode (`isUsedFormula: true`)
- Content lives in `textMessage.variants[].content`
- Links in `textMessage.variants[].smsLinks[]`
- Attachment in `textMessage.variants[].attachment`
- Variant selected based on `formulaMatch` evaluation per participant

## SMS Link Flow

### Creation (researcher side)
1. Researcher clicks "+ Add link" in the message editor
2. Fills in link type, variable name, URL in `SmsLinkModal`
3. `createSmsLinkRequest` dispatched → saga POSTs to `/v1/sms_links`
4. `::variable::` token appended to message content
5. Link appears in `SmsLinksList` below the textarea

### API payload branching

```js
// No-formula mode
{ sms_link: { sms_plan_id: '...', link_type, url, variable } }

// Formula mode
{ sms_link: { variant_id: '...', link_type, url, variable } }
```

### Resolution (send time)
At SMS delivery, the backend replaces `::variable::` tokens with unique per-user short URLs:
```
::promo:: → https://web-url.com/link/Ab3xY
```

Each user gets a unique slug tracked via `SmsLinksUser` for click analytics.

### Verification (participant side)
When a participant clicks the short URL:
1. `POST /v1/sms_links/verify` with `{ slug }` (no auth required)
2. Backend records click timestamp
3. Returns `{ link_type, redirect_url }`
4. Frontend redirects (website) or plays inline (video)

## Redux State Shape

```js
textMessages: {
  textMessages: [
    {
      id: 'plan-1',
      noFormulaText: 'Hello ::promo::',
      smsLinks: [{ id: '...', variable: 'promo', variantId: null }],
      variants: [
        {
          id: 'variant-1',
          content: 'Click ::offer::',
          formulaMatch: '< 5',
          smsLinks: [{ id: '...', variable: 'offer', variantId: 'variant-1' }],
        },
      ],
    },
  ],
}
```

## Key Components

| Component | Location | Purpose |
|---|---|---|
| `NoFormulaMessage` | `TextMessagesPage/components/NoFormulaMessages/` | Editor for no-formula mode |
| `VariantItem` | `TextMessagesPage/components/TextMessageVariants/VariantItem.js` | Editor for a single variant |
| `SmsLinkModal` | `app/containers/SmsLinkModal/` | Popover form for creating links |
| `SmsLinksList` | `TextMessagesPage/components/SmsLinksList/` | Displays links below textarea |

## Key Rules

- **Always check `isUsedFormula`** — it determines which content mode is active
- **Links are scoped** — no-formula links have `variantId: null`, variant links have the variant's ID
- **Variable names must be unique** within their scope (per plan or per variant)
- **`::variable::` tokens are NOT URLs** — they're resolved at send time by the backend
- **Attachments are per-variant** in formula mode, per-plan in no-formula mode
