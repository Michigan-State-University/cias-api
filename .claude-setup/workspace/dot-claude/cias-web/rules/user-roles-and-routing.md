# User Roles & Routing

## Roles

Defined in `app/models/User/RolesManager/UserRoles.ts`:

```typescript
enum Roles {
  Admin              = 'admin',
  TeamAdmin          = 'team_admin',
  Researcher         = 'researcher',
  Participant        = 'participant',
  Guest              = 'guest',
  ThirdParty         = 'third_party',
  OrganizationAdmin  = 'organization_admin',
  EInterventionAdmin = 'e_intervention_admin',
  HealthSystemAdmin  = 'health_system_admin',
  ClinicAdmin        = 'health_clinic_admin',
  Navigator          = 'navigator',
  PredefinedParticipant = 'predefined_participant',
}
```

### Role groups

| Group | Roles | Use |
|---|---|---|
| `PasswordAuthenticatedRoles` | All except Guest, PredefinedParticipant | Users who log in with email/password |
| `AuthenticatedRoles` | PasswordAuthenticated + PredefinedParticipant | All users with any auth |
| `AllRoles` | Every role | Unrestricted routes |

### Role hierarchy for organizations

```
OrganizationAdmin → manages the organization
  EInterventionAdmin → manages interventions within the org
    HealthSystemAdmin → manages a health system
      ClinicAdmin → manages a specific clinic
```

## Route-Level Access Control

### AppRoute component (`app/components/AppRoute/index.js`)

Extends React Router's `Route` with permission enforcement:

```jsx
<AppRoute
  exact
  path={RoutePath.DASHBOARD}
  render={() => renderDashboardByRole()}
  protectedRoute                    // requires authentication
  allowedRoles={AuthenticatedRoles} // role whitelist
  navbarProps={{ navbarId: NAVIGATION.DEFAULT }}
  sidebarProps={{ sidebarId: NAVIGATION.DEFAULT }}
/>
```

### Key props

| Prop | Type | Effect |
|---|---|---|
| `protectedRoute` | boolean | Requires authenticated user; redirects to login if not |
| `allowedRoles` | Roles[] | User must have at least one matching role |
| `unauthorizedUsersOnly` | boolean | Only for logged-out users (e.g. login page); redirects authenticated users away |

### Auth redirect flow

1. Unauthenticated user hits a protected route
2. `AppRoute` redirects to `/login?redirect_to=<encoded_original_path>`
3. After login, the redirect query param is used to navigate back

### Route paths

All paths are defined in the `RoutePath` enum at `app/global/constants/router.ts` (40+ routes). Always import from there — never hardcode path strings.

## Layout Structure

`AppRoute` renders the full page shell for protected routes:

```
PageContainer
  ├── Navbar (configurable via navbarProps)
  ├── Sidebar (conditional — canDisplayLeftSidebar per role)
  └── MainAppContainer
        └── <Route component/render>
```

### Sidebar visibility

Not all roles see the sidebar. The `canDisplayLeftSidebar()` function in RolesManager determines visibility based on the user's roles and the current page.

### Quick Exit

Certain roles (participants in sensitive studies) can enable "Quick Exit" which:
- Clears all localStorage data (`LocalStorageService.clearUserData()`)
- Immediately navigates away from the application
- Controlled by `user.quickExitEnabled` and `canUseQuickExit(user.roles)`

## Key Rules

- **Always use `RoutePath` enum** — never hardcode URL strings
- **Check `allowedRoles` when adding new routes** — default to the minimum required role set
- **Role-based UI rendering** — use RolesManager utilities to conditionally show/hide features based on user roles
- **Dashboard is role-aware** — different roles see different dashboard views (`renderDashboardByRole()`)
