import 'dart:math' show max, min;

/// An inclusive range of item indices.
class IndexRange {
  const IndexRange(this.start, this.end);

  final int start;
  final int end;

  bool contains(int index) => index >= start && index <= end;

  @override
  bool operator ==(Object other) => other is IndexRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'IndexRange($start..$end)';
}

/// Transition between two gesture ranges.
///
/// Indices inside [nextRange] get [shouldSelect]. Indices that left the range go
/// back to their state in [initial] (the selection when the gesture started).
/// Only the difference between the two ranges is processed — O(Δ).
/// The set is copied lazily, only on the first real change. Returns `null` when
/// nothing changed.
Set<K>? applyRangeTransition<K>({
  required Set<K> initial,
  required Set<K> current,
  required IndexRange? previousRange,
  required IndexRange nextRange,
  required bool shouldSelect,
  required K? Function(int index) keyForIndex,
  bool Function(int index)? isSelectable,
}) {
  Set<K>? next;

  void apply(int start, int end, {required bool restore}) {
    for (var index = start; index <= end; index++) {
      if (isSelectable != null && !isSelectable(index)) continue;
      final key = keyForIndex(index);
      if (key == null) continue;
      final selected = restore ? initial.contains(key) : shouldSelect;
      final source = next ?? current;
      if (source.contains(key) == selected) continue;
      next ??= Set<K>.of(current);
      if (selected) {
        next!.add(key);
      } else {
        next!.remove(key);
      }
    }
  }

  if (previousRange == null) {
    apply(nextRange.start, nextRange.end, restore: false);
  } else {
    // Left the range — restore the initial state.
    if (previousRange.start < nextRange.start) {
      apply(previousRange.start, min(previousRange.end, nextRange.start - 1), restore: true);
    }
    if (previousRange.end > nextRange.end) {
      apply(max(previousRange.start, nextRange.end + 1), previousRange.end, restore: true);
    }
    // Entered the range — apply the gesture mode.
    if (nextRange.start < previousRange.start) {
      apply(nextRange.start, min(nextRange.end, previousRange.start - 1), restore: false);
    }
    if (nextRange.end > previousRange.end) {
      apply(max(nextRange.start, previousRange.end + 1), nextRange.end, restore: false);
    }
  }

  return next;
}
