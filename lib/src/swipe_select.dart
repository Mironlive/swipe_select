import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'activation.dart';
import 'controller.dart';
import 'item.dart';
import 'range.dart';
import 'recognizer.dart';

/// Event for [SwipeSelect.onDragStart].
@immutable
class SwipeSelectDragStart<K> {
  const SwipeSelectDragStart(this.key, this.index, this.mode);
  final K key;
  final int index;
  final DragMode mode;
}

/// Event for [SwipeSelect.onItemEnter].
@immutable
class SwipeSelectItemEnter<K> {
  const SwipeSelectItemEnter(this.key, this.index, this.mode, {required this.isAutoScrolling});
  final K key;
  final int index;
  final DragMode mode;

  /// The list is auto-scrolling right now.
  final bool isAutoScrolling;
}

/// Event for [SwipeSelect.onDragEnd].
@immutable
class SwipeSelectDragEnd<K> {
  const SwipeSelectDragEnd(this.selected, this.mode);
  final Set<K> selected;
  final DragMode mode;
}

/// Swipe to multi-select for lists and grids.
///
/// Wrap your scroll view and wrap every item with [SwipeSelectItem]:
///
/// ```dart
/// SwipeSelect<String>(
///   controller: controller,
///   itemCount: mails.length,
///   keyForIndex: (i) => mails[i].id,
///   child: ListView.builder(
///     itemCount: mails.length,
///     itemBuilder: (context, i) => SwipeSelectItem(
///       index: i,
///       builder: (context, selected) => MailRow(mail: mails[i], selected: selected),
///     ),
///   ),
/// )
/// ```
///
/// Works with `ListView`, `GridView`, `CustomScrollView` with slivers, `reverse: true`
/// (chats) and horizontal lists. Items can have any size.
class SwipeSelect<K> extends StatefulWidget {
  const SwipeSelect({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.keyForIndex,
    required this.child,
    this.activation = const [SwipeSelectActivation.edge()],
    this.isSelectable,
    this.autoScroll = const SwipeSelectAutoScroll(),
    this.enabled = true,
    this.onDragStart,
    this.onItemEnter,
    this.onDragEnd,
  });

  final SwipeSelectController<K> controller;

  /// Number of items in the list — the same as your builder's `itemCount`.
  final int itemCount;

  /// Stable key of the item at [index] (usually its id). The selection holds keys,
  /// so it survives pagination, sorting and new items.
  final K Function(int index) keyForIndex;

  /// The scroll view. Every item inside must be wrapped with [SwipeSelectItem].
  final Widget child;

  /// How the gesture starts. Several activations can be combined, e.g.
  /// `[SwipeSelectActivation.longPress(when: ActivationWhen.idle), SwipeSelectActivation.edge()]`.
  final List<SwipeSelectActivation> activation;

  /// Whether the item at [index] can be selected. Non-selectable items are skipped.
  final bool Function(int index)? isSelectable;

  final SwipeSelectAutoScroll autoScroll;

  /// Turn the gesture off entirely.
  final bool enabled;

  final ValueChanged<SwipeSelectDragStart<K>>? onDragStart;

  /// The finger moved onto a new item. Handy for haptics.
  final ValueChanged<SwipeSelectItemEnter<K>>? onItemEnter;
  final ValueChanged<SwipeSelectDragEnd<K>>? onDragEnd;

  @override
  State<SwipeSelect<K>> createState() => _SwipeSelectState<K>();
}

class _DragSession<K> {
  _DragSession({required this.initial, required this.mode, required this.anchorIndex, required this.anchorKey})
    : hoverIndex = anchorIndex,
      hoverKey = anchorKey;

  final Set<K> initial;
  final DragMode mode;
  int anchorIndex;
  final K anchorKey;
  int hoverIndex;
  K hoverKey;
  IndexRange? range;

  /// Keys inside [range] — used to restore them if the data changes mid-gesture.
  Set<K> rangeKeys = <K>{};
}

class _SwipeSelectState<K> extends State<SwipeSelect<K>>
    with SingleTickerProviderStateMixin
    implements SwipeSelectRegistry {
  final Set<RenderSwipeSelectItem> _items = <RenderSwipeSelectItem>{};
  ScrollableState? _scrollable;
  _DragSession<K>? _drag;
  Offset? _pointer;

  late final Ticker _ticker;
  Duration? _lastTick;
  int _autoDirection = 0; // visual: -1 towards the start (top / left), 1 towards the end

  // ---------------- registry ----------------

  @override
  void registerItem(RenderSwipeSelectItem item) => _items.add(item);

  @override
  void unregisterItem(RenderSwipeSelectItem item) => _items.remove(item);

  @override
  void reportScrollable(ScrollableState? scrollable) {
    if (scrollable != null) _scrollable = scrollable;
  }

  @override
  bool isIndexSelected(int index) {
    if (index < 0 || index >= widget.itemCount) return false;
    return widget.controller.internalSelection.contains(widget.keyForIndex(index));
  }

  @override
  Listenable get selectionListenable => widget.controller;

  // ---------------- lifecycle ----------------

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void didUpdateWidget(SwipeSelect<K> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final drag = _drag;
    if (drag != null) _remapAfterDataChange(drag);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ---------------- geometry ----------------

  ScrollPosition? get _position {
    final scrollable = _scrollable;
    if (scrollable == null || !scrollable.mounted) return null;
    return scrollable.position;
  }

  Axis get _axis => _position?.axis ?? Axis.vertical;

  Rect? get _viewportRect {
    final box = _scrollable?.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Item under [global], or the nearest one when the finger is in a gap
  /// (separator, padding) or beyond the first / last item.
  RenderSwipeSelectItem? _hitTest(Offset global) {
    final vertical = _axis == Axis.vertical;
    RenderSwipeSelectItem? best;
    var bestScore = double.infinity;
    for (final item in _items) {
      final rect = item.globalRect;
      if (rect == null || item.index < 0 || item.index >= widget.itemCount) continue;
      if (rect.contains(global)) return item;
      final mainDist = vertical ? _gap(global.dy, rect.top, rect.bottom) : _gap(global.dx, rect.left, rect.right);
      final crossDist = vertical ? _gap(global.dx, rect.left, rect.right) : _gap(global.dy, rect.top, rect.bottom);
      // Main axis wins: a gap between rows is resolved by row, not by column.
      final score = mainDist * 1000 + crossDist;
      if (score < bestScore) {
        bestScore = score;
        best = item;
      }
    }
    return best;
  }

  static double _gap(double v, double a, double b) => v < a ? a - v : (v > b ? v - b : 0);

  // ---------------- activation ----------------

  bool _canStart(SwipeSelectActivation activation, Offset global) {
    if (!widget.enabled || widget.itemCount == 0) return false;
    final mode = widget.controller.isSelectionMode;
    switch (activation.when) {
      case ActivationWhen.selectionMode:
        if (!mode) return false;
      case ActivationWhen.idle:
        if (mode) return false;
      case ActivationWhen.always:
        break;
    }
    if (activation is EdgeActivation) {
      final viewport = _viewportRect;
      if (viewport == null || !viewport.contains(global)) return false;
      if (_axis == Axis.vertical) {
        final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
        final atLeft = (activation.side == EdgeSide.start) != rtl;
        return atLeft ? global.dx - viewport.left <= activation.size : viewport.right - global.dx <= activation.size;
      }
      return activation.side == EdgeSide.start
          ? global.dy - viewport.top <= activation.size
          : viewport.bottom - global.dy <= activation.size;
    }
    return true;
  }

  // ---------------- gesture ----------------

  bool _selectable(int index) => widget.isSelectable?.call(index) ?? true;

  void _onStart(Offset anchor, Offset current, SwipeSelectActivation activation) {
    _pointer = current;
    final item = _hitTest(anchor);
    if (item == null || !_selectable(item.index)) return;
    final index = item.index;
    final key = widget.keyForIndex(index);
    final controller = widget.controller;
    final mode = controller.isSelected(key) ? DragMode.deselect : DragMode.select;

    _drag = _DragSession<K>(
      initial: Set<K>.of(controller.internalSelection),
      mode: mode,
      anchorIndex: index,
      anchorKey: key,
    );
    _applyRange(index, index);
    controller.internalSetDragging(true);
    widget.onDragStart?.call(SwipeSelectDragStart<K>(key, index, mode));
    _updateHover(isAutoScrolling: false);
    _updateAutoScroll();
  }

  void _onUpdate(Offset global) {
    _pointer = global;
    if (_drag == null) return;
    _updateHover(isAutoScrolling: false);
    _updateAutoScroll();
  }

  void _onEnd() {
    _stopAutoScroll();
    final drag = _drag;
    _drag = null;
    _pointer = null;
    final controller = widget.controller;
    controller.internalSetDragging(false);
    if (drag == null) return;
    controller.internalEndGesture(drag.initial);
    widget.onDragEnd?.call(SwipeSelectDragEnd<K>(controller.selected, drag.mode));
  }

  void _updateHover({required bool isAutoScrolling}) {
    final drag = _drag;
    final pointer = _pointer;
    if (drag == null || pointer == null) return;
    final item = _hitTest(pointer);
    if (item == null) return;
    final index = item.index;
    final start = index < drag.anchorIndex ? index : drag.anchorIndex;
    final end = index > drag.anchorIndex ? index : drag.anchorIndex;
    final changedRange = drag.range != IndexRange(start, end);
    final changedHover = index != drag.hoverIndex;
    if (!changedRange && !changedHover) return;

    if (changedRange) _applyRange(start, end);
    if (changedHover) {
      drag.hoverIndex = index;
      final key = widget.keyForIndex(index);
      drag.hoverKey = key;
      widget.onItemEnter?.call(SwipeSelectItemEnter<K>(key, index, drag.mode, isAutoScrolling: isAutoScrolling));
    }
  }

  void _applyRange(int start, int end) {
    final drag = _drag!;
    final next = IndexRange(start, end);
    final count = widget.itemCount;
    final result = applyRangeTransition<K>(
      initial: drag.initial,
      current: widget.controller.internalSelection,
      previousRange: drag.range,
      nextRange: next,
      shouldSelect: drag.mode == DragMode.select,
      keyForIndex: (i) => i >= 0 && i < count ? widget.keyForIndex(i) : null,
      isSelectable: widget.isSelectable,
    );
    drag.range = next;
    drag.rangeKeys = {
      for (var i = start; i <= end; i++)
        if (i >= 0 && i < count) widget.keyForIndex(i),
    };
    if (result.changed) widget.controller.internalUpdate(result.next);
  }

  /// Data changed mid-gesture: indices shifted, remap anchor and range by key.
  void _remapAfterDataChange(_DragSession<K> drag) {
    final count = widget.itemCount;
    if (drag.anchorIndex < count && widget.keyForIndex(drag.anchorIndex) == drag.anchorKey) return;

    int indexOf(K key) {
      for (var i = 0; i < count; i++) {
        if (widget.keyForIndex(i) == key) return i;
      }
      return -1;
    }

    final anchor = indexOf(drag.anchorKey);
    if (anchor == -1) {
      // The anchor item is gone — nothing to extend the range from.
      _onEnd();
      return;
    }
    final hoverFound = indexOf(drag.hoverKey);
    final hover = hoverFound == -1 ? anchor : hoverFound;

    // Restore what the old range touched (by key), then apply the new range.
    final next = Set<K>.of(widget.controller.internalSelection);
    for (final key in drag.rangeKeys) {
      if (drag.initial.contains(key)) {
        next.add(key);
      } else {
        next.remove(key);
      }
    }
    widget.controller.internalUpdate(next);
    drag
      ..anchorIndex = anchor
      ..hoverIndex = hover
      ..range = null;
    _applyRange(anchor < hover ? anchor : hover, anchor > hover ? anchor : hover);
  }

  // ---------------- auto-scroll ----------------

  void _updateAutoScroll() {
    final config = widget.autoScroll;
    final viewport = _viewportRect;
    final pointer = _pointer;
    if (!config.enabled || viewport == null || pointer == null || _drag == null) {
      _stopAutoScroll();
      return;
    }
    final vertical = _axis == Axis.vertical;
    final local = vertical ? pointer.dy - viewport.top : pointer.dx - viewport.left;
    final size = vertical ? viewport.height : viewport.width;
    final direction = local < config.edgeSize ? -1 : (local > size - config.edgeSize ? 1 : 0);
    _autoDirection = direction;
    if (direction == 0) {
      _stopAutoScroll();
    } else if (!_ticker.isActive) {
      _lastTick = null;
      _ticker.start();
    }
  }

  void _stopAutoScroll() {
    _autoDirection = 0;
    if (_ticker.isActive) _ticker.stop();
    _lastTick = null;
  }

  void _onTick(Duration elapsed) {
    final position = _position;
    final viewport = _viewportRect;
    final pointer = _pointer;
    final config = widget.autoScroll;
    if (position == null || viewport == null || pointer == null || _drag == null || _autoDirection == 0) {
      _stopAutoScroll();
      return;
    }
    final last = _lastTick;
    _lastTick = elapsed;
    if (last == null) return;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    if (dt <= 0) return;

    final vertical = _axis == Axis.vertical;
    final local = vertical ? pointer.dy - viewport.top : pointer.dx - viewport.left;
    final size = vertical ? viewport.height : viewport.width;
    final depth = _autoDirection < 0 ? config.edgeSize - local : local - (size - config.edgeSize);
    final ratio = (depth / config.edgeSize).clamp(0.0, 1.0);
    final speed = config.minSpeed + (config.maxSpeed - config.minSpeed) * ratio;

    // Visual direction → scroll offset direction. Reversed lists (chats) and
    // RTL horizontal lists grow their offset towards the visual start.
    final reversed = position.axisDirection == AxisDirection.up || position.axisDirection == AxisDirection.left;
    final delta = (reversed ? -_autoDirection : _autoDirection) * speed * dt.clamp(0.0, 0.05);
    final target = (position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target == position.pixels) return;
    position.jumpTo(target);

    // New items get laid out this frame — re-check what's under the finger afterwards.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateHover(isAutoScrolling: true);
    });
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    return SwipeSelectScope(
      registry: this,
      child: RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        gestures: <Type, GestureRecognizerFactory>{
          SwipeSelectGestureRecognizer: GestureRecognizerFactoryWithHandlers<SwipeSelectGestureRecognizer>(
            () => SwipeSelectGestureRecognizer(debugOwner: this),
            (recognizer) {
              recognizer
                ..activations = widget.activation
                ..canStart = _canStart
                ..mainAxis = (() => _axis)
                ..onStart = _onStart
                ..onUpdate = _onUpdate
                ..onEnd = _onEnd;
            },
          ),
        },
        child: widget.child,
      ),
    );
  }
}
