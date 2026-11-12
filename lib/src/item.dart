import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Internal bridge between [SwipeSelect] and its items.
abstract class SwipeSelectRegistry {
  void registerItem(RenderSwipeSelectItem item);
  void unregisterItem(RenderSwipeSelectItem item);
  void reportScrollable(ScrollableState? scrollable);

  /// Selection state for an index, and a listenable that fires on selection changes.
  bool isIndexSelected(int index);
  Listenable get selectionListenable;
}

/// Makes [SwipeSelect]'s registry available to items.
class SwipeSelectScope extends InheritedWidget {
  const SwipeSelectScope({super.key, required this.registry, required super.child});

  final SwipeSelectRegistry registry;

  static SwipeSelectRegistry? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SwipeSelectScope>()?.registry;

  @override
  bool updateShouldNotify(SwipeSelectScope oldWidget) => oldWidget.registry != registry;
}

/// Wrap every list item with it — this is how [SwipeSelect] knows where items are.
///
/// ```dart
/// itemBuilder: (context, index) => SwipeSelectItem(
///   index: index,
///   builder: (context, selected) => MailRow(mail: mails[index], selected: selected),
/// ),
/// ```
///
/// With [builder], only the rows whose selection actually changed rebuild — not the
/// whole list. Use [child] if you rebuild rows yourself.
class SwipeSelectItem extends StatefulWidget {
  const SwipeSelectItem({super.key, required this.index, this.child, this.builder})
      : assert(child != null || builder != null, 'Pass child or builder');

  /// The item's index — the same one your list builder received.
  final int index;
  final Widget? child;
  final Widget Function(BuildContext context, bool selected)? builder;

  @override
  State<SwipeSelectItem> createState() => _SwipeSelectItemState();
}

class _SwipeSelectItemState extends State<SwipeSelectItem> {
  SwipeSelectRegistry? _registry;
  bool _selected = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = SwipeSelectScope.maybeOf(context);
    assert(registry != null, 'SwipeSelectItem must be placed under a SwipeSelect widget.');
    if (registry != _registry) {
      _registry?.selectionListenable.removeListener(_onSelectionChanged);
      _registry = registry;
      if (widget.builder != null) registry?.selectionListenable.addListener(_onSelectionChanged);
    }
    registry?.reportScrollable(Scrollable.maybeOf(context));
    _selected = registry?.isIndexSelected(widget.index) ?? false;
  }

  @override
  void didUpdateWidget(SwipeSelectItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.builder == null) != (widget.builder == null)) {
      _registry?.selectionListenable.removeListener(_onSelectionChanged);
      if (widget.builder != null) _registry?.selectionListenable.addListener(_onSelectionChanged);
    }
    _selected = _registry?.isIndexSelected(widget.index) ?? false;
  }

  void _onSelectionChanged() {
    final selected = _registry?.isIndexSelected(widget.index) ?? false;
    if (selected != _selected && mounted) {
      setState(() => _selected = selected);
    }
  }

  @override
  void dispose() {
    _registry?.selectionListenable.removeListener(_onSelectionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registry = _registry;
    final child = widget.builder != null ? widget.builder!(context, _selected) : widget.child!;
    if (registry == null) return child;
    return _SwipeSelectItemMarker(index: widget.index, registry: registry, child: child);
  }
}

class _SwipeSelectItemMarker extends SingleChildRenderObjectWidget {
  const _SwipeSelectItemMarker({required this.index, required this.registry, super.child});

  final int index;
  final SwipeSelectRegistry registry;

  @override
  RenderSwipeSelectItem createRenderObject(BuildContext context) =>
      RenderSwipeSelectItem(index: index, registry: registry);

  @override
  void updateRenderObject(BuildContext context, RenderSwipeSelectItem renderObject) {
    renderObject
      ..index = index
      ..registry = registry;
  }
}

/// Render object of a [SwipeSelectItem]. Registers itself while attached.
class RenderSwipeSelectItem extends RenderProxyBox {
  RenderSwipeSelectItem({required this.index, required SwipeSelectRegistry registry}) : _registry = registry;

  int index;

  SwipeSelectRegistry _registry;
  set registry(SwipeSelectRegistry value) {
    if (identical(value, _registry)) return;
    if (attached) _registry.unregisterItem(this);
    _registry = value;
    if (attached) _registry.registerItem(this);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _registry.registerItem(this);
  }

  @override
  void detach() {
    _registry.unregisterItem(this);
    super.detach();
  }

  /// Item bounds in global coordinates, or null when not laid out / not painted.
  Rect? get globalRect {
    if (!attached || !hasSize) return null;
    final topLeft = localToGlobal(Offset.zero);
    final bottomRight = localToGlobal(size.bottomRight(Offset.zero));
    return Rect.fromPoints(topLeft, bottomRight);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('index', index));
  }
}
