import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:studio_core/app/arcade_stage.dart';
import 'package:studio_core/app/play_kit.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/arcade.dart';
import 'bubble_engine.dart';

void _bubble(Canvas c, Offset o, int v, ArcadePalette p, [double r = kR - 3]) {
  if (v == kStone) {
    c.drawCircle(o, r, Paint()..color = const Color(0xFF6C757D));
    paintText(c, '▪', o, r, Colors.white54);
    return;
  }
  if (v == kBombShot) {
    c.drawCircle(o, r, Paint()..color = Colors.black87);
    paintText(c, '✸', o, r, const Color(0xFFFF6B35));
    return;
  }
  if (v == kRainbow) {
    c.drawCircle(o, r, Paint()..shader = SweepGradient(colors: [p.piece(0), p.piece(1), p.piece(2), p.piece(3), p.piece(0)]).createShader(Rect.fromCircle(center: o, radius: r)));
    return;
  }
  final col = p.piece(v);
  c.drawCircle(o, r, Paint()..color = col);
  c.drawCircle(o.translate(-r * 0.3, -r * 0.3), r * 0.28, Paint()..color = Colors.white38);
  if (p.colorBlind) paintText(c, ['●', '■', '▲', '◆', '★', '✚'][v % 6], o, r * 0.8, Colors.black54);
}

void paintBubbles(Canvas c, ArcadeSim sim, ArcadePalette p, double t) {
  final s = sim as BubbleSim;
  c.drawRect(const Rect.fromLTWH(0, kTop - 10, kWorldW, 10), Paint()..color = Colors.white24);
  c.drawLine(const Offset(0, kDeadLine), const Offset(kWorldW, kDeadLine),
      Paint()
        ..color = const Color(0x88FF4D6D)
        ..strokeWidth = 4);
  final g = s.grid;
  for (var r = 0; r < g.rows.length; r++) {
    for (var col = 0; col < g.width(r); col++) {
      final v = g.rows[r][col];
      if (v == kEmpty) continue;
      _bubble(c, Offset(g.cx(r, col), g.cy(r, s.top)), v, p);
    }
  }
  // aim guide (first segments of the traced path)
  if (s.flying == null) {
    final path = traceShot(g, s.top, s.aimX, s.aimY);
    if (path != null) {
      final dot = Paint()..color = Colors.white60;
      for (var i = 1; i < path.points.length; i++) {
        final a = path.points[i - 1], b = path.points[i];
        final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
        final len = math.sqrt(dx * dx + dy * dy);
        for (var d = 0.0; d < len; d += 40) {
          c.drawCircle(Offset(a.$1 + dx * d / len, a.$2 + dy * d / len), 5, dot);
        }
      }
    }
  } else {
    // flying bubble along its polyline
    final pth = s.flying!;
    var rem = s.flyT;
    var pos = Offset(pth.points.first.$1, pth.points.first.$2);
    for (var i = 1; i < pth.points.length; i++) {
      final a = pth.points[i - 1], b = pth.points[i];
      final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
      final seg = math.sqrt(dx * dx + dy * dy);
      if (rem <= seg) {
        pos = Offset(a.$1 + dx * rem / seg, a.$2 + dy * rem / seg);
        break;
      }
      rem -= seg;
      pos = Offset(b.$1, b.$2);
    }
    _bubble(c, pos, s.flyKind, p);
  }
  // shooter
  c.drawCircle(const Offset(kShooterX, kShooterY), 70, Paint()..color = Colors.black26);
  _bubble(c, const Offset(kShooterX, kShooterY), s.current, p);
  _bubble(c, const Offset(kShooterX + 150, kShooterY + 40), s.next, p, 30);
  paintText(c, '⇄', const Offset(kShooterX + 150, kShooterY - 20), 26, Colors.white70);
  if (s.level.descendEvery > 0) {
    final left = s.level.descendEvery - s.shots % s.level.descendEvery;
    for (var i = 0; i < s.level.descendEvery; i++) {
      c.drawCircle(Offset(80 + i * 26, kShooterY + 40), 9,
          Paint()..color = i < left ? Colors.white70 : Colors.white12);
    }
  }
}

Sfx? bubbleSound(ArcadeSim sim) => switch ((sim as BubbleSim).lastEvent) {
      1 => Sfx.clear,
      2 => Sfx.place,
      3 => Sfx.combo,
      _ => null,
    };

