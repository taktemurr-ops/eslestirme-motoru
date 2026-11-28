import 'dart:math' as math;
import 'dart:ui';

import 'package:studio_core/core/rng.dart';
import 'package:studio_core/core/stats.dart';
import 'package:studio_core/core/missions.dart';

import '../core.dart';
import '../glyphs.dart';
import '../texts.dart';
import 'grids.dart';

List<int> _l(Object? o) => [for (final v in (o as List)) (v as num).toInt()];

/// Üçlü eşleştirme: komşu iki taşı yer değiştir, yatay ya da dikey en az
/// üç aynı taş silinir. 4'lü çizgi siler (sıra ya da sütun), 5'li renk
/// bombası olur. Hedef: belirtilen taşları topla ve "jöle" karelerini
/// temizle. [timed]: mücevher modu — süre içinde hedef puan.
class Match3Kind extends MatchKind {
  @override
  final String id;
  final bool timed;
  const Match3Kind(this.id, {this.timed = false});

  @override
  List<GameStat> get stats => const [
        GameStat('rounds_won', 'Kazanılan bölüm', 'Levels won', scale: 10),
        GameStat('pairs_matched', 'Eşleşme', 'Matches made', scale: 1000),
        GameStat('specials', 'Özel taş', 'Special pieces', scale: 100),
      ];

  @override
  List<MissionTemplate> get missions => const [
        MissionTemplate('win', 'rounds_won', [3, 10, 25]),
        MissionTemplate('special', 'specials', [5, 15, 40]),
      ];

  @override
  MLevel make(int d, SeededRandom r) {
    final w = 7 + (d >= 6 ? 1 : 0), h = 8 + (d >= 4 ? 1 : 0), k = d <= 2 ? 4 : (d <= 7 ? 5 : 6);
    final seed = r.nextInt(1 << 30);
    // Jöle: zorlukla artan, ortada bir desen.
    final jelly = List.filled(w * h, 0);
    if (!timed && d >= 3) {
      final m = 1 + d ~/ 3;
      for (var y = h - m - 1; y < h; y++) {
        for (var x = 1; x < w - 1; x++) {
          if ((x + y + d).isEven || d >= 8) jelly[y * w + x] = 1;
        }
      }
    }
    final gcol = r.nextInt(k);
    final need = timed ? 0 : 12 + d * 3;
    final base = MLevel(id, d, seed, {
      'w': w, 'h': h, 'k': k, 'j': jelly, 'gc': gcol, 'gn': need, 'mv': 999,
      'tm': timed ? 75 : 0, 'ts': 0,
    });
    final g = Match3Game(base);
    var used = 0;
    while (!g.goalsMet && used < 120) {
      if (!g.botMove()) break;
      used++;
    }
    if (timed) {
      // Hedef: botun 25 hamlede yaptığı puanın bir kısmı (insan ~ 40 hamle / 75 sn).
      final g2 = Match3Game(base);
      for (var t = 0; t < 25; t++) {
        g2.botMove();
      }
      return MLevel(id, d, seed, {...base.data, 'ts': math.max(300, (g2.score * (0.9 - d * 0.03)).round())});
    }
    final limit = (used * (1.6 - d * 0.05)).ceil() + 3;
    return MLevel(id, d, seed, {...base.data, 'mv': limit});
  }

  @override
  MGame start(MLevel lv) => Match3Game(lv);

  @override
  bool solvable(MLevel lv) {
    final g = Match3Game(lv);
    if (g.timed) {
      for (var t = 0; t < 30; t++) {
        g.botMove();
      }
      return g.score >= g.targetScore;
    }
    while (!g.won && !g.lost) {
      if (!g.botMove()) return false;
    }
    return g.won;
  }
}

class Match3Game extends MGame {
  late int w, h, k, movesLeft, goalCol, goalLeft, targetScore;
  late List<int> c, sp, jelly;
  late bool timed;
  double timeLeft = 0;
  int refill = 0;
  int? _from;
  Offset? _downAt;
  List<int> hintTiles = [];
  final _fx = <(Rect, int, double)>[];

  // sp: 0 normal, 1 yatay çizgi, 2 dikey çizgi, 3 renk bombası
  Match3Game(super.lv) {
    w = lv.i('w');
    h = lv.i('h');
    k = lv.i('k');
    jelly = lv.ints('j');
    goalCol = lv.i('gc');
    goalLeft = lv.i('gn');
    movesLeft = lv.i('mv');
    timed = lv.i('tm') > 0;
    timeLeft = lv.i('tm').toDouble();
    targetScore = lv.i('ts');
    c = List.filled(w * h, 0);
    sp = List.filled(w * h, 0);
    // Başlangıçta eşleşmesiz doldur.
    for (var i = 0; i < c.length; i++) {
      var v = _next();
      var guard = 0;
      while (_wouldMatch(i, v) && guard++ < 10) {
        v = _next();
      }
      c[i] = v;
    }
    if (_moves().isEmpty) _shuffle();
  }

  int _next() => SeededRandom(mixSeed([lv.seed, refill++, 3])).nextInt(k);

  bool _wouldMatch(int i, int v) {
    final x = i % w, y = i ~/ w;
    if (x >= 2 && c[i - 1] == v && c[i - 2] == v) return true;
    if (y >= 2 && c[i - w] == v && c[i - 2 * w] == v) return true;
    return false;
  }

  bool get goalsMet => timed ? score >= targetScore : (goalLeft <= 0 && !jelly.contains(1));

  /// Eşleşen hücreler ve oluşacak özel taşlar.
  (Set<int>, Map<int, int>) _findMatches(int? prefer) {
    final out = <int>{};
    final make = <int, int>{};
    void line(List<int> cells, bool horiz) {
      if (cells.length < 3) return;
      out.addAll(cells);
      if (cells.length >= 4) {
        final at = (prefer != null && cells.contains(prefer)) ? prefer : cells[cells.length ~/ 2];
        make[at] = cells.length >= 5 ? 3 : (horiz ? 2 : 1);
      }
    }

    for (var y = 0; y < h; y++) {
      var run = <int>[y * w];
      for (var x = 1; x <= w; x++) {
        final i = y * w + x;
        if (x < w && c[i] >= 0 && c[i] == c[run.first] && sp[i] != 3 && sp[run.first] != 3) {
          run.add(i);
        } else {
          line(run, true);
          if (x < w) run = [i];
        }
      }
    }
    for (var x = 0; x < w; x++) {
      var run = <int>[x];
      for (var y = 1; y <= h; y++) {
        final i = y * w + x;
        if (y < h && c[i] >= 0 && c[i] == c[run.first] && sp[i] != 3 && sp[run.first] != 3) {
          run.add(i);
        } else {
          line(run, false);
          if (y < h) run = [i];
        }
      }
    }
    return (out, make);
  }

  bool _adjacent(int a, int b) {
    final ax = a % w, ay = a ~/ w, bx = b % w, by = b ~/ w;
    return (ax - bx).abs() + (ay - by).abs() == 1;
  }

  void _swap(int a, int b) {
    final t = c[a];
    c[a] = c[b];
    c[b] = t;
    final s = sp[a];
    sp[a] = sp[b];
    sp[b] = s;
  }

  /// Geçerli takaslar.
  List<(int, int)> _moves() {
    final out = <(int, int)>[];
    for (var i = 0; i < c.length; i++) {
      for (final j in [i + 1, i + w]) {
        if (j >= c.length || (j == i + 1 && i % w == w - 1)) continue;
        if (sp[i] == 3 || sp[j] == 3) {
          out.add((i, j));
          continue;
        }
        _swap(i, j);
        final ok = _findMatches(null).$1.isNotEmpty;
        _swap(i, j);
        if (ok) out.add((i, j));
      }
    }
    return out;
  }

  void _clear(Set<int> cells, {GridGeo? geo}) {
    final queue = cells.toList();
    final done = <int>{};
    while (queue.isNotEmpty) {
      final i = queue.removeLast();
      if (!done.add(i) || c[i] < 0) continue;
      if (sp[i] == 1) {
        for (var x = 0; x < w; x++) {
          queue.add((i ~/ w) * w + x);
        }
      } else if (sp[i] == 2) {
        for (var y = 0; y < h; y++) {
          queue.add(y * w + i % w);
        }
      }
    }
    for (final i in done) {
      if (c[i] < 0) continue;
      if (geo != null) _fx.add((geo.cell(i), c[i], 0));
      if (c[i] == goalCol && goalLeft > 0) goalLeft--;
      if (jelly[i] == 1) jelly[i] = 0;
      c[i] = -1;
      sp[i] = 0;
    }
    score += done.length * 10;
    bump('pairs_matched');
  }

  void _gravity() {
    for (var x = 0; x < w; x++) {
      final col = <(int, int)>[for (var y = h - 1; y >= 0; y--) if (c[y * w + x] >= 0) (c[y * w + x], sp[y * w + x])];
      for (var y = h - 1, n = 0; y >= 0; y--, n++) {
        if (n < col.length) {
          c[y * w + x] = col[n].$1;
          sp[y * w + x] = col[n].$2;
        } else {
          c[y * w + x] = _next();
          sp[y * w + x] = 0;
        }
      }
    }
  }

  void _shuffle() {
    final r = SeededRandom(mixSeed([lv.seed, refill++, 9]));
    for (var t = 0; t < 30; t++) {
      r.shuffle(c);
      if (_findMatches(null).$1.isEmpty && _moves().isNotEmpty) return;
    }
  }

  /// Takası uygula; geçersizse false.
  bool trySwap(int a, int b, {GridGeo? geo}) {
    if (!_adjacent(a, b)) return false;
    var combo = 1;
    if (sp[a] == 3 || sp[b] == 3) {
      // Renk bombası: diğer taşın rengindeki bütün taşlar.
      final bomb = sp[a] == 3 ? a : b, other = bomb == a ? b : a;
      final col = c[other];
      final cells = {bomb, for (var i = 0; i < c.length; i++) if (c[i] == col) i};
      _clear(cells, geo: geo);
      bump('specials');
    } else {
      _swap(a, b);
      final (m, make) = _findMatches(b);
      if (m.isEmpty) {
        _swap(a, b);
        return false;
      }
      _apply(m, make, geo);
    }
    moves++;
    if (!timed) movesLeft--;
    // Zincirleme
    while (true) {
      _gravity();
      final (m, make) = _findMatches(null);
      if (m.isEmpty) break;
      combo++;
      score += combo * 5;
      _apply(m, make, geo);
    }
    if (_moves().isEmpty) _shuffle();
    return true;
  }

  void _apply(Set<int> m, Map<int, int> make, GridGeo? geo) {
    final keep = <int, (int, int)>{for (final e in make.entries) e.key: (c[e.key], e.value)};
    _clear(m.difference(make.keys.toSet()).union(make.keys.toSet()), geo: geo);
    for (final e in keep.entries) {
      c[e.key] = e.value.$1;
      sp[e.key] = e.value.$2;
      bump('specials');
    }
  }

  bool botMove() {
    final ms = _moves();
    if (ms.isEmpty) return false;
    // En çok hedef taş ve jöle temizleyen takas.
    var best = ms.first, bestV = -1 << 30;
    for (final (a, b) in ms) {
      var v = 0;
      if (sp[a] == 3 || sp[b] == 3) {
        v = 50;
      } else {
        _swap(a, b);
        final (m, make) = _findMatches(b);
        for (final i in m) {
          v += 2 + (c[i] == goalCol ? 6 : 0) + (jelly[i] == 1 ? 8 : 0);
        }
        v += make.length * 10;
        _swap(a, b);
      }
      if (v > bestV) {
        bestV = v;
        best = (a, b);
      }
    }
    return trySwap(best.$1, best.$2);
  }

  GridGeo get _geo => GridGeo.fit(w, h, Rect.fromLTWH(0, size.height * 0.1, size.width, size.height * 0.9));

  @override
  bool down(Offset p) {
    _from = _geo.at(p);
    _downAt = p;
    return false;
  }

  @override
  bool move(Offset p) {
    final f = _from, d0 = _downAt;
    if (f == null || d0 == null) return false;
    final dv = p - d0;
    final geo = _geo;
    if (dv.distance < geo.cs * 0.35) return false;
    final x = f % w, y = f ~/ w;
    int? to;
    if (dv.dx.abs() > dv.dy.abs()) {
      if (dv.dx > 0 && x < w - 1) to = f + 1;
      if (dv.dx < 0 && x > 0) to = f - 1;
    } else {
      if (dv.dy > 0 && y < h - 1) to = f + w;
      if (dv.dy < 0 && y > 0) to = f - w;
    }
    _from = null;
    if (to == null) return false;
    hintTiles = [];
    return trySwap(f, to, geo: geo);
  }

  @override
  bool up(Offset p) {
    _from = null;
    return false;
  }

  @override
  bool get won => goalsMet;
  @override
  bool get lost => !goalsMet && _fx.isEmpty && (timed ? timeLeft <= 0 : movesLeft <= 0);

  @override
  bool continueAfterLoss() {
    if (timed) {
      timeLeft += 15;
    } else {
      movesLeft += 5;
    }
    return true;
  }

  @override
  bool get undoable => !timed;

  @override
  String status(String lang) => timed
      ? '${mt(lang, 'time')}: ${timeLeft.ceil()} · ${mt(lang, 'score')}: $score / $targetScore'
      : '${mt(lang, 'moves')}: $movesLeft';

  @override
  bool hint() {
    final ms = _moves();
    if (ms.isEmpty) return false;
    hintTiles = [ms.first.$1, ms.first.$2];
    return true;
  }

  /// Karıştır.
  @override
  bool booster() {
    _shuffle();
    hintTiles = [];
    return true;
  }

  @override
  bool step(double dt) {
    if (timed && timeLeft > 0 && !goalsMet) timeLeft = math.max(0, timeLeft - dt);
    for (var n = _fx.length - 1; n >= 0; n--) {
      final f = _fx[n];
      final t = f.$3 + dt * 4;
      if (t >= 1) {
        _fx.removeAt(n);
      } else {
        _fx[n] = (f.$1, f.$2, t);
      }
    }
    return _fx.isNotEmpty || timed;
  }

  @override
  void paint(Canvas cv, Size size, MPalette p, double t) {
    final top = size.height * 0.1;
    if (!timed) {
      final ctr = Offset(size.width / 2, top / 2);
      _gem(cv, Rect.fromCenter(center: ctr.translate(-top * 0.5, 0), width: top * 0.6, height: top * 0.6), goalCol, 0, p);
      drawText(cv, goalLeft <= 0 ? '✓' : '$goalLeft', ctr.translate(top * 0.3, 0), top * 0.35, p.ink);
      final jl = jelly.where((j) => j == 1).length;
      if (jl > 0) {
        final jr = Rect.fromCenter(center: ctr.translate(top * 1.3, 0), width: top * 0.55, height: top * 0.55);
        cv.drawRRect(RRect.fromRectAndRadius(jr, Radius.circular(top * 0.12)), Paint()..color = const Color(0xFFB7E4F7));
        drawText(cv, '$jl', ctr.translate(top * 2.0, 0), top * 0.35, p.ink);
      }
    }
    final geo = _geo;
    for (var i = 0; i < c.length; i++) {
      final r = geo.cell(i);
      if (timed) {
        // Mücevher: koyu kadife yuvalar
        cv.drawRRect(RRect.fromRectAndRadius(r.deflate(1), Radius.circular(r.width * 0.12)),
            Paint()..color = (i % w + i ~/ w).isEven ? const Color(0x55301A40) : const Color(0x66200F2E));
      } else {
        cv.drawRect(r, Paint()..color = (i % w + i ~/ w).isEven ? const Color(0x22FFFFFF) : const Color(0x11000000));
      }
      if (jelly[i] == 1) {
        cv.drawRRect(RRect.fromRectAndRadius(r.deflate(1.5), Radius.circular(r.width * 0.18)), Paint()..color = const Color(0xAAB7E4F7));
      }
      if (c[i] >= 0) _gem(cv, r, c[i], sp[i], p, hint: hintTiles.contains(i));
    }
    for (final f in _fx) {
      final r = Rect.fromCenter(center: f.$1.center, width: f.$1.width * (1 + f.$3 * 0.4), height: f.$1.height * (1 + f.$3 * 0.4));
      cv.drawCircle(r.center, r.width * 0.4, Paint()..color = p.piece(f.$2).withAlpha(((1 - f.$3) * 160).round()));
    }
  }

  /// Taş: renge göre farklı kesimli mücevher şekli.
  void _gem(Canvas cv, Rect r, int col, int special, MPalette p, {bool hint = false}) {
    // Mücevher Değiştirme kesik taşlar, Üçlü Eşleştirme yuvarlak şekerler kullanır.
    final shapes = timed ? const [3, 6, 1, 7, 4, 13] : const [0, 3, 13, 2, 4, 5];
    final inner = r.deflate(r.width * 0.12);
    if (special == 3) {
      for (var k = 0; k < 6; k++) {
        cv.drawArc(inner, k * math.pi / 3, math.pi / 3, true, Paint()..color = p.piece(k));
      }
      cv.drawCircle(inner.center, inner.width * 0.2, Paint()..color = const Color(0xFFFFFFFF));
      return;
    }
    final color = p.piece(col);
    final path = glyphPath(shapes[col % shapes.length], inner);
    cv.drawPath(path.shift(Offset(0, r.width * 0.04)), Paint()..color = const Color(0x44000000));
    cv.drawPath(path, Paint()..color = color);
    cv.drawPath(glyphPath(shapes[col % shapes.length], inner.deflate(inner.width * 0.28)).shift(Offset(-inner.width * 0.06, -inner.width * 0.06)),
        Paint()..color = const Color(0x40FFFFFF));
    if (special == 1 || special == 2) {
      final st = Paint()
        ..color = const Color(0xDDFFFFFF)
        ..strokeWidth = r.width * 0.08;
      for (var k = -1; k <= 1; k++) {
        if (special == 1) {
          cv.drawLine(Offset(inner.left + 4, inner.center.dy + k * r.width * 0.16), Offset(inner.right - 4, inner.center.dy + k * r.width * 0.16), st);
        } else {
          cv.drawLine(Offset(inner.center.dx + k * r.width * 0.16, inner.top + 4), Offset(inner.center.dx + k * r.width * 0.16, inner.bottom - 4), st);
        }
      }
    }
    if (hint) {
      cv.drawRRect(
          RRect.fromRectAndRadius(r.deflate(2), Radius.circular(r.width * 0.2)),
          Paint()
            ..color = const Color(0xFFFFC94D)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r.width * 0.08);
    }
  }

  @override
  Map<String, Object?> save() => {
        'c': List.of(c), 'sp': List.of(sp), 'j': List.of(jelly), 'gl': goalLeft, 'ml': movesLeft,
        'rf': refill, 'm': moves, 's': score, 'tl': timeLeft,
      };

  @override
  void load(Map<String, Object?> j) {
    c = _l(j['c']);
    sp = _l(j['sp']);
    jelly = _l(j['j']);
    goalLeft = (j['gl'] as num).toInt();
    movesLeft = (j['ml'] as num).toInt();
    refill = (j['rf'] as num).toInt();
    moves = (j['m'] as num).toInt();
    score = (j['s'] as num).toInt();
    timeLeft = (j['tl'] as num?)?.toDouble() ?? lv.i('tm').toDouble();
    hintTiles = [];
    _fx.clear();
  }
}
