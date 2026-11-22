import 'dart:math' as math;
import 'dart:ui';

import 'package:studio_core/core/rng.dart';
import 'package:studio_core/core/stats.dart';
import 'package:studio_core/core/missions.dart';

import '../core.dart';
import '../glyphs.dart';
import '../texts.dart';

/// Izgara yerleşimi.
class GridGeo {
  final double cs, ox, oy;
  final int w, h;
  GridGeo(this.cs, this.ox, this.oy, this.w, this.h);

  factory GridGeo.fit(int w, int h, Rect area, {double margin = 0, double maxCell = 90}) {
    final cs = math.min(maxCell, math.min((area.width - 12) / (w + margin * 2), (area.height - 12) / (h + margin * 2)));
    return GridGeo(cs, area.left + (area.width - cs * w) / 2, area.top + (area.height - cs * h) / 2, w, h);
  }

  Rect cell(int i) => Rect.fromLTWH(ox + (i % w) * cs, oy + (i ~/ w) * cs, cs, cs);
  Offset center(int x, int y) => Offset(ox + (x + 0.5) * cs, oy + (y + 0.5) * cs);

  int? at(Offset p) {
    final x = ((p.dx - ox) / cs).floor(), y = ((p.dy - oy) / cs).floor();
    if (x < 0 || y < 0 || x >= w || y >= h) return null;
    return y * w + x;
  }
}

List<int> _l(Object? o) => [for (final v in (o as List)) (v as num).toInt()];

// ======================================================================= ONET

/// Bağlantılı eşleştirme: en fazla iki dönüşlü boş bir yolla birleşen
/// iki aynı taşı kaldır (yol tahtanın dışından da geçebilir).
class OnetKind extends MatchKind {
  @override
  String get id => 'onet';
  const OnetKind();

  @override
  MLevel make(int d, SeededRandom r) {
    final w = 4 + (d + 1) ~/ 2, h = 4 + d ~/ 2 + (d >= 6 ? 2 : 0);
    final n = (w * h) ~/ 2 * 2;
    final faces = math.min(n ~/ 2, 6 + d * 2);
    for (var attempt = 0; attempt < 60; attempt++) {
      final cells = <int>[for (var k = 0; k < n ~/ 2; k++) ...[k % faces, k % faces]];
      while (cells.length < w * h) {
        cells.add(-1);
      }
      r.shuffle(cells);
      final lv = MLevel(id, d, r.nextInt(1 << 30), {'w': w, 'h': h, 'c': cells});
      if (solvable(lv)) return lv;
    }
    throw StateError('onet');
  }

  @override
  MGame start(MLevel lv) => OnetGame(lv);

  @override
  bool solvable(MLevel lv) {
    for (var pass = 0; pass < 4; pass++) {
      final g = OnetGame(lv);
      final r = SeededRandom(mixSeed([lv.seed, pass]));
      while (!g.won) {
        final ps = g.pairs();
        if (ps.isEmpty) break;
        final pk = pass == 0 ? ps.first : ps[r.nextInt(ps.length)];
        g.remove(pk.$1, pk.$2);
      }
      if (g.won) return true;
    }
    return false;
  }
}

class OnetGame extends MGame {
  late int w, h;
  late List<int> c;
  int? sel;
  List<int> hintTiles = [];
  List<Offset> _path = [];
  double _pathT = 0;
  int shuffles = 0;

  OnetGame(super.lv) {
    w = lv.i('w');
    h = lv.i('h');
    c = lv.ints('c');
  }

  int get left => c.where((v) => v >= 0).length;

  /// (x,y) dış çerçeve dahil koordinat (-1..w).
  bool _empty(int x, int y) => x < 0 || y < 0 || x >= w || y >= h || c[y * w + x] < 0;

  /// En fazla iki dönüşlü yol: köşe noktalarını döndürür (yoksa null).
  List<(int, int)>? link(int a, int b) {
    if (a == b || c[a] < 0 || c[a] != c[b]) return null;
    final ax = a % w, ay = a ~/ w, bx = b % w, by = b ~/ w;
    bool clearH(int y, int x1, int x2) {
      final lo = math.min(x1, x2), hi = math.max(x1, x2);
      for (var x = lo + 1; x < hi; x++) {
        if (!_empty(x, y)) return false;
      }
      return true;
    }

    bool clearV(int x, int y1, int y2) {
      final lo = math.min(y1, y2), hi = math.max(y1, y2);
      for (var y = lo + 1; y < hi; y++) {
        if (!_empty(x, y)) return false;
      }
      return true;
    }

    // Düz
    if (ay == by && clearH(ay, ax, bx)) return [(ax, ay), (bx, by)];
    if (ax == bx && clearV(ax, ay, by)) return [(ax, ay), (bx, by)];
    // Tek dönüş
    if (_empty(bx, ay) && clearH(ay, ax, bx) && clearV(bx, ay, by)) return [(ax, ay), (bx, ay), (bx, by)];
    if (_empty(ax, by) && clearV(ax, ay, by) && clearH(by, ax, bx)) return [(ax, ay), (ax, by), (bx, by)];
    // İki dönüş: ara sütun ya da satır (çerçeve dahil)
    for (var x = -1; x <= w; x++) {
      if (x == ax || x == bx) continue;
      if (_empty(x, ay) && _empty(x, by) && clearH(ay, ax, x) && clearV(x, ay, by) && clearH(by, x, bx)) {
        return [(ax, ay), (x, ay), (x, by), (bx, by)];
      }
    }
    for (var y = -1; y <= h; y++) {
      if (y == ay || y == by) continue;
      if (_empty(ax, y) && _empty(bx, y) && clearV(ax, ay, y) && clearH(y, ax, bx) && clearV(bx, y, by)) {
        return [(ax, ay), (ax, y), (bx, y), (bx, by)];
      }
    }
    return null;
  }

  List<(int, int)> pairs() {
    final out = <(int, int)>[];
    for (var a = 0; a < c.length; a++) {
      if (c[a] < 0) continue;
      for (var b = a + 1; b < c.length; b++) {
        if (c[b] == c[a] && link(a, b) != null) out.add((a, b));
      }
    }
    return out;
  }

  void remove(int a, int b) {
    c[a] = -1;
    c[b] = -1;
    moves++;
    score += 20;
    bump('pairs_matched');
  }

  GridGeo get _geo => GridGeo.fit(w, h, Offset.zero & size, margin: 0.6);

  @override
  bool down(Offset p) {
    final geo = _geo;
    final i = geo.at(p);
    if (i == null || c[i] < 0) return false;
    hintTiles = [];
    if (sel == null || sel == i) {
      sel = sel == i ? null : i;
      return true;
    }
    final path = link(sel!, i);
    if (path != null) {
      _path = [for (final (x, y) in path) geo.center(x, y)];
      _pathT = 0.35;
      remove(sel!, i);
      sel = null;
      return true;
    }
    sel = i;
    return true;
  }

  @override
  bool get won => left == 0;
  @override
  bool get lost => left > 0 && _pathT <= 0 && pairs().isEmpty;

  @override
  bool continueAfterLoss() => booster();

  @override
  String status(String lang) => '${mt(lang, 'pairs')}: ${left ~/ 2}';

  @override
  bool hint() {
    final p = pairs();
    if (p.isEmpty) return false;
    hintTiles = [p.first.$1, p.first.$2];
    return true;
  }

  @override
  bool booster() {
    final r = SeededRandom(mixSeed([lv.seed, 91, ++shuffles]));
    final idx = [for (var i = 0; i < c.length; i++) if (c[i] >= 0) i];
    final vals = [for (final i in idx) c[i]];
    for (var k = 0; k < 30; k++) {
      r.shuffle(vals);
      for (var j = 0; j < idx.length; j++) {
        c[idx[j]] = vals[j];
      }
      if (pairs().isNotEmpty) break;
    }
    sel = null;
    hintTiles = [];
    return true;
  }

  @override
  bool step(double dt) {
    if (_pathT > 0) {
      _pathT -= dt;
      return true;
    }
    return false;
  }

  @override
  void paint(Canvas cv, Size size, MPalette p, double t) {
    final geo = _geo;
    for (var i = 0; i < c.length; i++) {
      if (c[i] < 0) continue;
      drawTile(cv, geo.cell(i).deflate(geo.cs * 0.04), c[i], p, selected: sel == i, hint: hintTiles.contains(i), depth: geo.cs * 0.06);
    }
    if (_pathT > 0 && _path.length > 1) {
      final path = Path()..moveTo(_path.first.dx, _path.first.dy);
      for (final o in _path.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      cv.drawPath(
          path,
          Paint()
            ..color = p.accent.withAlpha((255 * (_pathT / 0.35)).round().clamp(0, 255))
            ..style = PaintingStyle.stroke
            ..strokeWidth = geo.cs * 0.12
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);
    }
  }

  @override
  Map<String, Object?> save() => {'c': List.of(c), 'm': moves, 's': score, 'sh': shuffles};

  @override
  void load(Map<String, Object?> j) {
    c = _l(j['c']);
    moves = (j['m'] as num).toInt();
    score = (j['s'] as num).toInt();
    shuffles = (j['sh'] as num?)?.toInt() ?? 0;
    sel = null;
    hintTiles = [];
    _pathT = 0;
  }
}

// ======================================================================= ortak: renk grupları

/// Altıgen ızgara (sütunlar, tek sütunlar yarım hücre aşağıda) komşulukları.
List<(int, int)> hexNeighbors(int x) => x.isOdd
    ? const [(0, -1), (0, 1), (-1, 0), (1, 0), (-1, 1), (1, 1)]
    : const [(0, -1), (0, 1), (-1, -1), (1, -1), (-1, 0), (1, 0)];

List<int> groupAt(List<int> c, int w, int h, int i, {bool hex = false}) {
  final col = c[i];
  if (col < 0) return const [];
  final seen = <int>{i};
  final stack = [i];
  while (stack.isNotEmpty) {
    final k = stack.removeLast();
    final x = k % w, y = k ~/ w;
    for (final (dx, dy) in hex ? hexNeighbors(x) : const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
      final j = ny * w + nx;
      if (c[j] == col && seen.add(j)) stack.add(j);
    }
  }
  return seen.toList();
}

/// Bütün gruplar (en az [min] hücre).
List<List<int>> allGroups(List<int> c, int w, int h, int min, {bool hex = false}) {
  final seen = <int>{};
  final out = <List<int>>[];
  for (var i = 0; i < c.length; i++) {
    if (c[i] < 0 || seen.contains(i)) continue;
    final g = groupAt(c, w, h, i, hex: hex);
    seen.addAll(g);
    if (g.length >= min) out.add(g);
  }
  return out;
}

/// Altıgen blok (düz üstlü).
void drawHex(Canvas cv, Rect r, int col, MPalette p, {bool hint = false, int special = 0}) {
  final ctr = r.center;
  final rad = r.width * 0.56;
  final path = Path();
  for (var k = 0; k < 6; k++) {
    final a = k * math.pi / 3;
    final o = ctr + Offset(math.cos(a), math.sin(a)) * rad;
    if (k == 0) {
      path.moveTo(o.dx, o.dy);
    } else {
      path.lineTo(o.dx, o.dy);
    }
  }
  path.close();
  cv.drawPath(path, Paint()..color = p.piece(col));
  cv.drawPath(path, Paint()
    ..color = const Color(0x55FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = r.width * 0.05);
  if (p.colorBlind) drawGlyph(cv, col * 3 % kGlyphCount, r.deflate(r.width * 0.3), const Color(0xCCFFFFFF));
  if (special == 1) {
    cv.drawCircle(ctr, r.width * 0.3, Paint()..color = const Color(0xFF2E2A28));
    drawGlyph(cv, 4, Rect.fromCircle(center: ctr, radius: r.width * 0.2), const Color(0xFFFFD166));
  }
  if (hint) {
    cv.drawPath(path, Paint()
      ..color = const Color(0xFFFFC94D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r.width * 0.1);
  }
}

void drawBlock(Canvas cv, Rect r, int col, MPalette p, {bool hint = false, int special = 0}) {
  final rr = RRect.fromRectAndRadius(r.deflate(r.width * 0.05), Radius.circular(r.width * 0.2));
  final color = p.piece(col);
  cv.drawRRect(rr, Paint()..color = color);
  cv.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(rr.left + r.width * 0.12, rr.top + r.width * 0.1, rr.width * 0.5, r.width * 0.18), Radius.circular(r.width * 0.1)),
      Paint()..color = const Color(0x40FFFFFF));
  if (p.colorBlind) drawGlyph(cv, col * 3 % kGlyphCount, r.deflate(r.width * 0.3), const Color(0xCCFFFFFF));
  if (special == 1) {
    // Bomba: koyu daire + kıvılcım
    cv.drawCircle(r.center, r.width * 0.32, Paint()..color = const Color(0xFF2E2A28));
    drawGlyph(cv, 4, Rect.fromCircle(center: r.center, radius: r.width * 0.2), const Color(0xFFFFD166));
  }
  if (hint) {
    cv.drawRRect(
        rr,
        Paint()
          ..color = const Color(0xFFFFC94D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r.width * 0.1);
  }
}

// ======================================================================= SAMEGAME

/// Blok patlatma: iki ya da daha fazla aynı renkli bitişik bloğa dokun;
/// bloklar düşer, boş sütunlar kapanır. Hedef puana ulaş.
class SameKind extends MatchKind {
  @override
  String get id => 'samegame';
  const SameKind();

  @override
  List<GameStat> get stats => const [
        GameStat('rounds_won', 'Kazanılan bölüm', 'Levels won', scale: 10),
        GameStat('pairs_matched', 'Patlatılan grup', 'Groups popped', scale: 500),
        GameStat('blocks_popped', 'Patlatılan blok', 'Blocks popped', scale: 3000),
      ];

  @override
  MLevel make(int d, SeededRandom r) {
    final w = 6 + d ~/ 2, h = 7 + d ~/ 2, k = d <= 2 ? 3 : (d <= 6 ? 4 : 5);
    final c = [for (var i = 0; i < w * h; i++) r.nextInt(k)];
    final g = SameGame(MLevel(id, d, 0, {'w': w, 'h': h, 'c': c, 't': 0}));
    while (true) {
      final gs = allGroups(g.c, w, h, 2);
      if (gs.isEmpty) break;
      gs.sort((a, b) => b.length.compareTo(a.length));
      g.pop(gs.first);
    }
    final target = (g.score * (0.95 - d * 0.02)).round();
    return MLevel(id, d, r.nextInt(1 << 30), {'w': w, 'h': h, 'c': c, 't': math.max(20, target)});
  }

  @override
  MGame start(MLevel lv) => SameGame(lv);

  @override
  bool solvable(MLevel lv) {
    final g = SameGame(lv);
    while (true) {
      final gs = allGroups(g.c, g.w, g.h, 2);
      if (gs.isEmpty) break;
      gs.sort((a, b) => b.length.compareTo(a.length));
      g.pop(gs.first);
    }
    return g.won;
  }
}

class SameGame extends MGame {
  late int w, h, target;
  late List<int> c;
  List<int> hintTiles = [];
  final _fx = <(Rect, int, double)>[];

  SameGame(super.lv) {
    w = lv.i('w');
    h = lv.i('h');
    c = lv.ints('c');
    target = lv.i('t');
  }

  void pop(List<int> g) {
    for (final i in g) {
      c[i] = -1;
    }
    score += (g.length - 1) * (g.length - 1) * 5;
    moves++;
    bump('pairs_matched');
    bump('blocks_popped', g.length);
    // Yerçekimi
    for (var x = 0; x < w; x++) {
      final col = [for (var y = h - 1; y >= 0; y--) if (c[y * w + x] >= 0) c[y * w + x]];
      for (var y = h - 1, k = 0; y >= 0; y--, k++) {
        c[y * w + x] = k < col.length ? col[k] : -1;
      }
    }
    // Boş sütunlar sola kapanır
    final cols = [for (var x = 0; x < w; x++) if (c[(h - 1) * w + x] >= 0) x];
    final copy = List.of(c);
    for (var i = 0; i < c.length; i++) {
      c[i] = -1;
    }
    for (var k = 0; k < cols.length; k++) {
      for (var y = 0; y < h; y++) {
        c[y * w + k] = copy[y * w + cols[k]];
      }
    }
    // Tahta temizlenirse ödül
    if (c.every((v) => v < 0)) score += 500;
  }

  GridGeo get _geo => GridGeo.fit(w, h, Offset.zero & size);

  bool get _noMoves => allGroups(c, w, h, 2).isEmpty;

  @override
  bool down(Offset p) {
    final geo = _geo;
    final i = geo.at(p);
    if (i == null || c[i] < 0) return false;
    final g = groupAt(c, w, h, i);
    if (g.length < 2) return false;
    for (final k in g) {
      _fx.add((geo.cell(k), c[k], 0));
    }
    pop(g);
    hintTiles = [];
    return true;
  }

  @override
  bool get won => _noMoves && score >= target;
  @override
  bool get lost => _noMoves && score < target && _fx.isEmpty;

  @override
  String status(String lang) => '${mt(lang, 'score')}: $score / $target';

  @override
  bool hint() {
    final gs = allGroups(c, w, h, 2);
    if (gs.isEmpty) return false;
    gs.sort((a, b) => b.length.compareTo(a.length));
    hintTiles = gs.first;
    return true;
  }

  /// Karıştır: kalan blokların renklerini yeniden dağıt.
  @override
  bool booster() {
    final idx = [for (var i = 0; i < c.length; i++) if (c[i] >= 0) i];
    if (idx.length < 2) return false;
    final vals = [for (final i in idx) c[i]];
    final r = SeededRandom(mixSeed([lv.seed, moves, 33]));
    r.shuffle(vals);
    for (var k = 0; k < idx.length; k++) {
      c[idx[k]] = vals[k];
    }
    return true;
  }

  @override
  bool continueAfterLoss() {
    // Devam: hedef puanı %10 düşür.
    target = (target * 0.9).round();
    return true;
  }

  @override
  bool step(double dt) {
    for (var k = _fx.length - 1; k >= 0; k--) {
      final f = _fx[k];
      final t = f.$3 + dt * 4;
      if (t >= 1) {
        _fx.removeAt(k);
      } else {
        _fx[k] = (f.$1, f.$2, t);
      }
    }
    return _fx.isNotEmpty;
  }

  @override
  void paint(Canvas cv, Size size, MPalette p, double t) {
    final geo = _geo;
    for (var i = 0; i < c.length; i++) {
      if (c[i] >= 0) drawBlock(cv, geo.cell(i), c[i], p, hint: hintTiles.contains(i));
    }
    for (final f in _fx) {
      final r = Rect.fromCenter(center: f.$1.center, width: f.$1.width * (1 - f.$3), height: f.$1.height * (1 - f.$3));
      drawBlock(cv, r, f.$2, p);
    }
  }

  @override
  Map<String, Object?> save() => {'c': List.of(c), 'm': moves, 's': score, 't': target};

  @override
  void load(Map<String, Object?> j) {
    c = _l(j['c']);
    moves = (j['m'] as num).toInt();
    score = (j['s'] as num).toInt();
    target = (j['t'] as num?)?.toInt() ?? lv.i('t');
    hintTiles = [];
    _fx.clear();
  }
}

// ======================================================================= GRUP PATLATMA

/// Hedefli grup patlatma: belirtilen renklerden istenen sayıda bloğu
/// sınırlı hamlede topla. 6+ grup bomba bırakır (3×3 patlatır).
class BlastKind extends MatchKind {
  @override
  final String id;
  final bool hex;
  const BlastKind({this.id = 'grup-patlatma', this.hex = false});

  @override
  MLevel make(int d, SeededRandom r) {
    final w = 7 + (d >= 5 ? 1 : 0), h = 8 + (d >= 7 ? 1 : 0), k = d <= 3 ? 4 : 5;
    final c = [for (var i = 0; i < w * h; i++) r.nextInt(k)];
    final gcols = <int>[r.nextInt(k)];
    if (d >= 3) {
      var g2 = r.nextInt(k);
      while (g2 == gcols.first) {
        g2 = r.nextInt(k);
      }
      gcols.add(g2);
    }
    final per = 10 + d * 4;
    final base = MLevel(id, d, r.nextInt(1 << 30),
        {'w': w, 'h': h, 'k': k, 'c': c, 'gc': gcols, 'gn': [for (final _ in gcols) per], 'mv': 999, 'hex': hex ? 1 : 0});
    final g = BlastGame(base);
    var used = 0;
    while (!g.goalsMet && used < 200) {
      g.botMove();
      used++;
    }
    final limit = (used * (1.7 - d * 0.06)).ceil() + 2;
    return MLevel(id, d, base.seed, {...base.data, 'mv': limit});
  }

  @override
  MGame start(MLevel lv) => BlastGame(lv);

  @override
  bool solvable(MLevel lv) {
    final g = BlastGame(lv);
    while (!g.won && !g.lost) {
      g.botMove();
    }
    return g.won;
  }
}

class BlastGame extends MGame {
  late int w, h, k, movesLeft;
  late bool hex;
  int get minGroup => hex ? 3 : 2;
  late List<int> c, special, goalCol, goalLeft;
  int refill = 0;
  List<int> hintTiles = [];
  final _fx = <(Rect, int, double)>[];

  BlastGame(super.lv) {
    w = lv.i('w');
    h = lv.i('h');
    k = lv.i('k');
    c = lv.ints('c');
    special = List.filled(c.length, 0);
    goalCol = lv.ints('gc');
    goalLeft = lv.ints('gn');
    movesLeft = lv.i('mv');
    hex = lv.i('hex') == 1;
  }

  bool get goalsMet => goalLeft.every((n) => n <= 0);

  int _newColor() => SeededRandom(mixSeed([lv.seed, refill++, 5])).nextInt(k);

  void _collect(int col) {
    final gi = goalCol.indexOf(col);
    if (gi >= 0 && goalLeft[gi] > 0) goalLeft[gi]--;
  }

  /// Hücreye dokunuş: grup ya da bomba.
  bool tapCell(int i, {GridGeo? geo}) {
    if (c[i] < 0) return false;
    List<int> gone;
    var bombAt = -1;
    if (special[i] == 1) {
      final x = i % w, y = i ~/ w;
      gone = [
        for (var dy = -1; dy <= 1; dy++)
          for (var dx = -1; dx <= 1; dx++)
            if (x + dx >= 0 && x + dx < w && y + dy >= 0 && y + dy < h) (y + dy) * w + x + dx
      ];
    } else {
      gone = groupAt(c, w, h, i, hex: hex).where((j) => special[j] == 0).toList();
      if (gone.length < minGroup) return false;
      if (gone.length >= 6) bombAt = i;
    }
    for (final j in gone) {
      if (c[j] < 0) continue;
      if (geo != null) _fx.add((_cell(geo, j), c[j], 0));
      _collect(c[j]);
      c[j] = -1;
      special[j] = 0;
    }
    if (bombAt >= 0) {
      c[bombAt] = 0;
      special[bombAt] = 1;
    }
    score += gone.length * 10;
    bump('pairs_matched');
    bump('blocks_popped', gone.length);
    moves++;
    movesLeft--;
    _gravity();
    if (allGroups(c, w, h, minGroup, hex: hex).isEmpty && !special.contains(1)) _shuffle();
    return true;
  }

  void _gravity() {
    for (var x = 0; x < w; x++) {
      final col = <(int, int)>[for (var y = h - 1; y >= 0; y--) if (c[y * w + x] >= 0) (c[y * w + x], special[y * w + x])];
      for (var y = h - 1, n = 0; y >= 0; y--, n++) {
        if (n < col.length) {
          c[y * w + x] = col[n].$1;
          special[y * w + x] = col[n].$2;
        } else {
          c[y * w + x] = _newColor();
          special[y * w + x] = 0;
        }
      }
    }
  }

  void _shuffle() {
    final r = SeededRandom(mixSeed([lv.seed, refill++, 71]));
    for (var t = 0; t < 20; t++) {
      r.shuffle(c);
      if (allGroups(c, w, h, minGroup, hex: hex).isNotEmpty) return;
    }
  }

  void botMove() {
    final bomb = special.indexOf(1);
    if (bomb >= 0) {
      tapCell(bomb);
      return;
    }
    final gs = allGroups(c, w, h, minGroup, hex: hex);
    if (gs.isEmpty) {
      _shuffle();
      movesLeft--;
      return;
    }
    int value(List<int> g) {
      final col = c[g.first];
      final gi = goalCol.indexOf(col);
      return (gi >= 0 && goalLeft[gi] > 0 ? 100 : 0) + g.length;
    }

    gs.sort((a, b) => value(b).compareTo(value(a)));
    tapCell(gs.first.first);
  }

  GridGeo get _geo => GridGeo.fit(w, h + (hex ? 1 : 0), Rect.fromLTWH(0, size.height * 0.1, size.width, size.height * 0.9));

  Rect _cell(GridGeo geo, int i) {
    final r = geo.cell(i);
    return hex && (i % w).isOdd ? r.translate(0, geo.cs / 2) : r;
  }

  int? _at(GridGeo geo, Offset p) {
    if (!hex) return geo.at(p);
    for (var i = 0; i < c.length; i++) {
      final r = _cell(geo, i);
      if ((p - r.center).distance < geo.cs * 0.5) return i;
    }
    return null;
  }

  @override
  bool down(Offset p) {
    final geo = _geo;
    final i = _at(geo, p);
    if (i == null) return false;
    hintTiles = [];
    return tapCell(i, geo: geo);
  }

  @override
  bool get won => goalsMet;
  @override
  bool get lost => !goalsMet && movesLeft <= 0 && _fx.isEmpty;

  @override
  bool continueAfterLoss() {
    movesLeft += 5;
    return true;
  }

  @override
  String status(String lang) => '${mt(lang, 'moves')}: $movesLeft';

  @override
  bool hint() {
    final gs = allGroups(c, w, h, minGroup, hex: hex);
    if (gs.isEmpty) return false;
    gs.sort((a, b) => b.length.compareTo(a.length));
    final goal = gs.where((g) => goalCol.contains(c[g.first])).toList();
    hintTiles = (goal.isNotEmpty ? goal.first : gs.first);
    return true;
  }

  @override
  bool booster() {
    movesLeft += 3;
    return true;
  }

  @override
  String boosterKey() => 'slot';

  @override
  bool step(double dt) {
    for (var n = _fx.length - 1; n >= 0; n--) {
      final f = _fx[n];
      final t = f.$3 + dt * 4;
      if (t >= 1) {
        _fx.removeAt(n);
      } else {
        _fx[n] = (f.$1, f.$2, t);
      }
    }
    return _fx.isNotEmpty;
  }

  @override
  void paint(Canvas cv, Size size, MPalette p, double t) {
    // Hedefler üstte
    final top = size.height * 0.1;
    final gw = math.min(120.0, size.width / (goalCol.length + 1));
    for (var g = 0; g < goalCol.length; g++) {
      final ctr = Offset(size.width / 2 + (g - (goalCol.length - 1) / 2) * gw, top / 2);
      drawBlock(cv, Rect.fromCenter(center: ctr.translate(-gw * 0.2, 0), width: top * 0.6, height: top * 0.6), goalCol[g], p);
      drawText(cv, goalLeft[g] <= 0 ? '✓' : '${goalLeft[g]}', ctr.translate(gw * 0.22, 0), top * 0.35, p.ink);
    }
    final geo = _geo;
    for (var i = 0; i < c.length; i++) {
      if (c[i] < 0) continue;
      if (hex) {
        drawHex(cv, _cell(geo, i), c[i], p, hint: hintTiles.contains(i), special: special[i]);
      } else {
        drawBlock(cv, geo.cell(i), c[i], p, hint: hintTiles.contains(i), special: special[i]);
      }
    }
    for (final f in _fx) {
      final r = Rect.fromCenter(center: f.$1.center, width: f.$1.width * (1 - f.$3), height: f.$1.height * (1 - f.$3));
      drawBlock(cv, r, f.$2, p);
    }
  }

  @override
  Map<String, Object?> save() => {'c': List.of(c), 'sp': List.of(special), 'gl': List.of(goalLeft), 'ml': movesLeft, 'rf': refill, 'm': moves, 's': score};

  @override
  void load(Map<String, Object?> j) {
    c = _l(j['c']);
    special = _l(j['sp']);
    goalLeft = _l(j['gl']);
    movesLeft = (j['ml'] as num).toInt();
    refill = (j['rf'] as num).toInt();
    moves = (j['m'] as num).toInt();
    score = (j['s'] as num).toInt();
    hintTiles = [];
    _fx.clear();
  }
}

// ======================================================================= RENK DOLDURMA

/// Renk doldurma: sol üst köşeden başlayan alanı renk seçerek büyüt;
/// sınırlı hamlede bütün tahtayı tek renk yap.
class FloodKind extends MatchKind {
  @override
  String get id => 'renk-doldurma';
  const FloodKind();

  @override
  MLevel make(int d, SeededRandom r) {
    final n = 6 + d, k = d <= 3 ? 4 : (d <= 7 ? 5 : 6);
    final c = [for (var i = 0; i < n * n; i++) r.nextInt(k)];
    final g = FloodGame(MLevel(id, d, 0, {'n': n, 'k': k, 'c': c, 'mv': 999}));
    var used = 0;
    while (!g.won && used < 200) {
      g.fill(g.botColor());
      used++;
    }
    final slack = d <= 2 ? 4 : (d <= 5 ? 2 : (d <= 8 ? 1 : 0));
    return MLevel(id, d, r.nextInt(1 << 30), {'n': n, 'k': k, 'c': c, 'mv': used + slack});
  }

  @override
  MGame start(MLevel lv) => FloodGame(lv);

  @override
  bool solvable(MLevel lv) {
    final g = FloodGame(lv);
    while (!g.won && !g.lost) {
      g.fill(g.botColor());
    }
    return g.won;
  }
}

class FloodGame extends MGame {
  late int n, k, limit;
  late List<int> c;

  FloodGame(super.lv) {
    n = lv.i('n');
    k = lv.i('k');
    c = lv.ints('c');
    limit = lv.i('mv');
  }

  List<int> region() => groupAt(c, n, n, 0);

  void fill(int col) {
    if (col == c[0]) return;
    for (final i in region()) {
      c[i] = col;
    }
    moves++;
    bump('pairs_matched');
  }

  int botColor() {
    var best = c[0] == 0 ? 1 : 0, bestSize = -1;
    for (var col = 0; col < k; col++) {
      if (col == c[0]) continue;
      final copy = List.of(c);
      for (final i in groupAt(copy, n, n, 0)) {
        copy[i] = col;
      }
      final s = groupAt(copy, n, n, 0).length;
      if (s > bestSize) {
        bestSize = s;
        best = col;
      }
    }
    return best;
  }

  double get _btn => math.min(64.0, size.width / (k + 1));
  GridGeo get _geo => GridGeo.fit(n, n, Rect.fromLTWH(0, 0, size.width, size.height - _btn * 1.5));
  Rect _button(int col) {
    final b = _btn;
    final total = b * k;
    return Rect.fromLTWH((size.width - total) / 2 + col * b, size.height - b * 1.25, b * 0.9, b * 0.9);
  }

  int hintColor = -1;

  @override
  bool down(Offset p) {
    for (var col = 0; col < k; col++) {
      if (_button(col).contains(p)) {
        if (col == c[0]) return false;
        fill(col);
        hintColor = -1;
        return true;
      }
    }
    // Tahtaya dokunmak da o rengi seçer.
    final i = _geo.at(p);
    if (i != null && c[i] != c[0]) {
      fill(c[i]);
      hintColor = -1;
      return true;
    }
    return false;
  }

  @override
  bool get won => c.every((v) => v == c[0]);
  @override
  bool get lost => !won && moves >= limit;

  @override
  bool continueAfterLoss() {
    limit += 3;
    return true;
  }

  @override
  String status(String lang) => '${mt(lang, 'moves')}: ${limit - moves}';

  @override
  bool hint() {
    hintColor = botColor();
    return true;
  }

  @override
  bool booster() {
    limit += 2;
    return true;
  }

  @override
  String boosterKey() => 'slot';

  @override
  void paint(Canvas cv, Size size, MPalette p, double t) {
    final geo = _geo;
    final reg = region().toSet();
    for (var i = 0; i < c.length; i++) {
      final r = geo.cell(i);
      cv.drawRect(r.inflate(0.5), Paint()..color = p.piece(c[i]));
      if (p.colorBlind) drawGlyph(cv, c[i] * 3 % kGlyphCount, r.deflate(r.width * 0.32), const Color(0x88FFFFFF));
    }
    // Ele geçirilen alanın çevresi
    final edge = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = math.max(2, geo.cs * 0.08);
    for (final i in reg) {
      final r = geo.cell(i);
      final x = i % n, y = i ~/ n;
      if (x == n - 1 || !reg.contains(i + 1)) cv.drawLine(r.topRight, r.bottomRight, edge);
      if (y == n - 1 || !reg.contains(i + n)) cv.drawLine(r.bottomLeft, r.bottomRight, edge);
    }
    for (var col = 0; col < k; col++) {
      final r = _button(col);
      cv.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.25)), Paint()..color = p.piece(col));
      if (p.colorBlind) drawGlyph(cv, col * 3 % kGlyphCount, r.deflate(r.width * 0.28), const Color(0xCCFFFFFF));
      if (col == hintColor || col == c[0]) {
        cv.drawRRect(
            RRect.fromRectAndRadius(r.inflate(3), Radius.circular(r.width * 0.28)),
            Paint()
              ..color = col == hintColor ? const Color(0xFFFFC94D) : p.ink.withAlpha(90)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4);
      }
    }
  }

  @override
  Map<String, Object?> save() => {'c': List.of(c), 'm': moves, 'l': limit};

  @override
  void load(Map<String, Object?> j) {
    c = _l(j['c']);
    moves = (j['m'] as num).toInt();
    limit = (j['l'] as num?)?.toInt() ?? lv.i('mv');
    hintColor = -1;
  }
}

// ======================================================================= ÇİFT BUL

/// Hafıza: kartları ikişer çevir, aynı resimleri bul. Hamle sınırı var.
class PairsKind extends MatchKind {
  @override
  String get id => 'cift-bul';
  const PairsKind();

  @override
  MLevel make(int d, SeededRandom r) {
    final pairs = 4 + d * 2;
    final w = pairs <= 8 ? 4 : (pairs <= 12 ? 5 : 6);
    final cards = [for (var k = 0; k < pairs; k++) ...[k * 5 % 48, k * 5 % 48]];
    r.shuffle(cards);
    final limit = pairs * 2 + (12 - d) * 2;
    return MLevel(id, d, r.nextInt(1 << 30), {'w': w, 'c': cards, 'mv': limit});
  }

  @override
  MGame start(MLevel lv) => PairsGame(lv);

  // Kusursuz hafızalı oyuncu en çok 2n-1 hamlede bitirir; sınır her zaman daha büyük.
  @override
  bool solvable(MLevel lv) => lv.i('mv') >= lv.ints('c').length;
}

class PairsGame extends MGame {
  late int w, h, limit;
  late List<int> c;
  late List<bool> done;
  final open = <int>[];
  double _wait = 0;
  int _peek = -1;
  double _peekT = 0;

  PairsGame(super.lv) {
    c = lv.ints('c');
    w = lv.i('w');
    h = (c.length / w).ceil();
    done = List.filled(c.length, false);
    limit = lv.i('mv');
  }

  @override
  bool get undoable => false;

  GridGeo get _geo => GridGeo.fit(w, h, Offset.zero & size, maxCell: 120);

  @override
  bool down(Offset p) {
    if (_wait > 0) return false;
    final i = _geo.at(p);
    if (i == null || i >= c.length || done[i] || open.contains(i)) return false;
    open.add(i);
    if (open.length == 2) {
      moves++;
      if (c[open[0]] == c[open[1]]) {
        done[open[0]] = true;
        done[open[1]] = true;
        open.clear();
        score += 25;
        bump('pairs_matched');
      } else {
        _wait = 0.8;
      }
    }
    return true;
  }

  @override
  bool step(double dt) {
    if (_peekT > 0) _peekT -= dt;
    if (_wait > 0) {
      _wait -= dt;
      if (_wait <= 0) open.clear();
      return true;
    }
    return _peekT > 0;
  }

  @override
  bool get won => done.every((x) => x);
  @override
  bool get lost => !won && moves >= limit && _wait <= 0;

  @override
  bool continueAfterLoss() {
    limit += 6;
    return true;
  }

  @override
  String status(String lang) => '${mt(lang, 'moves')}: ${limit - moves} · ${mt(lang, 'pairs')}: ${done.where((d) => !d).length ~/ 2}';

  /// İpucu: kapalı bir kartın eşini kısa süre göster.
  @override
  bool hint() {
    for (var i = 0; i < c.length; i++) {
      if (!done[i] && !open.contains(i)) {
        _peek = i;
        _peekT = 1.2;
        return true;
      }
    }
    return false;
  }

  @override
  bool booster() {
    limit += 4;
    return true;
  }

  @override
  String boosterKey() => 'slot';

  @override
  void paint(Canvas cv, Size size, MPalette p, double t) {
    final geo = _geo;
    for (var i = 0; i < c.length; i++) {
      final r = geo.cell(i).deflate(geo.cs * 0.06);
      final shown = done[i] || open.contains(i) || (_peekT > 0 && c[i] == c[_peek < 0 ? 0 : _peek]);
      if (shown) {
        drawTile(cv, r, c[i], p, alpha: done[i] ? 0.55 : 1);
      } else {
        final rr = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.16));
        cv.drawRRect(rr, Paint()..color = p.accent);
        // Arka yüz deseni
        final pat = Paint()
          ..color = const Color(0x33FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r.width * 0.04;
        cv.drawRRect(RRect.fromRectAndRadius(r.deflate(r.width * 0.12), Radius.circular(r.width * 0.1)), pat);
        drawGlyph(cv, 13, r.deflate(r.width * 0.32), const Color(0x44FFFFFF));
      }
    }
  }

  @override
  Map<String, Object?> save() => {'d': [for (var i = 0; i < c.length; i++) if (done[i]) i], 'm': moves, 's': score, 'l': limit};

  @override
  void load(Map<String, Object?> j) {
    for (var i = 0; i < done.length; i++) {
      done[i] = false;
    }
    for (final i in j['d'] as List) {
      done[(i as num).toInt()] = true;
    }
    moves = (j['m'] as num).toInt();
    score = (j['s'] as num).toInt();
    limit = (j['l'] as num?)?.toInt() ?? lv.i('mv');
    open.clear();
    _wait = 0;
  }
}
