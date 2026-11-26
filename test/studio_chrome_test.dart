import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eslestirme_motoru/eslestirme_motoru.dart';
import 'package:eslestirme_motoru/src/studio_chrome.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';

PlayContext _ctx(GeneratedLevel gl, String lang) => PlayContext(
      spec: gl.spec,
      generated: gl,
      resume: const {},
      pieceColors: const [Color(0xFF3E6FB0), Color(0xFFC8553D)],
      background: const [Color(0xFF1A2E5C), Color(0xFF3A6FC4)],
      colorBlind: false,
      reducedMotion: true,
      leftHanded: false,
      lang: lang,
      t: (k, [p = const {}]) => k,
      finish: (_) {},
      saveResume: (_) {},
      requestHint: () async => true,
      requestBooster: () async => true,
      requestContinue: () async => false,
      sfx: (_) {},
    );

/// Oyun ekranının sarmalayıcısı: oyun alanı eski (açık) temayla, palet tema
/// uzantısıyla gelir (studio-core play.dart gibi).
Widget _host(Widget child, {StudioLook look = const StudioLook()}) => MaterialApp(
      theme: ThemeData(brightness: Brightness.light, extensions: [look]),
      home: Scaffold(body: SafeArea(child: child)),
    );

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Görünümdeki bütün yazılar: koyu stüdyo zemininde okunur olmalı (siyah
/// yazı yalnız kendi açık zeminini çizen hap/rozetlerde olur).
void _expectLightText(WidgetTester t) {
  final ok = {StudioChoice, StudioSeatBadge, StudioButton};
  for (final e in find.byType(RichText).evaluate()) {
    final r = e.renderObject as RenderParagraph;
    final c = r.text.style?.color;
    if (c == null) continue;
    // Vurgu zeminli haplarda yazı, vurguya göre seçilen renktir (onAccent).
    if (c == StudioLook.of(e).onAccent) continue;
    var inside = false;
    e.visitAncestorElements((a) {
      if (ok.contains(a.widget.runtimeType)) {
        inside = true;
        return false;
      }
      return true;
    });
    if (inside) continue;
    expect(c.computeLuminance(), greaterThan(0.35), reason: 'koyu zeminde okunmayan yazı: "${r.text.toPlainText()}"');
  }
}

Future<void> _tapAround(WidgetTester t) async {
  final size = t.view.physicalSize / t.view.devicePixelRatio;
  for (var y = 80.0; y < size.height - 10; y += size.height / 7) {
    for (var x = 30.0; x < size.width; x += size.width / 4) {
      await t.tapAt(Offset(x, y));
      await t.pump(const Duration(milliseconds: 150));
    }
  }
}

void main() {
  final kinds = kMatchKinds.keys.take(6).toList();
  for (final id in kinds) {
    for (final lang in const ['tr', 'ar']) {
      testWidgets('$id ($lang): üst bilgi onaylı tasarımda, yazılar okunur', (t) async {
        t.view.physicalSize = const Size(1080, 2280);
        t.view.devicePixelRatio = 2.75;
        addTearDown(t.view.reset);
        final rules = matchRulesFor('t-$id', id);
        final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: const []);
        final gl = rules.build(planner.spec(3));
        await t.pumpWidget(_host(Directionality(
          textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: MatchView(ctx: _ctx(gl, lang), rules: rules),
        )));
        await t.pump(const Duration(milliseconds: 400));
        expect(t.takeException(), isNull);
        final inner = t.element(find.descendant(of: find.byType(StudioChrome), matching: find.byType(LayoutBuilder)).first);
        expect(Theme.of(inner).brightness, Brightness.dark);
        expect(find.byType(StudioTag), findsOneWidget);
        _expectLightText(t);
        await _tapAround(t);
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
        _expectLightText(t);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 3));
      });
    }
  }

  test('üst bilgi yazısı koyu paletlerde okunur', () {
    for (final look in [const StudioLook(), StudioLook.fromSeed(const Color(0xFFE76F51))]) {
      expect(_contrast(kStudioText, look.sheet), greaterThan(7));
      expect(_contrast(kStudioText, look.base), greaterThan(7));
    }
  });
}
