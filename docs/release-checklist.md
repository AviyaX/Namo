# Release checklist

- [ ] Pirith (text and recordings from pitaka.lk): do not publish the app or push the repository to a public place until the owner confirms the permission from pathnirvana has been given; then add "used with permission" to the Sources entry.
- [ ] Samantha Pattana (text from tipitaka.lk, recording from the channel Samata Dharmaya): do not publish the app or push the repository to a public place until the owner confirms permission for the tipitaka.lk text and the Samata Dharmaya recording; then add "used with permission" to the Sources entry.
- [ ] Samantha Pattana, owner checks:
  - [ ] Read the converted text against the PDF, using `source_material/samantha_patthana/REVIEW_converted_text.md`.
  - [ ] Listen to the opening, a short part and the long part 4 (in a web browser or on a phone) with `content/samantha_patthana_timing_report.md` at hand, and say whether the line highlight keeps pace. A unit whose highlight drifts goes into `UNTIMED_UNITS` in `tools/build_samantha_patthana.py` (it is then highlighted as a whole from its start time); then rebuild with `python -I -X utf8 tools/build_samantha_patthana.py .`.
- [ ] My flows, by hand on a phone (Android and iOS) and in a web browser:
  - [ ] In the Library, make a new flow from a reading; the editor shows all its sections.
  - [ ] Reorder sections by dragging the handle (on a phone, with a finger), and with Move up / Move down from a row's menu.
  - [ ] Remove a section, then Undo; add a pirith from Add sections.
  - [ ] Start chanting: the sections are in your order, numbered from 1; Back returns to the editor.
  - [ ] Close the app fully and open it again: the flow, its order and your place in it are still there, and it shows on Home under "Your flows".
