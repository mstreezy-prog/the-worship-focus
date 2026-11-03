# Modern Evergreen across the app and planner

The shared interface uses CMG Sans for headings, body text, navigation, forms,
buttons, ChordPro, and score text. The website includes the exact regular, bold,
italic, and bold-italic TTF files already bundled in the app, with their SIL
Open Font License. Web font files are served by the private site itself.

| Token | Light / planning | Dark / Music Stand |
| --- | --- | --- |
| Primary | `#245B4A` forest | `#B7D7C3` light sage |
| Canvas | `#F7F9F7` warm white | `#111D18` deep forest |
| Surface | `#FFFFFF` | `#18271F` |
| Main text | `#293B35` | `#F1F3EC` |
| Secondary text | `#56685C` | `#B7C6BC` |
| Soft selection | `#E3EEE6` | `#354E3F` |
| Border | `#D9E1D5` | `#415248` |

The app centralizes these choices in `lib/theme/worship_focus_theme.dart`.
The planner uses `dist/brand.css`. Keep these values coordinated when extending
the brand. Standard cards, buttons, and fields use 12px corners; dialogs use
20px corners. The existing magnifying-glass/cross mark is shared by the planner
and app header.

Music notation continues to use Bravura for musical symbols, with CMG Sans for
lyrics and chord labels. Saved chord colors/sizes, lyric sizes, annotations,
service plans, and cloud connections are independent of the interface theme.
Reader settings inherit the current Music Stand theme.

Validation: all four web font files match the app assets byte for byte. The
planner's 18 automated tests pass. Desktop and tablet browser checks cover song
selection, filtering, reordering, and the final review; 820px and 390px layouts
fit without horizontal page overflow. The Flutter analyzer, widget suite, and
physical iPad appearance require verification on the Mac before installation.
