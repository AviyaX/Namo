# Namo — My Flows (personal chanting sequences) — Design

Date: 2026-11-10. Status: approved by the owner on 2026-11-10 ("yes thats right"), including the calls in section 10. Built after the premium redesign is finished; its plan is written then, against the redesign's real components.

## 1. What the owner asked for

In the owner's words (2026-11-10):

> "i need to add a feacture that user can create a flow hw chanting works like. 1 user can start fro budda wandanawa and in that withput severl section as an exmple hes not pujaing flowers he dont wnat to say that part he can create his own flo by adding things that in ouer system well show eveything we have he can add and chnage the ordering"

> "several nemd flows"

> "user can crete the flows by adding the sections but defulet this has to be saty"

So: a person can make **several named flows**. A flow is their own chanting order — some of the app's sections, in the order they choose. Someone who does not offer flowers leaves that section out. The original Buddha Wandanawa **stays as it is**: always there, complete, never changed by anything a person does with flows.

## 2. Why

People do not all chant the same sequence. Today the app offers one fixed order, so a person skips past parts by hand every day. A flow lets the app follow the person's own practice.

## 3. Goals, non-goals, anti-goals

**Goals**
- Make, name, rename and delete flows; several can exist side by side.
- Start a flow from a whole reading (Buddha Wandanawa today) or from nothing.
- Add any section the app holds, remove sections, change their order.
- Chant a flow in the same reader as everything else, with auto-scroll, languages, text size, progress and the remembered place.
- Works offline, kept on the device, free.

**Non-goals (not in this piece of work)**
- Choosing single verses; the unit is a whole section.
- The same section twice in one flow.
- Sharing, exporting or syncing flows; accounts.
- Recordings for flows (a recording belongs to a whole original reading).
- Writing or pasting one's own text into a flow.

**Anti-goals (it has failed if this happens)**
- The original reading changes, loses a section or can be deleted.
- Verse text is copied into a flow and drifts from the checked content.
- A flow breaks or is lost when the app's content is updated.
- The feature makes the calm Library feel like a settings panel.

## 4. Constraints

- Verse text is never copied, changed or typed by hand. A flow stores only references to sections.
- Nothing is fetched at run time; no new packages.
- Built from the redesign's shared parts (`NamoPage`, `PageHeader`, `ListRow`, `SurfaceCard`, `SheetFrame`, buttons, `EmptyState`, palette roles) and its rules (48 × 48 targets, spacing and radius sets, motion, both themes, no text under 12). It is built after the redesign plan is finished.
- Existing saved data (`namo.settings.v1`, `namo.saved.v1`, `namo.position.v1`) keeps its format. Existing addresses keep working.
- Android, iOS and web together.

## 5. Approaches considered

1. **A flow is a list of section references, shown by the existing reader. — chosen by the owner.** Text is never copied, so it always matches the checked content; every reader function works; no second reader to keep in step.
2. **Skip switches on Buddha Wandanawa only.** Less work, but no adding and no reordering, and it would alter how the original behaves — against "default has to stay".
3. **A separate chanting screen for flows.** Duplicates the reader; the two would drift apart.

## 6. How it works for the person

### 6.1 Library
- A part named **My flows** sits above the topics.
- With no flows: one quiet card — "Make your own flow" / "Choose the sections you chant, in your order." — and a **New flow** button.
- With flows: one row per flow (name, "N sections"), in the order they were made. Tapping a row opens the flow in the reader. A trailing edit button (tooltip "Edit flow") opens the editor. The **New flow** button follows the rows.
- Search is unchanged: it searches the app's content, and results open the original reading.

### 6.2 New flow
- A sheet titled "New flow": a name field (label "Name", for example "Morning"), then "Start from": **Nothing** or any reading the app holds (today: Buddha Wandanawa). **Create** makes the flow and opens its editor.
- Name: spaces trimmed at the ends, at most 40 characters. Left empty, it becomes "My flow" (then "My flow 2", …). Two flows may share a name.
- Starting from a reading puts all its sections in, in the original order.

### 6.3 Editor
- A page under the Library: Back, the flow's name (a rename button opens a sheet with the name field), "N sections".
- The flow's sections as a list in flow order: position number, the section's heading, a remove button (tooltip "Remove from flow"), and a drag handle. Order changes by dragging the handle; the same change is available without dragging ("Move up" / "Move down" actions for screen readers and keyboard).
- Removing a section shows "Removed" with **Undo** for a few seconds.
- **Add sections** opens a sheet listing everything the app holds, grouped by topic (and by reading where a topic has several), each section with a tick. Sections already in the flow are ticked. Ticking adds to the end of the flow; unticking removes.
- **Start chanting** opens the flow in the reader; disabled while the flow is empty.
- An empty flow shows "This flow has no sections yet." and **Add sections**.
- **Delete flow** asks first ("Delete "<name>"? This cannot be undone." — Delete / Keep). Deleting also forgets the flow's remembered place.
- Every change is saved at once; there is no Save button.

### 6.4 Chanting a flow
- The reader opens with the flow's name as its title and the flow's sections in the flow's order, numbered 1, 2, 3 … by their place in the flow.
- Auto-scroll, previous/next section, languages, layout, text size, line spacing, progress, screen-awake and the remembered place all work as for a reading. Each flow remembers its own place.
- Bookmarking a section inside a flow bookmarks that section of the **original** reading (Saved shows it there, as today).
- There is no favourite button on a flow (flows are already listed under My flows).
- No recording controls on a flow.
- Back returns to where the flow was opened from (Home, the editor, or the Library).

### 6.5 Home
- With at least one flow: a row **Your flows** after "Continue reading" — one small card per flow (name, "N sections"), opening the reader at the flow's remembered place.
- "Continue reading" works for a flow exactly as for a reading (it shows the flow's name).

## 7. How it is built (my calls unless marked)

- **Stored** under a new key `namo.flows.v1`: the list of flows (id, name, ordered section references — reading id + section id) and a counter for the next id. Ids look like `flow-1`, `flow-2`, are never reused, and no content reading id may start with `flow-` (a test on the bundled content guards this).
- **Reading a flow**: one function resolves an id to something the reader can show — a content reading as today, or a flow turned into a reading object made at that moment from the referenced sections (same verse objects, new position numbers). The reader, Home's "Continue reading" and the position store use that function; the position store keeps the flow's place under the flow's id, in the existing format.
- **Section ids must be unique across the whole app** so a flow can mix sections from different topics. True today (one reading). The content build tool gets a check so it stays true when Pirith and Meditation are added.
- **A flow is a copy of choices, not a link.** Starting from a reading copies its section references once. Sections added to that reading later do not appear in the flow by themselves; the person adds them through Add sections.
- **Every section the app holds can be added**, whatever reading it belongs to. Each reference carries its reading id, which is what a bookmark needs (bookmarks are stored as reading id + section id today).
- **Remembered place after editing**: the place is remembered by section (as today). If that section is still in the flow, the flow opens there, wherever it now sits in the order. If it was removed, the flow opens from its start.
- **"Continue reading" on Home**: deleting a flow forgets its place, so the card behaves as it does today when nothing is remembered. A flow that has been emptied is not offered there.
- **No limit** on the number of flows or on sections in a flow.
- **Reordering** uses Flutter's own reorderable list (no new package).
- **Content changes**: a reference to a section that no longer exists is skipped when the flow is shown or edited; the rest of the flow is untouched. Damaged stored data gives no flows rather than an error; one unreadable flow is dropped alone.
- **Addresses**: new ones only — the editor under the Library, and the reader address accepts a flow id. All existing addresses are unchanged. An address for a flow that does not exist shows the existing not-found page.

## 8. Tests that must exist

- Flow storage: make, rename, delete, add, remove, reorder, undo; round-trip through storage; damaged data; ids never reused.
- Resolution: a flow's reading has exactly the referenced sections in order with the stored verse text object-for-object; missing references skipped; a flow never alters the library.
- The original reading is identical before and after any flow operation (section count, order, text).
- Reader with a flow: title, order, numbering, remembered place per flow, previous/next, bookmark goes to the original section, no favourite button, Back destinations.
- Library and Home: parts appear only as described; "N sections" wording for 0, 1 and many.
- Editor: reorder by the non-drag actions, remove + Undo, add sheet ticks, empty state, delete confirmation, rename; name rules (empty, spaces, 40 characters, very long paste).
- Layout: no overflow at 320 wide with 2× text and at phone, tablet and desktop widths, both themes; targets at least 48 × 48.
- Bundled content: no reading id starts with `flow-`; section ids unique.

## 9. Left to the builder

- Exact widget structure and file split; the sheet and row details within the redesign's rules.
- How drag is offered on each platform, as long as the non-drag way exists.
- The wording of small accessibility labels not fixed above.

## 10. Calls I made (the owner did not state these)

- A section can be in a flow only once.
- No recordings and no favourite button on flows.
- Bookmarks made inside a flow belong to the original section.
- Sections are numbered by their place in the flow.
- Name limit of 40 characters; default name "My flow".
- Changes save at once; removing offers Undo; deleting asks first.
- My flows sits at the top of the Library and as a row on Home.
- A flow started from a reading is a one-time copy; it does not follow later changes to that reading.
- After a flow is edited it reopens at the remembered section if that is still in it, otherwise from the start.
- No limit on how many flows or sections.
