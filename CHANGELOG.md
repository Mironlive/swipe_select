## 0.1.3

- Simpler internals: auto-scroll zone computed in one place, data changes mid-gesture re-apply the range from the initial selection instead of tracking keys. No API changes.

## 0.1.2

- README: links to the React Native, SwiftUI and Jetpack Compose versions.

## 0.1.1

- Shorter package description (pub.dev limit is 180 characters).
- README: iOS and Android recordings side by side.

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
- `controller.selected` is an unmodifiable view (no copying); `controller.autoScrollDirection` for highlighting the edge zone
- Range bookkeeping is O(Δ) per step — long ranges (thousands of rows) stay cheap
