# Named serving sizes

Each food has an ordered list of named sizes, each with a gram equivalent. The
first size is the nutrition-entry basis for a custom food. Nutrients continue
to be stored per 100 g; changing between sizes changes the gram weight and
preview, not the nutrient density. Custom foods can add or remove named sizes,
but must keep at least one. Names must be unique and weights positive.
Changing or removing the first size rescales the nutrition drafts to the new
basis, preserving nutrition per gram during catalog edits.

Existing foods without a catalog expose their existing `servingDescription`
and `servingSizeGrams` as their first named size. If the description is blank,
the label is “Serving”; if the legacy weight is invalid, the fallback is 100 g.
The catalog is stored as optional JSON on `FoodItem` so legacy rows keep their
data. The first catalog size is mirrored back to the legacy fields for capture,
plate, and recipe consumers.

The Food Log editor shows named sizes first and “Gram” last as a direct mass
entry option. Changing size keeps the typed numeric count and recalculates
weight and nutrition immediately. Counts accept up to two decimal places,
must exceed zero, and may not exceed 1,000 units or 100,000 g. A comma is
accepted as a decimal separator. Display formatting rounds weight and macro
preview with the existing `MFFormat.grams` formatter; stored grams and nutrient
snapshots retain full `Double` precision.

Each logged serving stores its name, gram weight per unit, and quantity on the
entry. This snapshot keeps the original selection understandable after a food
catalog edit or deletion. Older entries infer a named amount when their gram
weight divides evenly to two decimal places; otherwise they open in the Gram
option with the exact stored amount. An unchanged historical amount may be
saved with detail edits even when it exceeds the current typed-input limits. Portion edits scale
the entry's existing nutrient snapshot by the gram ratio, preserving historical
nutrition when a food's per-100-g facts have changed. Timestamp and meal slot
continue to use the existing entry fields.

Weightless Quick Add entries keep their existing details and nutrition editor;
they do not receive a fabricated serving size.
