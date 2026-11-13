part of 'swipe_select.dart';

/// Called when the selection changes: once per gesture (when it ends), and on
/// every `toggle` / `select` / `deselect` / `setSelection` / `clear`.
typedef SelectionChangedCallback<K> = void Function(Set<K> selected, SelectionChangeReason reason);

/// Holds the selection. Listen to it to rebuild your UI.
///
/// During a gesture it notifies listeners on every change (so rows update live),
/// but [onChanged] fires only once — when the gesture ends. Use [onChanged] to
/// sync with Bloc / Riverpod / Redux without dozens of updates per second.
class SwipeSelectController<K> extends ChangeNotifier {
  SwipeSelectController({Iterable<K>? initialSelection, this.onChanged, bool? selectionMode})
      : _selected = Set<K>.of(initialSelection ?? const []),
        _forcedSelectionMode = selectionMode;

  /// See [SelectionChangedCallback].
  SelectionChangedCallback<K>? onChanged;

  Set<K> _selected;
  bool? _forcedSelectionMode;
  bool _isDragging = false;

  /// Current selection as an unmodifiable view — no copying, cheap to read in `build`.
  /// The underlying set is replaced (never mutated) on every change, so a view you
  /// kept stays a stable snapshot.
  Set<K> get selected => UnmodifiableSetView<K>(_selected);

  int get selectedCount => _selected.length;

  bool isSelected(K key) => _selected.contains(key);

  /// Selection mode: forced by [selectionMode], otherwise on while something is selected.
  bool get isSelectionMode => _forcedSelectionMode ?? _selected.isNotEmpty;

  /// Force selection mode on / off, or `null` to derive it from the selection.
  /// Use it when your app has a "Select" button.
  bool? get selectionMode => _forcedSelectionMode;
  set selectionMode(bool? value) {
    if (_forcedSelectionMode == value) return;
    _forcedSelectionMode = value;
    notifyListeners();
  }

  /// A finger is dragging a selection right now.
  bool get isDragging => _isDragging;

  /// On-screen auto-scroll direction: -1 towards the start (top / left), 0, 1 towards the end.
  /// Listen to it to highlight the edge zone while the list auto-scrolls.
  ValueListenable<int> get autoScrollDirection => _autoScrollDirection;
  final ValueNotifier<int> _autoScrollDirection = ValueNotifier<int>(0);

  void toggle(K key) {
    final next = Set<K>.of(_selected);
    if (!next.remove(key)) next.add(key);
    _commit(next, SelectionChangeReason.toggle);
  }

  void select(Iterable<K> keys) => _commit({..._selected, ...keys}, SelectionChangeReason.api);

  void deselect(Iterable<K> keys) => _commit(Set<K>.of(_selected)..removeAll(keys), SelectionChangeReason.api);

  void setSelection(Iterable<K> keys) => _commit(Set<K>.of(keys), SelectionChangeReason.api);

  void clear() => _commit(<K>{}, SelectionChangeReason.api);

  /// Replaces the selection without calling [onChanged] — for syncing state that
  /// came from the outside (e.g. your store changed).
  void sync(Iterable<K> keys) {
    final next = Set<K>.of(keys);
    if (setEquals(next, _selected)) return;
    _selected = next;
    notifyListeners();
  }

  void _commit(Set<K> next, SelectionChangeReason reason) {
    if (setEquals(next, _selected)) return;
    _selected = next;
    notifyListeners();
    onChanged?.call(selected, reason);
  }

  // ---- used by SwipeSelect ----

  /// Gesture step: updates the selection and listeners, no [onChanged].
  void _update(Set<K> next) {
    if (identical(next, _selected)) return;
    _selected = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _autoScrollDirection.dispose();
    super.dispose();
  }

  void _setDragging(bool value) {
    if (_isDragging == value) return;
    _isDragging = value;
    notifyListeners();
  }

  /// Gesture ended: report once if anything changed.
  void _endGesture(Set<K> initial) {
    if (!setEquals(initial, _selected)) {
      onChanged?.call(selected, SelectionChangeReason.gesture);
    }
  }
}
