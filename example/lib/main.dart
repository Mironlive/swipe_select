import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swipe_select/swipe_select.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'swipe_select',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF2F6BFF), useMaterial3: true),
      home: const DemoTabs(),
    );
  }
}

class DemoTabs extends StatelessWidget {
  const DemoTabs({super.key});

  static const tabs = <(String, Widget)>[
    ('Long press → checkboxes', RevealDemo()),
    ('Mail · edge', MailDemo()),
    ('Right edge', MailDemo(side: EdgeSide.end)),
    ('Grid', GridDemo()),
    ('Chat · reverse', ChatDemo()),
    ('Horizontal', HorizontalDemo()),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      initialIndex: const int.fromEnvironment('TAB', defaultValue: 0),
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final t in tabs) Tab(text: t.$1)],
          ),
        ),
        body: TabBarView(physics: const NeverScrollableScrollPhysics(), children: [for (final t in tabs) t.$2]),
      ),
    );
  }
}

// ---------------- data ----------------

class Mail {
  const Mail(this.id, this.from, this.subject, this.lines, {this.locked = false});
  final String id;
  final String from;
  final String subject;
  final int lines;
  final bool locked;
}

const _senders = ['Anna', 'Boris', 'Vika', 'Gleb', 'Dasha', 'Egor', 'Jane', 'Ilya'];
const _subjects = ['Weekly report', 'Call at 3 pm', 'Invoice #482', 'Vacation plans', 'PR review', 'New design'];

List<Mail> makeMails(int count, {bool withLocked = false}) => [
  for (var i = 0; i < count; i++)
    Mail(
      'mail-$i',
      _senders[i % _senders.length],
      '${_subjects[i % _subjects.length]} #${i + 1}',
      1 + i % 4,
      locked: withLocked && i % 7 == 3,
    ),
];

// ---------------- shared UI ----------------

class Toolbar<K> extends StatelessWidget {
  const Toolbar({super.key, required this.controller, required this.hint, required this.all});
  final SwipeSelectController<K> controller;
  final String hint;
  final Iterable<K> Function() all;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF4F5F7),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => Text(
                    'Selected: ${controller.selectedCount}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                const Spacer(),
                TextButton(onPressed: () => controller.setSelection(all()), child: const Text('All')),
                TextButton(onPressed: controller.clear, child: const Text('Clear')),
              ],
            ),
            Text(hint, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class MailRow extends StatelessWidget {
  const MailRow({
    super.key,
    required this.mail,
    required this.selected,
    required this.showCheckbox,
    required this.onCheckbox,
    this.onTap,
    this.side = EdgeSide.start,
  });

  final Mail mail;
  final bool selected;
  final bool showCheckbox;
  final VoidCallback onCheckbox;
  final VoidCallback? onTap;
  final EdgeSide side;

  @override
  Widget build(BuildContext context) {
    final box = showCheckbox
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: mail.locked ? null : onCheckbox,
            child: SizedBox(
              width: 56,
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Icon(
                    selected ? Icons.check_box : Icons.check_box_outline_blank,
                    color: mail.locked ? Colors.black26 : (selected ? const Color(0xFF2F6BFF) : Colors.black45),
                  ),
                ),
              ),
            ),
          )
        : const SizedBox(width: 12);
    final body = Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mail.locked ? '${mail.from}  · locked' : mail.from,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(mail.subject),
            const SizedBox(height: 4),
            Text(
              'Message preview that takes one or several lines depending on the email. ' * mail.lines,
              maxLines: mail.lines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
    return Material(
      color: selected ? const Color(0xFFE8F0FF) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: mail.locked ? 0.5 : 1,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: side == EdgeSide.start ? [box, body] : [body, box],
          ),
        ),
      ),
    );
  }
}

// ---------------- demos ----------------

/// Like iOS Mail: no checkboxes at first, long press anywhere enters selection mode,
/// then drag along the checkbox column.
class RevealDemo extends StatefulWidget {
  const RevealDemo({super.key});
  @override
  State<RevealDemo> createState() => _RevealDemoState();
}

class _RevealDemoState extends State<RevealDemo> {
  final mails = makeMails(300);
  final controller = SwipeSelectController<String>();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final mode = controller.isSelectionMode;
        return Column(
          children: [
            Toolbar(
              controller: controller,
              all: () => mails.map((m) => m.id),
              hint: 'Hold any email → checkboxes appear → drag along the checkbox column.',
            ),
            Expanded(
              child: SwipeSelect<String>(
                controller: controller,
                itemCount: mails.length,
                keyForIndex: (i) => mails[i].id,
                activation: const [
                  SwipeSelectActivation.longPress(when: ActivationWhen.idle),
                  SwipeSelectActivation.edge(),
                ],
                onItemEnter: (_) => HapticFeedback.selectionClick(),
                child: ListView.separated(
                  itemCount: mails.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => SwipeSelectItem(
                    index: i,
                    builder: (context, selected) => MailRow(
                      mail: mails[i],
                      selected: selected,
                      showCheckbox: mode,
                      onCheckbox: () => controller.toggle(mails[i].id),
                      onTap: mode ? () => controller.toggle(mails[i].id) : null,
                    ),
                  ),
                ),
              ),
            ),
            if (mode)
              Material(
                color: const Color(0xFF2F6BFF),
                child: InkWell(
                  onTap: controller.clear,
                  child: SizedBox(
                    height: 48,
                    child: Center(
                      child: Text(
                        'Done (${controller.selectedCount})',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class MailDemo extends StatefulWidget {
  const MailDemo({super.key, this.side = EdgeSide.start});
  final EdgeSide side;
  @override
  State<MailDemo> createState() => _MailDemoState();
}

class _MailDemoState extends State<MailDemo> {
  late List<Mail> mails = makeMails(300, withLocked: widget.side == EdgeSide.start);
  final controller = SwipeSelectController<String>();
  Timer? _incoming;

  void _toggleIncoming() {
    setState(() {
      if (_incoming != null) {
        _incoming!.cancel();
        _incoming = null;
      } else {
        var n = 0;
        _incoming = Timer.periodic(const Duration(milliseconds: 1500), (_) {
          n++;
          setState(
            () => mails = [Mail('new-${DateTime.now().microsecondsSinceEpoch}', 'New', 'Incoming $n', 1), ...mails],
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _incoming?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final side = widget.side;
    return Column(
      children: [
        Toolbar(
          controller: controller,
          all: () => mails.where((m) => !m.locked).map((m) => m.id),
          hint: side == EdgeSide.start
              ? 'Tap a checkbox → drag along the left strip. Every 7th email is locked.'
              : 'Selection strip on the right.',
        ),
        if (side == EdgeSide.start)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _toggleIncoming,
              child: Text(_incoming != null ? '● New mail is arriving — tap to stop' : 'Simulate incoming mail'),
            ),
          ),
        Expanded(
          child: SwipeSelect<String>(
            controller: controller,
            itemCount: mails.length,
            keyForIndex: (i) => mails[i].id,
            isSelectable: (i) => !mails[i].locked,
            activation: [SwipeSelectActivation.edge(side: side)],
            child: ListView.separated(
              itemCount: mails.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => SwipeSelectItem(
                index: i,
                builder: (context, selected) => MailRow(
                  mail: mails[i],
                  selected: selected,
                  showCheckbox: true,
                  side: side,
                  onCheckbox: () => controller.toggle(mails[i].id),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Photos-like grid: long press a photo to enter selection mode and keep dragging;
/// then swipe sideways to select, vertically to scroll. 10,000 photos.
class GridDemo extends StatefulWidget {
  const GridDemo({super.key});
  @override
  State<GridDemo> createState() => _GridDemoState();
}

class _GridDemoState extends State<GridDemo> {
  final ids = List.generate(10000, (i) => 'photo-$i');
  final controller = SwipeSelectController<String>();
  int columns = 4;

  Color colorOf(int i) => HSLColor.fromAHSL(1, ((i * 37) % 360).toDouble(), 0.6, 0.55 + (i % 3) * 0.08).toColor();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              const Text('Columns:'),
              for (final n in [2, 3, 4, 6])
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text('$n'),
                    selected: n == columns,
                    onSelected: (_) => setState(() => columns = n),
                  ),
                ),
            ],
          ),
        ),
        Toolbar(
          controller: controller,
          all: () => ids,
          hint: 'Hold a photo → selection mode. Then swipe sideways to select, vertically to scroll.',
        ),
        Expanded(
          child: SwipeSelect<String>(
            controller: controller,
            itemCount: ids.length,
            keyForIndex: (i) => ids[i],
            activation: const [
              SwipeSelectActivation.longPress(when: ActivationWhen.idle),
              SwipeSelectActivation.pan(),
            ],
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: ids.length,
              itemBuilder: (context, i) => SwipeSelectItem(
                index: i,
                builder: (context, selected) => GestureDetector(
                  onTap: controller.isSelectionMode ? () => controller.toggle(ids[i]) : null,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: colorOf(i).withValues(alpha: selected ? 0.45 : 1)),
                      if (selected)
                        const Positioned(
                          right: 6,
                          bottom: 6,
                          child: Icon(Icons.check_circle, color: Color(0xFF2F6BFF), size: 22),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Reversed list like a chat: #1 at the bottom. Hold and drag up — auto-scrolls to older ones.
class ChatDemo extends StatefulWidget {
  const ChatDemo({super.key});
  @override
  State<ChatDemo> createState() => _ChatDemoState();
}

class _ChatDemoState extends State<ChatDemo> {
  final mails = makeMails(300);
  final controller = SwipeSelectController<String>();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Toolbar(
          controller: controller,
          all: () => mails.map((m) => m.id),
          hint: 'Reversed list (chat): #1 is at the bottom. Hold and drag up.',
        ),
        Expanded(
          child: SwipeSelect<String>(
            controller: controller,
            itemCount: mails.length,
            keyForIndex: (i) => mails[i].id,
            activation: const [SwipeSelectActivation.longPress()],
            child: ListView.separated(
              reverse: true,
              itemCount: mails.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => SwipeSelectItem(
                index: i,
                builder: (context, selected) => MailRow(
                  mail: mails[i],
                  selected: selected,
                  showCheckbox: true,
                  onCheckbox: () => controller.toggle(mails[i].id),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class HorizontalDemo extends StatefulWidget {
  const HorizontalDemo({super.key});
  @override
  State<HorizontalDemo> createState() => _HorizontalDemoState();
}

class _HorizontalDemoState extends State<HorizontalDemo> {
  final ids = List.generate(80, (i) => 'card-$i');
  final controller = SwipeSelectController<String>();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Toolbar(controller: controller, all: () => ids, hint: 'Horizontal list: long press, then drag left / right.'),
        SizedBox(
          height: 170,
          child: SwipeSelect<String>(
            controller: controller,
            itemCount: ids.length,
            keyForIndex: (i) => ids[i],
            activation: const [SwipeSelectActivation.longPress()],
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: ids.length,
              itemBuilder: (context, i) => SwipeSelectItem(
                index: i,
                builder: (context, selected) => Container(
                  width: 70.0 + (i % 3) * 30,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: HSLColor.fromAHSL(1, ((i * 37) % 360).toDouble(), 0.6, 0.55).toColor(),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? const Color(0xFF2F6BFF) : Colors.transparent, width: 4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
