import 'package:aqutter/aqutter.dart';
import 'package:aqutter_plugin_mirror_demo/aqutter_plugin_mirror_demo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

AqutterNativeMessage message(String type, [Map<String, dynamic> data = const {}]) =>
    AqutterNativeMessage(type, {'type': type, ...data});

void main() {
  test('id follows the naming rule', () {
    expect(MirrorDemoPlugin().id, 'mirror-demo');
  });

  test('every tap counts and doubleTap resets', () {
    final state = MirrorDemoState();
    final counts = <int>[];
    state.onCountChanged = counts.add;
    state
      ..apply(message('tap'))
      ..apply(message('tap'))
      ..apply(message('doubleTap'));
    expect(counts, [1, 2, 0]);
    expect(state.count, 0);
  });

  test('pan moves the circle and clamps to the canvas', () {
    final state = MirrorDemoState();
    state.apply(message('pan', {'phase': 'update', 'dx': 0.1, 'dy': -0.2}));
    expect(state.center.dx, closeTo(0.6, 1e-9));
    expect(state.center.dy, closeTo(0.3, 1e-9));
    state.apply(message('pan', {'phase': 'update', 'dx': 5.0, 'dy': -5.0}));
    expect(state.center.dx, 1.0);
    expect(state.center.dy, 0.0);
  });

  test('pinch scales relative to the radius at pinch start', () {
    final state = MirrorDemoState();
    state
      ..apply(message('pinch', {'phase': 'start', 'scale': 1}))
      ..apply(message('pinch', {'phase': 'update', 'scale': 2}));
    expect(state.radius, closeTo(0.36, 1e-9));
    state.apply(message('pinch', {'phase': 'update', 'scale': 100}));
    expect(state.radius, 0.45);
  });

  test('longPress cycles colors and the reset command restores everything', () {
    final state = MirrorDemoState();
    final first = state.color;
    state
      ..apply(message('longPress'))
      ..apply(message('tap'));
    expect(state.color, isNot(first));
    state.apply(message('command', {'name': 'reset'}));
    expect(state.color, first);
    expect(state.count, 0);
    expect(state.radius, 0.18);
  });

  test('state handler reports the current values', () async {
    final plugin = MirrorDemoPlugin();
    plugin.state.apply(message('tap'));
    expect((await plugin.handlers['state']!({}))['count'], 1);
  });

  group('MirrorDemoCanvas uses the standard Flutter gestures', () {
    late MirrorDemoState state;

    Future<void> pump(WidgetTester tester) async {
      state = MirrorDemoState();
      addTearDown(state.dispose);
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox(width: 400, height: 200, child: MirrorDemoCanvas(state: state))),
      ));
    }

    testWidgets('a single tap counts, after Flutter has ruled out a double tap', (tester) async {
      await pump(tester);
      await tester.tap(find.byType(MirrorDemoCanvas));
      await tester.pump(const Duration(milliseconds: 400));
      expect(state.count, 1);
    });

    testWidgets('a double tap resets and does not also count as a tap', (tester) async {
      await pump(tester);
      await tester.tap(find.byType(MirrorDemoCanvas));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(MirrorDemoCanvas));
      await tester.pump(const Duration(milliseconds: 400));
      expect(state.count, 0);
      // 互斥：若單擊也被觸發，之前的計數會是 1 或 2，且最後才被歸零；這裡確認中途沒有計數事件
    });

    testWidgets('a double tap fires no tap in between', (tester) async {
      await pump(tester);
      final counts = <int>[];
      state.onCountChanged = counts.add;
      await tester.tap(find.byType(MirrorDemoCanvas));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(MirrorDemoCanvas));
      await tester.pump(const Duration(milliseconds: 400));
      expect(counts, [0]); // 只有雙擊的歸零，沒有任何 +1
    });

    testWidgets('long press changes the color', (tester) async {
      await pump(tester);
      await tester.longPress(find.byType(MirrorDemoCanvas));
      await tester.pumpAndSettle();
      expect(state.colorIndex, 1);
    });

    testWidgets('a one-finger drag moves the circle by the dragged fraction of the canvas', (tester) async {
      await pump(tester);
      final before = state.center;
      await tester.drag(find.byType(MirrorDemoCanvas), const Offset(100, 0)); // 400 寬的 1/4
      await tester.pumpAndSettle();
      expect(state.center.dx, greaterThan(before.dx));
      expect(state.center.dy, closeTo(before.dy, 0.01));
    });

    testWidgets('releasing a fast drag keeps the circle gliding (fling)', (tester) async {
      await pump(tester);
      await tester.timedDrag(find.byType(MirrorDemoCanvas), const Offset(80, 0), const Duration(milliseconds: 80));
      final atRelease = state.center.dx;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.center.dx, greaterThan(atRelease));
      await tester.pumpAndSettle();
    });

    testWidgets('two fingers apart scale up and twisting rotates (multi-touch)', (tester) async {
      await pump(tester);
      final center = tester.getCenter(find.byType(MirrorDemoCanvas));
      final a = await tester.startGesture(center - const Offset(30, 0), pointer: 1);
      final b = await tester.startGesture(center + const Offset(30, 0), pointer: 2);
      await tester.pump();
      final radiusBefore = state.radius;
      // 兩指拉開（間距 60 → 120）並整體轉 45 度
      await a.moveTo(center + const Offset(-60, 0));
      await b.moveTo(center + const Offset(60, 0));
      await tester.pump();
      expect(state.radius, greaterThan(radiusBefore));
      await a.moveTo(center + const Offset(-42, -42));
      await b.moveTo(center + const Offset(42, 42));
      await tester.pump();
      expect(state.rotation.abs(), greaterThan(0.3));
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
    });
  });
}
