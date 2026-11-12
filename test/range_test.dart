import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_select/swipe_select.dart';

final _keys = List.generate(20, (i) => 'k$i');
String? _keyForIndex(int i) => i >= 0 && i < _keys.length ? _keys[i] : null;

List<String> _sorted(Set<String> s) =>
    s.toList()..sort((a, b) => int.parse(a.substring(1)).compareTo(int.parse(b.substring(1))));

/// Simulates a gesture: starts at [anchor], then the finger passes [path].
List<String> _drag(List<String> initial, int anchor, List<int> path, {bool Function(int)? selectable}) {
  final start = initial.toSet();
  final shouldSelect = !start.contains(_keys[anchor]);
  var current = start;
  IndexRange? previous;
  for (final index in [anchor, ...path]) {
    final next = IndexRange(index < anchor ? index : anchor, index > anchor ? index : anchor);
    current = applyRangeTransition<String>(
      initial: start,
      current: current,
      previousRange: previous,
      nextRange: next,
      shouldSelect: shouldSelect,
      keyForIndex: _keyForIndex,
      isSelectable: selectable,
    ).next;
    previous = next;
  }
  return _sorted(current);
}

void main() {
  test('selects a range downwards', () => expect(_drag([], 2, [3, 4, 5]), ['k2', 'k3', 'k4', 'k5']));
  test('selects a range upwards', () => expect(_drag([], 5, [4, 3]), ['k3', 'k4', 'k5']));
  test('moving back restores the initial state', () {
    expect(_drag(['k4'], 1, [2, 3, 4, 5, 6, 3]), ['k1', 'k2', 'k3', 'k4']);
    expect(_drag(['k4'], 1, [6, 1]), ['k1', 'k4']);
  });
  test('crossing the anchor', () => expect(_drag([], 5, [7, 3]), ['k3', 'k4', 'k5']));
  test('starting on a selected item deselects', () => expect(_drag(['k1', 'k2', 'k3', 'k9'], 2, [3, 4]), ['k1', 'k9']));
  test('deselect + move back restores', () => expect(_drag(['k1', 'k2', 'k3', 'k4'], 1, [4, 2]), ['k3', 'k4']));
  test('finger jumps over several items', () => expect(_drag([], 0, [10]).length, 11));
  test('non-selectable items are skipped', () {
    expect(_drag([], 0, [5], selectable: (i) => i != 3), ['k0', 'k1', 'k2', 'k4', 'k5']);
  });
  test('selection outside the range is untouched', () {
    expect(_drag(['k15', 'k16'], 2, [4]), ['k2', 'k3', 'k4', 'k15', 'k16']);
  });
  test('no change returns the same set', () {
    final current = {'k1'};
    final r = applyRangeTransition<String>(
      initial: {'k1'},
      current: current,
      previousRange: null,
      nextRange: const IndexRange(1, 1),
      shouldSelect: true,
      keyForIndex: _keyForIndex,
    );
    expect(r.changed, isFalse);
    expect(identical(r.next, current), isTrue);
  });
}
