import 'dart:math' as math;
import 'dart:ui';

import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../glyphs.dart';
import '../texts.dart';
import 'grids.dart';

List<int> _l(Object? o) => [for (final v in (o as List)) (v as num).toInt()];

// ======================================================================= BİRLEŞTİRME

const _mergeGlyphs = [0, 7, 10, 18, 19, 15, 4, 9, 14];

/// Üçlü birleştirme: sıradaki parçayı boş bir kareye koy; bitişik üç ya da
/// daha fazla aynı parça bir üst seviyeye birleşir (zincirleme). Hedef
/// seviyeye ulaş; tahta dolarsa kayıp.
class MergeKind extends MatchKind {
  @override
  String get id => 'uclu-birlestirme';
  const MergeKind();

  int targetFor(int d) => math.min(5, 2 + (d + 2) ~/ 3);

  @override
  MLevel make(int d, SeededRandom r) {
    final n = d <= 3 ? 5 : 6;
    for (var attempt = 0; attempt < 40; attempt++) {
      final rocks = d >= 5 ? (d - 3) : 0;
      final cells = List.filled(n * n, -1);
      for (var k = 0; k < rocks; k++) {
        cells[r.nextInt(n * n)] = -2;
      }
      final lv = MLevel(id, d, r.nextInt(1 << 30), {'n': n, 'c': cells, 't': attempt < 30 ? targetFor(d) : 3});
      if (solvable(lv)) return lv;
    }
    throw StateError('merge');
  }

  @override
  MGame start(MLevel lv) => MergeGame(lv);

  @override
  bool solvable(MLevel lv) {
    final g = MergeGame(lv);
    for (var t = 0; t < 500 && !g.won && !g.lost; t++) {
      g.place(g.botCell());
    }
    return g.won;
  }
}

class MergeGame extends MGame {
  late int n, target;
  late List<int> c;
  int drawn = 0;
  int best = 0;
  int hintCell = -1;
  final _fx = <(Rect, double)>[];

  MergeGame(super.lv) {
    n = lv.i('n');
    c = lv.ints('c');
    target = lv.i('t');
  }

  int get next {
    final v = SeededRandom(mixSeed([lv.seed, drawn, 41])).nextInt(100);
    return v < 68 ? 0 : (v < 92 ? 1 : 2);
  }

  void place(int i) {
    if (i < 0 || c[i] != -1) return;
    var lvl = next;
    drawn++;
    c[i] = lvl;
    moves++;
    while (true) {
      final g = groupAt(c, n, n, i);
      if (g.length < 3 || lvl < 0) break;
      for (final j in g) {
        c[j] = -1;
      }
      lvl++;
      c[i] = lvl;
      score += 10 * math.pow(3, lvl).toInt();
      bump('pairs_matched');
      _fx.add((Rect.zero, 0.5));
    }
    best = math.max(best, lvl);
  }

  int botCell() {
    var bestI = -1, bestV = -1 << 30;
    for (var i = 0; i < c.length; i++) {
      if (c[i] != -1) continue;
      final copy = List.of(c);
      final save = (drawn, best, score, moves);
      final st = Map.of(stats);
      place(i);
      var v = best * 1000 + c.where((x) => x == -1).length * 3;
      // Komşu aynı seviyeler (gelecekte birleşme)
      final x = i % n, y = i ~/ n;
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= n || ny >= n) continue;
        if (c[ny * n + nx] >= 0 && c[ny * n + nx] == c[i]) v += 20;
      }
      // Kenarlara yakın olmayı tercih et (merkez açık kalsın)
      v -= ((x - (n - 1) / 2).abs() + (y - (n - 1) / 2).abs()).round() * -2;
      c = copy;
      drawn = save.$1;
      best = save.$2;
      score = save.$3;
      moves = save.$4;
      stats
        ..clear()
        ..addAll(st);
      if (v > bestV) {
        bestV = v;
        bestI = i;
      }
    }
    _fx.clear();
    return bestI;
  }

  GridGeo get _geo => GridGeo.fit(n, n, Rect.fromLTWH(0, size.height * 0.14, size.width, size.height * 0.86), maxCell: 110);

  @override
  bool down(Offset p) {
    final i = _geo.at(p);
    if (i == null || c[i] != -1) return false;
    place(i);
    hintCell = -1;
    return true;
  }

  @override
  bool get won => best >= target;
  @override
  bool get lost => !won && !c.contains(-1);

  @override
  bool continueAfterLoss() => booster();

  @override
  String status(String lang) => '${mt(lang, 'target')}: ${target + 1} · ${mt(lang, 'score')}: $score';

  @override
  bool hint() {
    hintCell = botCell();
    return hintCell >= 0;
  }

  /// En düşük seviyeli bir parçayı kaldır.
  @override
  bool booster() {
    var at = -1;
    for (var i = 0; i < c.length; i++) {
      if (c[i] >= 0 && (at < 0 || c[i] < c[at])) at = i;
    }
    if (at < 0) return false;
    c[at] = -1;
    return true;
  }

  @override
  String boosterKey() => 'slot';

  @override
  bool step(double dt) {
    for (var k = _fx.length - 1; k >= 0; k--) {
      final t = _fx[k].$2 - dt;
      if (t <= 0) {
        _fx.removeAt(k);
      } else {
        _fx[k] = (_fx[k].$1, t);
      }
    }
    return _fx.isNotEmpty;
  }

  void _piece(Canvas cv, Rect r, int lvl, MPalette p) {
    if (lvl == -2) {
      // kaya
      final path = Path()
        ..moveTo(r.left + r.width * 0.15, r.bottom - r.height * 0.18)
        ..lineTo(r.left + r.width * 0.3, r.top + r.height * 0.3)
        ..lineTo(r.center.dx, r.top + r.height * 0.18)
        ..lineTo(r.right - r.width * 0.2, r.top + r.height * 0.35)
        ..lineTo(r.right - r.width * 0.12, r.bottom - r.height * 0.18)
        ..close();
      cv.drawPath(path, Paint()..color = const Color(0xFF8A847C));
      return;
    }
    final s = 0.55 + math.min(lvl, 8) * 0.05;
    final rr = Rect.fromCenter(center: r.center, width: r.width * s, height: r.height * s);
    cv.drawCircle(r.center, r.width * (s / 2 + 0.06), Paint()..color = p.piece(lvl).withAlpha(70));
    drawGlyph(cv, _mergeGlyphs[lvl % _mergeGlyphs.length], rr, p.piece(lvl), outline: true);
    drawText(cv, '${lvl + 1}', r.bottomRight - Offset(r.width * 0.16, r.height * 0.16), r.width * 0.18, p.ink.withAlpha(160));
  }

  @override
  void paint(Canvas cv, Size size, MPalette p, double t) {
    final top = size.height * 0.14;
    // Sıradaki parça ve hedef
    final nr = Rect.fromCenter(center: Offset(size.width * 0.3, top / 2), width: top * 0.8, height: top * 0.8);
    cv.drawRRect(RRect.fromRectAndRadius(nr.inflate(4), const Radius.circular(12)), Paint()..color = const Color(0x22000000));
    _piece(cv, nr, next, p);
    final tr = Rect.fromCenter(center: Offset(size.width * 0.7, top / 2), width: top * 0.8, height: top * 0.8);
    cv.drawRRect(RRect.fromRectAndRadius(tr.inflate(4), const Radius.circular(12)), Paint()..color = const Color(0x22FFC94D));
    _piece(cv, tr, target, p);
    final geo = _geo;
    for (var i = 0; i < c.length; i++) {
      final r = geo.cell(i).deflate(2);
      cv.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.15)),
          Paint()..color = i == hintCell ? const Color(0x88FFC94D) : const Color(0x33FFFFFF));
      if (c[i] != -1) _piece(cv, r, c[i], p);
    }
  }

  @override
  Map<String, Object?> save() => {'c': List.of(c), 'dr': drawn, 'b': best, 'm': moves, 's': score};

  @override
  void load(Map<String, Object?> j) {
    c = _l(j['c']);
    drawn = (j['dr'] as num).toInt();
    best = (j['b'] as num).toInt();
    moves = (j['m'] as num).toInt();
    score = (j['s'] as num).toInt();
    hintCell = -1;
    _fx.clear();
  }
}

// ======================================================================= ORTAK SEMBOL

/// 5. dereceden projektif düzlem: 31 kart, her kartta 6 simge; her iki
/// kartın tam bir ortak simgesi vardır.
List<List<int>> symbolCards() {
  const q = 5;
  int pt(int x, int y) => y * q + x; // 0..24
  int slope(int m) => 25 + m; // 25..29
  const inf = 30;
  final cards = <List<int>>[];
  for (var m = 0; m < q; m++) {
    for (var b = 0; b < q; b++) {
      cards.add([for (var x = 0; x < q; x++) pt(x, (m * x + b) % q), slope(m)]);
    }
  }
  for (var x = 0; x < q; x++) {
    cards.add([for (var y = 0; y < q; y++) pt(x, y), inf]);
  }
  cards.add([for (var m = 0; m < q; m++) slope(m), inf]);
  return cards;
}

/// Ortak sembol: iki karttaki tek ortak simgeyi bul. Süre içinde hedef
/// sayıya ulaş; yanlış dokunuş 2 saniye götürür.
class SymbolKind extends MatchKind {
  @override
  String get id => 'ortak-sembol';
  const SymbolKind();

  @override
  MLevel make(int d, SeededRandom r) => MLevel(id, d, r.nextInt(1 << 30), {'t': 6 + d * 2, 'tm': 60 + d * 4});

  @override
  MGame start(MLevel lv) => SymbolGame(lv);

  // Saniyede yarım eşleşme bile hedefi tutar.
  @override
  bool solvable(MLevel lv) => lv.i('tm') * 0.5 >= lv.i('t');
}

class SymbolGame extends MGame {
  static final cards = symbolCards();
  late int target;
  double timeLeft = 0;
  int round = 0;
  bool _hint = false;
  double _flash = 0;
  bool _wrong = false;

  SymbolGame(super.lv) {
    target = lv.i('t');
    timeLeft = lv.i('tm').toDouble();
  }

  @override
  bool get undoable => false;

  (int, int) get pair {
    final r = SeededRandom(mixSeed([lv.seed, round, 8]));
    final a = r.nextInt(cards.length);
    var b = r.nextInt(cards.length - 1);
    if (b >= a) b++;
    return (a, b);
  }

  int get common => cards[pair.$1].firstWhere((s) => cards[pair.$2].contains(s));

  /// Kartın simge yerleşimi: (simge, merkez, yarıçap) birim daire içinde.
  List<(int, Offset, double)> layout(int card) {
    final r = SeededRandom(mixSeed([lv.seed, round, card, 2]));
    final syms = List.of(cards[card]);
    r.shuffle(syms);
    final out = <(int, Offset, double)>[];
    // Ortada bir, çevrede beş
    for (var k = 0; k < syms.length; k++) {
      final size = 0.2 + r.nextDouble() * 0.12;
      if (k == 0) {
        out.add((syms[k], Offset.zero, size));
      } else {
        final a = (k - 1) * 2 * math.pi / 5 + r.nextDouble() * 0.5;
        out.add((syms[k], Offset(math.cos(a), math.sin(a)) * 0.6, size));
      }
    }
    return out;
  }

  (Rect, Rect) get _cards {
    final wide = size.width > size.height;
    if (wide) {
      final s = math.min(size.width / 2, size.height) * 0.9;
      return (
        Rect.fromCenter(center: Offset(size.width * 0.27, size.height / 2), width: s, height: s),
        Rect.fromCenter(center: Offset(size.width * 0.73, size.height / 2), width: s, height: s)
      );
    }
    final s = math.min(size.width, size.height / 2) * 0.88;
    return (
      Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.27), width: s, height: s),
      Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.73), width: s, height: s)
    );
  }

  @override
  bool down(Offset p) {
    if (timeLeft <= 0) return false;
    final (ra, rb) = _cards;
    final (a, b) = pair;
    for (final (rect, card) in [(ra, a), (rb, b)]) {
      if (!rect.contains(p)) continue;
      for (final (s, o, rad) in layout(card)) {
        final ctr = rect.center + o * (rect.width / 2);
        if ((p - ctr).distance < rad * rect.width / 2 * 1.15) {
          if (s == common) {
            round++;
            moves++;
            score += 15;
            bump('pairs_matched');
            _hint = false;
            _flash = 0.25;
            _wrong = false;
          } else {
            timeLeft = math.max(0, timeLeft - 2);
            _flash = 0.25;
            _wrong = true;
          }
          return true;
        }
      }
    }
    return false;
  }

  @override
  bool get won => round >= target;
  @override
  bool get lost => !won && timeLeft <= 0;

  @override
  bool continueAfterLoss() {
    timeLeft += 15;
    return true;
  }

  @override
  String status(String lang) => '${mt(lang, 'time')}: ${timeLeft.ceil()} · ${mt(lang, 'found')}: $round / $target';

  @override
  bool hint() {
    _hint = true;
    return true;
  }

  @override
  bool booster() {
    timeLeft += 10;
    return true;
  }

  @override
  String boosterKey() => 'slot';

  @override
  bool step(double dt) {
    if (!won && timeLeft > 0) timeLeft = math.max(0, timeLeft - dt);
    if (_flash > 0) _flash -= dt;
    return true;
  }

  @override
  void paint(Canvas cv, Size size, MPalette p, double t) {
    final (ra, rb) = _cards;
    final (a, b) = pair;
    for (final (rect, card) in [(ra, a), (rb, b)]) {
      cv.drawCircle(rect.center.translate(3, 5), rect.width / 2, Paint()..color = const Color(0x33000000));
      cv.drawCircle(rect.center, rect.width / 2, Paint()..color = const Color(0xFFFFFCF5));
      cv.drawCircle(
          rect.center,
          rect.width / 2 - 3,
          Paint()
            ..color = (_flash > 0 ? (_wrong ? const Color(0xFFE76F51) : const Color(0xFF52B788)) : p.accent).withAlpha(140)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5);
      for (final (s, o, rad) in layout(card)) {
        final ctr = rect.center + o * (rect.width / 2);
        final rr = Rect.fromCircle(center: ctr, radius: rad * rect.width / 2);
        final (g, col) = faceOf(s, p.pieces.length);
        drawGlyph(cv, g, rr, p.piece(col), outline: p.colorBlind);
        if (_hint && s == common) {
          cv.drawCircle(ctr, rr.width * 0.62, Paint()
            ..color = const Color(0xFFFFC94D)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4);
        }
      }
    }
  }

  @override
  Map<String, Object?> save() => {'r': round, 'tl': timeLeft, 'm': moves, 's': score};

  @override
  void load(Map<String, Object?> j) {
    round = (j['r'] as num).toInt();
    timeLeft = (j['tl'] as num).toDouble();
    moves = (j['m'] as num).toInt();
    score = (j['s'] as num).toInt();
    _hint = false;
  }
}

// ======================================================================= SAHNELER

/// Sahne öğesi: simge, renk, konum (0..1), boyut (0..1), açı.
class SceneItem {
  final int glyph, color;
  final double x, y, size, rot;
  const SceneItem(this.glyph, this.color, this.x, this.y, this.size, this.rot);
  List<num> enc() => [glyph, color, (x * 1000).round(), (y * 1000).round(), (size * 1000).round(), (rot * 100).round()];
  static SceneItem dec(List l) => SceneItem((l[0] as num).toInt(), (l[1] as num).toInt(), (l[2] as num) / 1000, (l[3] as num) / 1000,
      (l[4] as num) / 1000, (l[5] as num) / 100);
}

void drawItem(Canvas c, SceneItem it, Rect area, MPalette p, {Color? tint, double scale = 1}) {
  final s = it.size * area.shortestSide * scale;
  final ctr = Offset(area.left + it.x * area.width, area.top + it.y * area.height);
  c.save();
  c.translate(ctr.dx, ctr.dy);
  c.rotate(it.rot);
  final r = Rect.fromCenter(center: Offset.zero, width: s, height: s);
  drawGlyph(c, it.glyph, r.shift(Offset(s * 0.04, s * 0.05)), const Color(0x33000000));
  drawGlyph(c, it.glyph, r, tint ?? p.piece(it.color), outline: true);
  c.restore();
}

/// Sahne arka planı: yumuşak tepeler ve noktalar (her bölümde farklı).
void drawSceneBg(Canvas c, Rect area, int seed, MPalette p) {
  final r = SeededRandom(seed);
  c.drawRRect(RRect.fromRectAndRadius(area, const Radius.circular(14)), Paint()..color = const Color(0xFFF4EBDD));
  c.save();
  c.clipRRect(RRect.fromRectAndRadius(area, const Radius.circular(14)));
  for (var k = 0; k < 4; k++) {
    final y = area.top + area.height * (0.45 + k * 0.15);
    final path = Path()..moveTo(area.left, area.bottom);
    path.lineTo(area.left, y);
    for (var x = 0; x <= 8; x++) {
      path.lineTo(area.left + area.width * x / 8, y - r.nextDouble() * area.height * 0.08);
    }
    path
      ..lineTo(area.right, area.bottom)
      ..close();
    c.drawPath(path, Paint()..color = p.piece(k + seed % 3).withAlpha(28 + k * 10));
  }
  c.restore();
}

// ======================================================================= FARKI BUL

/// Farkı bul: iki sahne arasındaki farkları bul. Yanlış dokunuş hakkı sınırlı.
class DiffKind extends MatchKind {
  @override
  String get id => 'farki-bul';
  const DiffKind();

  @override
  MLevel make(int d, SeededRandom r) {
    final count = 14 + d * 2;
    final items = <SceneItem>[];
    var guard = 0;
    while (items.length < count && guard++ < 2000) {
      final s = 0.07 + r.nextDouble() * 0.08;
      final it = SceneItem(r.nextInt(kGlyphCount), r.nextInt(6), 0.08 + r.nextDouble() * 0.84, 0.08 + r.nextDouble() * 0.84, s, r.nextDouble() * 0.8 - 0.4);
      if (items.any((o) => (Offset(o.x, o.y) - Offset(it.x, it.y)).distance < (o.size + it.size) * 0.6)) continue;
      items.add(it);
    }
    final nd = math.min(3 + d ~/ 2, 8);
    final idx = [for (var i = 0; i < items.length; i++) i];
    r.shuffle(idx);
    final diffs = idx.take(nd).toList();
    final types = [for (final _ in diffs) r.nextInt(4)];
    final alt = [for (final _ in diffs) r.nextInt(kGlyphCount)];
    return MLevel(id, d, r.nextInt(1 << 30), {
      'it': [for (final it in items) it.enc()],
      'df': diffs,
      'ty': types,
      'al': alt,
      'mx': 3 + (10 - d) ~/ 3,
    });
  }

  @override
  MGame start(MLevel lv) => DiffGame(lv);

  @override
  bool solvable(MLevel lv) => lv.ints('df').length >= 3;
}

class DiffGame extends MGame {
  late List<SceneItem> items;
  late List<int> diffs, types, alt;
  late int maxMiss;
  final found = <int>{};
  int misses = 0;
  int hintIdx = -1;
  double _miss = 0;
  Offset _missAt = Offset.zero;

  DiffGame(super.lv) {
    items = [for (final e in lv.data['it'] as List) SceneItem.dec(e as List)];
    diffs = lv.ints('df');
    types = lv.ints('ty');
    alt = lv.ints('al');
    maxMiss = lv.i('mx');
  }

  @override
  bool get undoable => false;

  (Rect, Rect) get _panels {
    final wide = size.width > size.height * 1.1;
    if (wide) {
      final w = size.width / 2 - 12;
      final s = math.min(w, size.height - 16);
      return (Rect.fromLTWH(size.width / 4 - s / 2, (size.height - s) / 2, s, s), Rect.fromLTWH(size.width * 3 / 4 - s / 2, (size.height - s) / 2, s, s));
    }
    final h = size.height / 2 - 10;
    final s = math.min(h, size.width - 16);
    return (Rect.fromLTWH((size.width - s) / 2, size.height / 4 - s / 2, s, s), Rect.fromLTWH((size.width - s) / 2, size.height * 3 / 4 - s / 2, s, s));
  }

  @override
  bool down(Offset p) {
    final (a, b) = _panels;
    final area = a.contains(p) ? a : (b.contains(p) ? b : null);
    if (area == null) return false;
    final u = Offset((p.dx - area.left) / area.width, (p.dy - area.top) / area.height);
    for (var k = 0; k < diffs.length; k++) {
      if (found.contains(k)) continue;
      final it = items[diffs[k]];
      if ((u - Offset(it.x, it.y)).distance < it.size * 0.9 + 0.045) {
        found.add(k);
        moves++;
        score += 40;
        bump('pairs_matched');
        hintIdx = -1;
        return true;
      }
    }
    misses++;
    _miss = 0.5;
    _missAt = p;
    return true;
  }

  @override
  bool get won => found.length == diffs.length;
  @override
  bool get lost => !won && misses >= maxMiss;

  @override
  bool continueAfterLoss() {
    maxMiss += 3;
    return true;
  }

  @override
  String status(String lang) => '${mt(lang, 'differences')}: ${found.length} / ${diffs.length} · ✕ $misses/$maxMiss';

  @override
  bool hint() {
    for (var k = 0; k < diffs.length; k++) {
      if (!found.contains(k)) {
        hintIdx = k;
        return true;
      }
    }
    return false;
  }

  @override
  bool booster() => hint();

  @override
  bool step(double dt) {
    if (_miss > 0) {
      _miss -= dt;
      return true;
    }
    return false;
  }

  @override
  void paint(Canvas c, Size size, MPalette p, double t) {
    final (a, b) = _panels;
    for (final (area, right) in [(a, false), (b, true)]) {
      drawSceneBg(c, area, lv.seed, p);
      for (var i = 0; i < items.length; i++) {
        final k = diffs.indexOf(i);
        var it = items[i];
        if (right && k >= 0) {
          switch (types[k]) {
            case 0:
              continue;
            case 1:
              it = SceneItem(it.glyph, (it.color + 3) % 6, it.x, it.y, it.size, it.rot);
            case 2:
              it = SceneItem(alt[k] == it.glyph ? (it.glyph + 1) % kGlyphCount : alt[k], it.color, it.x, it.y, it.size, it.rot);
            default:
              it = SceneItem(it.glyph, it.color, it.x, it.y, it.size * 1.55, it.rot);
          }
        }
        drawItem(c, it, area, p);
      }
      for (final k in found) {
        final it = items[diffs[k]];
        final ctr = Offset(area.left + it.x * area.width, area.top + it.y * area.height);
        c.drawCircle(ctr, (it.size * 0.9 + 0.03) * area.width, Paint()
          ..color = const Color(0xFF2A9D8F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);
      }
      if (hintIdx >= 0) {
        final it = items[diffs[hintIdx]];
        final ctr = Offset(area.left + it.x * area.width, area.top + it.y * area.height);
        c.drawCircle(ctr, (it.size + 0.06) * area.width, Paint()
          ..color = const Color(0xFFFFC94D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5);
      }
    }
    if (_miss > 0) {
      final st = Paint()
        ..color = const Color(0xFFE76F51).withAlpha((_miss * 500).round().clamp(0, 255))
        ..strokeWidth = 5;
      c.drawLine(_missAt.translate(-12, -12), _missAt.translate(12, 12), st);
      c.drawLine(_missAt.translate(12, -12), _missAt.translate(-12, 12), st);
    }
  }

  @override
  Map<String, Object?> save() => {'f': found.toList(), 'ms': misses, 'mx': maxMiss, 'm': moves, 's': score};

  @override
  void load(Map<String, Object?> j) {
    found
      ..clear()
      ..addAll(_l(j['f']));
    misses = (j['ms'] as num).toInt();
    maxMiss = (j['mx'] as num?)?.toInt() ?? lv.i('mx');
    moves = (j['m'] as num).toInt();
    score = (j['s'] as num).toInt();
    hintIdx = -1;
  }
}

// ======================================================================= GİZLİ NESNE

/// Gizli nesne: kalabalık sahnede alttaki listedeki nesneleri bul.
class HiddenKind extends MatchKind {
  @override
  String get id => 'gizli-nesne';
  const HiddenKind();

  @override
  MLevel make(int d, SeededRandom r) {
    final count = 40 + d * 9;
    final items = <SceneItem>[];
    for (var k = 0; k < count; k++) {
      items.add(SceneItem(r.nextInt(kGlyphCount), r.nextInt(6), 0.05 + r.nextDouble() * 0.9, 0.05 + r.nextDouble() * 0.9,
          0.06 + r.nextDouble() * 0.07, r.nextDouble() * 6.28));
    }
    // Hedefler: sahnede tek olan (simge+renk) öğeler.
    final nt = 5 + d ~/ 2;
    final targets = <int>[];
    final idx = [for (var i = 0; i < items.length; i++) i];
    r.shuffle(idx);
    for (final i in idx) {
      if (targets.length >= nt) break;
      final it = items[i];
      final dup = items.where((o) => o.glyph == it.glyph && o.color == it.color).length;
      if (dup == 1 && !targets.any((t) => items[t].glyph == it.glyph)) targets.add(i);
    }
    // Hedefler örtülmesin: listenin sonuna (üste) taşı.
    final order = [for (var i = 0; i < items.length; i++) if (!targets.contains(i)) i, ...targets];
    final remapped = [for (final i in order) items[i]];
    final newTargets = [for (var k = 0; k < targets.length; k++) items.length - targets.length + k];
    return MLevel(id, d, r.nextInt(1 << 30), {
      'it': [for (final it in remapped) it.enc()],
      'tg': newTargets,
      'mx': 4 + (10 - d) ~/ 2,
    });
  }

  @override
  MGame start(MLevel lv) => HiddenGame(lv);

  @override
  bool solvable(MLevel lv) => lv.ints('tg').length >= 4;
}

class HiddenGame extends MGame {
  late List<SceneItem> items;
  late List<int> targets;
  late int maxMiss;
  final found = <int>{};
  int misses = 0;
  int hintIdx = -1;
  double _miss = 0;
  Offset _missAt = Offset.zero;

  HiddenGame(super.lv) {
    items = [for (final e in lv.data['it'] as List) SceneItem.dec(e as List)];
    targets = lv.ints('tg');
    maxMiss = lv.i('mx');
  }

  @override
  bool get undoable => false;

  Rect get _scene {
    final s = math.min(size.width - 12, size.height * 0.8);
    return Rect.fromLTWH((size.width - s) / 2, 6, s, s);
  }

  Rect get _bar => Rect.fromLTWH(8, _scene.bottom + 8, size.width - 16, math.min(size.height - _scene.bottom - 14, 80));

  @override
  bool down(Offset p) {
    final area = _scene;
    if (!area.contains(p)) return false;
    final u = Offset((p.dx - area.left) / area.width, (p.dy - area.top) / area.height);
    for (var i = items.length - 1; i >= 0; i--) {
      final it = items[i];
      if ((u - Offset(it.x, it.y)).distance < it.size * 0.55) {
        final k = targets.indexOf(i);
        if (k >= 0 && !found.contains(k)) {
          found.add(k);
          moves++;
          score += 40;
          bump('pairs_matched');
          hintIdx = -1;
          return true;
        }
        break;
      }
    }
    misses++;
    _miss = 0.5;
    _missAt = p;
    return true;
  }

  @override
  bool get won => found.length == targets.length;
  @override
  bool get lost => !won && misses >= maxMiss;

  @override
  bool continueAfterLoss() {
    maxMiss += 3;
    return true;
  }

  @override
  String status(String lang) => '${mt(lang, 'found')}: ${found.length} / ${targets.length} · ✕ $misses/$maxMiss';

  @override
  bool hint() {
    for (var k = 0; k < targets.length; k++) {
      if (!found.contains(k)) {
        hintIdx = k;
        return true;
      }
    }
    return false;
  }

  @override
  bool booster() => hint();

  @override
  bool step(double dt) {
    if (_miss > 0) {
      _miss -= dt;
      return true;
    }
    return false;
  }

  @override
  void paint(Canvas c, Size size, MPalette p, double t) {
    final area = _scene;
    drawSceneBg(c, area, lv.seed + 5, p);
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(area, const Radius.circular(14)));
    for (var i = 0; i < items.length; i++) {
      final k = targets.indexOf(i);
      if (k >= 0 && found.contains(k)) continue;
      drawItem(c, items[i], area, p);
    }
    if (hintIdx >= 0) {
      final it = items[targets[hintIdx]];
      final ctr = Offset(area.left + it.x * area.width, area.top + it.y * area.height);
      c.drawCircle(ctr, (it.size + 0.05) * area.width, Paint()
        ..color = const Color(0xFFFFC94D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5);
    }
    c.restore();
    // Aranan listesi
    final bar = _bar;
    c.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(14)), Paint()..color = p.surface.withAlpha(235));
    final w = bar.width / targets.length;
    for (var k = 0; k < targets.length; k++) {
      final it = items[targets[k]];
      final r = Rect.fromCenter(center: Offset(bar.left + w * (k + 0.5), bar.center.dy), width: math.min(w, bar.height) * 0.62, height: math.min(w, bar.height) * 0.62);
      drawGlyph(c, it.glyph, r, p.piece(it.color).withAlpha(found.contains(k) ? 70 : 255), outline: true);
      if (found.contains(k)) drawText(c, '✓', r.center, r.width * 0.7, const Color(0xFF2A9D8F));
    }
    if (_miss > 0) {
      final st = Paint()
        ..color = const Color(0xFFE76F51).withAlpha((_miss * 500).round().clamp(0, 255))
        ..strokeWidth = 5;
      c.drawLine(_missAt.translate(-12, -12), _missAt.translate(12, 12), st);
      c.drawLine(_missAt.translate(12, -12), _missAt.translate(-12, 12), st);
    }
  }

  @override
  Map<String, Object?> save() => {'f': found.toList(), 'ms': misses, 'mx': maxMiss, 'm': moves, 's': score};

  @override
  void load(Map<String, Object?> j) {
    found
      ..clear()
      ..addAll(_l(j['f']));
    misses = (j['ms'] as num).toInt();
    maxMiss = (j['mx'] as num?)?.toInt() ?? lv.i('mx');
    moves = (j['m'] as num).toInt();
    score = (j['s'] as num).toInt();
    hintIdx = -1;
  }
}
