import 'package:flutter/foundation.dart';

/// When an activation is available.
enum ActivationWhen {
  /// Always.
  always,

  /// Only in selection mode (something is selected, or selection mode is forced on).
  selectionMode,

  /// Only outside selection mode. Handy to let a long press enter the mode
  /// and the edge strip take over afterwards.
  idle,
}

/// Which edge of the list the selection strip is on.
enum EdgeSide { start, end }

/// How a selection gesture starts. Combine several in a list.
@immutable
sealed class SwipeSelectActivation {
  const SwipeSelectActivation({required this.when});

  /// When this activation is available.
  final ActivationWhen when;

  /// A strip along the edge of the list (like mail apps). Dragging inside the strip
  /// selects; outside of it the list scrolls as usual. Starts after the finger
  /// moves a few pixels, so taps inside the strip still reach your own buttons.
  const factory SwipeSelectActivation.edge({EdgeSide side, double size, ActivationWhen when}) = EdgeActivation;

  /// Long press anywhere on an item (like Photos or Gmail). Until the finger is held,
  /// the list scrolls as usual.
  const factory SwipeSelectActivation.longPress({Duration duration, ActivationWhen when}) = LongPressActivation;

  /// Swipe across the list (like iOS Photos in select mode): moving along the list
  /// scrolls, moving across it selects.
  const factory SwipeSelectActivation.pan({double distance, ActivationWhen when}) = PanActivation;
}

/// See [SwipeSelectActivation.edge].
final class EdgeActivation extends SwipeSelectActivation {
  const EdgeActivation({this.side = EdgeSide.start, this.size = 56, super.when = ActivationWhen.selectionMode});

  /// [EdgeSide.start] is the left edge (right in RTL), [EdgeSide.end] the other one.
  /// For horizontal lists the strip runs along the top / bottom edge.
  final EdgeSide side;

  /// Strip width (height for horizontal lists), logical pixels.
  final double size;
}

/// See [SwipeSelectActivation.longPress].
final class LongPressActivation extends SwipeSelectActivation {
  const LongPressActivation({this.duration = const Duration(milliseconds: 300), super.when = ActivationWhen.always});

  final Duration duration;
}

/// See [SwipeSelectActivation.pan].
final class PanActivation extends SwipeSelectActivation {
  const PanActivation({this.distance = 10, super.when = ActivationWhen.selectionMode});

  /// How far the finger must move across the list to start, logical pixels.
  final double distance;
}

/// Auto-scroll near the edges of the list.
@immutable
class SwipeSelectAutoScroll {
  const SwipeSelectAutoScroll({this.enabled = true, this.edgeSize = 60, this.minSpeed = 120, this.maxSpeed = 900});

  /// No auto-scroll.
  static const SwipeSelectAutoScroll disabled = SwipeSelectAutoScroll(enabled: false);

  final bool enabled;

  /// Size of the zone near the edge that triggers auto-scroll, logical pixels.
  final double edgeSize;

  /// Speed at the inner border of the zone, logical pixels per second.
  final double minSpeed;

  /// Speed at the very edge, logical pixels per second.
  final double maxSpeed;
}

/// What the current gesture does.
enum DragMode { select, deselect }

/// Where a selection change came from.
enum SelectionChangeReason { gesture, toggle, api }
