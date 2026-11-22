import 'dart:math' as math;
import 'dart:ui';

import 'package:studio_core/core/rng.dart';
import 'package:studio_core/core/stats.dart';
import 'package:studio_core/core/missions.dart';

import '../core.dart';
import '../glyphs.dart';
import '../texts.dart';

/// Katmanlı taş dizilimleri: mahjong solitaire, büyük taşlı tek kat,
/// domino (toplam 12), üçlü tepsi ve 3B nesne yığını.
///
/// Konumlar "yarım taş" biriminde: bir taş 2×2 birim kaplar (x, y), z kat.
class Pos {
  final int x, y, z;
  const Pos(this.x, this.y, this.z);
}

// ---------------------------------------------------------------- dizilimler

/// Dizilim üretimi: [style] 0..9 farklı şekiller, [n] yaklaşık taş sayısı (çift).
List<Pos> makeLayout(int style, int n, SeededRandom r, {int maxZ = 4}) {
  final out = <Pos>[];
  final used = <int>{};
  int key(int x, int y, int z) => (z * 200 + y) * 200 + x;
  bool canPlace(int x, int y, int z) {
    for (final p in out) {
      if (p.z == z && (p.x - x).abs() < 2 && (p.y - y).abs() < 2) return false;
    }
    if (z == 0) return true;
    // Üst kattaki taş alttaki taşların üstüne tam otursun.
    var support = 0;
    for (final p in out) {
      if (p.z == z - 1 && (p.x - x).abs() < 2 && (p.y - y).abs() < 2) support++;
    }
    return support > 0;
  }

  void add(int x, int y, int z) {
    if (out.length >= n || used.contains(key(x, y, z)) || !canPlace(x, y, z)) return;
    used.add(key(x, y, z));
    out.add(Pos(x, y, z));
  }

  // Taban şekli: (kolon, satır) taş ızgarası maskesi.
  final cols = math.max(4, (math.sqrt(n * 1.4)).round());
  final rows = math.max(3, (n / cols / 1.6).ceil() + 1);
  bool inBase(int c, int rw) {
    final cx = (cols - 1) / 2, cy = (rows - 1) / 2;
    final dx = (c - cx).abs() / (cols / 2), dy = (rw - cy).abs() / (rows / 2);
    switch (style % 10) {
      case 0: // dikdörtgen
        return true;
      case 1: // elmas
        return dx + dy <= 1.05;
      case 2: // artı
        return dx < 0.35 || dy < 0.4;
      case 3: // halka
        return dx > 0.4 || dy > 0.45;
      case 4: // köprü (iki blok + orta şerit)
        return dx > 0.45 || dy < 0.25;
      case 5: // kelebek
        return dy <= dx + 0.25;
      case 6: // kale (köşe kuleleri)
        return dy < 0.7 || dx > 0.7;
      case 7: // oval
        return dx * dx + dy * dy <= 1.05;
      case 8: // basamak
        return rw >= (c * rows / cols) - 1;
      default: // zikzak
        return (rw + c ~/ 2).isEven || dy < 0.3;
    }
  }

  for (var z = 0; z <= maxZ && out.length < n; z++) {
    final shrink = z; // her kat bir taş içeri
    for (var rw = shrink; rw < rows - shrink && out.length < n; rw++) {
      for (var c = shrink; c < cols - shrink && out.length < n; c++) {
        if (!inBase(c, rw)) continue;
        // Üst katlar yarım taş kaydırılabilir (gerçek dizilim hissi).
        final off = (z.isOdd && style % 3 == 1) ? 1 : 0;
        add(c * 2 + off, rw * 2 + (z.isOdd && style % 3 == 2 ? 1 : 0), z);
      }
    }
  }
  if (out.length.isOdd) out.removeLast();
  return out;
}

// ---------------------------------------------------------------- tahta

class TileBoard {
  final List<Pos> pos;
  final List<int> face;
  final List<bool> gone;

  /// Serbestlik kuralı: true = mahjong (üstü boş + sağ ya da sol boş);
  /// false = yalnızca üstü boş (tepsi oyunları).
  final bool sideRule;

  TileBoard(this.pos, this.face, this.sideRule) : gone = List.filled(pos.length, false);

  bool covered(int i) {
    final a = pos[i];
    for (var j = 0; j < pos.length; j++) {
      if (gone[j] || j == i) continue;
      final b = pos[j];
      if (b.z > a.z && (b.x - a.x).abs() < 2 && (b.y - a.y).abs() < 2) return true;
    }
    return false;
  }

  bool sideBlocked(int i, int dir) {
    final a = pos[i];
    for (var j = 0; j < pos.length; j++) {
      if (gone[j] || j == i) continue;
      final b = pos[j];
      if (b.z == a.z && b.x == a.x + 2 * dir && (b.y - a.y).abs() < 2) return true;
    }
    return false;
  }

  bool free(int i) {
    if (gone[i]) return false;
    if (covered(i)) return false;
    if (!sideRule) return true;
    return !sideBlocked(i, -1) || !sideBlocked(i, 1);
  }

  List<int> freeTiles() => [for (var i = 0; i < pos.length; i++) if (free(i)) i];
  int get left => gone.where((g) => !g).length;
}

/// Ekran yerleşimi: birimleri piksele çevirir.
class TileGeo {
  final double unit, ox, oy, depth;
  TileGeo(this.unit, this.ox, this.oy, this.depth);

  Rect rect(Pos p) =>
      Rect.fromLTWH(ox + p.x * unit - p.z * depth, oy + p.y * unit * 1.25 - p.z * depth, unit * 2 - unit * 0.08, unit * 2.5 - unit * 0.08);

  static TileGeo fit(List<Pos> pos, Rect area) {
    var minX = 1 << 30, minY = 1 << 30, maxX = -1, maxY = -1, maxZ = 0;
    for (final p in pos) {
      minX = math.min(minX, p.x);
      minY = math.min(minY, p.y);
      maxX = math.max(maxX, p.x + 2);
      maxY = math.max(maxY, p.y + 2);
      maxZ = math.max(maxZ, p.z);
    }
    if (pos.isEmpty) return TileGeo(10, area.left, area.top, 2);
    final w = (maxX - minX).toDouble(), h = (maxY - minY) * 1.25 + 0.5;
    final unit = math.min((area.width - 8) / (w + maxZ * 0.25), (area.height - 8) / (h + maxZ * 0.25));
    final depth = unit * 0.22;
    final bw = w * unit, bh = h * unit;
    return TileGeo(unit, area.left + (area.width - bw) / 2 - minX * unit + maxZ * depth * 0.5,
        area.top + (area.height - bh) / 2 - minY * unit * 1.25 + maxZ * depth * 0.5, depth);
  }
}

/// Kaldırma sırasını üretir: her adımda serbest [group] taş seçilir.
/// Dönen liste, yüz atanacak grupların sırasıdır (geri yönde çözüm).
List<List<int>>? removalOrder(List<Pos> pos, bool sideRule, int group, SeededRandom r) {
  final b = TileBoard(pos, List.filled(pos.length, 0), sideRule);
  final order = <List<int>>[];
  while (b.left > 0) {
    final f = b.freeTiles();
    if (f.length < group) return null;
    r.shuffle(f);
    // Yüksek katları ve uçları önce seç ki dizilim dengeli açılsın.
    f.sort((a, c) => pos[c].z.compareTo(pos[a].z));
    final pick = <int>[];
    for (final i in f) {
      if (pick.length == group) break;
      if (r.chance(0.75) || f.length - f.indexOf(i) <= group - pick.length) pick.add(i);
    }
    while (pick.length < group) {
      pick.add(f.firstWhere((i) => !pick.contains(i)));
    }
    for (final i in pick) {
      b.gone[i] = true;
    }
    order.add(pick);
  }
  return order;
}

// ---------------------------------------------------------------- mahjong

/// Mahjong solitaire ve türevleri: aynı yüzlü iki serbest taşı eşleştir.
class PairTilesKind extends MatchKind {
  @override
  final String id;

  /// Dizilim stili (-1: zorluğa göre değişir).
  final int style;

  /// 0: klasik mahjong, 1: büyük taş tek kat, 2: domino toplam 12.
  final int mode;

  const PairTilesKind(this.id, {this.style = -1, this.mode = 0});

  int tilesFor(int d) => switch (mode) {
        1 => 12 + d * 4,
        2 => 16 + d * 6,
        _ => 24 + d * 12,
      };

  @override
  MLevel make(int d, SeededRandom r) {
    for (var attempt = 0; attempt < 30; attempt++) {
      final st = style >= 0 ? style : r.nextInt(10);
      final pos = makeLayout(st, tilesFor(d), r, maxZ: mode == 1 ? 0 : (mode == 2 ? 1 : 1 + d ~/ 3));
      final order = removalOrder(pos, true, 2, r);
      if (order == null) continue;
      final face = List.filled(pos.length, 0);
      final faces = mode == 2 ? 0 : math.min(order.length, 8 + d * 3);
      // Yüzleri sırayla dağıt (aynı yüz birkaç çifte gelebilir).
      final pool = [for (var i = 0; i < order.length; i++) i % math.max(1, faces)];
      r.shuffle(pool);
      for (var k = 0; k < order.length; k++) {
        if (mode == 2) {
          // Domino: toplamı 12 olan iki taş. Taş kodu a*7+b (a<=b).
          final s1 = r.range(math.max(0, 12 - 12), 12);
          final a1 = r.range(math.max(0, s1 - 6), math.min(6, s1));
          final s2 = 12 - s1;
          final a2 = r.range(math.max(0, s2 - 6), math.min(6, s2));
          face[order[k][0]] = math.min(a1, s1 - a1) * 7 + math.max(a1, s1 - a1);
          face[order[k][1]] = math.min(a2, s2 - a2) * 7 + math.max(a2, s2 - a2);
        } else {
          face[order[k][0]] = pool[k];
          face[order[k][1]] = pool[k];
        }
      }
      return MLevel(id, d, r.nextInt(1 << 30), {
        'x': [for (final p in pos) p.x],
        'y': [for (final p in pos) p.y],
        'z': [for (final p in pos) p.z],
        'f': face,
        'o': [for (final g in order.reversed) ...g],
      });
    }
    throw StateError('layout');
  }

  @override
  MGame start(MLevel lv) => PairTilesGame(lv, mode);

  @override
  bool solvable(MLevel lv) {
    // Saklı çözüm sırasını oynat.
    final g = PairTilesGame(lv, mode);
    final o = lv.ints('o');
    for (var k = 0; k + 1 < o.length; k += 2) {
      if (!g.b.free(o[k]) || !g.b.free(o[k + 1]) || !g.matches(o[k], o[k + 1])) return false;
      g.b.gone[o[k]] = true;
      g.b.gone[o[k + 1]] = true;
    }
    return g.b.left == 0;
  }
}

int pipSum(int code) => code ~/ 7 + code % 7;

class PairTilesGame extends MGame {
  final int mode;
  late TileBoard b;
  int? sel;
  List<int> hintTiles = [];
  int shuffles = 0;
  final _fx = <(Rect, int, double)>[]; // kaybolan taş efekti

  PairTilesGame(super.lv, this.mode) {
    final xs = lv.ints('x'), ys = lv.ints('y'), zs = lv.ints('z');
    b = TileBoard([for (var i = 0; i < xs.length; i++) Pos(xs[i], ys[i], zs[i])], lv.ints('f'), true);
  }

  bool matches(int a, int c) => mode == 2 ? pipSum(b.face[a]) + pipSum(b.face[c]) == 12 : b.face[a] == b.face[c];

  TileGeo _geo() => TileGeo.fit(b.pos, Offset.zero & size);

  int? _hit(Offset p) {
    final geo = _geo();
    int? best;
    for (var i = 0; i < b.pos.length; i++) {
      if (b.gone[i]) continue;
      if (geo.rect(b.pos[i]).contains(p) && (best == null || b.pos[i].z >= b.pos[best].z)) best = i;
    }
    return best;
  }

  @override
  bool down(Offset p) {
    final i = _hit(p);
    if (i == null) return false;
    if (!b.free(i)) {
      hintTiles = [];
      return false;
    }
    hintTiles = [];
    if (sel == null || sel == i) {
      sel = sel == i ? null : i;
      return true;
    }
    if (matches(sel!, i)) {
      final geo = _geo();
      _fx
        ..add((geo.rect(b.pos[sel!]), b.face[sel!], 0))
        ..add((geo.rect(b.pos[i]), b.face[i], 0));
      b.gone[sel!] = true;
      b.gone[i] = true;
      sel = null;
      moves++;
      score += 20;
      bump('pairs_matched');
      return true;
    }
    sel = i;
    return true;
  }

  List<(int, int)> _pairs() {
    final f = b.freeTiles();
    final out = <(int, int)>[];
    for (var a = 0; a < f.length; a++) {
      for (var c = a + 1; c < f.length; c++) {
        if (matches(f[a], f[c])) out.add((f[a], f[c]));
      }
    }
    return out;
  }

  @override
  bool get won => b.left == 0;

  @override
  bool get lost => b.left > 0 && _pairs().isEmpty && _fx.isEmpty;

  @override
  bool continueAfterLoss() => booster();

  @override
  String status(String lang) => '${mt(lang, 'pairs')}: ${b.left ~/ 2}';

  @override
  bool hint() {
    final p = _pairs();
    if (p.isEmpty) return false;
    // Çözüm sırasında önce gelen çifti tercih et.
    final o = lv.ints('o');
    for (var k = 0; k + 1 < o.length; k += 2) {
      if (!b.gone[o[k]] && b.free(o[k]) && b.free(o[k + 1]) && matches(o[k], o[k + 1])) {
        hintTiles = [o[k], o[k + 1]];
        return true;
      }
    }
    hintTiles = [p.first.$1, p.first.$2];
    return true;
  }

  /// Karıştır: kalan yüzleri çözülebilir biçimde yeniden dağıt.
  @override
  bool booster() {
    final alive = [for (var i = 0; i < b.pos.length; i++) if (!b.gone[i]) i];
    if (alive.length < 2) return false;
    final r = SeededRandom(mixSeed([lv.seed, 77, ++shuffles]));
    final sub = [for (final i in alive) b.pos[i]];
    for (var attempt = 0; attempt < 40; attempt++) {
      final order = removalOrder(sub, true, 2, r);
      if (order == null) continue;
      final faces = [for (final i in alive) b.face[i]];
      // Eşleşen ikilileri koru: yüzleri çiftler hâlinde topla.
      final pairs = _pairUp(faces, r);
      if (pairs == null) break;
      r.shuffle(pairs);
      for (var k = 0; k < order.length && k < pairs.length; k++) {
        b.face[alive[order[k][0]]] = pairs[k].$1;
        b.face[alive[order[k][1]]] = pairs[k].$2;
      }
      sel = null;
      hintTiles = [];
      return true;
    }
    return false;
  }

  List<(int, int)>? _pairUp(List<int> faces, SeededRandom r) {
    final rest = List.of(faces);
    final out = <(int, int)>[];
    while (rest.isNotEmpty) {
      final a = rest.removeLast();
      final j = rest.indexWhere((c) => mode == 2 ? pipSum(a) + pipSum(c) == 12 : c == a);
      if (j < 0) return null;
      out.add((a, rest.removeAt(j)));
    }
    return out;
  }

  @override
  String boosterKey() => 'shuffle';

  @override
  bool step(double dt) {
    for (var k = _fx.length - 1; k >= 0; k--) {
      final f = _fx[k];
      final t = f.$3 + dt * 3;
      if (t >= 1) {
        _fx.removeAt(k);
      } else {
        _fx[k] = (f.$1, f.$2, t);
      }
    }
    return _fx.isNotEmpty;
  }

  @override
  void paint(Canvas c, Size size, MPalette p, double t) {
    final geo = _geo();
    final idx = [for (var i = 0; i < b.pos.length; i++) if (!b.gone[i]) i]
      ..sort((a, d) {
        final pa = b.pos[a], pd = b.pos[d];
        if (pa.z != pd.z) return pa.z.compareTo(pd.z);
        if (pa.y != pd.y) return pa.y.compareTo(pd.y);
        return pd.x.compareTo(pa.x);
      });
    for (final i in idx) {
      final r = geo.rect(b.pos[i]);
      final free = b.free(i);
      _tile(c, r, b.face[i], p, sel == i, !free, hintTiles.contains(i), geo.depth, 1);
    }
    for (final f in _fx) {
      final s = 1 + f.$3 * 0.3;
      final r = Rect.fromCenter(center: f.$1.center, width: f.$1.width * s, height: f.$1.height * s);
      _tile(c, r, f.$2, p, false, false, false, 0, 1 - f.$3);
    }
  }

  void _tile(Canvas c, Rect r, int face, MPalette p, bool sel, bool dim, bool hint, double depth, double alpha) {
    if (mode == 2) {
      drawTile(c, r, -1, p, selected: sel, dim: dim, hint: hint, depth: depth, alpha: alpha);
      _domino(c, r, face, p, alpha);
    } else {
      drawTile(c, r, face, p, selected: sel, dim: dim, hint: hint, depth: depth, alpha: alpha);
    }
  }

  void _domino(Canvas c, Rect r, int code, MPalette p, double alpha) {
    final a = code ~/ 7, bb = code % 7;
    final top = Rect.fromLTWH(r.left, r.top, r.width, r.height / 2), bot = Rect.fromLTWH(r.left, r.center.dy, r.width, r.height / 2);
    c.drawLine(Offset(r.left + r.width * 0.15, r.center.dy), Offset(r.right - r.width * 0.15, r.center.dy),
        Paint()
          ..color = p.ink.withAlpha((90 * alpha).round())
          ..strokeWidth = r.width * 0.03);
    _pips(c, top, a, p.piece(a), alpha);
    _pips(c, bot, bb, p.piece(bb + 3), alpha);
    drawText(c, '${a + bb}', r.bottomRight - Offset(r.width * 0.16, r.height * 0.1), r.width * 0.16, p.ink.withAlpha((150 * alpha).round()));
  }

  static const _pipXY = {
    1: [(0.5, 0.5)],
    2: [(0.28, 0.28), (0.72, 0.72)],
    3: [(0.25, 0.25), (0.5, 0.5), (0.75, 0.75)],
    4: [(0.28, 0.28), (0.72, 0.28), (0.28, 0.72), (0.72, 0.72)],
    5: [(0.25, 0.25), (0.75, 0.25), (0.5, 0.5), (0.25, 0.75), (0.75, 0.75)],
    6: [(0.28, 0.2), (0.72, 0.2), (0.28, 0.5), (0.72, 0.5), (0.28, 0.8), (0.72, 0.8)],
  };

  void _pips(Canvas c, Rect r, int n, Color col, double alpha) {
    final pts = _pipXY[n] ?? const [];
    final rad = r.shortestSide * 0.09;
    for (final (x, y) in pts) {
      c.drawCircle(Offset(r.left + r.width * x, r.top + r.height * y), rad, Paint()..color = col.withAlpha((255 * alpha).round()));
    }
  }

  @override
  Map<String, Object?> save() => {'g': [for (var i = 0; i < b.gone.length; i++) if (b.gone[i]) i], 'f': List.of(b.face), 'm': moves, 's': score, 'sh': shuffles};

  @override
  void load(Map<String, Object?> j) {
    for (var i = 0; i < b.gone.length; i++) {
      b.gone[i] = false;
    }
    for (final i in (j['g'] as List)) {
      b.gone[(i as num).toInt()] = true;
    }
    final f = j['f'] as List;
    for (var i = 0; i < f.length; i++) {
      b.face[i] = (f[i] as num).toInt();
    }
    moves = (j['m'] as num).toInt();
    score = (j['s'] as num).toInt();
    shuffles = (j['sh'] as num?)?.toInt() ?? 0;
    sel = null;
    hintTiles = [];
    _fx.clear();
  }
}

// ---------------------------------------------------------------- tepsi oyunları

/// Üçlü tepsi: serbest taşa dokun, tepsiye iner; aynı üç taş silinir.
/// Tepsi (7 yer) dolarsa kayıp. [pile]: 3B nesne yığını görünümü.
class TrayKind extends MatchKind {
  @override
  final String id;
  final bool pile;
  const TrayKind(this.id, {this.pile = false});

  @override
  List<GameStat> get stats => const [
        GameStat('rounds_won', 'Kazanılan bölüm', 'Levels won', scale: 10),
        GameStat('pairs_matched', 'Üçlü', 'Triples made', scale: 200),
      ];

  @override
  List<MissionTemplate> get missions => const [
        MissionTemplate('win', 'rounds_won', [3, 10, 25]),
        MissionTemplate('match', 'pairs_matched', [20, 60, 150]),
      ];

  @override
  MLevel make(int d, SeededRandom r) {
    final n = (12 + d * 9) ~/ 3 * 3;
    for (var attempt = 0; attempt < 30; attempt++) {
      List<Pos> pos;
      if (pile) {
        // Serbest yığın: taşlar rastgele kaydırılmış, katlar üst üste.
        pos = <Pos>[];
        final layers = 2 + d ~/ 2;
        final perLayer = (n / layers).ceil();
        for (var z = 0; z < layers && pos.length < n; z++) {
          for (var k = 0; k < perLayer && pos.length < n; k++) {
            final x = r.nextInt(9), y = r.nextInt(11);
            if (pos.any((p) => p.z == z && (p.x - x).abs() < 2 && (p.y - y).abs() < 2)) continue;
            pos.add(Pos(x, y, z));
          }
        }
        pos = pos.take(pos.length ~/ 3 * 3).toList();
        if (pos.length < 9) continue;
      } else {
        pos = makeLayout(r.nextInt(10), n, r, maxZ: 1 + d ~/ 3);
        pos = pos.take(pos.length ~/ 3 * 3).toList();
      }
      final order = removalOrder(pos, false, 3, r);
      if (order == null) continue;
      final faces = math.min(order.length, 5 + d * 2);
      final face = List.filled(pos.length, 0);
      final pool = [for (var i = 0; i < order.length; i++) i % faces];
      r.shuffle(pool);
      for (var k = 0; k < order.length; k++) {
        for (final i in order[k]) {
          face[i] = pool[k];
        }
      }
      return MLevel(id, d, r.nextInt(1 << 30), {
        'x': [for (final p in pos) p.x],
        'y': [for (final p in pos) p.y],
        'z': [for (final p in pos) p.z],
        'f': face,
        'o': [for (final g in order.reversed) ...g],
        'pile': pile ? 1 : 0,
      });
    }
    throw StateError('tray');
  }

  @override
  MGame start(MLevel lv) => TrayGame(lv);

  @override
  bool solvable(MLevel lv) {
    final g = TrayGame(lv);
    for (final i in lv.ints('o')) {
      if (!g.b.free(i)) return false;
      g.take(i);
      if (g.lost) return false;
    }
    return g.won;
  }
}

class TrayGame extends MGame {
  late TileBoard b;
  final tray = <int>[];
  int slots = 7;
  List<int> hintTiles = [];
  final _fx = <(Rect, int, double)>[];

  TrayGame(super.lv) {
    final xs = lv.ints('x'), ys = lv.ints('y'), zs = lv.ints('z');
    b = TileBoard([for (var i = 0; i < xs.length; i++) Pos(xs[i], ys[i], zs[i])], lv.ints('f'), false);
  }

  bool get pile => lv.i('pile') == 1;

  Rect get _boardArea => Rect.fromLTWH(0, 0, size.width, size.height * 0.8);
  Rect get _trayArea => Rect.fromLTWH(size.width * 0.04, size.height * 0.83, size.width * 0.92, size.height * 0.15);

  TileGeo _geo() => TileGeo.fit(b.pos, _boardArea);

  void take(int i) {
    b.gone[i] = true;
    final f = b.face[i];
    // Aynı yüzlerin yanına koy.
    final at = tray.lastIndexOf(f);
    if (at >= 0) {
      tray.insert(at + 1, f);
    } else {
      tray.add(f);
    }
    final cnt = tray.where((x) => x == f).length;
    if (cnt >= 3) {
      for (var k = 0; k < 3; k++) {
        tray.remove(f);
      }
      score += 30;
      bump('pairs_matched');
    }
    moves++;
  }

  @override
  bool down(Offset p) {
    final geo = _geo();
    int? best;
    for (var i = 0; i < b.pos.length; i++) {
      if (b.gone[i]) continue;
      if (geo.rect(b.pos[i]).contains(p) && (best == null || b.pos[i].z >= b.pos[best].z)) best = i;
    }
    if (best == null || !b.free(best)) return false;
    _fx.add((geo.rect(b.pos[best]), b.face[best], 0));
    take(best);
    hintTiles = [];
    return true;
  }

  @override
  bool get won => b.left == 0 && tray.isEmpty;

  @override
  bool get lost => tray.length >= slots;

  @override
  bool continueAfterLoss() {
    // Tepsideki son üç taşı tahtaya geri koyamayız; bir yer ekleriz.
    slots++;
    return true;
  }

  @override
  String status(String lang) => '${mt(lang, 'tiles')}: ${b.left + tray.length}';

  @override
  bool hint() {
    final f = b.freeTiles();
    if (f.isEmpty) return false;
    // Tepsideki yüzü tamamlayan taş > serbest kopyası çok olan.
    int best = f.first, bestScore = -1;
    for (final i in f) {
      final inTray = tray.where((x) => x == b.face[i]).length;
      final freeSame = f.where((j) => b.face[j] == b.face[i]).length;
      final sc = inTray * 10 + freeSame;
      if (sc > bestScore) {
        bestScore = sc;
        best = i;
      }
    }
    hintTiles = [best];
    return true;
  }

  /// Ek yer: tepsi 1 büyür.
  @override
  bool booster() {
    if (slots >= 9) return false;
    slots++;
    return true;
  }

  @override
  String boosterKey() => 'slot';

  @override
  bool step(double dt) {
    for (var k = _fx.length - 1; k >= 0; k--) {
      final f = _fx[k];
      final t = f.$3 + dt * 3.5;
      if (t >= 1) {
        _fx.removeAt(k);
      } else {
        _fx[k] = (f.$1, f.$2, t);
      }
    }
    return _fx.isNotEmpty;
  }

  @override
  void paint(Canvas c, Size size, MPalette p, double t) {
    final geo = _geo();
    final idx = [for (var i = 0; i < b.pos.length; i++) if (!b.gone[i]) i]
      ..sort((a, d) => b.pos[a].z != b.pos[d].z ? b.pos[a].z.compareTo(b.pos[d].z) : b.pos[a].y.compareTo(b.pos[d].y));
    for (final i in idx) {
      final r = geo.rect(b.pos[i]);
      if (pile) {
        _token(c, r, b.face[i], p, !b.free(i), hintTiles.contains(i));
      } else {
        drawTile(c, r, b.face[i], p, dim: !b.free(i), hint: hintTiles.contains(i), depth: geo.depth);
      }
    }
    // Tepsi
    final ta = _trayArea;
    c.drawRRect(RRect.fromRectAndRadius(ta, const Radius.circular(18)), Paint()..color = const Color(0xFF6B4E3D));
    c.drawRRect(RRect.fromRectAndRadius(ta.deflate(4), const Radius.circular(14)), Paint()..color = const Color(0xFF8A6A55));
    final w = (ta.width - 16) / slots;
    final s = math.min(w - 4, ta.height - 16);
    for (var k = 0; k < slots; k++) {
      final cell = Rect.fromCenter(center: Offset(ta.left + 8 + w * k + w / 2, ta.center.dy), width: s, height: s);
      if (k < tray.length) {
        if (pile) {
          _token(c, cell, tray[k], p, false, false);
        } else {
          drawTile(c, cell, tray[k], p);
        }
      } else {
        c.drawRRect(RRect.fromRectAndRadius(cell, Radius.circular(s * 0.16)), Paint()..color = const Color(0x33000000));
      }
    }
    for (final f in _fx) {
      final target = Offset(ta.center.dx, ta.center.dy);
      final ctr = Offset.lerp(f.$1.center, target, f.$3)!;
      final r = Rect.fromCenter(center: ctr, width: f.$1.width * (1 - f.$3 * 0.4), height: f.$1.height * (1 - f.$3 * 0.4));
      drawTile(c, r, f.$2, p, alpha: 1 - f.$3);
    }
  }

  void _token(Canvas c, Rect r, int face, MPalette p, bool dim, bool hint) {
    final (g, col) = faceOf(face, p.pieces.length);
    final ctr = r.center;
    final rad = r.shortestSide * 0.5;
    c.drawCircle(ctr.translate(rad * 0.08, rad * 0.12), rad, Paint()..color = const Color(0x44000000));
    c.drawCircle(ctr, rad, Paint()..color = p.piece(col));
    c.drawCircle(ctr.translate(-rad * 0.25, -rad * 0.3), rad * 0.35, Paint()..color = const Color(0x33FFFFFF));
    drawGlyph(c, g, Rect.fromCircle(center: ctr, radius: rad * 0.6), const Color(0xFFFDF8EE), outline: p.colorBlind);
    if (hint) {
      c.drawCircle(ctr, rad + 2, Paint()
        ..color = const Color(0xFFFFC94D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = rad * 0.15);
    }
    if (dim) c.drawCircle(ctr, rad, Paint()..color = const Color(0x77000000));
  }

  @override
  Map<String, Object?> save() =>
      {'g': [for (var i = 0; i < b.gone.length; i++) if (b.gone[i]) i], 't': List.of(tray), 'sl': slots, 'm': moves, 's': score};

  @override
  void load(Map<String, Object?> j) {
    for (var i = 0; i < b.gone.length; i++) {
      b.gone[i] = false;
    }
    for (final i in (j['g'] as List)) {
      b.gone[(i as num).toInt()] = true;
    }
    tray
      ..clear()
      ..addAll([for (final v in j['t'] as List) (v as num).toInt()]);
    slots = (j['sl'] as num).toInt();
    moves = (j['m'] as num).toInt();
    score = (j['s'] as num).toInt();
    hintTiles = [];
    _fx.clear();
  }
}
