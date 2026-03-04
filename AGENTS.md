# AGENTS.md

## Mission
Build `coding-plan-status` for macOS 14+ as a native menu bar app to monitor GLM and MiniMAX coding plan usage.

## MVP
- Native stack: SwiftUI + MenuBarExtra
- Providers: GLM + MiniMAX, single personal account each
- Polling: every 5 minutes
- Alerts: 80/90/95 thresholds, NotificationCenter + menu bar color
- Storage: Keychain (credentials), SQLite (snapshots + daily aggregates)
- History: 90 days, daily EOD used-percent

## Provider Contracts
### GLM
- Endpoints:
  - `/api/monitor/usage/quota/limit` (primary)
  - `/api/monitor/usage/model-usage` (secondary)
  - `/api/monitor/usage/tool-usage` (secondary)
- Auth: raw `Authorization` token passthrough
- Primary status uses monthly quota semantics (`TIME_LIMIT(1 Month)`)

### MiniMAX
- Endpoints:
  - `/v1/api/openplatform/coding_plan/remains` (primary)
  - `/v1/api/openplatform/charge/combo/cycle_audio_resource_package` (secondary)
  - `/account/amount` (secondary)
- Auth: `Authorization: Bearer <token>`
- Requires `groupId`

## Normalized Model
`PlanStatus` fields:
- provider, accountId, planId, planName
- usedPercent, remaining, remainingUnit
- resetAt, fetchedAt
- severity (ok|warning|critical|unsupported|error)

## Risk and Selection Rules
- If multiple plans exist, choose highest-risk plan for menu bar summary.
- Unsupported provider capability must be explicit (`unsupported`), never faked.
- Alert dedupe key: provider+accountId+planId+threshold.
- Re-arm threshold only after usage drops below (threshold - 5).

## Security
- Credentials only in Keychain.
- Never log tokens, cookies, or full auth headers.
- Raw payload logging must be redacted.

## Data Rules
- Snapshot retention: 90 days.
- Daily aggregate metric: end-of-day usedPercent.
- Cleanup job runs daily in local timezone.

## Coding Workflow
1. Implement adapter + mapper tests.
2. Integrate polling and persistence.
3. Implement alert state machine tests.
4. Build menu bar UI from normalized store only.
5. Run full tests before packaging app.

## Definition of Done
- Local `.app` runs on macOS 14+.
- GLM + MiniMAX both fetch real usage at least once.
- Alerts verified for 80/90/95 with dedupe and re-arm.
- 90-day history chart works with daily EOD aggregation.
