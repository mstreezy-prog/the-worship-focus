# iPad UX redesign — review notes

Application changes target `ipad-foundation`; `main` is unchanged.

## Library and service launch

- Launch shows the searchable song library with an Open Music Stand service card. The most recently selected service is remembered across launches.
- Selecting a song opens Preview, with Editor and MusicXML tabs available. Done editing returns to the dashboard.
- Service planning retains ordering, sections, notes, import/export and existing storage.

## Current Music Stand navigation

- One native horizontal PageView contains every chart page in service order. Swiping advances through the current chart, then opens the next song after its last page. Reverse swiping from a song's first page opens the previous song's last page. Song buttons and the service-order picker still jump directly to a song.
- Chart-page arrows use the same continuous sequence as swiping. Chart widgets render individual pages and have no nested horizontal pager. Layout changes rebuild the sequence while preserving the selected song and clamping its chart page to the new layout.
- MusicXML scrolls vertically in Music Stand and pans vertically in the standalone XML viewer. The XML viewer retains zoom and Fit score controls.
- Go live with score receives the full library list, starts at the selected song, and passes annotation changes back to the appropriate song. Previously this route supplied only one song, making next-song navigation impossible.
- Left/right keyboard arrows follow the continuous page/song sequence. Up/down and page-up/page-down advance chart pages or scroll the current XML score vertically.
- Tap the music with a finger to hide both toolbars and reclaim their space; tap again to restore them. Pencil taps/strokes and scroll/swipe gestures do not toggle the toolbars. Chart pagination uses a stable layout height while the controls are hidden, preserving the current page. The Pencil icon beside Reader settings opens a floating tool popover; drawing controls are hidden by default.
- Text size, columns, session transposition, stage theme and screen-awake options remain in Reader settings. Two columns fall back to one below 700 logical pixels. Long lyrics scale to fit.
- Session transposition leaves saved source unchanged. Explicit chord shapes remain available in the original key and are hidden when transposed rather than relabeled with incorrect fingerings.

## XML rendering and barlines

- A stable logical score width keeps full-score Pencil coordinates unchanged during vertical scrolling and rotation.
- The vendored notation engine previously added an implicit final double bar to every wrapped system. Grand-staff layout fragments now request a single implicit closing bar. Explicit final bars and repeat marks from source XML are preserved.
- The small vendored change adds `automaticFinalBarline` to LayoutEngine (default true) and disables it for GrandStaffPainter's layout fragments. Other layout clients retain their prior behavior.
- The superseded horizontal XML page slicer and boundary-overscroll song detector have been removed.

## Pencil and persistence

- ChordPro and MusicXML support Pencil, highlighter, eraser, colors and bounded undo/redo history. The Markup-style popover includes illustrated tools, six colors, Fine/Medium/Bold stroke widths, undo/redo, and labeled Eraser and Remove pencil marks controls. Removal clears only the current song chart or XML arrangement, includes offscreen marks, and is undoable in a single step. Undo/redo remain available after clearing even in Navigate mode.
- ChordPro ink is included in song JSON and existing library backup serialization. Older songs load with no markings. MusicXML uses its existing arrangement annotations.
- ChordPro markings attach to lyric/diagram blocks by content and occurrence, following those blocks through layout changes. Drawing is scoped to its starting block; page-spanning sketches are not supported. Review markings after editing/reordering identical repeated lines.
- Fingers navigate while a Pencil tool is selected. Erasing checks stroke segments and cancellation rolls back unfinished erasing.

## Validation

Dart formatting and Flutter analysis completed. Regression coverage includes tap-to-hide/restore, Pencil tap safety, eraser input, undoable removal across chart anchors, arrangement-specific XML clearing, retained XML scroll position, and iOS swipes through chart pages and song boundaries in both directions, one-page songs, starting at a later song, rotation/text-size reflow, vertical XML movement, Pencil persistence, XML-to-Music-Stand song context, and single implicit versus explicit final/repeat bars. Existing parser, import/save, PDF, backup, service-plan and MusicXML tests remain in the suite.

Physical iPad testing is still needed to confirm gesture feel and palm rejection. Widget tests do not establish hardware behavior.

## Protected configuration

The checkout already contained local modifications to:

- `ios/Runner.xcodeproj/project.pbxproj`
- `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`
- `ios/Runner/Info.plist`

These files are excluded from application patches. Automatic build-tool project rewrites are restored to the pre-build version after deployment. Local iOS configuration is excluded from the application commit. No merges or modifications to `main` are part of this work. Synced project reference files are untouched.
