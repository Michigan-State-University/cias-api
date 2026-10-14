# Domain Model — Core Concepts

## Entity Hierarchy

```
Organization
  └── HealthSystem
        └── HealthClinic

Intervention (study/project)
  ├── Session (Classic | SMS | CatMh)
  │     ├── Question (19+ types)
  │     │     └── Answer
  │     ├── TextMessage (SMS plan)
  │     │     ├── TextMessageVariant (formula-based content)
  │     │     │     └── SmsLink
  │     │     └── SmsLink (no-formula)
  │     └── ReportTemplate
  └── Collaborator (shared access)

User
  ├── UserSession (participant's session attempt)
  │     └── Answer
  └── UserIntervention
```

## Intervention

The top-level entity representing a research study or program.

- **Statuses**: `draft`, `published`, `paused`, `closed`, `archived` (`InterventionStatus` enum)
- **Types**: `Default`, `FixedOrder`, `FlexibleOrder` (`InterventionType` enum)
- **Sharing**: `anyone`, `registered`, `invited` (`InterventionSharedTo` enum)
- **Sensitive data**: tracks state as `collected`, `marked_to_remove`, `removed`
- **External integrations**: CatMH (adaptive testing), HFHS (Henry Ford Health System)
- **Model**: `app/models/Intervention/Intervention.ts`

## Session

A single activity within an intervention. Three types:

| Type | Enum | Description |
|---|---|---|
| Classic | `Session::Classic` | Question-based interactive session with narrator |
| SMS | `Session::Sms` | Scheduled text message delivery |
| CatMH | `Session::CatMh` | Computerized Adaptive Testing for Mental Health |

### Scheduling

Sessions can be triggered via `SessionSchedule` enum:
- `after_fill` — after participant completes a prior session
- `days_after_fill` — N days after completing a prior session
- `exact_date` — specific calendar date
- `days_after` — N days after intervention start
- `days_after_date` — N days after a specific date
- `immediately` — right away

Note: SMS-level scheduling uses a different enum — see `TextMessageScheduleOption` below.

### Session settings
- **Narrator**: voice (Google TTS) and animation (Lottie character) toggles
- **Formula support**: conditional branching logic
- **Auto-finish/auto-close**: timed session completion
- **Model**: `app/models/Session/Session.ts`

## Question

19+ question types defined in the `Question` model. Key types:

| Type | Purpose |
|---|---|
| `Single` | Single-choice answer |
| `Multiple` | Multi-select answer |
| `FreeResponse` | Open text |
| `Number` | Numeric input |
| `Slider` | Visual analog scale |
| `Grid` | Matrix/table format |
| `Date` | Date picker |
| `Phone` | Phone number input |
| `Currency` | Currency amount |
| `Name` | First/last name |
| `Information` | Read-only text (no answer) |
| `ExternalLink` | Link to external resource |
| `Feedback` | Displays computed feedback |
| `Finish` | Session end screen |
| `ThirdParty` | External integration question |
| `ParticipantReport` | Generated report |
| `TlfbConfig/Events/Question` | Timeline Follow-Back instrument |
| `HenryFord` | HFHS-specific question |

- Generic interface: `GenericQuestion<VType, TBody, TSettings>`
- Each question has: narrator blocks, optional video, formulas, body, answer images
- **Model**: `app/models/Question/Question.ts`

## TextMessage (SMS Plan)

Represents a scheduled SMS message within an SMS session.

- **Scheduling**: `TextMessageScheduleOption` (`after_session_end`, `days_after_session_end`, `days_after_user_defined_time`)
- **Frequency**: `TextMessageScheduleFrequency` (`once`, `once_a_day`, `once_a_week`, `once_a_month`)
- **Send time**: `SmsSendTimeType` with details (specific time, or time range)
- **Formula support**: when `isUsedFormula` is true, content comes from `variants[]` instead of `noFormulaText`
- **Include options**: can auto-insert `firstName`, `lastName`, `phoneNumber`, `email`
- **SMS Links**: `::variable::` tokens in message body, resolved to per-user short URLs at send time
- **Model**: `app/models/TextMessage/TextMessage.ts`

## TextMessageVariant

A conditional version of SMS content, selected based on formula evaluation.

- Fields: `id`, `content`, `formulaMatch`, `originalText`, `attachment`, `smsLinks[]`
- **Model**: `app/models/TextMessage/TextMessageVariant.ts`

## SmsLink

A trackable link embedded in an SMS via `::variable::` tokens.

- Types: `website`, `video`
- At send time, `::variable::` is replaced with a unique per-user short URL
- The short URL resolves via `POST /v1/sms_links/verify` (no auth required)
- Tracks click timestamps per user via `SmsLinksUser` backend model
- **Model**: `app/models/SmsLink/SmsLink.ts`

## TLFB (Timeline Follow-Back)

A calendar-based assessment instrument for tracking substance use or behaviors over time.

- Config question sets up the calendar range
- Events question defines event types
- TLFB question is the actual calendar fill
- **Models**: `app/models/Tlfb/`
- **Reducer**: `app/global/reducers/tlfb/`

## LiveChat

Real-time messaging between navigators and participants during sessions.

- **Models**: Message, Conversation, Interlocutor, InterventionConversation
- Uses WebSocket channels for real-time delivery
- **Models**: `app/models/LiveChat/`
- **Reducer**: `app/global/reducers/liveChat/`

## Organization Hierarchy

Three-level hierarchy for managing access:

```
Organization
  └── HealthSystem
        └── HealthClinic
```

Each level has its own admin role (`OrganizationAdmin`, `HealthSystemAdmin`, `ClinicAdmin`). E-Intervention Admins operate at the organization level for managing interventions.

- **Models**: `app/models/Organization/`, `app/models/HealthSystem/`, `app/models/HealthClinic/`
