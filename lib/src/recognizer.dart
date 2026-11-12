import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'activation.dart';

/// Edge strip activates after this much movement: less than the scroll slop
/// (so it wins over scrolling) but more than a tap jitter (so taps still reach
/// your own buttons inside the strip).
const double kSwipeSelectEdgeSlop = 4;

/// One recognizer for all activations of a [SwipeSelect].
///
/// It competes with the list's own drag recognizer in the gesture arena:
/// - edge: claims the pointer after [kSwipeSelectEdgeSlop] px of movement inside the strip;
/// - long press: claims it after the hold duration, if the finger stayed put;
/// - pan: claims it when the finger moves across the list before moving along it.
class SwipeSelectGestureRecognizer extends OneSequenceGestureRecognizer {
  SwipeSelectGestureRecognizer({super.debugOwner});

  List<SwipeSelectActivation> activations = const [];

  /// Whether [activation] may start for a touch at [globalPosition].
  bool Function(SwipeSelectActivation activation, Offset globalPosition)? canStart;

  /// Scroll axis of the list.
  Axis Function()? mainAxis;

  /// The gesture won the arena. [anchor] is where the selection starts.
  void Function(Offset anchor, Offset current, SwipeSelectActivation activation)? onStart;
  void Function(Offset globalPosition)? onUpdate;
  VoidCallback? onEnd;

  int? _pointer;
  Offset? _down;
  Offset? _last;
  Timer? _longPressTimer;
  final List<SwipeSelectActivation> _candidates = [];
  SwipeSelectActivation? _winner;
  bool _started = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null) return; // single finger only
    _candidates
      ..clear()
      ..addAll(activations.where((a) => canStart?.call(a, event.position) ?? false));
    if (_candidates.isEmpty) return;

    super.addAllowedPointer(event);
    _pointer = event.pointer;
    _down = event.position;
    _last = event.position;
    _winner = null;
    _started = false;

    final longPress = _candidates.whereType<LongPressActivation>().firstOrNull;
    if (longPress != null) {
      _longPressTimer = Timer(longPress.duration, () {
        if (_winner == null && _candidates.contains(longPress)) _claim(longPress);
      });
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;

    if (event is PointerMoveEvent) {
      _last = event.position;
      if (_started) {
        onUpdate?.call(event.position);
      } else if (_winner == null) {
        _evaluateMove(event.position);
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (_started) {
        _started = false;
        onEnd?.call();
      } else {
        resolve(GestureDisposition.rejected);
      }
      stopTrackingPointer(event.pointer);
    }
  }

  void _evaluateMove(Offset position) {
    final delta = position - _down!;
    final vertical = (mainAxis?.call() ?? Axis.vertical) == Axis.vertical;
    final along = vertical ? delta.dy.abs() : delta.dx.abs();
    final across = vertical ? delta.dx.abs() : delta.dy.abs();

    for (final activation in List.of(_candidates)) {
      switch (activation) {
        case EdgeActivation():
          if (delta.distance >= kSwipeSelectEdgeSlop) {
            _claim(activation);
            return;
          }
        case PanActivation(:final distance):
          if (across >= distance && across > along) {
            _claim(activation);
            return;
          }
          if (along > kTouchSlop) _candidates.remove(activation);
        case LongPressActivation():
          if (delta.distance > kTouchSlop) {
            _candidates.remove(activation);
            _longPressTimer?.cancel();
          }
      }
    }

    if (_candidates.isEmpty) {
      resolve(GestureDisposition.rejected);
      if (_pointer != null) stopTrackingPointer(_pointer!);
    }
  }

  void _claim(SwipeSelectActivation activation) {
    _winner = activation;
    _longPressTimer?.cancel();
    resolve(GestureDisposition.accepted);
  }

  @override
  void acceptGesture(int pointer) {
    super.acceptGesture(pointer);
    final winner = _winner;
    if (winner == null || _started) return;
    _started = true;
    final anchor = winner is LongPressActivation ? _last! : _down!;
    onStart?.call(anchor, _last!, winner);
  }

  @override
  void rejectGesture(int pointer) {
    super.rejectGesture(pointer);
    _longPressTimer?.cancel();
    if (_started) {
      _started = false;
      onEnd?.call();
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _longPressTimer?.cancel();
    _pointer = null;
    _down = null;
    _last = null;
    _winner = null;
    _candidates.clear();
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  String get debugDescription => 'swipe select';
}
