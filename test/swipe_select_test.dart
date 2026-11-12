import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_select/swipe_select.dart';

/// Rows with different heights: 60, 90, 120, 60, 90, 120, …
double heightOf(int i) => 60.0 + (i % 3) * 30;
double topOf(int i) {
  var y = 0.0;
  for (var k = 0; k < i; k++) {
    y += heightOf(k);
  }
  return y;
}

class Harness extends StatefulWidget {
  const Harness({
    super.key,
    required this.controller,
    this.count = 200,
    this.activation = const [SwipeSelectActivation.edge()],
    this.isSelectable,
    this.reverse = false,
    this.onTapCheckbox,
    this.ids,
  });

  final SwipeSelectController<String> controller;
  final int count;
  final List<SwipeSelectActivation> activation;
  final bool Function(int)? isSelectable;
  final bool reverse;
  final void Function(String id)? onTapCheckbox;
  final List<String>? ids;

  @override
  State<Harness> createState() => HarnessState();
}

class HarnessState extends State<Harness> {
  late List<String> ids = widget.ids ?? List.generate(widget.count, (i) => 'id$i');

  void prepend(String id) => setState(() => ids = [id, ...ids]);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SwipeSelect<String>(
          controller: widget.controller,
          itemCount: ids.length,
          keyForIndex: (i) => ids[i],
          activation: widget.activation,
          isSelectable: widget.isSelectable,
          child: ListView.builder(
            reverse: widget.reverse,
            itemCount: ids.length,
            itemBuilder: (context, i) => SwipeSelectItem(
              index: i,
              builder: (context, selected) => SizedBox(
                key: ValueKey(ids[i]),
                height: heightOf(i),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => widget.onTapCheckbox?.call(ids[i]),
                      child: SizedBox(width: 56, height: heightOf(i), child: Text(selected ? 'x' : 'o')),
                    ),
                    Expanded(child: Text(ids[i])),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Drags with fine-grained moves, like a real finger.
Future<TestGesture> dragPath(WidgetTester tester, List<Offset> points, {Duration hold = Duration.zero}) async {
  final g = await tester.startGesture(points.first, kind: PointerDeviceKind.touch);
  if (hold > Duration.zero) await tester.pump(hold);
  for (var i = 1; i < points.length; i++) {
    final from = points[i - 1];
    final to = points[i];
    final steps = ((to - from).distance / 6).ceil().clamp(1, 1000);
    for (var s = 1; s <= steps; s++) {
      await g.moveTo(Offset.lerp(from, to, s / steps)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
  return g;
}

Offset rowCenter(int i, {double x = 28}) => Offset(x, topOf(i) + heightOf(i) / 2);

void main() {
  testWidgets('edge drag selects a range of rows with different heights', (tester) async {
    final c = SwipeSelectController<String>(initialSelection: {'id0'});
    await tester.pumpWidget(Harness(controller: c));
    final g = await dragPath(tester, [rowCenter(1), rowCenter(5)]);
    await g.up();
    await tester.pump();
    expect(c.selected, {'id0', 'id1', 'id2', 'id3', 'id4', 'id5'});
  });

  testWidgets('edge strip is inactive outside selection mode', (tester) async {
    final c = SwipeSelectController<String>();
    await tester.pumpWidget(Harness(controller: c));
    final g = await dragPath(tester, [rowCenter(1), rowCenter(5)]);
    await g.up();
    await tester.pump();
    expect(c.selected, isEmpty);
  });

  testWidgets('a tap in the strip goes to your own button, no double toggle', (tester) async {
    final c = SwipeSelectController<String>(initialSelection: {'id0'});
    await tester.pumpWidget(Harness(controller: c, onTapCheckbox: c.toggle));
    await tester.tapAt(rowCenter(2));
    await tester.pump();
    expect(c.selected, {'id0', 'id2'});
    await tester.tapAt(rowCenter(2));
    await tester.pump();
    expect(c.selected, {'id0'});
  });

  testWidgets('dragging outside the strip scrolls instead of selecting', (tester) async {
    final c = SwipeSelectController<String>(initialSelection: {'id0'});
    await tester.pumpWidget(Harness(controller: c));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(c.selected, {'id0'});
    final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(position.pixels, greaterThan(100));
  });

  testWidgets('moving back restores the selection from gesture start', (tester) async {
    final c = SwipeSelectController<String>(initialSelection: {'id0', 'id4'});
    await tester.pumpWidget(Harness(controller: c));
    final g = await dragPath(tester, [rowCenter(1), rowCenter(6), rowCenter(2)]);
    await g.up();
    await tester.pump();
    expect(c.selected, {'id0', 'id1', 'id2', 'id4'});
  });

  testWidgets('starting on a selected row deselects', (tester) async {
    final c = SwipeSelectController<String>(initialSelection: {'id1', 'id2', 'id3', 'id4'});
    await tester.pumpWidget(Harness(controller: c));
    final g = await dragPath(tester, [rowCenter(2), rowCenter(4)]);
    await g.up();
    await tester.pump();
    expect(c.selected, {'id1'});
  });

  testWidgets('non-selectable rows are skipped', (tester) async {
    final c = SwipeSelectController<String>(initialSelection: {'id0'});
    await tester.pumpWidget(Harness(controller: c, isSelectable: (i) => i != 3));
    final g = await dragPath(tester, [rowCenter(1), rowCenter(5)]);
    await g.up();
    await tester.pump();
    expect(c.selected, {'id0', 'id1', 'id2', 'id4', 'id5'});
  });

  testWidgets('onChanged fires once per gesture', (tester) async {
    final calls = <Set<String>>[];
    final c = SwipeSelectController<String>(initialSelection: {'id0'}, onChanged: (s, r) => calls.add(s));
    await tester.pumpWidget(Harness(controller: c));
    final g = await dragPath(tester, [rowCenter(1), rowCenter(6)]);
    expect(calls, isEmpty);
    await g.up();
    await tester.pump();
    expect(calls.length, 1);
    expect(calls.single.length, 7);
  });

  testWidgets('long press anywhere enters selection mode, then the drag extends it', (tester) async {
    final c = SwipeSelectController<String>();
    await tester.pumpWidget(Harness(controller: c, activation: const [SwipeSelectActivation.longPress()]));
    final g = await dragPath(tester, [
      rowCenter(2, x: 200),
      rowCenter(4, x: 200),
    ], hold: const Duration(milliseconds: 400));
    await g.up();
    await tester.pump();
    expect(c.selected, {'id2', 'id3', 'id4'});
  });

  testWidgets('a quick swipe does not trigger long press — the list scrolls', (tester) async {
    final c = SwipeSelectController<String>();
    await tester.pumpWidget(Harness(controller: c, activation: const [SwipeSelectActivation.longPress()]));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(c.selected, isEmpty);
  });

  testWidgets('long press when idle + edge strip in selection mode', (tester) async {
    final c = SwipeSelectController<String>();
    await tester.pumpWidget(
      Harness(
        controller: c,
        activation: const [
          SwipeSelectActivation.longPress(when: ActivationWhen.idle),
          SwipeSelectActivation.edge(),
        ],
      ),
    );
    final g1 = await dragPath(tester, [rowCenter(1, x: 200)], hold: const Duration(milliseconds: 400));
    await g1.up();
    await tester.pump();
    expect(c.selected, {'id1'});
    final g2 = await dragPath(tester, [rowCenter(2), rowCenter(4)]);
    await g2.up();
    await tester.pump();
    expect(c.selected, {'id1', 'id2', 'id3', 'id4'});
  });

  testWidgets('auto-scroll near the bottom edge keeps selecting', (tester) async {
    final c = SwipeSelectController<String>(initialSelection: {'id0'});
    await tester.pumpWidget(Harness(controller: c));
    final bottom = tester.getSize(find.byType(ListView)).height - 10;
    final g = await dragPath(tester, [rowCenter(1), Offset(28, bottom)]);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump();
    final count = c.selectedCount;
    expect(count, greaterThan(12));
    // Contiguous from id0.
    for (var i = 0; i < count; i++) {
      expect(c.isSelected('id$i'), isTrue, reason: 'id$i');
    }
  });

  testWidgets('reverse (chat) list: dragging up selects older items with auto-scroll', (tester) async {
    final c = SwipeSelectController<String>();
    await tester.pumpWidget(
      Harness(controller: c, reverse: true, activation: const [SwipeSelectActivation.longPress()]),
    );
    final h = tester.getSize(find.byType(ListView)).height;
    final first = tester.getCenter(find.byKey(const ValueKey('id1')));
    final g = await dragPath(tester, [
      Offset(200, first.dy),
      const Offset(200, 8),
    ], hold: const Duration(milliseconds: 400));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump();
    expect(h, greaterThan(0));
    expect(c.selectedCount, greaterThan(8));
    for (var i = 1; i <= c.selectedCount; i++) {
      expect(c.isSelected('id$i'), isTrue, reason: 'id$i');
    }
  });

  testWidgets('data prepended mid-gesture: the range follows the keys', (tester) async {
    final c = SwipeSelectController<String>(initialSelection: {'id0'});
    final key = GlobalKey<HarnessState>();
    await tester.pumpWidget(Harness(key: key, controller: c));
    final g = await dragPath(tester, [rowCenter(1), rowCenter(3)]);
    key.currentState!.prepend('new');
    await tester.pump();
    await g.up();
    await tester.pump();
    expect(c.isSelected('new'), isFalse);
    expect(c.isSelected('id1'), isTrue);
    expect(c.isSelected('id0'), isTrue);
  });

  testWidgets('grid: pan across selects linearly by index', (tester) async {
    final c = SwipeSelectController<String>(selectionMode: true);
    final ids = List.generate(100, (i) => 'p$i');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeSelect<String>(
            controller: c,
            itemCount: ids.length,
            keyForIndex: (i) => ids[i],
            activation: const [SwipeSelectActivation.pan()],
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
              itemCount: ids.length,
              itemBuilder: (context, i) => SwipeSelectItem(
                index: i,
                child: ColoredBox(color: Colors.blue, child: Text(ids[i])),
              ),
            ),
          ),
        ),
      ),
    );
    final cell = tester.getSize(find.byType(SwipeSelectItem).first).width;
    final g = await dragPath(tester, [
      Offset(cell / 2, cell / 2),
      Offset(cell * 3.5, cell / 2),
      Offset(cell * 1.5, cell * 1.5),
    ]);
    await g.up();
    await tester.pump();
    expect(c.selected, {for (var i = 0; i <= 5; i++) 'p$i'});
  });

  testWidgets('horizontal list with long press', (tester) async {
    final c = SwipeSelectController<String>();
    final ids = List.generate(50, (i) => 'h$i');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 120,
            child: SwipeSelect<String>(
              controller: c,
              itemCount: ids.length,
              keyForIndex: (i) => ids[i],
              activation: const [SwipeSelectActivation.longPress()],
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: ids.length,
                itemBuilder: (context, i) => SwipeSelectItem(
                  index: i,
                  child: SizedBox(width: 70.0 + (i % 3) * 30, child: Text(ids[i])),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final a = tester.getCenter(find.text('h0'));
    final b = tester.getCenter(find.text('h3'));
    final g = await dragPath(tester, [a, b], hold: const Duration(milliseconds: 400));
    await g.up();
    await tester.pump();
    expect(c.selected, {'h0', 'h1', 'h2', 'h3'});
  });

  testWidgets('SwipeSelectItem.builder rebuilds only rows whose selection changed', (tester) async {
    final c = SwipeSelectController<String>();
    final builds = <int, int>{};
    await tester.pumpWidget(
      MaterialApp(
        home: SwipeSelect<String>(
          controller: c,
          itemCount: 30,
          keyForIndex: (i) => 'r$i',
          child: ListView.builder(
            itemCount: 30,
            itemBuilder: (context, i) => SwipeSelectItem(
              index: i,
              builder: (context, selected) {
                builds[i] = (builds[i] ?? 0) + 1;
                return SizedBox(height: 50, child: Text('r$i $selected'));
              },
            ),
          ),
        ),
      ),
    );
    builds.clear();
    c.toggle('r3');
    await tester.pump();
    expect(builds.keys, [3]);
  });
}
