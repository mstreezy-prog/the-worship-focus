# MusicXML engraving and chord appearance

Music Stand's Reader settings now show the same Score display controls as the
standalone score viewer when a MusicXML arrangement is selected. Chord size and
five high-contrast chord colors are independent of note/staff size and lyrics.
Preferences persist on the device; old saved preferences default to black.

The pinned notation fork now shares one staff origin between noteheads and beam
geometry. Horizontal staff alignment re-anchors beam endpoints as well. Wrapped
systems retain voices and inherited meter, and beam grouping preserves the order
of notes and intervening chord labels. Chord tones share their written duration
and participate in beaming. Unmatched beams retain individual stems/flags.

Chord symbols use a separate text style and a higher lane. Tempo and rehearsal
marks sit above them. Larger chord labels reserve horizontal clearance and extra
top/bottom space. Imported/saved/exported MusicXML remains unchanged; display-only
harmony text is tagged separately from ordinary expression words.

The importer preserves divisions/time signatures across measures, numeric note
durations when a note type is omitted, forward gaps, hidden-note timing, and
separate voices coordinated by backup. Grace notes do not add time to a bar.
Mixed tuplet durations are summed instead of assuming every note has equal length.

## Validation

The uploaded lead sheet for “All My Boast Is in Jesus” was checked privately. All
112 source measures have six eighth-note beats; all 112 parsed measures preserve
that duration. The original arrangement is not included in this repository.

A framework-free parser harness passes timing, harmony classification, legacy
preferences, and independent chord appearance checks. That harness substitutes
only the unused bounding-box mixin; it does not test Flutter painting.

Flutter regression checks in `test/music_xml_engraving_test.dart` cover beam
coordinates, wrapped voices/meter, and harmony alignment. The score settings
widget check covers the Music Stand sliders and color selection. Run
`flutter analyze` and `flutter test` on the Mac before installing the update.
Full Flutter rendering and physical-iPad visual verification remain pending.
