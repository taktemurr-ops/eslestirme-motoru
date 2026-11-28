// QA: eşleştirme oyunlarında takılma. Oyuncu rastgele (ama kurala uygun)
// eşleştirmeler yapar; çift kalmayınca "devam" (karıştır) her zaman oyunu
// yeniden oynanır kılmalı ve sonunda tahta temizlenebilmeli.
import 'package:eslestirme_motoru/eslestirme_motoru.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';

void main() {
  for (final id in ['mahjong', 'tas-cikarma', 'domino']) {
    test('$id: rastgele oyunda karıştır takılmayı çözer, tahta biter', () {
      final rules = matchRulesFor('oyun-$id', id);
      final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: const []);
      var shuffles = 0;
      for (final l in [1, 2, 3, 5, 8, 12, 20, 50, 100, 500, 5000, 50000]) {
        final gl = rules.build(planner.spec(l));
        final g = rules.kindForLevel(MatchRules.campaignDifficulty(gl.spec)).start(gl.puzzle) as PairTilesGame;
        final r = SeededRandom(l * 101);
        var guard = 0;
        while (!g.won && guard++ < 2000) {
          final f = g.b.freeTiles();
          final pairs = <(int, int)>[];
          for (var a = 0; a < f.length; a++) {
            for (var c = a + 1; c < f.length; c++) {
              if (g.matches(f[a], f[c])) pairs.add((f[a], f[c]));
            }
          }
          if (pairs.isEmpty) {
            expect(g.lost, isTrue, reason: '$id L$l: çift yok ama kayıp değil');
            expect(g.continueAfterLoss(), isTrue, reason: '$id L$l karıştır başarısız');
            shuffles++;
            expect(g.lost, isFalse, reason: '$id L$l karıştırdıktan sonra hâlâ çift yok');
            continue;
          }
          expect(g.lost, isFalse);
          final (a, c) = pairs[r.nextInt(pairs.length)];
          g.b.gone[a] = true;
          g.b.gone[c] = true;
        }
        expect(g.won, isTrue, reason: '$id L$l bitmedi');
      }
      // ignore: avoid_print
      print('QA $id: karıştırma sayısı $shuffles');
    });
  }
}
