# Food Log copy and paste

- The Day menu pastes into the selected log day. For a copied food or hour block, each entry keeps its source local hour, minute, second, meal slot, amount, and note. The Food Log has no separate paste-time picker, so the source clock time is the default. If that clock time cannot occur on the destination day because of a calendar transition, the destination day's start is used.
- A copied hour block retains each entry's individual minute. The source entries and totals do not change.
- The clipboard is held in memory until another copy replaces it or the app process exits. Paste does not clear it. A second paste deliberately creates another independent set of entries.
- Each entry is saved before the success count is shown. If a block write fails partway through, saved entries remain, the count reports only entries visible on the selected day, and an error alert explains the incomplete paste.
- The empty clipboard has no Paste menu item. Whole-day copy uses the repository's existing day-copy behavior. QA-003's Quick Add paste finding is separate from this issue's food and hour-block timestamp fix.
