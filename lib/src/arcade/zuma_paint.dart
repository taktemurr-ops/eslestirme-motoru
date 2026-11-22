import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/arcade_stage.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/arcade.dart';

import '../glyphs.dart';
import 'zuma_engine.dart';

void _ball(Canvas c, Offset o, int color, ArcadePalette p, double r) {
  c.drawCircle(o.translate(3, 5), r, Paint()..color = Colors.black26);
  c.drawCircle(o, r, Paint()..color = p.piece(color));
  c.drawCircle(o.translate(-r * 0.32, -r * 0.32), r * 0.3, Paint()..color = Colors.white38);
  if (p.colorBlind) drawGlyph(c, color * 3 % kGlyphCount, Rect.fromCircle(center: o, radius: r * 0.5), Colors.black45);
}

void paintZuma(Canvas c, ArcadeSim sim, ArcadePalette p, double t) {
  final z = sim as ZumaSim;
  final l = z.level;
  // Ray: oluk + kenar
  final path = Path()..moveTo(l.px.first, l.py.first);
  for (var i = 1; i < l.px.length; i += 3) {
    path.lineTo(l.px[i], l.py[i]);
  }
  c.drawPath(path, Paint()
    ..color = const Color(0x33000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = kBall + 18
    ..strokeCap = StrokeCap.round);
  c.drawPath(path, Paint()
    ..color = const Color(0x22FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = kBall + 4
    ..strokeCap = StrokeCap.round);
  // Delik
  final hx = l.px.last, hy = l.py.last;
  c.drawCircle(Offset(hx, hy), kBall * 0.75, Paint()..color = const Color(0xFF2B2420));
  c.drawCircle(Offset(hx, hy), kBall * 0.75, Paint()
    ..color = const Color(0x55FFD166)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6);
  // Toplar
  for (final b in z.balls) {
    if (b.s < -kBall / 2) continue;
    final (x, y) = z.pos(math.max(0, b.s));
    _ball(c, Offset(x, y), b.color, p, kBall / 2 - 2);
  }
  // Atıcı: taş disk + nişan çizgisi
  final ang = math.atan2(z.aimY - kCy, z.aimX - kCx);
  final dot = Paint()..color = Colors.white30;
  for (var k = 1; k < 14; k++) {
    c.drawCircle(Offset(kCx + math.cos(ang) * (80 + k * 34), kCy + math.sin(ang) * (80 + k * 34)), 4, dot);
  }
  c.drawCircle(const Offset(kCx, kCy), 82, Paint()..color = const Color(0xFF6F5B4B));
  c.drawCircle(const Offset(kCx, kCy), 70, Paint()..color = const Color(0xFF8E7562));
  c.save();
  c.translate(kCx, kCy);
  c.rotate(ang);
  c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(30, -16, 70, 32), const Radius.circular(14)), Paint()..color = const Color(0xFF5A4A3D));
  c.restore();
  _ball(c, const Offset(kCx, kCy), z.current, p, kBall / 2 - 2);
  _ball(c, Offset(kCx + math.cos(ang + math.pi) * 52, kCy + math.sin(ang + math.pi) * 52), z.next, p, 18);
  if (z.shotX != null) _ball(c, Offset(z.shotX!, z.shotY!), z.shotColor, p, kBall / 2 - 2);
}

Sfx? zumaSound(ArcadeSim sim) => switch ((sim as ZumaSim).lastEvent) {
      1 => Sfx.clear,
      2 => Sfx.tap,
      3 => Sfx.combo,
      _ => null,
    };
