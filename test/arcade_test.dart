import 'package:eslestirme_motoru/eslestirme_motoru.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/level_plan.dart';

void main() {
  final all = <String, ArcadeRules>{
    'balon': BubbleRules('oyun-balon-patlatici'),
    'balon-cesit': BubbleRules('oyun-balon-cesit-1', forced: const ['stone', 'descend']),
    'zincir': ZumaRules('oyun-top-zinciri'),
    'meyve': FruitRules('oyun-meyve-birlestirme'),
  };
  for (final e in all.entries) {
    test('${e.key}: kampanya, günlük ve sonsuz bölümler bot tarafından geçilir', () {
      final r = e.value;
      final planner = LevelPlanner(gameId: r.gameId, optionalMechanics: r.optionalMechanics);
      for (final n in [1, 5, 20, 60, 2000, 60000]) {
        final g = r.build(planner.spec(n));
        expect(g.validation.ok, isTrue, reason: '${e.key} bölüm $n');
      }
      expect(r.build(planner.daily('2026-11-22')).validation.ok, isTrue);
      expect(r.build(planner.run(GameModeId.endless, 2)).validation.ok, isTrue);
    });
  }

  test('top zinciri: aynı tohum aynı oyun', () {
    final r = ZumaRules('oyun-top-zinciri');
    final planner = LevelPlanner(gameId: r.gameId, optionalMechanics: r.optionalMechanics);
    final l = r.build(planner.spec(9)).puzzle;
    final a = ZumaSim(l), b = ZumaSim(l);
    for (var t = 0; t < 2000; t++) {
      a.tick(zumaBot(a));
      b.tick(zumaBot(b));
    }
    expect(a.score, b.score);
    expect(a.balls.length, b.balls.length);
  });
}
