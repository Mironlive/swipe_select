## 0.1.0

First public release.

- `SwipeSelect` widget + `SwipeSelectItem` + `SwipeSelectController`
- Activation: edge strip (start / end), long press, swipe across; combine several with `ActivationWhen` (`always` / `selectionMode` / `idle`)
- Works with `ListView`, `GridView`, `CustomScrollView` slivers; `reverse` (chat) and horizontal lists; items of any size
- Auto-scroll that ramps up towards the edge
- Moving back restores the selection from gesture start
- Non-selectable items, forced selection mode, `onChanged` once per gesture
- Data changes mid-gesture are remapped by key
- `SwipeSelectItem.builder` rebuilds only rows whose selection changed
