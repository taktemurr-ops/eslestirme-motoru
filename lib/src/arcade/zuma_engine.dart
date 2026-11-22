import 'dart:math' as math;

import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';

/// Top zinciri: renkli toplar sarmal bir rayda deliğe doğru ilerler.
/// Ortadaki atıcıdan top fırlat; aynı renkten üç ya da daha fazlası
/// bitişince patlar. Boşluğun iki yanı aynı renkse ön parça geri çekilir
/// ve zincirleme patlama olur. Bütün toplar bitince bölüm biter.
const double kBall = 62;
const double kShotSpeed = 34;
const double kCx = 500, kCy = 820;

class ZumaLevel {
  final ArcadeMeta meta;
  final List<double> px, py; // ray noktaları (eşit aralıklı)
  final int colors;
  final int total;
  final double speed;
  const ZumaLevel(this.meta, this.px, this.py, this.colors, this.total, this.speed);

  double get length => (px.length - 1) * kStep;
}

const double kStep = 4;

ZumaLevel generateZuma(LevelSpec spec) {
  final m = ArcadeMeta.of(spec);
  final r = SeededRandom(mixSeed([spec.seed, 211]));
  final d = spec.difficulty;
  // Sarmal: dıştan içe; elips oranı, başlangıç açısı ve tur sayısı değişir.
  final turns = 1.6 + r.nextDouble() * 0.6 + d * 0.04;
  final a0 = r.nextDouble() * math.pi * 2;
  final ex = 0.92 + r.nextDouble() * 0.08, ey = 1.0 + r.nextDouble() * 0.35;
  final dir = r.chance(0.5) ? 1.0 : -1.0;
  const rOut = 430.0, rIn = 175.0;
  final raw = <(double, double)>[];
  const n = 2400;
  for (var k = 0; k <= n; k++) {
    final t = k / n;
    final ang = a0 + dir * t * turns * 2 * math.pi;
    final rad = rOut - (rOut - rIn) * t;
    raw.add((kCx + math.cos(ang) * rad * ex, kCy + math.sin(ang) * rad * ey));
  }
  // Eşit aralıklı yeniden örnekle.
  final cum = <double>[0];
  for (var k = 1; k < raw.length; k++) {
    final dx = raw[k].$1 - raw[k - 1].$1, dy = raw[k].$2 - raw[k - 1].$2;
    cum.add(cum.last + math.sqrt(dx * dx + dy * dy));
  }
  final px = <double>[], py = <double>[];
  var seg = 1;
  for (var s = 0.0; s <= cum.last; s += kStep) {
    while (seg < cum.length - 1 && cum[seg] < s) {
      seg++;
    }
    final l0 = cum[seg - 1], l1 = cum[seg];
    final t = l1 > l0 ? (s - l0) / (l1 - l0) : 0.0;
    px.add(raw[seg - 1].$1 + (raw[seg].$1 - raw[seg - 1].$1) * t);
    py.add(raw[seg - 1].$2 + (raw[seg].$2 - raw[seg - 1].$2) * t);
  }
  final colors = (3 + d ~/ 3).clamp(3, 5);
  final total = m.goal ? 26 + d * 6 : 9999;
  final speed = 0.55 + d * 0.06;
  return ZumaLevel(m, px, py, colors, total, speed);
}

class ZBall {
  double s;
  int color;
  ZBall(this.s, this.color);
}

class ZumaSim extends ArcadeSim {
  final ZumaLevel level;
  final balls = <ZBall>[]; // kuyruk (0) → baş
  int spawned = 0;
  int current = 0, next = 0;
  double aimX = kCx, aimY = kCy - 300;
  double? shotX, shotY, shotVX, shotVY;
  int shotColor = 0;
  int cooldown = 0;
  int rush = 0;
  int popped = 0, combos = 0;
  int lastEvent = 0; // 1 patlama, 2 atış, 3 zincir
  int _colorSeq = 0;

  ZumaSim(this.level) : super(level.meta) {
    rush = 150;
    current = _drawShot();
    next = _drawShot();
  }

  int _chainColor() => SeededRandom(mixSeed([meta.seed, 5, _colorSeq++])).nextInt(level.colors);

  int _drawShot() {
    // Zincirde kalan renklerden seç (yoksa rastgele).
    final present = {for (final b in balls) b.color};
    final r = SeededRandom(mixSeed([meta.seed, 6, ticks, _colorSeq]));
    if (present.isEmpty) return r.nextInt(level.colors);
    final list = present.toList()..sort();
    return list[r.nextInt(list.length)];
  }

  (double, double) pos(double s) {
    final f = (s / kStep).clamp(0, level.px.length - 1.001);
    final i = f.floor();
    final t = f - i;
    return (level.px[i] + (level.px[i + 1] - level.px[i]) * t, level.py[i] + (level.py[i + 1] - level.py[i]) * t);
  }

  bool get allSpawned => spawned >= level.total;

  @override
  double get progress => level.total == 0 ? 0 : (popped / level.total).clamp(0.0, 1.0);

  @override
  String get goalText => meta.goal ? '${level.total - popped}' : '$score';

  @override
  Map<String, int> get stats => {'balls_popped': popped, 'combos': combos};

  @override
  int get stars => won ? lifeStars(this, 3) : 0;

  /// Bir adım: kuyruk ilerler, temas eden toplar itilir.
  void _advance() {
    final v = rush > 0 ? level.speed * 7 : level.speed;
    if (rush > 0) rush--;
    if (balls.isEmpty) {
      if (!allSpawned) {
        balls.add(ZBall(0, _chainColor()));
        spawned++;
      } else if (meta.goal) {
        win();
      }
      return;
    }
    balls[0].s += v;
    for (var i = 1; i < balls.length; i++) {
      if (balls[i].s - balls[i - 1].s < kBall) balls[i].s = balls[i - 1].s + kBall;
    }
    // Yeni top girişi
    if (!allSpawned && balls[0].s >= kBall) {
      balls.insert(0, ZBall(balls[0].s - kBall, _chainColor()));
      spawned++;
    }
    // Geri çekilme: boşluğun iki yanı aynı renkse ön parça geri gelir.
    for (var i = 1; i < balls.length; i++) {
      final gap = balls[i].s - balls[i - 1].s;
      if (gap > kBall + 0.5 && balls[i].color == balls[i - 1].color) {
        final pull = math.min(gap - kBall, 9.0);
        for (var j = i; j < balls.length; j++) {
          if (j > i && balls[j].s - balls[j - 1].s > kBall + pull + 0.5) break;
          balls[j].s -= pull;
        }
        if (balls[i].s - balls[i - 1].s <= kBall + 0.5) {
          balls[i].s = balls[i - 1].s + kBall;
          if (_popAround(i, chain: true)) {
            combos++;
            lastEvent = 3;
          }
        }
        break;
      }
    }
    // Deliğe ulaştı mı
    if (balls.isNotEmpty && balls.last.s >= level.length) {
      if (meta.zen) {
        balls.removeLast();
      } else {
        hit();
      }
    }
  }

  /// [i] çevresindeki aynı renk dizisi 3+ ise patlat.
  bool _popAround(int i, {bool chain = false}) {
    if (i < 0 || i >= balls.length) return false;
    final c = balls[i].color;
    var lo = i, hi = i;
    while (lo > 0 && balls[lo - 1].color == c && balls[lo].s - balls[lo - 1].s <= kBall + 1) {
      lo--;
    }
    while (hi < balls.length - 1 && balls[hi + 1].color == c && balls[hi + 1].s - balls[hi].s <= kBall + 1) {
      hi++;
    }
    final n = hi - lo + 1;
    if (n < 3) return false;
    balls.removeRange(lo, hi + 1);
    popped += n;
    score += n * 10 * (chain ? 2 : 1);
    lastEvent = lastEvent == 0 ? 1 : lastEvent;
    return true;
  }

  void _fire(double tx, double ty) {
    if (shotX != null || cooldown > 0) return;
    final dx = tx - kCx, dy = ty - kCy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return;
    shotX = kCx;
    shotY = kCy;
    shotVX = dx / len * kShotSpeed;
    shotVY = dy / len * kShotSpeed;
    shotColor = current;
    current = next;
    next = _drawShot();
    cooldown = 8;
    lastEvent = 2;
  }

  void _moveShot() {
    if (shotX == null) return;
    shotX = shotX! + shotVX!;
    shotY = shotY! + shotVY!;
    if (shotX! < -80 || shotX! > kWorldW + 80 || shotY! < -80 || shotY! > kWorldH + 80) {
      shotX = null;
      return;
    }
    for (var i = 0; i < balls.length; i++) {
      if (balls[i].s < 0) continue;
      final (bx, by) = pos(balls[i].s);
      final dx = shotX! - bx, dy = shotY! - by;
      if (dx * dx + dy * dy < kBall * kBall * 0.8) {
        // Rayda önce mi sonra mı?
        final (ax, ay) = pos(balls[i].s + 8);
        final tx = ax - bx, ty = ay - by;
        final ahead = dx * tx + dy * ty > 0;
        final at = ahead ? i + 1 : i;
        final s = ahead ? balls[i].s + kBall : balls[i].s;
        balls.insert(at, ZBall(s, shotColor));
        for (var j = at + 1; j < balls.length; j++) {
          if (balls[j].s - balls[j - 1].s < kBall) balls[j].s = balls[j - 1].s + kBall;
        }
        shotX = null;
        _popAround(at);
        return;
      }
    }
  }

  @override
  void update(ArcadeInput input) {
    lastEvent = 0;
    if (cooldown > 0) cooldown--;
    if (input.hasPointer) {
      aimX = input.x;
      aimY = input.y;
    }
    if (input.tap && input.hasPointer) {
      final dx = input.x - kCx, dy = input.y - kCy;
      if (dx * dx + dy * dy < 90 * 90) {
        final t = current;
        current = next;
        next = t;
      } else {
        _fire(input.x, input.y);
      }
    }
    _moveShot();
    _advance();
  }

  @override
  void onLifeLost() {
    // Zinciri geriye it: baş, rayın yarısına çekilir.
    if (balls.isEmpty) return;
    final back = balls.last.s - level.length * 0.45;
    for (final b in balls) {
      b.s -= back;
    }
    shotX = null;
  }

  /// Güçlendirici: zinciri 3 saniye geri yürüt.
  @override
  bool useBooster() {
    if (over || balls.isEmpty) return false;
    for (final b in balls) {
      b.s -= kBall * 4;
    }
    return true;
  }
}

/// Atış doğrultusunda ilk çarpılan top (yoksa -1).
int firstHit(ZumaSim z, double tx, double ty) {
  final dx = tx - kCx, dy = ty - kCy;
  final len = math.sqrt(dx * dx + dy * dy);
  if (len < 1) return -1;
  final vx = dx / len * 12, vy = dy / len * 12;
  var x = kCx, y = kCy;
  for (var k = 0; k < 160; k++) {
    x += vx;
    y += vy;
    for (var i = 0; i < z.balls.length; i++) {
      if (z.balls[i].s < 0) continue;
      final (bx, by) = z.pos(z.balls[i].s);
      if ((x - bx) * (x - bx) + (y - by) * (y - by) < kBall * kBall * 0.8) return i;
    }
  }
  return -1;
}

int _runAt(ZumaSim z, int i, int color) {
  var n = 0;
  if (z.balls[i].color == color) n++;
  var k = i;
  while (k > 0 && z.balls[k - 1].color == color && z.balls[k].s - z.balls[k - 1].s <= kBall + 1) {
    n++;
    k--;
  }
  k = i;
  while (k < z.balls.length - 1 && z.balls[k + 1].color == color && z.balls[k + 1].s - z.balls[k].s <= kBall + 1) {
    n++;
    k++;
  }
  return n;
}

/// Otomatik oyuncu: görünen topları dener, atışın ilk çarptığı yerde
/// aynı renkten en az iki top varsa ve deliğe yakınsa onu seçer.
ArcadeInput zumaBot(ArcadeSim sim) {
  final z = sim as ZumaSim;
  if (z.shotX != null || z.cooldown > 0 || z.balls.isEmpty || sim.ticks % 5 != 0) return const ArcadeInput();
  (double, double)? bestAim;
  var bestScore = -1e9;
  for (final color in [z.current, z.next]) {
    for (var i = 0; i < z.balls.length; i++) {
      final b = z.balls[i];
      if (b.s < kBall || b.color != color) continue;
      final (x, y) = z.pos(b.s);
      final h = firstHit(z, x, y);
      if (h < 0 || z.balls[h].color != color) continue;
      final run = _runAt(z, h, color);
      final sc = z.balls[h].s / z.level.length * 100 + (run >= 2 ? 300 : 0);
      if (sc > bestScore) {
        bestScore = sc;
        bestAim = color == z.current ? (x, y) : null;
        if (color != z.current) bestAim = (-1, -1);
      }
    }
  }
  if (bestAim == null) {
    // Uygun hedef yok: sıradakiyle değiştir ya da kuyruğa (girişe) at.
    if (z.next != z.current) return const ArcadeInput(tap: true, x: kCx, y: kCy, down: true);
    final (x, y) = z.pos(math.max(0, z.balls.first.s));
    return ArcadeInput(tap: true, x: x.roundToDouble(), y: y.roundToDouble(), down: true);
  }
  if (bestAim.$1 < 0) {
    // Sıradaki top daha iyi: değiştir.
    return const ArcadeInput(tap: true, x: kCx, y: kCy, down: true);
  }
  return ArcadeInput(tap: true, x: bestAim.$1.roundToDouble(), y: bestAim.$2.roundToDouble(), down: true);
}
