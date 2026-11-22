import 'dart:math' as math;
import 'dart:ui';

import 'core.dart';

/// Stüdyoya özgü vektör simgeler (emoji ya da hazır görsel yok). Taş
/// yüzleri "simge × renk" ile çeşitlenir; renk körü modunda simge tek
/// başına ayırt edicidir.
const int kGlyphCount = 24;

Path glyphPath(int g, Rect r) {
  final c = r.center;
  final s = r.shortestSide / 2;
  final p = Path();
  switch (g % kGlyphCount) {
    case 0: { // daire
      p.addOval(Rect.fromCircle(center: c, radius: s * 0.8));
    }
    case 1: { // kare
      p.addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: s * 1.45, height: s * 1.45), Radius.circular(s * 0.18)));
    }
    case 2: { // üçgen
      p
        ..moveTo(c.dx, c.dy - s * 0.85)
        ..lineTo(c.dx + s * 0.85, c.dy + s * 0.7)
        ..lineTo(c.dx - s * 0.85, c.dy + s * 0.7)
        ..close();
    }
    case 3: { // baklava
      p
        ..moveTo(c.dx, c.dy - s * 0.9)
        ..lineTo(c.dx + s * 0.65, c.dy)
        ..lineTo(c.dx, c.dy + s * 0.9)
        ..lineTo(c.dx - s * 0.65, c.dy)
        ..close();
    }
    case 4: { // yıldız
      _star(p, c, s * 0.9, s * 0.4, 5);
    }
    case 5: { // kalp
      p
        ..moveTo(c.dx, c.dy + s * 0.8)
        ..cubicTo(c.dx - s * 1.2, c.dy - s * 0.05, c.dx - s * 0.55, c.dy - s * 1.0, c.dx, c.dy - s * 0.35)
        ..cubicTo(c.dx + s * 0.55, c.dy - s * 1.0, c.dx + s * 1.2, c.dy - s * 0.05, c.dx, c.dy + s * 0.8)
        ..close();
    }
    case 6: { // damla
      p
        ..moveTo(c.dx, c.dy - s * 0.9)
        ..quadraticBezierTo(c.dx + s * 0.75, c.dy + s * 0.05, c.dx + s * 0.55, c.dy + s * 0.45)
        ..arcToPoint(Offset(c.dx - s * 0.55, c.dy + s * 0.45), radius: Radius.circular(s * 0.6))
        ..quadraticBezierTo(c.dx - s * 0.75, c.dy + s * 0.05, c.dx, c.dy - s * 0.9)
        ..close();
    }
    case 7: { // yaprak
      p
        ..moveTo(c.dx - s * 0.8, c.dy + s * 0.8)
        ..quadraticBezierTo(c.dx - s * 0.8, c.dy - s * 0.8, c.dx + s * 0.8, c.dy - s * 0.8)
        ..quadraticBezierTo(c.dx + s * 0.8, c.dy + s * 0.8, c.dx - s * 0.8, c.dy + s * 0.8)
        ..close();
    }
    case 8: { // hilal
      final a = Path()..addOval(Rect.fromCircle(center: c, radius: s * 0.8));
      final b = Path()..addOval(Rect.fromCircle(center: c.translate(s * 0.4, -s * 0.2), radius: s * 0.7));
      return Path.combine(PathOperation.difference, a, b);
    }
    case 9: { // güneş
      p.addOval(Rect.fromCircle(center: c, radius: s * 0.45));
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4;
        final o = c + Offset(math.cos(a), math.sin(a)) * s * 0.75;
        p.addOval(Rect.fromCircle(center: o, radius: s * 0.13));
      }
    }
    case 10: { // çiçek
      for (var k = 0; k < 5; k++) {
        final a = k * 2 * math.pi / 5 - math.pi / 2;
        p.addOval(Rect.fromCircle(center: c + Offset(math.cos(a), math.sin(a)) * s * 0.45, radius: s * 0.36));
      }
    }
    case 11: { // şimşek
      p
        ..moveTo(c.dx + s * 0.15, c.dy - s * 0.95)
        ..lineTo(c.dx - s * 0.55, c.dy + s * 0.1)
        ..lineTo(c.dx - s * 0.05, c.dy + s * 0.1)
        ..lineTo(c.dx - s * 0.2, c.dy + s * 0.95)
        ..lineTo(c.dx + s * 0.55, c.dy - s * 0.15)
        ..lineTo(c.dx + s * 0.05, c.dy - s * 0.15)
        ..close();
    }
    case 12: { // artı
      final w = s * 0.32;
      p
        ..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: s * 1.6, height: w * 2), Radius.circular(w * 0.5)))
        ..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: w * 2, height: s * 1.6), Radius.circular(w * 0.5)));
    }
    case 13: { // altıgen
      _poly(p, c, s * 0.85, 6, 0);
    }
    case 14: { // halka
      final a = Path()..addOval(Rect.fromCircle(center: c, radius: s * 0.82));
      final b = Path()..addOval(Rect.fromCircle(center: c, radius: s * 0.42));
      return Path.combine(PathOperation.difference, a, b);
    }
    case 15: { // taç
      p
        ..moveTo(c.dx - s * 0.8, c.dy + s * 0.6)
        ..lineTo(c.dx - s * 0.85, c.dy - s * 0.5)
        ..lineTo(c.dx - s * 0.4, c.dy)
        ..lineTo(c.dx, c.dy - s * 0.75)
        ..lineTo(c.dx + s * 0.4, c.dy)
        ..lineTo(c.dx + s * 0.85, c.dy - s * 0.5)
        ..lineTo(c.dx + s * 0.8, c.dy + s * 0.6)
        ..close();
    }
    case 16: { // çan
      p
        ..moveTo(c.dx - s * 0.75, c.dy + s * 0.5)
        ..quadraticBezierTo(c.dx - s * 0.55, c.dy + s * 0.3, c.dx - s * 0.55, c.dy - s * 0.1)
        ..quadraticBezierTo(c.dx - s * 0.5, c.dy - s * 0.8, c.dx, c.dy - s * 0.8)
        ..quadraticBezierTo(c.dx + s * 0.5, c.dy - s * 0.8, c.dx + s * 0.55, c.dy - s * 0.1)
        ..quadraticBezierTo(c.dx + s * 0.55, c.dy + s * 0.3, c.dx + s * 0.75, c.dy + s * 0.5)
        ..close()
        ..addOval(Rect.fromCircle(center: c.translate(0, s * 0.68), radius: s * 0.17));
    }
    case 17: { // balık
      p
        ..addOval(Rect.fromCenter(center: c.translate(-s * 0.15, 0), width: s * 1.3, height: s * 0.85))
        ..moveTo(c.dx + s * 0.4, c.dy)
        ..lineTo(c.dx + s * 0.9, c.dy - s * 0.45)
        ..lineTo(c.dx + s * 0.9, c.dy + s * 0.45)
        ..close();
    }
    case 18: { // ağaç
      p
        ..moveTo(c.dx, c.dy - s * 0.9)
        ..lineTo(c.dx + s * 0.75, c.dy + s * 0.35)
        ..lineTo(c.dx - s * 0.75, c.dy + s * 0.35)
        ..close()
        ..addRect(Rect.fromCenter(center: c.translate(0, s * 0.6), width: s * 0.3, height: s * 0.5));
    }
    case 19: { // ev
      p
        ..moveTo(c.dx, c.dy - s * 0.85)
        ..lineTo(c.dx + s * 0.85, c.dy - s * 0.05)
        ..lineTo(c.dx + s * 0.6, c.dy - s * 0.05)
        ..lineTo(c.dx + s * 0.6, c.dy + s * 0.8)
        ..lineTo(c.dx - s * 0.6, c.dy + s * 0.8)
        ..lineTo(c.dx - s * 0.6, c.dy - s * 0.05)
        ..lineTo(c.dx - s * 0.85, c.dy - s * 0.05)
        ..close();
    }
    case 20: { // fincan
      p
        ..moveTo(c.dx - s * 0.7, c.dy - s * 0.5)
        ..lineTo(c.dx + s * 0.5, c.dy - s * 0.5)
        ..lineTo(c.dx + s * 0.4, c.dy + s * 0.55)
        ..quadraticBezierTo(c.dx - s * 0.1, c.dy + s * 0.8, c.dx - s * 0.6, c.dy + s * 0.55)
        ..close();
      final h = Path()..addOval(Rect.fromCircle(center: c.translate(s * 0.55, 0), radius: s * 0.28));
      final hi = Path()..addOval(Rect.fromCircle(center: c.translate(s * 0.55, 0), radius: s * 0.14));
      return Path.combine(PathOperation.union, p, Path.combine(PathOperation.difference, h, hi));
    }
    case 21: { // şemsiye
      p
        ..moveTo(c.dx - s * 0.9, c.dy)
        ..arcToPoint(Offset(c.dx + s * 0.9, c.dy), radius: Radius.circular(s * 0.9))
        ..close()
        ..addRect(Rect.fromLTWH(c.dx - s * 0.07, c.dy, s * 0.14, s * 0.75));
    }
    case 22: { // nota
      p
        ..addOval(Rect.fromCenter(center: c.translate(-s * 0.3, s * 0.55), width: s * 0.6, height: s * 0.45))
        ..addRect(Rect.fromLTWH(c.dx - s * 0.05, c.dy - s * 0.8, s * 0.13, s * 1.35))
        ..addRect(Rect.fromLTWH(c.dx - s * 0.05, c.dy - s * 0.8, s * 0.55, s * 0.18));
    }
    default: { // yonca
      for (var k = 0; k < 3; k++) {
        final a = k * 2 * math.pi / 3 - math.pi / 2;
        p.addOval(Rect.fromCircle(center: c.translate(0, -s * 0.1) + Offset(math.cos(a), math.sin(a)) * s * 0.38, radius: s * 0.33));
      }
      p.addRect(Rect.fromLTWH(c.dx - s * 0.06, c.dy + s * 0.2, s * 0.12, s * 0.7));
    }
  }
  return p;
}

void _star(Path p, Offset c, double ro, double ri, int n) {
  for (var k = 0; k < n * 2; k++) {
    final r = k.isEven ? ro : ri;
    final a = -math.pi / 2 + k * math.pi / n;
    final o = c + Offset(math.cos(a), math.sin(a)) * r;
    if (k == 0) {
      p.moveTo(o.dx, o.dy);
    } else {
      p.lineTo(o.dx, o.dy);
    }
  }
  p.close();
}

void _poly(Path p, Offset c, double r, int n, double rot) {
  for (var k = 0; k < n; k++) {
    final a = rot + k * 2 * math.pi / n;
    final o = c + Offset(math.cos(a), math.sin(a)) * r;
    if (k == 0) {
      p.moveTo(o.dx, o.dy);
    } else {
      p.lineTo(o.dx, o.dy);
    }
  }
  p.close();
}

/// Yüz kimliği → (simge, renk). Aynı yüz her zaman aynı görünür.
(int, int) faceOf(int face, int colors) => (face % kGlyphCount, (face * 7 + face ~/ kGlyphCount) % colors);

/// Simgeyi verilen kutuda çizer.
void drawGlyph(Canvas c, int glyph, Rect r, Color color, {bool outline = false}) {
  final path = glyphPath(glyph, r);
  c.drawPath(path, Paint()..color = color);
  if (outline) {
    c.drawPath(
        path,
        Paint()
          ..color = const Color(0x55000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r.shortestSide * 0.04);
  }
}

/// Kabartmalı taş. [depth] alt kenarın kalınlığı (katmanlı dizilimler).
void drawTile(Canvas c, Rect r, int face, MPalette p,
    {bool selected = false, bool dim = false, bool hint = false, double depth = 0, double alpha = 1}) {
  final rad = Radius.circular(r.shortestSide * 0.16);
  final a = (alpha * 255).round().clamp(0, 255);
  if (depth > 0) {
    c.drawRRect(RRect.fromRectAndRadius(r.translate(depth * 0.6, depth), rad), Paint()..color = p.shadow.withAlpha((a * 0.5).round()));
    c.drawRRect(RRect.fromRectAndRadius(r.translate(depth * 0.3, depth * 0.55), rad), Paint()..color = p.tileEdge.withAlpha(a));
  }
  final body = selected ? Color.lerp(p.tile, p.accent, 0.35)! : p.tile;
  c.drawRRect(RRect.fromRectAndRadius(r, rad), Paint()..color = body.withAlpha(a));
  c.drawRRect(
      RRect.fromRectAndRadius(r.deflate(r.shortestSide * 0.06), rad),
      Paint()
        ..color = const Color(0x22000000).withAlpha((0x22 * alpha).round())
        ..style = PaintingStyle.stroke
        ..strokeWidth = r.shortestSide * 0.03);
  if (face >= 0) {
    final (g, col) = faceOf(face, p.pieces.length);
    final color = p.piece(col);
    drawGlyph(c, g, r.deflate(r.shortestSide * 0.2), color.withAlpha(a), outline: p.colorBlind);
    if (p.colorBlind) {
      // Renk körü: köşede rengin numarası.
      final tp = _label('${col + 1}', r.shortestSide * 0.2, p.ink.withAlpha(a));
      tp.paint(c, r.topLeft + Offset(r.shortestSide * 0.1, r.shortestSide * 0.06));
    }
  }
  if (hint || selected) {
    c.drawRRect(
        RRect.fromRectAndRadius(r.inflate(1.5), rad),
        Paint()
          ..color = (hint ? const Color(0xFFFFC94D) : p.accent).withAlpha(a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r.shortestSide * 0.07);
  }
  if (dim) {
    c.drawRRect(RRect.fromRectAndRadius(r, rad), Paint()..color = const Color(0x66000000).withAlpha((0x66 * alpha).round()));
  }
}

/// Küçük yazı (ParagraphBuilder ile, widget katmanına bağlı değil).
_Label _label(String text, double size, Color color) => _Label(text, size, color);

class _Label {
  final Paragraph para;
  _Label(String text, double size, Color color)
      : para = (ParagraphBuilder(ParagraphStyle(fontSize: size, fontWeight: FontWeight.w700))
              ..pushStyle(TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w700))
              ..addText(text))
            .build()
          ..layout(const ParagraphConstraints(width: 400));
  void paint(Canvas c, Offset o) => c.drawParagraph(para, o);
}

/// Ortada yazı çizer (sayılar, kısa etiketler).
void drawText(Canvas c, String text, Offset center, double size, Color color) {
  final l = _Label(text, size, color);
  c.drawParagraph(l.para, center - Offset(l.para.maxIntrinsicWidth / 2, l.para.height / 2));
}
