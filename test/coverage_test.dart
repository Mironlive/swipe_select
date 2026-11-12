import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_select/swipe_select.dart';

const double rowH = 70;
const double width = 800; // default test surface is 800x600

Widget list({
  required SwipeSelectController<String> c,
  List<SwipeSelectActivation> activation = const [SwipeSelectActivation.edge()],
  TextDirection dir = TextDirection.ltr,
}) {
  return MaterialApp(
    home: Directionality(
      textDirection: dir,
      child: Scaffold(
        body: SwipeSelect<String>(
          controller: c,
          itemCount: 100,
          keyForIndex: (i) => 'id$i',
          activation: activation,
          child: ListView.builder(
            itemCount: 100,
            itemBuilder: (context, i) => SwipeSelectItem(index: i, child: SizedBox(height: rowH, child: Text('id$i'))),
          ),
        ),
      ),
    ),
  );
}

Future<void> drag(WidgetTester tester, List<Offset> pts, {Duration hold = Duration.zero}) async {
  final g = await tester.startGesture(pts.first, kind: PointerDeviceKind.touch);
  if (hold > Duration.zero) await tester.pump(hold);
  for (var i = 1; i < pts.length; i++) {
    final steps = ((pts[i] - pts[i - 1]).distance / 6).ceil().clamp(1, 1000);
    for (var s = 1; s <= steps; s++) {
      await g.moveTo(Offset.lerp(pts[i - 1], pts[i], s / steps)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
  await g.up();
  await tester.pump();
}

Offset row(int i, double x) => Offset(x, i * rowH + rowH / 2);

void main() {
  testWidgets('right edge strip (EdgeSide.end) selects; the left side does not', (tester) async {
    final c = SwipeSelectController<String>(initialSelection: {'id0'});
    await tester.pumpWidget(list(c: c, activation: const [SwipeSelectActivation.edge(side: EdgeSide.end)]));
    await drag(tester, [row(1, 20), row(4, 20)]);
    expect(c.selected, {'id0'}, reason: 'left side must not start the gesture');
    await drag(tester, [row(1, width - 20), row(4, width - 20)]);
    expect(c.selected, {'id0', 'id1', 'id2', 'id3', 'id4'});
  });

  testWidgets('RTL: EdgeSide.start is on the right', (tester) async {
    final c = SwipeSelectController<String>(initialSelection: {'id0'});
    await tester.pumpWidget(list(c: c, dir: TextDirection.rtl));
    await drag(tester, [row(1, 20), row(3, 20)]);
    expect(c.selected, {'id0'});
    await drag(tester, [row(1, width - 20), row(3, width - 20)]);
    expect(c.selected, {'id0', 'id1', 'id2', 'id3'});
  });

  testWidgets('CustomScrollView with a header and SliverList / SliverGrid', (tester) async {
    final c = SwipeSelectController<String>(selectionMode: true);
    final keys = [for (var i = 0; i < 10; i++) 'l$i', for (var i = 0; i < 40; i++) 'g$i'];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SwipeSelect<String>(
          controller: c,
          itemCount: keys.length,
          keyForIndex: (i) => keys[i],
          activation: const [SwipeSelectActivation.longPress()],
          child: CustomScrollView(slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 100, child: Text('header'))),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => SwipeSelectItem(index: i, child: SizedBox(height: 30, child: Text(keys[i]))),
                childCount: 10,
              ),
            ),
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
              delegate: SliverChildBuilderDelegate(
                (context, i) => SwipeSelectItem(index: 10 + i, child: Text(keys[10 + i])),
                childCount: 40,
              ),
            ),
          ]),
        ),
      ),
    ));
    // List rows start after the 100 px header.
    await drag(tester, [const Offset(300, 100 + 15 + 30), const Offset(300, 100 + 15 + 90)],
        hold: const Duration(milliseconds: 400));
    expect(c.selected, {'l1', 'l2', 'l3'});
    // Across the list → grid boundary: last list row to the first grid cell.
    c.clear();
    final firstCell = tester.getCenter(find.text('g0'));
    await drag(tester, [const Offset(300, 100 + 9 * 30 + 15), firstCell], hold: const Duration(milliseconds: 400));
    expect(c.selected, {'l9', 'g0'});
  });

  testWidgets('inside a swipeable TabBarView: long press + drag selects, a plain horizontal swipe still changes tabs',
      (tester) async {
    final c = SwipeSelectController<String>();
    await tester.pumpWidget(MaterialApp(
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(bottom: const TabBar(tabs: [Tab(text: 'A'), Tab(text: 'B')])),
          body: TabBarView(children: [
            SwipeSelect<String>(
              controller: c,
              itemCount: 100,
              keyForIndex: (i) => 'id$i',
              activation: const [SwipeSelectActivation.longPress()],
              child: ListView.builder(
                itemCount: 100,
                itemBuilder: (context, i) =>
                    SwipeSelectItem(index: i, child: SizedBox(height: rowH, child: Text('id$i'))),
              ),
            ),
            const Center(child: Text('tab B')),
          ]),
        ),
      ),
    ));
    final top = tester.getTopLeft(find.byType(TabBarView)).dy;
    Offset r(int i) => Offset(400, top + i * rowH + rowH / 2);
    await drag(tester, [r(1), r(3)], hold: const Duration(milliseconds: 400));
    expect(c.selected, {'id1', 'id2', 'id3'});
    await tester.fling(find.byType(TabBarView), const Offset(-500, 0), 2000);
    await tester.pumpAndSettle();
    expect(find.text('tab B'), findsOneWidget);
  });

  testWidgets('pan activation inside a swipeable TabBarView: selection wins over the tab swipe', (tester) async {
    final c = SwipeSelectController<String>(selectionMode: true);
    final ids = List.generate(60, (i) => 'p$i');
    await tester.pumpWidget(MaterialApp(
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          body: TabBarView(children: [
            SwipeSelect<String>(
              controller: c,
              itemCount: ids.length,
              keyForIndex: (i) => ids[i],
              activation: const [SwipeSelectActivation.pan()],
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
                itemCount: ids.length,
                itemBuilder: (context, i) => SwipeSelectItem(index: i, child: Text(ids[i])),
              ),
            ),
            const Center(child: Text('tab B')),
          ]),
        ),
      ),
    ));
    final cell = tester.getSize(find.byType(SwipeSelectItem).first).width;
    await drag(tester, [Offset(cell / 2, cell / 2), Offset(cell * 3.5, cell / 2)]);
    expect(c.selected, {'p0', 'p1', 'p2', 'p3'});
    expect(find.text('tab B'), findsNothing);
  });
}
