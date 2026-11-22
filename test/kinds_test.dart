import 'dart:ui';

import 'package:eslestirme_motoru/eslestirme_motoru.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/level_plan.dart';

const pal = MPalette(
  pieces: [Color(0xFFE76F51), Color(0xFF2A9D8F), Color(0xFFE9C46A), Color(0xFF264653), Color(0xFF8D6A9F), Color(0xFFF4A261)],
  ink: Color(0xFF222222),
  surface: Color(0xFFFFFFFF),
  accent: Color(0xFF3D5A80),
  tile: Color(0xFFFBF6EC),
  tileEdge: Color(0xFFD9CBB2),
  shadow: Color(0xFF000000),
  colorBlind: true,
  reducedMotion: false,
);

void paintOnce(MGame g, Size s) {
  g.size = s;
  final rec = PictureRecorder();
  g.paint(Canvas(rec), s, pal, 0.5);
  rec.endRecording();
}

void main() {
  for (final e in kMatchKinds.entries) {
    test('tür ${e.key}: bölümler üretilir, doğrulanır, oynanır, kaydedilir', () {
      final rules = matchRulesFor('oyun-test-${e.key}', e.key);
      final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: const []);
      for (final lvNo in [1, 7, 40, 300, 5000, 99999]) {
        final gl = rules.build(planner.spec(lvNo));
        expect(gl.validation.ok, isTrue, reason: '${e.key} bölüm $lvNo');
        final lv = MLevel.fromJson(gl.puzzle.toJson());
        final g = rules.kindForLevel(gl.spec.difficulty).start(lv);
        for (final s in const [Size(400, 720), Size(1000, 640)]) {
          paintOnce(g, s);
          // Ekranın her yerine birkaç dokunuş: çökmemeli.
          for (var y = 20.0; y < s.height; y += s.height / 7) {
            for (var x = 20.0; x < s.width; x += s.width / 5) {
              g.down(Offset(x, y));
              g.move(Offset(x + 30, y));
              g.up(Offset(x + 30, y));
              g.step(0.1);
            }
          }
          paintOnce(g, s);
        }
        g.hint();
        g.booster();
        g.status('tr');
        g.status('ar');
        final saved = g.save();
        final g2 = rules.kindForLevel(gl.spec.difficulty).start(lv)..load(saved);
        expect(g2.save().toString(), saved.toString());
        expect(g.won && g.lost, isFalse);
      }
    });
  }

  test('ortak sembol: her iki kartın tam bir ortak simgesi var', () {
    final cards = symbolCards();
    expect(cards.length, 31);
    for (var a = 0; a < cards.length; a++) {
      expect(cards[a].toSet().length, 6);
      for (var b = a + 1; b < cards.length; b++) {
        expect(cards[a].where(cards[b].contains).length, 1);
      }
    }
  });

  test('kısa metinler 33 dilde', () {
    for (final v in kMatchTexts.values) {
      expect(v.length, 33);
    }
    expect(kMatchHowTo.text.length, 33);
  });
}
