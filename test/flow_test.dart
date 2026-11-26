import 'package:eslestirme_motoru/eslestirme_motoru.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/rng.dart';

/// Konveyör ve tepsi oyunları: üretilen bölümleri bot sonuna kadar oynar.
void main() {
  test('piksel akışı: resim her renkte piksel içerir, bot resmi temizler', () {
    for (var d = 1; d <= 10; d += 3) {
      final m = const PixelFlowKind().make(d, SeededRandom(100 + d)).data;
      final s = PixelSim(m);
      final ammo = <int, int>{};
      for (final c in s.queues) {
        for (final e in c) {
          ammo[e[0]] = (ammo[e[0]] ?? 0) + e[1];
        }
      }
      final px = <int, int>{};
      for (final v in s.px) {
        if (v >= 0) px[v] = (px[v] ?? 0) + 1;
      }
      expect(ammo, px, reason: 'cephane = piksel sayısı');
      expect(pixelSolvable(m), isTrue);
    }
  });

  test('renk döngüsü: tane sayısı kap kapasitesinin katı, bot bitirir', () {
    for (var d = 1; d <= 10; d += 3) {
      final m = const ColorLoopKind().make(d, SeededRandom(200 + d)).data;
      final s = LoopSim(m);
      final cups = s.queues.fold<int>(0, (a, q) => a + q.length);
      expect(s.grainsLeft, cups * s.cap);
      expect(loopSolvable(m), isTrue);
    }
  });

  test('tatlı tepsisi: altı aynı dilim tamamlanır, bot hedefe ulaşır', () {
    final s = TraySim({'r': 1, 'c': 2, 't': 3, 'g': 1, 'bl': <int>[], 'seed': 5, 'pre': [
      [0, 1, 1, 1, 2]
    ]});
    s.offer[0] = [1, 1, 1];
    expect(s.place(0, 1), isTrue);
    expect(s.done, 1);
    for (var d = 1; d <= 10; d += 3) {
      final m = const DessertTrayKind().make(d, SeededRandom(300 + d)).data;
      expect(traySolvable(m), isTrue);
    }
  });
}
