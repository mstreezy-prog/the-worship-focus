# Service-plan cloud sync · first integration

This branch contains a Supabase-backed service-plan connection. It is disabled unless the app is built with the public project URL and publishable key. Administrative/service-role keys must never be included in an app build.

The matching website repository owns `supabase/migrations/202610300001_service_sync.sql`, the JavaScript sync client, and the shared protocol. Run that migration on the selected **Free development project** before enabling clients. The hosted website keeps its existing owner-only access.

## Enable cloud sync

1. Select or create a Free development project in the owner's connected Supabase account; do not enable paid services implicitly.
2. Apply the migration. Provision the development Worship Focus auth account through Supabase's normal user setup. The Supabase dashboard login and the app's Worship Focus user login are separate identities.
3. Set the website's `dist/cloud-config.js` to its public `url` and `publishableKey` and redeploy the private Site.
4. On the Mac, run dependency resolution and the Flutter checks, then build with:

   ```sh
   flutter run --dart-define=SUPABASE_URL=https://PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=PUBLIC_KEY
   ```

5. In Cloud Sync, sign in to the same Worship Focus account on the website and iPad. Create one church workspace, then connect each device. Choose whether to copy existing local plans on its first connection. The original local plans remain available in Device-only mode.
6. Verify an actual website → iPad → website round trip before treating sync as active. Test changing title/date/order/key/notes, working offline, reconnecting, concurrent edits, and signing out.

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
- GitHub access is verified and this integration is saved on `ipad-foundation`. Supabase's tools currently return an “Unknown tool” connection error in the authoring chat, despite the owner's account connection. Project configuration and an actual cloud round trip remain pending; no live sync success is claimed.
- Run `flutter pub get` on the Mac to resolve the pinned Supabase dependency and update `pubspec.lock`, then run `flutter analyze` and `flutter test` before a native build. The lockfile has not been regenerated in the authoring environment.
