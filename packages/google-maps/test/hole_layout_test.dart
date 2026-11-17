import 'dart:ui';

import 'package:aqutter_plugin_google_maps/src/hole_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the first report becomes the reference with no shift', () {
    final layout = AqutterHoleLayout.update(null, const Rect.fromLTWH(40, 200, 320, 300));
    expect(layout.reference, const Rect.fromLTWH(40, 200, 320, 300));
    expect(layout.shift, Offset.zero);
  });

  test('mapRect follows the hole and keeps its size', () {
    final first = AqutterHoleLayout.update(null, const Rect.fromLTWH(40, 1400, 320, 700));
    final moved = AqutterHoleLayout.update(first, const Rect.fromLTWH(40, 900, 320, 700));
    expect(first.mapRect, const Rect.fromLTWH(40, 1400, 320, 700));
    expect(moved.mapRect, const Rect.fromLTWH(40, 900, 320, 700));
  });

  test('moving a hole of the same size only changes the shift', () {
    final first = AqutterHoleLayout.update(null, const Rect.fromLTWH(40, 200, 320, 300));
    final moved = AqutterHoleLayout.update(first, const Rect.fromLTWH(40, 120, 320, 300));
    expect(moved.reference, first.reference);
    expect(moved.shift, const Offset(0, -80));
  });

  test('a hole of a new size becomes the new reference', () {
    final first = AqutterHoleLayout.update(null, const Rect.fromLTWH(40, 200, 320, 300));
    final resized = AqutterHoleLayout.update(first, const Rect.fromLTWH(40, 150, 320, 400));
    expect(resized.reference, const Rect.fromLTWH(40, 150, 320, 400));
    expect(resized.shift, Offset.zero);
  });

  group('toMapGesture', () {
    const viewport = Size(400, 800);
    const mapRect = Rect.fromLTWH(40, 200, 320, 400);

    test('maps a tap at the hole center to the map center', () {
      final mapped = toMapGesture({'type': 'tap', 'x': 0.5, 'y': 0.5}, viewport: viewport, mapRect: mapRect);
      expect(mapped['x'], closeTo(0.5, 1e-9));
      expect(mapped['y'], closeTo(0.5, 1e-9));
    });

    test('maps a position at the hole corner to the map corner', () {
      final mapped = toMapGesture({'type': 'pinch', 'phase': 'start', 'x': 40 / 400, 'y': 200 / 800}, viewport: viewport, mapRect: mapRect);
      expect(mapped['x'], closeTo(0, 1e-9));
      expect(mapped['y'], closeTo(0, 1e-9));
    });

    test('rescales pan deltas to the map size', () {
      final mapped = toMapGesture({'type': 'pan', 'phase': 'update', 'dx': 0.1, 'dy': 0.1}, viewport: viewport, mapRect: mapRect);
      expect(mapped['dx'], closeTo(0.1 * 400 / 320, 1e-9));
      expect(mapped['dy'], closeTo(0.1 * 800 / 400, 1e-9));
    });

    test('leaves gestures without a position untouched', () {
      final payload = {'type': 'pinch', 'phase': 'end'};
      expect(toMapGesture(payload, viewport: viewport, mapRect: mapRect), payload);
    });
  });
}
