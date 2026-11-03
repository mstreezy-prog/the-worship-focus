# ChordPro appearance in Music Stand

Reader settings now offer separate **Lyric size**, **Chord size** (14–50 pt),
and **Chord color** controls for ChordPro. Changing lyrics leaves the selected
chord size and color intact; changing chords leaves the lyric size intact.
Chord-only lines use the same chord appearance as lyrics with chords.

Match lyrics preserves the default monochrome appearance. Blue, Burgundy,
Green, and Purple use darker shades on the light theme and lighter shades on
the dark stage theme. Lyrics, comments, and Pencil markings retain their own
colors. ChordPro appearance is stored separately from MusicXML appearance.

Preferences persist on the device. Existing preference files without the new
fields preserve the previous chord size (110% of the saved lyric size), then
allow independent changes. Line height and both page-count calculations take
the chosen chord size into account. The existing fit-to-width behavior remains.

Seventeen standalone Dart checks pass for preference migration, independent
sizes, JSON round-tripping, color contrast on light/dark backgrounds, line
spacing, and pagination without dropped content. Static analysis of the pure
models/services used by those checks reports no issues. These checks do not
exercise Flutter painting or widgets.

Flutter regression coverage checks preference migration/persistence, independent sizes,
chord/lyric separation, content preservation during pagination, and Music Stand
controls at portrait and landscape iPad dimensions. Full Flutter widget tests
and physical iPad appearance must be checked on the Mac before installation.
