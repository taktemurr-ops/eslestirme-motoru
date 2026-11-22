import 'dart:math' as math;
import 'dart:ui';

import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../glyphs.dart';
import '../texts.dart';

List<int> _l(Object? o) => [for (final v in (o as List)) (v as num).toInt()];

/// Sıralama oyunlarının ortak modeli: kaplar (alt → üst yığın).
///  * [run]: üstteki aynı renk dizisi birlikte taşınır (yoksa tek tek).
///  * [vanish]: tek renkle dolan kap boşalır (kart sıralama, içecek).
/// Görünüm [style] ile değişir: 0 yün (çubuk + halkalar), 1 kart sütunları,
/// 2 içecek kasaları.
class BinsKind extends MatchKind {
  @override
  final String id;
  final bool run, vanish, varCap;
  final int style;
  const BinsKind(this.id, {required this.run, required this.vanish, required this.style, this.varCap = false});

  @override
  MLevel make(int d, SeededRandom r) {
    final colors = math.min(3 + d ~/ 2, 8);
    for (var attempt = 0; attempt < 80; attempt++) {
      final caps = <int>[];
      final items = <int>[];
      for (var col = 0; col < colors; col++) {
        final cap = varCap ? 3 + r.nextInt(3) : (style == 1 ? 5 : 4);
        caps.add(cap);
        for (var k = 0; k < cap; k++) {
          items.add(col);
        }
      }
      r.shuffle(items);
      // Kaplara dağıt (her kap kapasitesi kadar ya da biraz eksik)
      final bins = <List<int>>[for (final _ in caps) <int>[]];
      var k = 0;
      for (var b = 0; b < caps.length; b++) {
        while (bins[b].length < caps[b] && k < items.length) {
          bins[b].add(items[k++]);
        }
      }
      final empties = d <= 6 ? 2 : 1 + (d >= 9 ? 0 : 1);
      final maxCap = caps.reduce(math.max);
      for (var e = 0; e < math.max(1, empties); e++) {
        bins.add([]);
        caps.add(maxCap);
      }
      // Zaten çözülmüş kap olmasın.
      if (bins.any((b) => b.length >= 2 && b.every((x) => x == b.first) && b.length == caps[bins.indexOf(b)])) continue;
      final lv = MLevel(id, d, r.nextInt(1 << 30), {
        'b': [for (final b in bins) b],
        'cap': caps,
      });
      if (solvable(lv)) return lv;
    }
    throw StateError('bins');
  }

  @override
  MGame start(MLevel lv) => BinsGame(lv, this);

  @override
  bool solvable(MLevel lv) => BinsGame(lv, this).solve(60000) != null;
}

class BinsGame extends MGame {
  final BinsKind k;
  late List<List<int>> bins;
  late List<int> cap;
  int? sel;
  (int, int)? hintMove;
  int extra = 0;
  final _flash = <int, double>{};

  BinsGame(super.lv, this.k) {
    bins = [for (final b in (lv.data['b'] as List)) _l(b)];
    cap = lv.ints('cap');
  }

  @override
  bool get won => bins.every((b) => b.isEmpty || (b.every((x) => x == b.first) && b.length == cap[bins.indexOf(b)]));

  bool _complete(int i) => bins[i].isNotEmpty && bins[i].length == cap[i] && bins[i].every((x) => x == bins[i].first);

  int _runLen(List<int> b) {
    if (b.isEmpty) return 0;
    var n = 1;
    while (n < b.length && b[b.length - 1 - n] == b.last) {
      n++;
    }
    return n;
  }

  /// Taşınacak adet (0: geçersiz).
  int canMove(int a, int b) {
    if (a == b || bins[a].isEmpty || _complete(a)) return 0;
    final room = cap[b] - bins[b].length;
    if (room <= 0) return 0;
    if (bins[b].isNotEmpty && bins[b].last != bins[a].last) return 0;
    final n = k.run ? _runLen(bins[a]) : 1;
    // Boş kaba tamamı aynı renk kabı taşımak anlamsız.
    if (bins[b].isEmpty && n == bins[a].length && (k.run || bins[a].length == 1)) return 0;
    return math.min(n, room);
  }

  void doMove(int a, int b) {
    final n = canMove(a, b);
    for (var t = 0; t < n; t++) {
      bins[b].add(bins[a].removeLast());
    }
    moves++;
    if (k.vanish && _complete(b)) {
      bins[b].clear();
      score += 50;
      bump('pairs_matched');
      _flash[b] = 0.5;
    } else if (_complete(b)) {
      bump('pairs_matched');
      _flash[b] = 0.5;
    }
  }

  List<(int, int)> legal() => [
        for (var a = 0; a < bins.length; a++)
          for (var b = 0; b < bins.length; b++)
            if (canMove(a, b) > 0) (a, b)
      ];

  String _key() {
    final parts = [for (var i = 0; i < bins.length; i++) '${cap[i]}:${bins[i].join(',')}']..sort();
    return parts.join('|');
  }

  /// Derinlik öncelikli arama: çözüme giden hamle listesi (yoksa null).
  List<(int, int)>? solve(int budget) {
    final seen = <String>{};
    final path = <(int, int)>[];
    var nodes = 0;
    bool go() {
      if (won) return true;
      if (++nodes > budget) return false;
      if (!seen.add(_key())) return false;
      final ms = legal();
      // Tamamlayan ve boş olmayana taşıyan hamleler önce.
      ms.sort((x, y) => _prio(y).compareTo(_prio(x)));
      for (final m in ms) {
        final saveB = [for (final b in bins) List.of(b)];
        final saveM = moves, saveS = score;
        doMove(m.$1, m.$2);
        path.add(m);
        if (go()) return true;
        path.removeLast();
        bins = saveB;
        moves = saveM;
        score = saveS;
      }
      return false;
    }

    final orig = [for (final b in bins) List.of(b)];
    final om = moves, os = score, ost = Map.of(stats);
    final ok = go();
    bins = orig;
    moves = om;
    score = os;
    stats
      ..clear()
      ..addAll(ost);
    _flash.clear();
    return ok ? path : null;
  }

  int _prio((int, int) m) {
    final a = bins[m.$1], b = bins[m.$2];
    var p = 0;
    if (b.isNotEmpty) p += 10;
    if (b.isNotEmpty && b.length + _runLen(a) == cap[m.$2] && b.every((x) => x == a.last)) p += 20;
    if (a.length == _runLen(a)) p -= 5;
    return p;
  }

  // ---- yerleşim
  List<Rect> _rects() {
    final n = bins.length;
    final perRow = n <= 6 ? n : (n / 2).ceil();
    final rowsN = (n / perRow).ceil();
    final maxCap = cap.reduce(math.max);
    final w = size.width / perRow;
    final unit = math.min(w * 0.7, (size.height / rowsN - 30) / (maxCap + 0.8));
    final out = <Rect>[];
    for (var i = 0; i < n; i++) {
      final row = i ~/ perRow, col = i % perRow;
      final inRow = row == rowsN - 1 ? n - perRow * row : perRow;
      final rowW = inRow * w;
      final x = (size.width - rowW) / 2 + col * w + (w - unit) / 2;
      final hh = unit * (cap[i] + 0.6);
      final yBase = size.height / rowsN * (row + 1) - 16;
      out.add(Rect.fromLTWH(x, yBase - hh, unit, hh));
    }
    return out;
  }

  @override
  bool down(Offset p) {
    final rs = _rects();
    for (var i = 0; i < rs.length; i++) {
      if (!rs[i].inflate(8).contains(p)) continue;
      hintMove = null;
      if (sel == null) {
        if (bins[i].isEmpty) return false;
        sel = i;
        return true;
      }
      if (sel == i) {
        sel = null;
        return true;
      }
      if (canMove(sel!, i) > 0) {
        doMove(sel!, i);
        sel = null;
        return true;
      }
      sel = bins[i].isEmpty ? null : i;
      return true;
    }
    return false;
  }

  @override
  bool get lost => !won && legal().isEmpty;

  @override
  bool continueAfterLoss() => booster();

  @override
  String status(String lang) {
    final total = bins.where((b) => b.isNotEmpty).length;
    return '${mt(lang, 'colors')}: ${bins.where((b) => b.isNotEmpty && !_complete(bins.indexOf(b))).length} / $total';
  }

  @override
  bool hint() {
    final s = solve(20000);
    if (s != null && s.isNotEmpty) {
      hintMove = s.first;
      return true;
    }
    final l = legal();
    if (l.isEmpty) return false;
    hintMove = l.first;
    return true;
  }

  @override
  bool booster() {
    if (extra >= 2) return false;
    extra++;
    bins.add([]);
    cap.add(cap.reduce(math.max));
    return true;
  }

  @override
  String boosterKey() => 'slot';

  @override
  bool step(double dt) {
    for (final key in _flash.keys.toList()) {
      final v = _flash[key]! - dt;
      if (v <= 0) {
        _flash.remove(key);
      } else {
        _flash[key] = v;
      }
    }
    return _flash.isNotEmpty;
  }

  @override
  void paint(Canvas c, Size size, MPalette p, double t) {
    final rs = _rects();
    for (var i = 0; i < bins.length; i++) {
      final r = rs[i].translate(0, sel == i ? -10 : 0);
      final unit = r.width;
      final hint = hintMove != null && (hintMove!.$1 == i || hintMove!.$2 == i);
      switch (k.style) {
        case 0:
          _peg(c, r, i, unit, p, hint);
        case 1:
          _cards(c, r, i, unit, p, hint);
        default:
          _crate(c, r, i, unit, p, hint);
      }
      final f = _flash[i];
      if (f != null) {
        c.drawRRect(RRect.fromRectAndRadius(r.inflate(6), const Radius.circular(12)), Paint()..color = const Color(0xFFFFE08A).withAlpha((f * 300).round().clamp(0, 255)));
      }
    }
  }

  void _peg(Canvas c, Rect r, int i, double unit, MPalette p, bool hint) {
    // Tahta taban + çubuk
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.left - unit * 0.2, r.bottom - unit * 0.18, unit * 1.4, unit * 0.22), Radius.circular(unit * 0.1)),
        Paint()..color = hint ? const Color(0xFFFFC94D) : const Color(0xFF8C6A4F));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.center.dx - unit * 0.06, r.top, unit * 0.12, r.height - unit * 0.1), Radius.circular(unit * 0.06)),
        Paint()..color = const Color(0xFFB08B6A));
    for (var k = 0; k < bins[i].length; k++) {
      final y = r.bottom - unit * 0.2 - unit * (k + 0.5);
      final rr = Rect.fromCenter(center: Offset(r.center.dx, y), width: unit * 1.05, height: unit * 0.82);
      final col = p.piece(bins[i][k]);
      c.drawOval(rr, Paint()..color = col);
      // yün dokusu
      final line = Paint()
        ..color = const Color(0x33FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.04;
      for (var s = 1; s <= 3; s++) {
        c.drawArc(rr.deflate(unit * 0.08 * s), 3.6, 2.2, false, line);
      }
      if (p.colorBlind) drawGlyph(c, bins[i][k] * 3 % kGlyphCount, rr.deflate(unit * 0.22), const Color(0xAAFFFFFF));
    }
  }

  void _cards(Canvas c, Rect r, int i, double unit, MPalette p, bool hint) {
    c.drawRRect(RRect.fromRectAndRadius(r.inflate(4), Radius.circular(unit * 0.15)),
        Paint()
          ..color = hint ? const Color(0xFFFFC94D) : const Color(0x33000000)
          ..style = hint ? PaintingStyle.stroke : PaintingStyle.fill
          ..strokeWidth = 4);
    for (var k = 0; k < bins[i].length; k++) {
      final top = r.bottom - unit * 1.3 - k * unit * 0.85;
      final cr = Rect.fromLTWH(r.left, top, unit, unit * 1.3);
      final col = bins[i][k];
      c.drawRRect(RRect.fromRectAndRadius(cr, Radius.circular(unit * 0.12)), Paint()..color = const Color(0xFFFFFCF5));
      c.drawRRect(
          RRect.fromRectAndRadius(cr, Radius.circular(unit * 0.12)),
          Paint()
            ..color = const Color(0x44000000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      drawGlyph(c, col * 3 % kGlyphCount, Rect.fromLTWH(cr.left + unit * 0.1, cr.top + unit * 0.08, unit * 0.32, unit * 0.32), p.piece(col));
      drawGlyph(c, col * 3 % kGlyphCount, Rect.fromCenter(center: cr.center.translate(0, unit * 0.18), width: unit * 0.55, height: unit * 0.55), p.piece(col));
    }
  }

  void _crate(Canvas c, Rect r, int i, double unit, MPalette p, bool hint) {
    final crate = Rect.fromLTWH(r.left - unit * 0.12, r.top + unit * 0.3, unit * 1.24, r.height - unit * 0.3);
    c.drawRRect(RRect.fromRectAndRadius(crate, Radius.circular(unit * 0.12)), Paint()..color = hint ? const Color(0xFFFFC94D) : const Color(0xFF7A5C48));
    c.drawRRect(RRect.fromRectAndRadius(crate.deflate(unit * 0.08), Radius.circular(unit * 0.08)), Paint()..color = const Color(0xFF9B7A62));
    for (var k = 0; k < bins[i].length; k++) {
      final y = r.bottom - unit * 0.12 - unit * (k + 1);
      final col = p.piece(bins[i][k]);
      // Şişe: gövde + boyun
      final body = Rect.fromLTWH(r.left + unit * 0.2, y + unit * 0.3, unit * 0.6, unit * 0.62);
      c.drawRRect(RRect.fromRectAndRadius(body, Radius.circular(unit * 0.14)), Paint()..color = col);
      c.drawRect(Rect.fromLTWH(r.left + unit * 0.4, y + unit * 0.08, unit * 0.2, unit * 0.24), Paint()..color = col);
      c.drawRect(Rect.fromLTWH(r.left + unit * 0.38, y + unit * 0.04, unit * 0.24, unit * 0.08), Paint()..color = const Color(0xFFE9E2D6));
      c.drawRect(Rect.fromLTWH(body.left + unit * 0.08, body.top + unit * 0.1, unit * 0.1, unit * 0.38), Paint()..color = const Color(0x44FFFFFF));
      if (p.colorBlind) drawGlyph(c, bins[i][k] * 3 % kGlyphCount, body.deflate(unit * 0.12), const Color(0xAAFFFFFF));
    }
  }

  @override
  Map<String, Object?> save() => {'b': [for (final b in bins) List.of(b)], 'cap': List.of(cap), 'm': moves, 's': score, 'x': extra};

  @override
  void load(Map<String, Object?> j) {
    bins = [for (final b in j['b'] as List) _l(b)];
    cap = _l(j['cap']);
    moves = (j['m'] as num).toInt();
    score = (j['s'] as num).toInt();
    extra = (j['x'] as num?)?.toInt() ?? 0;
    sel = null;
    hintMove = null;
    _flash.clear();
  }
}

// ======================================================================= ÜRÜN SIRALAMA

/// Raf düzenleme: her rafın önünde 3 yer, arkasında sıra bekleyen katlar.
/// Bir ürünü boş bir yere taşı; rafın önü aynı üç üründen oluşunca
/// silinir ve arkadaki kat öne gelir. Bütün rafları boşalt.
class ShelfKind extends MatchKind {
  @override
  String get id => 'urun-siralama';
  const ShelfKind();

  @override
  MLevel make(int d, SeededRandom r) {
    final shelves = 4 + d ~/ 2;
    final kinds = 3 + d;
    for (var attempt = 0; attempt < 120; attempt++) {
      final layers = 1 + (d + 1) ~/ 3;
      // Her üründen 3'ün katı kadar
      final items = <int>[];
      final totalSlots = shelves * 3 * layers - (2 + (d <= 4 ? 2 : 1)) * 1;
      var kk = 0;
      while (items.length + 3 <= totalSlots) {
        items.addAll([kk % kinds, kk % kinds, kk % kinds]);
        kk++;
      }
      r.shuffle(items);
      // Raflar: katlar listesi (0 = ön). Boşluk -1.
      final data = <List<int>>[for (var s = 0; s < shelves; s++) List.filled(3 * layers, -1)];
      var n = 0;
      final order = [for (var s = 0; s < shelves; s++) for (var q = 0; q < 3 * layers; q++) (s, q)];
      r.shuffle(order);
      // Arka katlar dolu, boşluklar ön katlarda olsun.
      order.sort((a, b) => b.$2.compareTo(a.$2));
      for (final (s, q) in order) {
        if (n >= items.length) break;
        data[s][q] = items[n++];
      }
      final lv = MLevel(id, d, r.nextInt(1 << 30), {'n': shelves, 'L': layers, 'c': [for (final s in data) ...s]});
      if (solvable(lv)) return lv;
    }
    throw StateError('shelf');
  }

  @override
  MGame start(MLevel lv) => ShelfGame(lv);

  @override
  bool solvable(MLevel lv) => ShelfGame(lv).solve(40000) != null;
}

class ShelfGame extends MGame {
  late int n, layers;
  /// Raf başına dizi: [ön0, ön1, ön2, arka katlar...]
  late List<List<int>> sh;
  (int, int)? sel; // raf, yer
  (int, int, int)? hintMove;
  final _flash = <int, double>{};

  ShelfGame(super.lv) {
    n = lv.i('n');
    layers = lv.i('L');
    final c = lv.ints('c');
    sh = [for (var s = 0; s < n; s++) c.sublist(s * 3 * layers, (s + 1) * 3 * layers)];
  }

  void _settle(int s) {
    // Ön tamamen boşsa arkadaki katı öne çek.
    while (sh[s].length > 3 && sh[s].sublist(0, 3).every((x) => x < 0)) {
      sh[s].removeRange(0, 3);
    }
    final f = sh[s].sublist(0, 3);
    if (f[0] >= 0 && f[0] == f[1] && f[1] == f[2]) {
      for (var q = 0; q < 3; q++) {
        sh[s][q] = -1;
      }
      score += 30;
      bump('pairs_matched');
      _flash[s] = 0.5;
      _settle(s);
    }
  }

  bool shift(int s1, int q1, int s2, int q2) {
    if (sh[s1][q1] < 0 || sh[s2][q2] >= 0 || q1 > 2 || q2 > 2) return false;
    sh[s2][q2] = sh[s1][q1];
    sh[s1][q1] = -1;
    moves++;
    _settle(s2);
    _settle(s1);
    return true;
  }

  @override
  bool get won => sh.every((s) => s.every((x) => x < 0));

  List<(int, int, int, int)> legal() {
    final out = <(int, int, int, int)>[];
    final empties = <(int, int)>[];
    for (var s = 0; s < n; s++) {
      for (var q = 0; q < 3; q++) {
        if (sh[s][q] < 0) empties.add((s, q));
      }
    }
    for (var s = 0; s < n; s++) {
      for (var q = 0; q < 3; q++) {
        if (sh[s][q] < 0) continue;
        for (final (s2, q2) in empties) {
          if (s2 != s) out.add((s, q, s2, q2));
        }
      }
    }
    return out;
  }

  String _key() => [for (final s in sh) '${(List.of(s.take(3))..sort()).join(',')}/${s.skip(3).join(',')}'].join('|');

  List<(int, int, int, int)>? solve(int budget) {
    final seen = <String>{};
    final path = <(int, int, int, int)>[];
    var nodes = 0;
    bool go() {
      if (won) return true;
      if (++nodes > budget) return false;
      if (!seen.add(_key())) return false;
      final ms = legal();
      int pr((int, int, int, int) m) {
        final item = sh[m.$1][m.$2];
        final dest = sh[m.$3].take(3).where((x) => x == item).length;
        return dest * 10 - sh[m.$3].take(3).where((x) => x >= 0 && x != item).length * 3;
      }

      ms.sort((a, b) => pr(b).compareTo(pr(a)));
      // Aynı hedef rafa yapılan eşdeğer hamleleri ele.
      final tried = <String>{};
      for (final m in ms) {
        if (!tried.add('${sh[m.$1][m.$2]}>${m.$3}')) continue;
        final save = [for (final s in sh) List.of(s)];
        final sm = moves, ss = score;
        shift(m.$1, m.$2, m.$3, m.$4);
        path.add(m);
        if (go()) return true;
        path.removeLast();
        sh = save;
        moves = sm;
        score = ss;
      }
      return false;
    }

    final orig = [for (final s in sh) List.of(s)];
    final om = moves, os = score, ost = Map.of(stats);
    final ok = go();
    sh = orig;
    moves = om;
    score = os;
    stats
      ..clear()
      ..addAll(ost);
    _flash.clear();
    return ok ? path : null;
  }

  (Rect, List<Rect>) _shelf(int s) {
    final cols = n <= 4 ? 2 : 3;
    final rows = (n / cols).ceil();
    final w = size.width / cols, h = size.height / rows;
    final col = s % cols, row = s ~/ cols;
    final box = Rect.fromLTWH(col * w + w * 0.06, row * h + h * 0.18, w * 0.88, math.min(h * 0.62, w * 0.88 / 3 * 1.2));
    final sw = box.width / 3;
    return (box, [for (var q = 0; q < 3; q++) Rect.fromLTWH(box.left + q * sw, box.top, sw, box.height)]);
  }

  @override
  bool down(Offset p) {
    for (var s = 0; s < n; s++) {
      final (_, slots) = _shelf(s);
      for (var q = 0; q < 3; q++) {
        if (!slots[q].contains(p)) continue;
        hintMove = null;
        if (sel == null) {
          if (sh[s][q] < 0) return false;
          sel = (s, q);
          return true;
        }
        if (sel == (s, q)) {
          sel = null;
          return true;
        }
        if (sh[s][q] < 0) {
          final ok = shift(sel!.$1, sel!.$2, s, q);
          sel = null;
          return ok;
        }
        sel = (s, q);
        return true;
      }
    }
    return false;
  }

  @override
  bool get lost => !won && legal().isEmpty;

  @override
  bool continueAfterLoss() => booster();

  @override
  String status(String lang) => '${mt(lang, 'tiles')}: ${sh.fold<int>(0, (a, s) => a + s.where((x) => x >= 0).length)}';

  @override
  bool hint() {
    final s = solve(15000);
    final m = (s != null && s.isNotEmpty) ? s.first : (legal().isEmpty ? null : legal().first);
    if (m == null) return false;
    hintMove = (m.$1, m.$2, m.$3);
    return true;
  }

  /// Karıştır: ön sıradaki ürünleri yeniden dağıt.
  @override
  bool booster() {
    final idx = <(int, int)>[];
    final vals = <int>[];
    for (var s = 0; s < n; s++) {
      for (var q = 0; q < 3; q++) {
        idx.add((s, q));
        vals.add(sh[s][q]);
      }
    }
    final r = SeededRandom(mixSeed([lv.seed, moves, 17]));
    r.shuffle(vals);
    for (var k = 0; k < idx.length; k++) {
      sh[idx[k].$1][idx[k].$2] = vals[k];
    }
    for (var s = 0; s < n; s++) {
      _settle(s);
    }
    return true;
  }

  @override
  bool step(double dt) {
    for (final key in _flash.keys.toList()) {
      final v = _flash[key]! - dt;
      if (v <= 0) {
        _flash.remove(key);
      } else {
        _flash[key] = v;
      }
    }
    return _flash.isNotEmpty;
  }

  @override
  void paint(Canvas c, Size size, MPalette p, double t) {
    for (var s = 0; s < n; s++) {
      final (box, slots) = _shelf(s);
      // Arka kat önizlemesi (soluk)
      final back = sh[s].length > 3 ? sh[s].sublist(3, 6) : const <int>[];
      c.drawRRect(RRect.fromRectAndRadius(box.inflate(6), const Radius.circular(10)), Paint()..color = const Color(0xFF6E5444));
      c.drawRRect(RRect.fromRectAndRadius(box.inflate(2), const Radius.circular(8)), Paint()..color = const Color(0xFFE9DCC8));
      for (var q = 0; q < 3; q++) {
        final r = slots[q].deflate(slots[q].width * 0.1);
        if (q < back.length && back[q] >= 0) {
          _item(c, r.translate(0, -r.height * 0.12).deflate(r.width * 0.12), back[q], p, 0.28);
        }
        if (sh[s][q] >= 0) {
          final lift = sel == (s, q) ? -8.0 : 0.0;
          _item(c, r.translate(0, lift), sh[s][q], p, 1);
        }
        final hm = hintMove;
        if (hm != null && ((hm.$1 == s && hm.$2 == q) || (hm.$3 == s && sh[s][q] < 0))) {
          c.drawRRect(
              RRect.fromRectAndRadius(slots[q].deflate(2), const Radius.circular(8)),
              Paint()
                ..color = const Color(0xFFFFC94D)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4);
        }
      }
      // Raf tahtası
      c.drawRect(Rect.fromLTWH(box.left - 6, box.bottom, box.width + 12, 8), Paint()..color = const Color(0xFF8C6A4F));
      final layersLeft = (sh[s].length / 3).ceil();
      if (layersLeft > 1) drawText(c, '+${layersLeft - 1}', box.topRight.translate(-12, -14), 14, p.ink);
      final f = _flash[s];
      if (f != null) c.drawRRect(RRect.fromRectAndRadius(box.inflate(8), const Radius.circular(12)), Paint()..color = const Color(0xFFFFE08A).withAlpha((f * 300).round().clamp(0, 255)));
    }
  }

  /// Ürün: renkli kutu/kavanoz + simge.
  void _item(Canvas c, Rect r, int item, MPalette p, double a) {
    final (g, col) = faceOf(item, p.pieces.length);
    final color = p.piece(col);
    final alpha = (255 * a).round();
    final shape = item % 3;
    final body = Rect.fromLTWH(r.left + r.width * 0.12, r.top + r.height * 0.18, r.width * 0.76, r.height * 0.8);
    if (shape == 0) {
      // kavanoz
      c.drawRRect(RRect.fromRectAndRadius(body, Radius.circular(r.width * 0.18)), Paint()..color = color.withAlpha(alpha));
      c.drawRect(Rect.fromLTWH(body.left + body.width * 0.1, r.top + r.height * 0.08, body.width * 0.8, r.height * 0.14), Paint()..color = const Color(0xFF5B4636).withAlpha(alpha));
    } else if (shape == 1) {
      // kutu
      c.drawRect(body, Paint()..color = color.withAlpha(alpha));
      c.drawRect(Rect.fromLTWH(body.left, body.top, body.width, body.height * 0.18), Paint()..color = const Color(0x33000000).withAlpha((0x33 * a).round()));
    } else {
      // şişe
      c.drawRRect(RRect.fromRectAndRadius(body.deflate(body.width * 0.08).translate(0, body.height * 0.06), Radius.circular(r.width * 0.25)), Paint()..color = color.withAlpha(alpha));
      c.drawRect(Rect.fromLTWH(r.center.dx - r.width * 0.1, r.top + r.height * 0.02, r.width * 0.2, r.height * 0.24), Paint()..color = color.withAlpha(alpha));
    }
    drawGlyph(c, g, Rect.fromCenter(center: body.center.translate(0, body.height * 0.05), width: body.width * 0.55, height: body.width * 0.55),
        const Color(0xFFFDF8EE).withAlpha(alpha));
  }

  @override
  Map<String, Object?> save() => {'sh': [for (final s in sh) List.of(s)], 'm': moves, 's': score};

  @override
  void load(Map<String, Object?> j) {
    sh = [for (final s in j['sh'] as List) _l(s)];
    moves = (j['m'] as num).toInt();
    score = (j['s'] as num).toInt();
    sel = null;
    hintMove = null;
    _flash.clear();
  }
}
