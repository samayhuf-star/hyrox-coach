# Tests

| Suite | What it covers | Command |
|---|---|---|
| Workout logic (33 tests) | Plan builder, session timer, pause/undo/skip, auto-pause, storage and recovery, rewards, insights, race workouts | `swift test` (Linux, Swift 6) |
| AI Coach function (32 tests) | Sign-in checks, input validation, credit reserve/refund, purchase sync incl. sandbox switch, Coach reference notes | `deno run --allow-env --allow-read cloud/tests/coach_test.ts` |

`Package.swift` exists only for the logic tests. It compiles `Models/` and two service files with
small stand-ins for UIKit and AudioToolbox (`LogicTests/Stubs`). The iOS app is still built from
`HyroxAllInOneCoach.xcodeproj`. The SwiftUI screens are not covered by these tests.

## Server switch

`COACH_ALLOW_SANDBOX_PURCHASES=true` on the `ai-coach` function credits sandbox credit-pack
purchases (TestFlight and App Review). Leave it unset to credit production purchases only.

`COACH_KEEP_AUTH_USER=true` makes "Delete account" erase the Coach data but keep the sign-in. Use it
only when the Supabase project's sign-ins are shared with another product.

## Database

`cloud/migrations/001_coach_backend.sql` creates the Coach tables and credit-ledger functions
(20 free replies a month, purchased credits, refunds, pending-reply recovery). It was written to
match the calls the edge function makes; the original database script was never in this repo.
