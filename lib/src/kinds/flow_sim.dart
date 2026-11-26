import 'dart:math' as math;

import 'package:studio_core/core/rng.dart';

/// Konveyörlü ve tepsili eşleştirme oyunlarının saf Dart benzetimleri
/// (Flutter'sız; üretim, botla doğrulama ve oyun aynı kodu kullanır).

List<int> _li(Object? o) => [for (final v in (o as List)) (v as num).toInt()];
List<List<int>> _ll(Object? o) => [for (final v in (o as List)) _li(v)];

// ===================================================================
// Piksel Akışı: renkli atıcılar resmin çevresindeki bantta döner, kendi
// rengindeki ilk görünen pikseli vurur.
// ===================================================================

/// Prosedürel piksel resmi: kilim, çini gülü, simetrik figür, kalp/yıldız.
List<int> pixelArt(int w, int h, int colors, SeededRandom r) {
  final px = List.filled(w * h, -1);
  final pal = [for (var i = 0; i < colors; i++) i];
  r.shuffle(pal);
  final kind = r.nextInt(5);
  final cx = (w - 1) / 2, cy = (h - 1) / 2;
  final band = 1 + r.nextInt(2);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final dx = (x - cx).abs(), dy = (y - cy).abs();
      int v;
      switch (kind) {
        case 0: // kilim: iç içe baklava dilimleri
          v = ((dx + dy) / band).floor() % colors;
        case 1: // çini gülü: halkalar + yapraklar
          final d = math.sqrt(dx * dx + dy * dy);
          final a = math.atan2(y - cy, x - cx);
          final petal = (math.cos(a * 4) > 0.3) ? 1 : 0;
          v = ((d / (band + 0.6)).floor() + petal) % colors;
        case 2: // çerçeveli şerit
          final edge = math.min(math.min(x, y), math.min(w - 1 - x, h - 1 - y));
          v = edge == 0 ? 0 : 1 + ((y ~/ band) + (edge.isEven ? 0 : 1)) % math.max(1, colors - 1);
        case 3: // kalp / yıldız biçimi + zemin
          final nx = (x - cx) / (w / 2), ny = (y - cy) / (h / 2);
          final heart = math.pow(nx * nx + ny * ny - 0.55, 3) - nx * nx * math.pow(-ny, 3) * 0.9 < 0;
          v = heart ? 1 + ((dx + dy) ~/ (band + 2)) % math.max(1, colors - 1) : 0;
        default: // simetrik figür (sol yarı rastgele, aynalanır)
          v = -2;
      }
      px[y * w + x] = v;
    }
  }
  if (kind == 4) {
    final half = (w + 1) ~/ 2;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < half; x++) {
        final v = r.nextInt(100) < 18 ? -1 : r.nextInt(colors);
        px[y * w + x] = v;
        px[y * w + (w - 1 - x)] = v;
      }
    }
  }
  return [for (final v in px) v < 0 ? v : pal[v % colors]];
}

class Shooter {
  int color, ammo, pos;
  Shooter(this.color, this.ammo, [this.pos = 0]);
  List<int> toList() => [color, ammo, pos];
}

/// Piksel Akışı benzetimi.
class PixelSim {
  final int w, h, beltMax;
  int slotsMax;
  late List<int> px;
  late List<List<List<int>>> queues; // sütun → [renk, cephane] (üstten)
  final List<Shooter?> slots = [];
  final List<Shooter> belt = [];
  bool lost = false;
  int fired = 0;

  /// Son atışlar (çizim için): [atıcı konumu, piksel].
  final List<(int, int)> shots = [];

  PixelSim(Map<String, Object?> d)
      : w = (d['w'] as num).toInt(),
        h = (d['h'] as num).toInt(),
        beltMax = (d['belt'] as num).toInt(),
        slotsMax = (d['slots'] as num).toInt() {
    px = _li(d['px']);
    queues = [for (final c in (d['q'] as List)) _ll(c)];
  }

  int get loop => 2 * (w + h);
  bool get won => px.every((v) => v < 0);
  int get pixelsLeft => px.where((v) => v >= 0).length;

  /// Bant konumundan bakılan sıradaki hücreler.
  List<int> lineOf(int p) {
    if (p < w) return [for (var y = 0; y < h; y++) y * w + p];
    if (p < w + h) {
      final y = p - w;
      return [for (var x = w - 1; x >= 0; x--) y * w + x];
    }
    if (p < 2 * w + h) {
      final x = w - 1 - (p - w - h);
      return [for (var y = h - 1; y >= 0; y--) y * w + x];
    }
    final y = h - 1 - (p - 2 * w - h);
    return [for (var x = 0; x < w; x++) y * w + x];
  }

  int firstVisible(int p) {
    for (final i in lineOf(p)) {
      if (px[i] >= 0) return i;
    }
    return -1;
  }

  /// Bir rengin şu an görünen piksel sayısı (herhangi bir kenardan).
  int exposed(int color) {
    final seen = <int>{};
    for (var p = 0; p < loop; p++) {
      final i = firstVisible(p);
      if (i >= 0 && px[i] == color) seen.add(i);
    }
    return seen.length;
  }

  bool get entryFree => belt.length < beltMax && belt.every((s) => s.pos > 1);

  /// Gönderilebilir atıcılar: (-1-sütun ya da yuva dizini, renk, cephane).
  List<(int, int, int)> candidates() => [
        for (var c = 0; c < queues.length; c++)
          if (queues[c].isNotEmpty) (-1 - c, queues[c].first[0], queues[c].first[1]),
        for (var s = 0; s < slots.length; s++)
          if (slots[s] != null) (s, slots[s]!.color, slots[s]!.ammo),
      ];

  /// [src]: -1-sütun (kuyruk) ya da yuva dizini.
  bool send(int src) {
    if (!entryFree || lost) return false;
    Shooter s;
    if (src < 0) {
      final c = -1 - src;
      if (c >= queues.length || queues[c].isEmpty) return false;
      final e = queues[c].removeAt(0);
      s = Shooter(e[0], e[1]);
    } else {
      if (src >= slots.length || slots[src] == null) return false;
      s = slots[src]!;
      slots[src] = null;
      s.pos = 0;
    }
    belt.add(s);
    return true;
  }

  /// Bir adım: bant bir konum ilerler, atıcılar ateş eder.
  void tick() {
    shots.clear();
    if (lost) return;
    for (final s in List.of(belt)) {
      final i = firstVisible(s.pos);
      if (i >= 0 && px[i] == s.color && s.ammo > 0) {
        px[i] = -1;
        s.ammo--;
        fired++;
        shots.add((s.pos, i));
      }
      if (s.ammo == 0) {
        belt.remove(s);
        continue;
      }
      s.pos++;
      if (s.pos >= loop) {
        belt.remove(s);
        final free = slots.indexOf(null);
        if (free >= 0) {
          slots[free] = s;
        } else if (slots.length < slotsMax) {
          slots.add(s);
        } else {
          lost = true;
        }
      }
    }
  }

  /// Bütün atıcılar bitti ama piksel kaldıysa (olmamalı) kayıp.
  bool get stuck => !won && belt.isEmpty && queues.every((q) => q.isEmpty) && slots.every((s) => s == null);

  /// Bot: en çok görünen pikseli olan rengi gönder; yuvadakiler öncelikli.
  int? botChoice() {
    if (!entryFree) return null;
    final c = candidates();
    if (c.isEmpty) return null;
    final onBelt = <int>{for (final s in belt) s.color};
    (int, int, int)? best;
    var bestScore = -1 << 30;
    final usedSlots = slots.where((s) => s != null).length;
    for (final e in c) {
      final ex = exposed(e.$2);
      var score = math.min(ex, e.$3) * 10 - (onBelt.contains(e.$2) ? 40 : 0);
      if (e.$1 >= 0) score += 15;
      if (ex == 0) score -= 1000;
      if (e.$3 > ex) score -= (e.$3 - ex) * (usedSlots >= slotsMax - 1 ? 30 : 4);
      if (score > bestScore) {
        bestScore = score;
        best = e;
      }
    }
    if (best == null) return null;
    if (bestScore < -500 && belt.isNotEmpty) return null;
    return best.$1;
  }

  Map<String, Object?> save() => {
        'px': List.of(px),
        'q': [for (final c in queues) [for (final e in c) List.of(e)]],
        'sl': [for (final s in slots) s?.toList() ?? []],
        'b': [for (final s in belt) s.toList()],
        'lo': lost ? 1 : 0,
        'sm': slotsMax,
        'f': fired,
      };

  void load(Map<String, Object?> j) {
    px = _li(j['px']);
    queues = [for (final c in (j['q'] as List)) _ll(c)];
    slots
      ..clear()
      ..addAll([for (final s in (j['sl'] as List)) (s as List).isEmpty ? null : Shooter(_li(s)[0], _li(s)[1], _li(s)[2])]);
    belt
      ..clear()
      ..addAll([for (final s in (j['b'] as List)) Shooter(_li(s)[0], _li(s)[1], _li(s)[2])]);
    lost = j['lo'] == 1;
    slotsMax = (j['sm'] as num).toInt();
    fired = (j['f'] as num?)?.toInt() ?? 0;
  }
}

/// Piksel Akışı bölümü üretir: resim, cephane parçaları, sütunlar.
Map<String, Object?> makePixelFlow(int d, SeededRandom r) {
  final size = const [8, 9, 10, 10, 11, 12, 12, 13, 14, 15][d - 1];
  final colors = math.min(2 + (d + 1) ~/ 2, 6);
  final px = pixelArt(size, size, colors, r);
  final counts = List.filled(colors, 0);
  for (final v in px) {
    if (v >= 0) counts[v]++;
  }
  final shooters = <List<int>>[];
  final chunk = d <= 3 ? 20 : (d <= 6 ? 15 : 10);
  for (var c = 0; c < colors; c++) {
    var left = counts[c];
    while (left > 0) {
      final a = math.min(left, chunk ~/ 2 + r.nextInt(chunk));
      shooters.add([c, a]);
      left -= a;
    }
  }
  r.shuffle(shooters);
  final cols = d <= 2 ? 2 : (d <= 6 ? 3 : 4);
  final q = <List<List<int>>>[for (var i = 0; i < cols; i++) []];
  for (var i = 0; i < shooters.length; i++) {
    q[i % cols].add(shooters[i]);
  }
  return {'w': size, 'h': size, 'px': px, 'q': q, 'slots': d <= 4 ? 5 : 4, 'belt': d <= 3 ? 5 : 4};
}

/// Botla oynatarak çözülebilirliği sınar (en çok [maxTicks] adım).
bool pixelSolvable(Map<String, Object?> d, {int maxTicks = 40000}) {
  final s = PixelSim(d);
  for (var t = 0; t < maxTicks; t++) {
    if (s.won) return true;
    if (s.lost || s.stuck) return false;
    final c = s.botChoice();
    if (c != null) s.send(c);
    s.tick();
  }
  return s.won;
}

// ===================================================================
// Renk Döngüsü: döngü bandındaki taneler, istasyonlardaki aynı renk
// kaplara dökülür; kap dolunca gider. Hazne bandın boşluklarını doldurur.
// ===================================================================
class LoopSim {
  final int n; // bant uzunluğu
  final int cap; // kap kapasitesi
  final List<int> stations; // istasyonların bant konumları
  late List<int> belt; // konum → renk (-1 boş)
  late List<int> hopper; // sıradaki taneler (baştan)
  late List<List<int>> queues; // sütun → renkler (üstten)
  late List<int> cupColor, cupFill; // istasyon başına (-1 boş)
  int offset = 0; // bant dönüşü
  int idle = 0;
  bool lost = false;
  int collected = 0;
  int inlet = 0;
  final List<int> justFilled = [];

  LoopSim(Map<String, Object?> d)
      : n = (d['n'] as num).toInt(),
        cap = (d['cap'] as num).toInt(),
        stations = _li(d['st']) {
    belt = _li(d['belt']);
    hopper = _li(d['hop']);
    queues = _ll(d['q']);
    cupColor = List.filled(stations.length, -1);
    cupFill = List.filled(stations.length, 0);
    inlet = (d['in'] as num?)?.toInt() ?? 0;
  }

  bool get won => belt.every((v) => v < 0) && hopper.isEmpty;
  int get grainsLeft => belt.where((v) => v >= 0).length + hopper.length;

  /// Bant yuvası: istasyon konumundaki dizin (dönüşle).
  int at(int pos) => ((pos - offset) % n + n) % n;

  bool get slotFree => cupColor.contains(-1);

  bool send(int col) {
    if (lost || col < 0 || col >= queues.length || queues[col].isEmpty || !slotFree) return false;
    final s = cupColor.indexOf(-1);
    cupColor[s] = queues[col].removeAt(0);
    cupFill[s] = 0;
    idle = 0;
    return true;
  }

  void tick() {
    justFilled.clear();
    if (lost) return;
    offset = (offset + 1) % n;
    var active = false;
    for (var s = 0; s < stations.length; s++) {
      final c = cupColor[s];
      if (c < 0) continue;
      final i = at(stations[s]);
      if (belt[i] == c && cupFill[s] < cap) {
        belt[i] = -1;
        cupFill[s]++;
        collected++;
        active = true;
        if (cupFill[s] >= cap) {
          cupColor[s] = -1;
          cupFill[s] = 0;
          justFilled.add(s);
        }
      }
    }
    final ii = at(inlet);
    // Hazne yalnızca bant yarı dolu değilken akar (bant hep sınırlı bir renk penceresi taşır).
    if (belt[ii] < 0 && hopper.isNotEmpty && belt.where((v) => v >= 0).length < (n * 0.5).ceil()) {
      belt[ii] = hopper.removeAt(0);
      active = true;
    }
    idle = active ? 0 : idle + 1;
    if (!slotFree && idle > n + 2) lost = true;
  }

  int? botChoice() {
    if (!slotFree) return null;
    final have = <int, int>{};
    for (final v in belt) {
      if (v >= 0) have[v] = (have[v] ?? 0) + 1;
    }
    for (var k = 0; k < math.min(hopper.length, n ~/ 3); k++) {
      have[hopper[k]] = (have[hopper[k]] ?? 0) + 1;
    }
    for (var s = 0; s < stations.length; s++) {
      final c = cupColor[s];
      if (c >= 0) have[c] = (have[c] ?? 0) - (cap - cupFill[s]);
    }
    int? best;
    var bestScore = -1 << 30;
    for (var col = 0; col < queues.length; col++) {
      if (queues[col].isEmpty) continue;
      final c = queues[col].first;
      final score = (have[c] ?? 0) * 10 - (cupColor.contains(c) ? 5 : 0);
      if (score > bestScore) {
        bestScore = score;
        best = col;
      }
    }
    if (bestScore < cap * 10 && cupColor.any((c) => c >= 0)) return null;
    return best;
  }

  Map<String, Object?> save() => {
        'belt': List.of(belt),
        'hop': List.of(hopper),
        'q': [for (final c in queues) List.of(c)],
        'cc': List.of(cupColor),
        'cf': List.of(cupFill),
        'o': offset,
        'i': idle,
        'lo': lost ? 1 : 0,
        'co': collected,
      };

  void load(Map<String, Object?> j) {
    belt = _li(j['belt']);
    hopper = _li(j['hop']);
    queues = _ll(j['q']);
    cupColor = _li(j['cc']);
    cupFill = _li(j['cf']);
    offset = (j['o'] as num).toInt();
    idle = (j['i'] as num).toInt();
    lost = j['lo'] == 1;
    collected = (j['co'] as num).toInt();
  }
}

Map<String, Object?> makeColorLoop(int d, SeededRandom r) {
  final colors = math.min(3 + d ~/ 2, 7);
  const cap = 3;
  final n = 18 + d * 2;
  final cups = <int>[];
  for (var c = 0; c < colors; c++) {
    final k = 2 + r.nextInt(d <= 3 ? 2 : 3);
    for (var i = 0; i < k; i++) {
      cups.add(c);
    }
  }
  // Hazne: kum kavanozu gibi renk katmanları (1-2 kaplık öbekler).
  final chunks = <List<int>>[];
  final per = <int, int>{};
  for (final c in cups) {
    per[c] = (per[c] ?? 0) + 1;
  }
  per.forEach((c, k) {
    var left = k;
    while (left > 0) {
      final take = math.min(left, 1 + r.nextInt(2));
      chunks.add(List.filled(take * cap, c));
      left -= take;
    }
  });
  r.shuffle(chunks);
  final grains = [for (final ch in chunks) ...ch];
  // Katmanlar komşularıyla biraz karışır.
  for (var i = 0; i < grains.length - 1; i++) {
    if (r.nextInt(100) < 18) {
      final t = grains[i];
      grains[i] = grains[i + 1];
      grains[i + 1] = t;
    }
  }
  final belt = List.filled(n, -1);
  final fill = math.min(grains.length, (n * 0.5).round());
  for (var k = 0; k < fill; k++) {
    belt[(k * 2) % n] = grains[k];
  }
  final hopper = grains.sublist(fill);
  r.shuffle(cups);
  final cols = d <= 2 ? 2 : (d <= 6 ? 3 : 4);
  final q = <List<int>>[for (var i = 0; i < cols; i++) []];
  for (var i = 0; i < cups.length; i++) {
    q[i % cols].add(cups[i]);
  }
  final st = d <= 2 ? 4 : (d <= 6 ? 3 : 2);
  final stations = [for (var s = 0; s < st; s++) (n * (s + 0.5) / st).floor()];
  return {'n': n, 'cap': cap, 'st': stations, 'belt': belt, 'hop': hopper, 'q': q, 'in': 0};
}

bool loopSolvable(Map<String, Object?> d, {int maxTicks = 30000}) {
  final s = LoopSim(d);
  for (var t = 0; t < maxTicks; t++) {
    if (s.won) return true;
    if (s.lost) return false;
    final c = s.botChoice();
    if (c != null) s.send(c);
    s.tick();
  }
  return s.won;
}

// ===================================================================
// Tatlı Tepsisi: 6 dilimlik tabaklar; yerleştirilen tabak komşularıyla
// aynı tatlıları toplar, 6 aynı dilimle dolan tabak tamamlanıp kalkar.
// ===================================================================
class TraySim {
  final int rows, cols, types, target;
  final List<int> blocked;
  late List<List<int>> board; // hücre → dilimler (boş liste: tabak yok)
  late List<bool> has; // hücrede tabak var mı
  late List<List<int>> offer; // 3 sunulan tabak
  late int rngState;
  int done = 0;
  final List<int> completedNow = [];

  TraySim(Map<String, Object?> d)
      : rows = (d['r'] as num).toInt(),
        cols = (d['c'] as num).toInt(),
        types = (d['t'] as num).toInt(),
        target = (d['g'] as num).toInt(),
        blocked = _li(d['bl']) {
    board = [for (var i = 0; i < rows * cols; i++) <int>[]];
    has = List.filled(rows * cols, false);
    rngState = (d['seed'] as num).toInt();
    final pre = d['pre'] as List? ?? const [];
    for (final e in pre) {
      final l = _li(e);
      board[l[0]] = l.sublist(1);
      has[l[0]] = true;
    }
    offer = [for (var i = 0; i < 3; i++) newPlate()];
  }

  List<int> newPlate() {
    final r = SeededRandom.fromState(rngState);
    final n = 1 + r.nextInt(r.nextInt(100) < 35 ? 4 : 3);
    final kinds = 1 + (n >= 3 && r.nextInt(100) < 55 ? 1 : 0) + (n >= 4 && r.nextInt(100) < 30 ? 1 : 0);
    final pick = [for (var k = 0; k < kinds; k++) r.nextInt(types)];
    final out = [for (var i = 0; i < n; i++) pick[i % kinds]]..sort();
    rngState = r.state;
    return out;
  }

  bool get won => done >= target;
  bool free(int i) => !has[i] && !blocked.contains(i);
  bool get lost => !won && [for (var i = 0; i < rows * cols; i++) i].every((i) => !free(i));

  List<int> nb(int i) {
    final x = i % cols, y = i ~/ cols;
    return [if (x > 0) i - 1, if (x < cols - 1) i + 1, if (y > 0) i - cols, if (y < rows - 1) i + cols];
  }

  int cnt(List<int> p, int t) => p.where((v) => v == t).length;

  /// Sunulan [k]. tabağı [cell] hücresine koy ve birleştir.
  bool place(int k, int cell) {
    if (k < 0 || k >= offer.length || offer[k].isEmpty || !free(cell)) return false;
    board[cell] = List.of(offer[k]);
    has[cell] = true;
    offer[k] = newPlate();
    _resolve(cell);
    return true;
  }

  void _resolve(int start) {
    completedNow.clear();
    final dirty = <int>[start];
    var guard = 0;
    while (dirty.isNotEmpty && guard++ < 200) {
      final a = dirty.removeAt(0);
      if (!has[a]) continue;
      for (final b in nb(a)) {
        if (!has[b]) continue;
        for (var t = 0; t < types; t++) {
          final ca = cnt(board[a], t), cb = cnt(board[b], t);
          if (ca == 0 || cb == 0) continue;
          // çoğunluğa doğru akar; eşitse etkin tabağa
          final toA = ca >= cb;
          final from = toA ? b : a, to = toA ? a : b;
          final room = 6 - board[to].length;
          final mv = math.min(room, toA ? cb : ca);
          if (mv <= 0) continue;
          for (var m = 0; m < mv; m++) {
            board[from].remove(t);
            board[to].add(t);
          }
          board[to].sort();
          if (!dirty.contains(from)) dirty.add(from);
          if (!dirty.contains(to)) dirty.add(to);
        }
      }
      for (final i in [a, ...nb(a)]) {
        if (!has[i]) continue;
        if (board[i].length == 6 && board[i].every((v) => v == board[i].first)) {
          board[i] = [];
          has[i] = false;
          done++;
          completedNow.add(i);
        } else if (board[i].isEmpty) {
          has[i] = false;
        }
      }
    }
  }

  /// Bot: her (tabak, hücre) için sonucu dener; en iyisini seçer.
  (int, int)? botChoice() {
    (int, int)? best;
    var bestScore = -1 << 30;
    for (var k = 0; k < offer.length; k++) {
      for (var cell = 0; cell < rows * cols; cell++) {
        if (!free(cell)) continue;
        final t = copy()..place(k, cell);
        var score = (t.done - done) * 1000;
        // tabak başına tek tür yoğunluğu
        for (var i = 0; i < rows * cols; i++) {
          if (!t.has[i]) continue;
          final p = t.board[i];
          final kinds = p.toSet().length;
          score += (p.length * 6) ~/ kinds - kinds * 8;
        }
        score -= [for (var i = 0; i < rows * cols; i++) i].where((i) => t.has[i]).length * 25;
        if (score > bestScore) {
          bestScore = score;
          best = (k, cell);
        }
      }
    }
    return best;
  }

  TraySim copy() => TraySim._copy(this);
  TraySim._copy(TraySim o)
      : rows = o.rows,
        cols = o.cols,
        types = o.types,
        target = o.target,
        blocked = o.blocked {
    board = [for (final p in o.board) List.of(p)];
    has = List.of(o.has);
    offer = [for (final p in o.offer) List.of(p)];
    rngState = o.rngState;
    done = o.done;
  }

  Map<String, Object?> save() => {
        'b': [for (final p in board) List.of(p)],
        'h': [for (final v in has) v ? 1 : 0],
        'o': [for (final p in offer) List.of(p)],
        's': rngState,
        'd': done,
      };

  void load(Map<String, Object?> j) {
    board = _ll(j['b']);
    has = [for (final v in _li(j['h'])) v == 1];
    offer = _ll(j['o']);
    rngState = (j['s'] as num).toInt();
    done = (j['d'] as num).toInt();
  }
}

Map<String, Object?> makeTray(int d, SeededRandom r) {
  final rows = d <= 3 ? 3 : 4, cols = d <= 5 ? 4 : 5;
  final types = math.min(3 + d ~/ 2, 7);
  final target = 4 + d * 2;
  final blocked = <int>[];
  if (d >= 6) {
    for (var k = 0; k < (d - 4) ~/ 2; k++) {
      final i = r.nextInt(rows * cols);
      if (!blocked.contains(i)) blocked.add(i);
    }
  }
  return {'r': rows, 'c': cols, 't': types, 'g': target, 'bl': blocked, 'seed': r.nextInt(1 << 30), 'pre': <List<int>>[]};
}

bool traySolvable(Map<String, Object?> d, {int maxMoves = 400}) {
  final s = TraySim(d);
  for (var m = 0; m < maxMoves; m++) {
    if (s.won) return true;
    if (s.lost) return false;
    final c = s.botChoice();
    if (c == null) return false;
    s.place(c.$1, c.$2);
  }
  return s.won;
}
