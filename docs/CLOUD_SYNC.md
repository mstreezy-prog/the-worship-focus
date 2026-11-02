# Service-plan cloud sync · first integration

This branch is configured for the owner's Free Supabase development project, `pmmxucapanhsnuyoqxde`, in `us-east-2`. Only its public URL and publishable key are included. Build-time `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` values can override the defaults for another environment. Administrative/service-role keys must never be included in an app build.

The matching private website owns the migration files, JavaScript sync client, and shared protocol. Its church membership and revision-guarded RPC schema is applied; the security advisor reports no issues. The hosted website retains owner-only access.

## Start testing

1. In the Supabase project's **Authentication → Users → Add user → Create new user**, create a Worship Focus test login using your email and a password you choose; mark this user's email confirmed. Your Supabase dashboard account and app login are separate. Do not share passwords in chat.
2. Open the private website, choose **Cloud sync settings**, sign in, create a church workspace, and connect the browser. Decide whether to include existing browser plans on the first connection.
3. On the Mac, in the existing app checkout, run:

   ```sh
   git switch ipad-foundation
   git pull --ff-only origin ipad-foundation
   flutter pub get
   flutter analyze
   flutter test
   flutter run
   ```

   `flutter pub get` resolves the pinned Supabase dependency and updates `pubspec.lock`. Full Flutter checks/build remain unverified in the authoring environment. Stop and share errors if checks fail. No project keys need to be copied.
4. In the iPad's **Cloud sync**, sign in with the same Worship Focus login, select the same church, and connect. Choose whether to include device-only plans on the first connection.
5. Verify an actual website → iPad → website round trip. Test title/date/order/key/notes, an offline edit and reconnect, concurrent edits, and signing out before relying on sync for a service.

## Boundaries

- Synced: service name, calendar date, global notes, ordered songs and sections, per-item notes, and planning keys.
- Native song IDs and shared song references are distinct. Downloaded titles without a local chart create clearly labeled reference entries. Use **Song planning options → Use chart from this iPad** to bind one to an existing chart; sync does not overwrite that chart.
- Planning keys are metadata in this first integration. They do not rewrite local ChordPro/MusicXML arrangements or change audio pitch. Check/transpose the local chart before leading.
- Charts, recordings, and pencil annotations remain local. The schema reserves audio metadata for a future milestone; no MP3 upload or playback feature is enabled.
- Each account/church has separate baseline metadata. Server-enforced membership controls reads, while writes use a revision-checked RPC. A conflict keeps the cloud plan and a separate local copy instead of overwriting either.
- Deletes use revisioned tombstones. Downloads and pending local changes survive offline periods. Foreground clients poll at 30-second intervals and sync after edits/resume; this is not a promise of instantaneous collaboration.
- Existing local plans and backups remain backward-compatible. Cloud plans retain scoped references so signing into another church cannot silently upload an earlier church's plans.

## Verification in the authoring environment

- `dart tool/verify_service_sync.dart`: 9 isolated network-free checks pass.
- `dart analyze lib/services/service_plan_sync.dart lib/models/service_plan.dart`: passes.
- JavaScript sync tests and local PostgreSQL/PGlite authorization/revision tests are in the website repository.
- Full Flutter dependency resolution, widget tests, and native build are **not verified**. Automatic approval review blocked the Flutter setup command because it attempted to contact a cloud metadata endpoint. That command was not retried or bypassed; only direct, network-free Dart checks were used afterward.
- The database and both clients now have matching public project configuration. Hosted SQL/RLS checks pass; anonymous HTTP plan reads are denied. No real app login or plan has been seeded.
- Signed-in website/iPad sync remains unverified until the owner creates the test login and runs the updated app on the physical iPad.
