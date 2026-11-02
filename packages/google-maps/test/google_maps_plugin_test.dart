import 'package:aqutter/aqutter.dart';
import 'package:aqutter_plugin_google_maps/aqutter_plugin_google_maps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

AqutterNativeMessage _message(String type, [Map<String, dynamic> data = const {}]) => AqutterNativeMessage(type, data);

void main() {
  const size = (width: 400.0, height: 200.0);

  group('gesture mapper', () {
    List<Object> json(AqutterMapDelta delta) => delta.toUpdates().map((update) => update.toJson()).toList();

    test('dragging right scrolls the camera left, scaled by the map size', () {
      final delta = AqutterMapGestureMapper().update(
        _message('pan', {'phase': 'update', 'dx': 0.25, 'dy': -0.5}),
        size: size,
      );
      // 0.25 × 400 = 100、-0.5 × 200 = -100；相機方向與手指相反
      expect(json(delta), [
        ['scrollBy', -100.0, 100.0],
      ]);
    });

    test('pan start and end do not move the camera', () {
      final mapper = AqutterMapGestureMapper();
      expect(mapper.update(_message('pan', {'phase': 'start'}), size: size).isEmpty, isTrue);
      expect(mapper.update(_message('pan', {'phase': 'end'}), size: size).isEmpty, isTrue);
    });

    test('pinch zooms by the increment since the previous event, around the finger center', () {
      final mapper = AqutterMapGestureMapper();
      expect(mapper.update(_message('pinch', {'phase': 'start', 'x': 0.5, 'y': 0.5}), size: size).isEmpty, isTrue);
      // 累計倍率 2：兩指距離加倍＝放大一級；焦點是兩指中心（0.25, 0.5）→ (100, 100) 邏輯像素
      final first = mapper.update(_message('pinch', {'phase': 'update', 'scale': 2.0, 'x': 0.25, 'y': 0.5}), size: size);
      expect(first.toUpdates().first.toJson(), ['zoomBy', 1.0, [100.0, 100.0]]);
      // 累計倍率 4（相對上一次又是一級）：增量是 1，不是 2——不依賴任何「目前縮放」的記錄值
      final second = mapper.update(_message('pinch', {'phase': 'update', 'scale': 4.0, 'x': 0.25, 'y': 0.5}), size: size);
      expect(json(second), [
        ['zoomBy', 1.0, [100.0, 100.0]],
      ]);
    });

    test('moving the two-finger center pans the map in the same direction as a one-finger drag', () {
      final mapper = AqutterMapGestureMapper();
      mapper.update(_message('pinch', {'phase': 'start', 'x': 0.5, 'y': 0.5}), size: size);
      final delta = mapper.update(_message('pinch', {'phase': 'update', 'scale': 1.0, 'x': 0.75, 'y': 0.5}), size: size);
      // 中心右移 0.25 × 400 = 100：只有平移（倍率沒變就不送縮放）
      expect(json(delta), [
        ['scrollBy', -100.0, 0.0],
      ]);
    });

    test('a new pinch starts from scale 1 again', () {
      final mapper = AqutterMapGestureMapper();
      mapper.update(_message('pinch', {'phase': 'start', 'x': 0.5, 'y': 0.5}), size: size);
      mapper.update(_message('pinch', {'phase': 'update', 'scale': 3.0, 'x': 0.5, 'y': 0.5}), size: size);
      mapper.update(_message('pinch', {'phase': 'end', 'scale': 1.0, 'x': 0.5, 'y': 0.5}), size: size);
      mapper.update(_message('pinch', {'phase': 'start', 'x': 0.5, 'y': 0.5}), size: size);
      final delta = mapper.update(_message('pinch', {'phase': 'update', 'scale': 0.5, 'x': 0.5, 'y': 0.5}), size: size);
      expect(json(delta), [
        ['zoomBy', -1.0, [200.0, 100.0]],
      ]);
    });

    test('an invalid scale is ignored', () {
      final mapper = AqutterMapGestureMapper();
      mapper.update(_message('pinch', {'phase': 'start', 'x': 0.5, 'y': 0.5}), size: size);
      expect(mapper.update(_message('pinch', {'phase': 'update', 'scale': 0.0, 'x': 0.5, 'y': 0.5}), size: size).isEmpty, isTrue);
    });

    test('double tap zooms in around the tapped point; other gestures do not touch the camera', () {
      final mapper = AqutterMapGestureMapper();
      expect(json(mapper.update(_message('doubleTap', {'x': 0.5, 'y': 0.25}), size: size)), [
        ['zoomBy', 1.0, [200.0, 50.0]],
      ]);
      expect(json(mapper.update(_message('doubleTap'), size: size)), [
        ['zoomBy', 1.0],
      ]);
      expect(mapper.update(_message('tap'), size: size).isEmpty, isTrue);
      expect(mapper.update(_message('longPress'), size: size).isEmpty, isTrue);
    });
  });

  group('camera accumulator', () {
    test('merges many small updates into one: zoom and scroll add up, the latest focal point wins', () {
      final accumulator = AqutterMapCameraAccumulator();
      expect(accumulator.hasPending, isFalse);
      accumulator
        ..add(const AqutterMapDelta(zoom: 0.25, focal: Offset(10, 10), scroll: Offset(-5, 0)))
        ..add(const AqutterMapDelta(zoom: 0.5, focal: Offset(20, 30), scroll: Offset(5, 2)))
        ..add(const AqutterMapDelta(scroll: Offset(1, 1)));
      expect(accumulator.hasPending, isTrue);
      final merged = accumulator.take();
      expect(merged.zoom, 0.75);
      expect(merged.focal, const Offset(20, 30));
      expect(merged.scroll, const Offset(1, 3));
      expect(merged.toUpdates().map((u) => u.toJson()), [
        ['zoomBy', 0.75, [20.0, 30.0]],
        ['scrollBy', 1.0, 3.0],
      ]);
      // 取走後清空
      expect(accumulator.hasPending, isFalse);
      expect(accumulator.take().isEmpty, isTrue);
    });

    test('zoom in then out cancels, so a busy map is not asked to do work that nets to nothing', () {
      final accumulator = AqutterMapCameraAccumulator()
        ..add(const AqutterMapDelta(zoom: 1, focal: Offset(1, 1)))
        ..add(const AqutterMapDelta(zoom: -1, focal: Offset(1, 1)));
      expect(accumulator.hasPending, isFalse);
    });
  });

  group('plugin', () {
    test('id follows the naming rule and the session id matches the web element', () {
      expect(GoogleMapsPlugin().id, 'google-maps');
      expect(aqutterGoogleMapsSession, 'google-maps');
    });

    test('methods before the map exists report failure instead of throwing', () async {
      final plugin = GoogleMapsPlugin();
      expect(await plugin.handlers['moveTo']!({'lat': 25.0, 'lng': 121.5, 'zoom': 12}), {'ok': false});
      expect((await plugin.handlers['getCamera']!({}))['zoom'], isA<num>());
    });

    test('setMarkers keeps valid entries and drops malformed ones', () async {
      final plugin = GoogleMapsPlugin();
      final result = await plugin.handlers['setMarkers']!({
        'markers': [
          {'id': 'a', 'lat': 25.03, 'lng': 121.56, 'title': 'A'},
          {'id': 'bad', 'lat': 'x', 'lng': 1},
          {'lat': 24.1, 'lng': 120.6},
        ],
      });
      expect(result, {'count': 2});
    });

    test('setMapType maps names and falls back to normal', () async {
      final plugin = GoogleMapsPlugin();
      expect(await plugin.handlers['setMapType']!({'type': 'satellite'}), {'type': 'satellite'});
      expect(await plugin.handlers['setMapType']!({'type': 'unknown'}), {'type': 'normal'});
    });

    test('the plugin declares only Android and iOS as supported platforms', () {
      final plugin = GoogleMapsPlugin();
      expect(plugin.supportedPlatforms, {TargetPlatform.android, TargetPlatform.iOS});
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        expect(aqutterPluginSupports(plugin, platform), isTrue, reason: '$platform');
      }
      for (final platform in [TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.fuchsia]) {
        expect(aqutterPluginSupports(plugin, platform), isFalse, reason: '$platform');
      }
    });

    test('there is no isSupported handler any more: the web asks the shell instead', () {
      expect(GoogleMapsPlugin().handlers.containsKey('isSupported'), isFalse);
    });
  });
}
