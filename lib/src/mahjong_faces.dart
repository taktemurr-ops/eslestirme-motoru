import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'core.dart';
import 'glyphs.dart';

/// Klasik Mahjong taş yüzleri (geleneksel, kamu malı semboller; özgün
/// vektör çizim): 0–8 daire 1–9, 9–17 bambu 1–9, 18–26 karakter 1–9,
/// 27–30 rüzgârlar, 31–33 ejderhalar, 34+ mevsimler. Piyasadaki Mahjong
/// Solitaire oyunlarında oyuncu bu yüzleri bekler; renkli simgeler yalnız
/// taş çıkarma gibi diğer oyunlarda kalır.
const kMahjongFaceCount = 38;

const _cRed = Color(0xFFC0392B), _cGreen = Color(0xFF1E7B4F), _cBlue = Color(0xFF1F4E8C), _cInk = Color(0xFF1C2230);

void drawMahjongFace(Canvas c, Rect r, int face, MPalette p, double alpha) {
  final f = face % kMahjongFaceCount;
  final inner = Rect.fromLTRB(r.left + r.width * 0.12, r.top + r.height * 0.1, r.right - r.width * 0.12, r.bottom - r.height * 0.1);
  Color k(Color col) => col.withValues(alpha: alpha);
  if (f < 9) {
    _dots(c, inner, f + 1, k);
  } else if (f < 18) {
    _bamboo(c, inner, f - 8, k);
  } else if (f < 27) {
    const nums = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];
    drawText(c, nums[f - 18], Offset(inner.center.dx, inner.top + inner.height * 0.27), inner.width * 0.62, k(_cBlue));
    drawText(c, '萬', Offset(inner.center.dx, inner.top + inner.height * 0.72), inner.width * 0.62, k(_cRed));
  } else if (f < 31) {
    const winds = ['東', '南', '西', '北'];
    drawText(c, winds[f - 27], inner.center, inner.width * 0.86, k(_cInk));
  } else if (f == 31) {
    drawText(c, '中', inner.center, inner.width * 0.9, k(_cRed));
  } else if (f == 32) {
    drawText(c, '發', inner.center, inner.width * 0.86, k(_cGreen));
  } else if (f == 33) {
    // Beyaz ejderha: mavi çerçeve
    final fr = inner.deflate(inner.width * 0.1);
    c.drawRRect(
        RRect.fromRectAndRadius(fr, Radius.circular(fr.width * 0.08)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = fr.width * 0.1
          ..color = k(_cBlue));
    c.drawRRect(
        RRect.fromRectAndRadius(fr.deflate(fr.width * 0.18), Radius.circular(fr.width * 0.05)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = fr.width * 0.04
          ..color = k(_cBlue));
  } else {
    // Mevsimler: çiçek + mevsim adı
    const seasons = ['春', '夏', '秋', '冬'];
    const cols = [Color(0xFFD45D8A), Color(0xFF2E9E78), Color(0xFFD9822B), Color(0xFF3F7CC4)];
    final s = f - 34;
    final o = Offset(inner.center.dx, inner.top + inner.height * 0.34);
    final pr = inner.width * 0.17;
    for (var q = 0; q < 5; q++) {
      final a = -math.pi / 2 + q * 2 * math.pi / 5;
      c.drawCircle(o + Offset(math.cos(a), math.sin(a)) * pr, pr * 0.75, Paint()..color = k(cols[s]));
    }
    c.drawCircle(o, pr * 0.6, Paint()..color = k(const Color(0xFFF2C14E)));
    drawText(c, seasons[s], Offset(inner.center.dx, inner.top + inner.height * 0.78), inner.width * 0.46, k(_cInk));
  }
}

/// Daireler: klasik dizilimler.
void _dots(Canvas c, Rect r, int n, Color Function(Color) k) {
  const lay = <int, List<(double, double)>>{
    1: [(0.5, 0.5)],
    2: [(0.5, 0.25), (0.5, 0.75)],
    3: [(0.2, 0.18), (0.5, 0.5), (0.8, 0.82)],
    4: [(0.27, 0.25), (0.73, 0.25), (0.27, 0.75), (0.73, 0.75)],
    5: [(0.25, 0.2), (0.75, 0.2), (0.5, 0.5), (0.25, 0.8), (0.75, 0.8)],
    6: [(0.3, 0.17), (0.7, 0.17), (0.3, 0.5), (0.7, 0.5), (0.3, 0.83), (0.7, 0.83)],
    7: [(0.2, 0.12), (0.5, 0.22), (0.8, 0.32), (0.3, 0.6), (0.7, 0.6), (0.3, 0.86), (0.7, 0.86)],
    8: [(0.3, 0.12), (0.7, 0.12), (0.3, 0.37), (0.7, 0.37), (0.3, 0.63), (0.7, 0.63), (0.3, 0.88), (0.7, 0.88)],
    9: [(0.2, 0.17), (0.5, 0.17), (0.8, 0.17), (0.2, 0.5), (0.5, 0.5), (0.8, 0.5), (0.2, 0.83), (0.5, 0.83), (0.8, 0.83)],
  };
  final pts = lay[n]!;
  final rad = n == 1 ? r.width * 0.36 : (n <= 4 ? r.width * 0.19 : (n <= 6 ? r.width * 0.16 : r.width * 0.13));
  for (var q = 0; q < pts.length; q++) {
    final (x, y) = pts[q];
    final o = Offset(r.left + r.width * x, r.top + r.height * y);
    final col = n == 1 ? _cRed : (n == 3 || n == 6 || n == 9 ? [_cBlue, _cRed, _cGreen][(q * 3 ~/ pts.length) % 3] : (q.isEven ? _cBlue : _cGreen));
    c.drawCircle(o, rad, Paint()..color = k(col));
    c.drawCircle(o, rad * 0.62, Paint()..color = k(const Color(0xFFF8F3E3)));
    c.drawCircle(o, rad * 0.34, Paint()..color = k(col));
  }
}

/// Bambu: yeşil/kırmızı boğumlu çubuklar; 1 bambu tek büyük çubuk ve kuş başı.
void _bamboo(Canvas c, Rect r, int n, Color Function(Color) k) {
  void stick(Offset o, double h, Color col) {
    final w = r.width * 0.13;
    final rr = RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: w, height: h), Radius.circular(w * 0.5));
    c.drawRRect(rr, Paint()..color = k(col));
    final node = Paint()
      ..color = k(const Color(0xFFF8F3E3))
      ..strokeWidth = math.max(1, w * 0.18);
    c.drawLine(Offset(o.dx - w * 0.5, o.dy), Offset(o.dx + w * 0.5, o.dy), node);
  }

  if (n == 1) {
    final o = r.center;
    stick(o.translate(0, r.height * 0.08), r.height * 0.6, _cGreen);
    c.drawCircle(o.translate(0, -r.height * 0.3), r.width * 0.16, Paint()..color = k(_cRed));
    c.drawCircle(o.translate(r.width * 0.05, -r.height * 0.32), r.width * 0.04, Paint()..color = k(const Color(0xFFF8F3E3)));
    return;
  }
  final rows = n <= 3 ? 1 : (n <= 6 ? 2 : 3);
  final perRow = <int>[];
  var left = n;
  for (var i = 0; i < rows; i++) {
    final m = (left / (rows - i)).ceil();
    perRow.add(m);
    left -= m;
  }
  final h = r.height / rows * 0.82;
  for (var row = 0; row < rows; row++) {
    final m = perRow[row];
    for (var q = 0; q < m; q++) {
      final x = r.left + r.width * (q + 0.5) / m;
      final y = r.top + r.height * (row + 0.5) / rows;
      final col = (n == 5 || n == 7 || n == 9) && row == rows ~/ 2 && q == m ~/ 2 ? _cRed : (row.isEven ? _cGreen : _cBlue);
      stick(Offset(x, y), h, col);
    }
  }
}
