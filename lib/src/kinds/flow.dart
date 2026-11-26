import 'dart:math' as math;
import 'dart:ui';

import 'package:studio_core/core/rng.dart';

import '../core.dart';
import '../glyphs.dart';
import '../texts.dart';
import 'flow_sim.dart';

const _kWhite = Color(0xFFFFFFFF);
const _kInk = Color(0xFF263045);

Paint _fill(Color c) => Paint()..color = c;
Paint _line(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w;

// ===================================================================
// Piksel Akışı
// ===================================================================
class PixelFlowKind extends MatchKind {
  const PixelFlowKind();
  @override
  String get id => 'piksel-akisi';

  @override
  MLevel make(int d, SeededRandom r) {
    for (var a = 0; a < 60; a++) {
      final data = makePixelFlow(d, r);
      if (pixelSolvable(data)) return MLevel(id, d, r.nextInt(1 << 30), data);
    }
    throw StateError('pixel');
  }

  @override
  MGame start(MLevel lv) => PixelFlowGame(lv);

  @override
  bool solvable(MLevel lv) => pixelSolvable(lv.data);
}

class PixelFlowGame extends MGame {
  late PixelSim sim;
  double _acc = 0;
  int _hint = -99;
  double _hintT = 0;
  int _extra = 0;
  final List<(int, int, double)> _beams = [];
  static const _dt = 1 / 14;

  PixelFlowGame(super.lv) {
    sim = PixelSim(lv.data);
  }

  @override
  bool get undoable => false;
  @override
  bool get won => sim.won;
  @override
  bool get lost => sim.lost || sim.stuck;
  @override
  String status(String lang) => '${mt(lang, 'pixels')}: ${sim.pixelsLeft}';

  // yerleşim
  late Rect _img;
  late double _cell, _m;
  void _layout() {
    final side = math.min(size.width * 0.74, size.height * 0.46);
    _cell = side / math.max(sim.w, sim.h);
    _m = _cell * 1.6;
    _img = Rect.fromLTWH((size.width - _cell * sim.w) / 2, _m + 8, _cell * sim.w, _cell * sim.h);
  }

  Offset _beltPos(double p) {
    final w = sim.w, h = sim.h;
    final loop = sim.loop;
    p = p % loop;
    final o = _m * 0.62;
    if (p < w) return Offset(_img.left + (p + 0.5) * _cell, _img.top - o);
    if (p < w + h) return Offset(_img.right + o, _img.top + (p - w + 0.5) * _cell);
    if (p < 2 * w + h) return Offset(_img.right - (p - w - h + 0.5) * _cell, _img.bottom + o);
    return Offset(_img.left - o, _img.bottom - (p - 2 * w - h + 0.5) * _cell);
  }

  Rect _slotRect(int s) {
    final n = math.max(sim.slotsMax, sim.slots.length);
    final sz = math.min(size.width / (n + 1), _cell * 2.4);
    final top = _img.bottom + _m + 14;
    return Rect.fromLTWH((size.width - n * sz) / 2 + s * sz + 3, top, sz - 6, sz - 6);
  }

  Rect _colRect(int c, int k) {
    final cols = sim.queues.length;
    final cw = math.min(size.width / cols, _cell * 4);
    final top = _slotRect(0).bottom + 18;
    final sz = math.min(cw * 0.72, (size.height - top) / 4.2);
    return Rect.fromLTWH((size.width - cols * cw) / 2 + c * cw + (cw - sz) / 2, top + k * sz * 1.05, sz, sz);
  }

  @override
  bool down(Offset p) {
    _layout();
    for (var c = 0; c < sim.queues.length; c++) {
      if (sim.queues[c].isNotEmpty && _colRect(c, 0).inflate(6).contains(p)) return _send(-1 - c);
    }
    for (var s = 0; s < sim.slots.length; s++) {
      if (sim.slots[s] != null && _slotRect(s).inflate(4).contains(p)) return _send(s);
    }
    return false;
  }

  bool _send(int src) {
    if (!sim.send(src)) return false;
    moves++;
    _hint = -99;
    bump('pairs_matched');
    return true;
  }

  @override
  bool step(double dt) {
    _acc += dt;
    while (_acc >= _dt) {
      _acc -= _dt;
      sim.tick();
      for (final (pos, i) in sim.shots) {
        _beams.add((pos, i, 0.18));
      }
      score = sim.fired * 5;
    }
    for (var k = _beams.length - 1; k >= 0; k--) {
      final b = _beams[k];
      if (b.$3 - dt <= 0) {
        _beams.removeAt(k);
      } else {
        _beams[k] = (b.$1, b.$2, b.$3 - dt);
      }
    }
    if (_hint != -99) _hintT += dt;
    return true;
  }

  @override
  bool hint() {
    final c = sim.botChoice() ?? (sim.candidates().isEmpty ? null : sim.candidates().first.$1);
    if (c == null) return false;
    _hint = c;
    _hintT = 0;
    return true;
  }

  @override
  bool booster() {
    if (_extra >= 2) return false;
    _extra++;
    sim.slotsMax++;
    return true;
  }

  @override
  String boosterKey() => 'slot';

  @override
  bool continueAfterLoss() {
    if (!sim.lost) return false;
    sim.lost = false;
    sim.slotsMax = math.max(sim.slotsMax, sim.slots.length) + 1;
    return true;
  }

  void _shooter(Canvas c, Rect r, int color, int ammo, MPalette p, {bool glow = false}) {
    final col = p.piece(color);
    if (glow) c.drawRRect(RRect.fromRectAndRadius(r.inflate(5), Radius.circular(r.width * 0.3)), _fill(const Color(0xFFFFE08A)));
    c.drawRRect(RRect.fromRectAndRadius(r.shift(const Offset(0, 3)), Radius.circular(r.width * 0.24)), _fill(const Color(0x44000000)));
    c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.24)), _fill(col));
    c.drawCircle(r.center, r.width * 0.3, _fill(const Color(0x33000000)));
    if (p.colorBlind) drawGlyph(c, color * 3 % kGlyphCount, r.deflate(r.width * 0.28), const Color(0x88FFFFFF));
    drawText(c, '$ammo', r.center, r.width * 0.36, _kWhite);
  }

  @override
  void paint(Canvas c, Size size, MPalette p, double t) {
    this.size = size;
    _layout();
    // bant
    final track = RRect.fromRectAndRadius(_img.inflate(_m * 0.62), Radius.circular(_m * 0.5));
    c.drawRRect(track, _line(const Color(0xFF3A4256), _m * 0.7));
    c.drawRRect(track, _line(const Color(0xFF59627A), 2));
    // resim
    c.drawRect(_img.inflate(3), _fill(const Color(0xFF1B2030)));
    for (var i = 0; i < sim.px.length; i++) {
      final v = sim.px[i];
      if (v < 0) continue;
      final r = Rect.fromLTWH(_img.left + (i % sim.w) * _cell, _img.top + (i ~/ sim.w) * _cell, _cell, _cell).deflate(0.6);
      c.drawRect(r, _fill(p.piece(v)));
      c.drawRect(Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.22), _fill(const Color(0x26FFFFFF)));
      if (p.colorBlind && _cell > 14) drawGlyph(c, v * 3 % kGlyphCount, r.deflate(_cell * 0.25), const Color(0x66FFFFFF));
    }
    // ışınlar
    for (final (pos, i, life) in _beams) {
      final a = _beltPos(pos.toDouble());
      final b = Rect.fromLTWH(_img.left + (i % sim.w) * _cell, _img.top + (i ~/ sim.w) * _cell, _cell, _cell).center;
      c.drawLine(a, b, _line(const Color(0xFFFFF2A8).withValues(alpha: (life / 0.18).clamp(0.0, 1.0)), 3));
    }
    // banttaki atıcılar
    final f = (_acc / _dt).clamp(0.0, 1.0);
    final sz = _m * 0.82;
    for (final s in sim.belt) {
      final at = _beltPos(s.pos + f);
      _shooter(c, Rect.fromCenter(center: at, width: sz, height: sz), s.color, s.ammo, p);
    }
    // bekleme yuvaları
    final n = math.max(sim.slotsMax, sim.slots.length);
    for (var s = 0; s < n; s++) {
      final r = _slotRect(s);
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.2)), _line(const Color(0x66FFFFFF), 2));
      final sh = s < sim.slots.length ? sim.slots[s] : null;
      if (sh != null) _shooter(c, r.deflate(3), sh.color, sh.ammo, p, glow: _hint == s && (_hintT * 3).floor().isEven);
    }
    // kuyruk sütunları
    for (var col = 0; col < sim.queues.length; col++) {
      final q = sim.queues[col];
      for (var k = math.min(q.length, 4) - 1; k >= 0; k--) {
        final r = _colRect(col, k);
        final e = q[k];
        _shooter(c, k == 0 ? r : r.deflate(r.width * 0.12), e[0], e[1], p, glow: k == 0 && _hint == -1 - col && (_hintT * 3).floor().isEven);
        if (k > 0) c.drawRRect(RRect.fromRectAndRadius(r.deflate(r.width * 0.12), Radius.circular(r.width * 0.2)), _fill(const Color(0x66000000)));
      }
      if (q.length > 4) drawText(c, '+${q.length - 4}', _colRect(col, 4).topCenter + const Offset(0, 8), 14, const Color(0xAAFFFFFF));
    }
    // kapasite göstergesi
    drawText(c, '${sim.belt.length}/${sim.beltMax}', Offset(_img.right + _m * 0.62, _img.top - _m * 0.62), _m * 0.34, const Color(0xCCFFFFFF));
  }

  @override
  Map<String, Object?> save() => {'s': sim.save(), 'm': moves, 'x': _extra};

  @override
  void load(Map<String, Object?> j) {
    sim = PixelSim(lv.data)..load(Map<String, Object?>.from(j['s'] as Map));
    moves = (j['m'] as num).toInt();
    _extra = (j['x'] as num?)?.toInt() ?? 0;
    _beams.clear();
  }
}

// ===================================================================
// Renk Döngüsü
// ===================================================================
class ColorLoopKind extends MatchKind {
  const ColorLoopKind();
  @override
  String get id => 'renk-dongusu';

  @override
  MLevel make(int d, SeededRandom r) {
    for (var a = 0; a < 80; a++) {
      final data = makeColorLoop(d, r);
      if (loopSolvable(data)) return MLevel(id, d, r.nextInt(1 << 30), data);
    }
    throw StateError('loop');
  }

  @override
  MGame start(MLevel lv) => ColorLoopGame(lv);

  @override
  bool solvable(MLevel lv) => loopSolvable(lv.data);
}

class ColorLoopGame extends MGame {
  late LoopSim sim;
  double _acc = 0;
  int _hint = -1;
  double _hintT = 0;
  int _extra = 0;
  final Map<int, double> _pop = {};
  static const _dt = 1 / 8;

  ColorLoopGame(super.lv) {
    sim = LoopSim(lv.data);
  }

  @override
  bool get undoable => false;
  @override
  bool get won => sim.won;
  @override
  bool get lost => sim.lost;
  @override
  String status(String lang) => '${mt(lang, 'grains')}: ${sim.grainsLeft}';

  late Rect _track;
  void _layout() {
    final w = size.width * 0.86, h = math.min(size.height * 0.36, w * 0.62);
    _track = Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.16 + h / 2 + 34), width: w, height: h);
  }

  /// Stadyum yolu üzerinde 0..1 (0 = üst orta, saat yönünde).
  Offset _path(double u) {
    final r = _track.height / 2;
    final straight = _track.width - 2 * r;
    final per = 2 * straight + 2 * math.pi * r;
    var d = (u % 1) * per;
    final topY = _track.top, botY = _track.bottom;
    final lx = _track.left + r, rx = _track.right - r;
    // üst ortadan sağa
    if (d < straight / 2) return Offset(_track.center.dx + d, topY);
    d -= straight / 2;
    if (d < math.pi * r) {
      final a = -math.pi / 2 + d / r;
      return Offset(rx + r * math.cos(a), _track.center.dy + r * math.sin(a));
    }
    d -= math.pi * r;
    if (d < straight) return Offset(rx - d, botY);
    d -= straight;
    if (d < math.pi * r) {
      final a = math.pi / 2 + d / r;
      return Offset(lx + r * math.cos(a), _track.center.dy + r * math.sin(a));
    }
    d -= math.pi * r;
    return Offset(lx + d, topY);
  }

  Offset _outward(double u) {
    final a = _path(u), b = _path(u + 0.001);
    final t = b - a;
    final len = t.distance == 0 ? 1.0 : t.distance;
    return Offset(t.dy, -t.dx) / len; // saat yönünde dışa
  }

  Rect _station(int s) {
    final u = sim.stations[s] / sim.n;
    final o = _path(u) + _outward(u) * (_track.height * 0.2);
    final sz = _track.height * 0.24;
    return Rect.fromCenter(center: o, width: sz, height: sz * 1.1);
  }

  Rect _colRect(int c, int k) {
    final cols = sim.queues.length;
    final top = _track.bottom + _track.height * 0.32;
    final cw = size.width / (cols + 0.5);
    final sz = math.min(cw * 0.55, (size.height - top) / 4.4);
    return Rect.fromLTWH((size.width - cols * cw) / 2 + c * cw + (cw - sz) / 2, top + k * sz * 1.1, sz, sz * 1.05);
  }

  @override
  bool down(Offset p) {
    _layout();
    for (var c = 0; c < sim.queues.length; c++) {
      if (sim.queues[c].isNotEmpty && _colRect(c, 0).inflate(8).contains(p)) {
        if (sim.send(c)) {
          moves++;
          _hint = -1;
          return true;
        }
        return false;
      }
    }
    return false;
  }

  @override
  bool step(double dt) {
    _acc += dt;
    while (_acc >= _dt) {
      _acc -= _dt;
      final before = sim.collected;
      sim.tick();
      for (final s in sim.justFilled) {
        _pop[s] = 0.5;
        bump('pairs_matched');
      }
      score += (sim.collected - before) * 10;
    }
    for (final k in _pop.keys.toList()) {
      final v = _pop[k]! - dt;
      if (v <= 0) {
        _pop.remove(k);
      } else {
        _pop[k] = v;
      }
    }
    if (_hint >= 0) _hintT += dt;
    return true;
  }

  @override
  bool hint() {
    final c = sim.botChoice() ?? [for (var i = 0; i < sim.queues.length; i++) if (sim.queues[i].isNotEmpty) i].firstOrNull;
    if (c == null) return false;
    _hint = c;
    _hintT = 0;
    return true;
  }

  @override
  bool booster() {
    // Ek istasyon: en uzun boşluğun ortasına.
    if (_extra >= 1) return false;
    _extra++;
    final st = List.of(sim.stations)..sort();
    var best = 0, gap = -1;
    for (var i = 0; i < st.length; i++) {
      final g = ((i + 1 < st.length ? st[i + 1] : st[0] + sim.n) - st[i]);
      if (g > gap) {
        gap = g;
        best = (st[i] + g ~/ 2) % sim.n;
      }
    }
    sim.stations.add(best);
    sim.cupColor.add(-1);
    sim.cupFill.add(0);
    sim.idle = 0;
    return true;
  }

  @override
  String boosterKey() => 'slot';

  @override
  bool continueAfterLoss() {
    if (!sim.lost) return false;
    // En az dolu kabı kuyruğa geri koy.
    var s = 0;
    for (var i = 1; i < sim.cupColor.length; i++) {
      if (sim.cupFill[i] < sim.cupFill[s]) s = i;
    }
    final col = sim.cupColor[s];
    final back = sim.cupFill[s];
    sim.cupColor[s] = -1;
    sim.cupFill[s] = 0;
    // dökülen taneler hazneye döner
    for (var k = 0; k < back; k++) {
      sim.hopper.insert(0, col);
    }
    sim.queues.first.insert(0, col);
    sim.lost = false;
    sim.idle = 0;
    return true;
  }

  void _grain(Canvas c, Offset o, double r, int color, MPalette p) {
    c.drawCircle(o + Offset(0, r * 0.25), r, _fill(const Color(0x44000000)));
    c.drawCircle(o, r, _fill(p.piece(color)));
    c.drawCircle(o - Offset(r * 0.35, r * 0.35), r * 0.32, _fill(const Color(0x55FFFFFF)));
    if (p.colorBlind) drawGlyph(c, color * 3 % kGlyphCount, Rect.fromCircle(center: o, radius: r * 0.6), const Color(0x99FFFFFF));
  }

  void _cup(Canvas c, Rect r, int color, int fill, MPalette p, {bool glow = false, double pop = 0}) {
    if (glow) c.drawRRect(RRect.fromRectAndRadius(r.inflate(6), Radius.circular(r.width * 0.25)), _fill(const Color(0xFFFFE08A)));
    final col = p.piece(color);
    final path = Path()
      ..moveTo(r.left, r.top)
      ..lineTo(r.right, r.top)
      ..lineTo(r.right - r.width * 0.14, r.bottom)
      ..lineTo(r.left + r.width * 0.14, r.bottom)
      ..close();
    c.drawPath(path.shift(const Offset(0, 3)), _fill(const Color(0x44000000)));
    c.drawPath(path, _fill(Color.lerp(col, _kWhite, 0.55)!));
    final fr = (fill / sim.cap).clamp(0.0, 1.0);
    if (fr > 0) {
      c.save();
      c.clipPath(path);
      c.drawRect(Rect.fromLTRB(r.left, r.bottom - r.height * fr, r.right, r.bottom), _fill(col));
      c.restore();
    }
    c.drawPath(path, _line(col, 3));
    c.drawLine(r.topLeft, r.topRight, _line(Color.lerp(col, _kInk, 0.3)!, 5));
    if (p.colorBlind) drawGlyph(c, color * 3 % kGlyphCount, r.deflate(r.width * 0.3), const Color(0xAAFFFFFF));
    if (pop > 0) c.drawCircle(r.center, r.width * (1.2 - pop), _line(const Color(0xFFFFE08A), 4));
  }

  @override
  void paint(Canvas c, Size size, MPalette p, double t) {
    this.size = size;
    _layout();
    final r = _track.height / 2;
    final rr = RRect.fromRectAndRadius(_track, Radius.circular(r));
    c.drawRRect(rr, _line(const Color(0xFF3A4256), r * 0.34));
    c.drawRRect(rr, _line(const Color(0xFF59627A), 2));
    // hazne (kum kavanozu)
    final jar = Rect.fromCenter(center: Offset(size.width / 2, _track.top - r * 0.78), width: r * 0.75, height: r * 1.05);
    c.drawRRect(RRect.fromRectAndRadius(jar, Radius.circular(r * 0.16)), _fill(const Color(0x33FFFFFF)));
    final show = math.min(sim.hopper.length, 15);
    final band = jar.height / 15;
    for (var k = 0; k < show; k++) {
      final y = jar.bottom - (k + 1) * band;
      c.drawRect(Rect.fromLTWH(jar.left + 3, y, jar.width - 6, band + 0.5), _fill(p.piece(sim.hopper[k])));
    }
    c.drawRRect(RRect.fromRectAndRadius(jar, Radius.circular(r * 0.16)), _line(const Color(0xAAFFFFFF), 2.5));
    if (sim.hopper.length > 15) drawText(c, '+${sim.hopper.length - 15}', jar.topCenter - Offset(0, 12), 14, const Color(0xCCFFFFFF));
    // taneler
    final f = (_acc / _dt).clamp(0.0, 1.0);
    for (var i = 0; i < sim.n; i++) {
      final v = sim.belt[i];
      if (v < 0) continue;
      _grain(c, _path((i + sim.offset + f) / sim.n), r * 0.13, v, p);
    }
    // istasyonlar
    for (var s = 0; s < sim.stations.length; s++) {
      final rc = _station(s);
      final u = sim.stations[s] / sim.n;
      c.drawLine(_path(u), rc.center, _line(const Color(0x66FFFFFF), 3));
      if (sim.cupColor[s] < 0) {
        c.drawRRect(RRect.fromRectAndRadius(rc, Radius.circular(rc.width * 0.2)), _line(const Color(0x88FFFFFF), 2));
        if (_pop[s] != null) c.drawCircle(rc.center, rc.width * (1.3 - _pop[s]!), _line(const Color(0xFFFFE08A), 4));
      } else {
        _cup(c, rc, sim.cupColor[s], sim.cupFill[s], p);
      }
    }
    // kuyruk
    for (var col = 0; col < sim.queues.length; col++) {
      final q = sim.queues[col];
      for (var k = math.min(q.length, 4) - 1; k >= 0; k--) {
        final rc = _colRect(col, k);
        _cup(c, k == 0 ? rc : rc.deflate(rc.width * 0.1), q[k], 0, p, glow: k == 0 && _hint == col && (_hintT * 3).floor().isEven);
        if (k > 0) c.drawRect(rc.deflate(rc.width * 0.1), _fill(const Color(0x55000000)));
      }
      if (q.length > 4) drawText(c, '+${q.length - 4}', _colRect(col, 4).topCenter + const Offset(0, 8), 14, const Color(0xAAFFFFFF));
    }
  }

  @override
  Map<String, Object?> save() => {'s': sim.save(), 'm': moves, 'x': _extra, 'st': List.of(sim.stations)};

  @override
  void load(Map<String, Object?> j) {
    sim = LoopSim(lv.data);
    final st = [for (final v in (j['st'] as List? ?? const [])) (v as num).toInt()];
    while (sim.stations.length < st.length) {
      sim.stations.add(st[sim.stations.length]);
    }
    sim.load(Map<String, Object?>.from(j['s'] as Map));
    moves = (j['m'] as num).toInt();
    _extra = (j['x'] as num?)?.toInt() ?? 0;
  }
}

// ===================================================================
// Tatlı Tepsisi
// ===================================================================
class DessertTrayKind extends MatchKind {
  const DessertTrayKind();
  @override
  String get id => 'tatli-tepsisi';

  @override
  MLevel make(int d, SeededRandom r) {
    for (var a = 0; a < 60; a++) {
      final data = makeTray(d, r);
      if (traySolvable(data)) return MLevel(id, d, r.nextInt(1 << 30), data);
    }
    throw StateError('tray');
  }

  @override
  MGame start(MLevel lv) => DessertTrayGame(lv);

  @override
  bool solvable(MLevel lv) => traySolvable(lv.data);
}

class DessertTrayGame extends MGame {
  late TraySim sim;
  int sel = -1;
  int _drag = -1;
  Offset _pos = Offset.zero;
  bool _moved = false;
  (int, int)? _hint;
  double _hintT = 0;
  int _rerolls = 0;
  final Map<int, double> _flash = {};

  DessertTrayGame(super.lv) {
    sim = TraySim(lv.data);
  }

  @override
  bool get won => sim.won;
  @override
  bool get lost => sim.lost;
  @override
  String status(String lang) => '${mt(lang, 'target')}: ${sim.done} / ${sim.target}';

  late double _cell;
  late Offset _o;
  void _layout() {
    _cell = math.min(size.width * 0.94 / sim.cols, size.height * 0.68 / sim.rows);
    _o = Offset((size.width - _cell * sim.cols) / 2, 10);
  }

  Rect _cellRect(int i) => Rect.fromLTWH(_o.dx + (i % sim.cols) * _cell, _o.dy + (i ~/ sim.cols) * _cell, _cell, _cell);

  Rect _offerRect(int k) {
    final top = _o.dy + sim.rows * _cell + 16;
    final sz = math.min(size.width / 3.4, size.height - top - 8);
    return Rect.fromLTWH((size.width - 3 * sz) / 2 + k * sz, top, sz, sz);
  }

  int _cellAt(Offset p) {
    for (var i = 0; i < sim.rows * sim.cols; i++) {
      if (_cellRect(i).contains(p)) return i;
    }
    return -1;
  }

  @override
  bool down(Offset p) {
    _layout();
    _moved = false;
    _pos = p;
    for (var k = 0; k < 3; k++) {
      if (_offerRect(k).contains(p)) {
        _drag = k;
        sel = k;
        return true;
      }
    }
    final i = _cellAt(p);
    if (i >= 0 && sel >= 0 && sim.free(i)) return _place(sel, i);
    return false;
  }

  @override
  bool move(Offset p) {
    if (_drag < 0) return false;
    if ((p - _pos).distance > 8) _moved = true;
    _pos = p;
    return true;
  }

  @override
  bool up(Offset p) {
    if (_drag < 0) return false;
    final k = _drag;
    _drag = -1;
    if (!_moved) return true;
    final i = _cellAt(_pos);
    if (i >= 0 && sim.free(i)) return _place(k, i);
    return true;
  }

  bool _place(int k, int i) {
    if (!sim.place(k, i)) return false;
    moves++;
    sel = -1;
    _hint = null;
    for (final c in sim.completedNow) {
      _flash[c] = 0.6;
      bump('pairs_matched');
      score += 100;
    }
    return true;
  }

  @override
  bool hint() {
    final b = sim.botChoice();
    if (b == null) return false;
    _hint = b;
    _hintT = 0;
    return true;
  }

  @override
  bool booster() {
    if (_rerolls >= 3) return false;
    _rerolls++;
    for (var k = 0; k < 3; k++) {
      sim.offer[k] = sim.newPlate();
    }
    return true;
  }

  @override
  String boosterKey() => 'shuffle';

  @override
  bool continueAfterLoss() {
    if (!sim.lost) return false;
    // En karışık üç tabağı kaldır.
    final cells = [for (var i = 0; i < sim.rows * sim.cols; i++) if (sim.has[i]) i]
      ..sort((a, b) => sim.board[b].toSet().length.compareTo(sim.board[a].toSet().length));
    for (final i in cells.take(3)) {
      sim.board[i] = [];
      sim.has[i] = false;
    }
    return true;
  }

  @override
  bool step(double dt) {
    for (final k in _flash.keys.toList()) {
      final v = _flash[k]! - dt;
      if (v <= 0) {
        _flash.remove(k);
      } else {
        _flash[k] = v;
      }
    }
    if (_hint != null) _hintT += dt;
    return _flash.isNotEmpty || _hint != null;
  }

  static const _dessert = [
    Color(0xFFD9A441), // baklava
    Color(0xFFF4A7B9), // lokum
    Color(0xFFF3DDE6), // mochi
    Color(0xFFE8772E), // künefe
    Color(0xFF6B4226), // brownie
    Color(0xFFF3E3B5), // peynirli kek
    Color(0xFF8DB65B), // yeşil çay keki
  ];

  void _slice(Canvas c, Offset o, double r, int i, int type, bool cb) {
    final a0 = -math.pi / 2 + i * math.pi / 3;
    final path = Path()
      ..moveTo(o.dx, o.dy)
      ..arcTo(Rect.fromCircle(center: o, radius: r), a0 + 0.04, math.pi / 3 - 0.08, false)
      ..close();
    c.drawPath(path, _fill(_dessert[type % _dessert.length]));
    c.save();
    c.clipPath(path);
    final mid = a0 + math.pi / 6;
    final m = o + Offset(math.cos(mid), math.sin(mid)) * r * 0.6;
    switch (type % _dessert.length) {
      case 0: // baklava: baklava dilimi çizgileri + fıstık
        for (var k = -3; k <= 3; k++) {
          c.drawLine(m + Offset(k * r * 0.18 - r, -r), m + Offset(k * r * 0.18 + r, r), _line(const Color(0x66A0661C), 1.4));
          c.drawLine(m + Offset(k * r * 0.18 + r, -r), m + Offset(k * r * 0.18 - r, r), _line(const Color(0x66A0661C), 1.4));
        }
        c.drawCircle(m, r * 0.07, _fill(const Color(0xFF6FA341)));
      case 1: // lokum: pudra
        for (var k = 0; k < 5; k++) {
          c.drawCircle(m + Offset(math.cos(k * 1.3) * r * 0.2, math.sin(k * 2.1) * r * 0.2), r * 0.035, _fill(const Color(0xCCFFFFFF)));
        }
      case 2: // mochi: yumuşak parlaklık
        c.drawCircle(m - Offset(r * 0.06, r * 0.06), r * 0.13, _fill(const Color(0x99FFFFFF)));
      case 3: // künefe: tel kadayıf
        for (var k = 0; k < 6; k++) {
          c.drawLine(m + Offset(-r * 0.3, -r * 0.3 + k * r * 0.11), m + Offset(r * 0.3, -r * 0.25 + k * r * 0.11), _line(const Color(0x88FFD08A), 1.2));
        }
      case 4: // brownie: çikolata sosu
        c.drawLine(m - Offset(r * 0.3, r * 0.1), m + Offset(r * 0.3, r * 0.15), _line(const Color(0x99D7B48A), 2));
      case 5: // peynirli kek: meyve
        c.drawCircle(m - Offset(0, r * 0.1), r * 0.09, _fill(const Color(0xFFC0392B)));
      default: // yeşil çay keki: katman
        c.drawLine(m - Offset(r * 0.4, 0), m + Offset(r * 0.4, 0), _line(const Color(0x99FFFFFF), 2));
    }
    c.restore();
    c.drawPath(path, _line(const Color(0x33000000), 1));
    if (cb) drawGlyph(c, type * 3 % kGlyphCount, Rect.fromCircle(center: m, radius: r * 0.12), const Color(0xCC263045));
  }

  void _plate(Canvas c, Offset o, double r, List<int> p, MPalette pal) {
    c.drawCircle(o + Offset(0, r * 0.06), r, _fill(const Color(0x44000000)));
    c.drawCircle(o, r, _fill(const Color(0xFFF7F3EA)));
    c.drawCircle(o, r * 0.86, _line(const Color(0xFFDDD3C0), 2));
    for (var i = 0; i < p.length; i++) {
      _slice(c, o, r * 0.82, i, p[i], pal.colorBlind);
    }
  }

  @override
  void paint(Canvas c, Size size, MPalette p, double t) {
    this.size = size;
    _layout();
    for (var i = 0; i < sim.rows * sim.cols; i++) {
      final r = _cellRect(i).deflate(4);
      final blocked = sim.blocked.contains(i);
      final hl = _hint != null && _hint!.$2 == i && (_hintT * 3).floor().isEven;
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.18)),
          _fill(blocked ? const Color(0x55000000) : (hl ? const Color(0x66FFE08A) : const Color(0x22FFFFFF))));
      if (blocked) {
        c.drawLine(r.topLeft + Offset(r.width * 0.3, r.height * 0.3), r.bottomRight - Offset(r.width * 0.3, r.height * 0.3), _line(const Color(0x66FFFFFF), 3));
        continue;
      }
      if (sim.has[i]) _plate(c, r.center, r.width * 0.44, sim.board[i], p);
      final f = _flash[i];
      if (f != null) {
        c.drawCircle(r.center, r.width * (0.6 - f * 0.3), _line(const Color(0xFFFFE08A).withValues(alpha: (f / 0.6).clamp(0.0, 1.0)), 6));
        drawText(c, '✓', r.center, r.width * 0.4, const Color(0xFFFFE08A).withValues(alpha: (f / 0.6).clamp(0.0, 1.0)));
      }
    }
    for (var k = 0; k < 3; k++) {
      final r = _offerRect(k).deflate(8);
      final hl = (_hint != null && _hint!.$1 == k && (_hintT * 3).floor().isEven) || sel == k;
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.2)), _fill(hl ? const Color(0x88FFE08A) : const Color(0x22FFFFFF)));
      if (k == _drag && _moved) continue;
      _plate(c, r.center, r.width * 0.4, sim.offer[k], p);
    }
    if (_drag >= 0 && _moved) _plate(c, _pos, _cell * 0.42, sim.offer[_drag], p);
  }

  @override
  Map<String, Object?> save() => {'s': sim.save(), 'm': moves, 'r': _rerolls, 'sc': score};

  @override
  void load(Map<String, Object?> j) {
    sim = TraySim(lv.data)..load(Map<String, Object?>.from(j['s'] as Map));
    moves = (j['m'] as num).toInt();
    _rerolls = (j['r'] as num?)?.toInt() ?? 0;
    score = (j['sc'] as num?)?.toInt() ?? 0;
    sel = -1;
    _drag = -1;
  }
}
