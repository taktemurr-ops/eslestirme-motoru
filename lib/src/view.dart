import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/game_rules.dart';

import 'core.dart';
import 'texts.dart';
import 'studio_chrome.dart';

/// Bütün sıra tabanlı eşleştirme oyunları için ortak ekran.
class MatchView extends StatefulWidget {
  final PlayContext ctx;
  final MatchRules rules;
  const MatchView({super.key, required this.ctx, required this.rules});

  @override
  State<MatchView> createState() => _MatchViewState();
}

class _MatchViewState extends State<MatchView> with SingleTickerProviderStateMixin {
  late MGame g;
  final _undo = <Map<String, Object?>>[];
  late Map<String, Object?> _start;
  int _seconds = 0, _hints = 0, _undos = 0;
  bool _ended = false, _asking = false;
  Timer? _timer;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _t = 0;
  int _lastMoves = 0;
  String _checkKey = '';
  double _checkT = 0;

  PlayContext get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    final lv = (ctx.generated as GeneratedLevel<MLevel>).puzzle;
    g = widget.rules.kindForLevel(ctx.spec.difficulty).start(lv);
    _start = g.save();
    final snap = ctx.resume['snap'];
    if (snap is Map) {
      try {
        g.load(Map<String, Object?>.from(snap));
      } catch (_) {
        g.load(_start);
      }
    }
    _seconds = (ctx.resume['secs'] as num?)?.toInt() ?? 0;
    _hints = (ctx.resume['hints'] as num?)?.toInt() ?? 0;
    _lastMoves = g.moves;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_ended && mounted) setState(() => _seconds++);
    });
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration now) {
    final dt = _last == Duration.zero ? 0.0 : (now - _last).inMicroseconds / 1e6;
    _last = now;
    _t += dt;
    final busy = g.step(math.min(dt, 0.05));
    if (mounted) setState(() {});
    // Durum denetimi pahalı olabilir: hamle değişince, animasyon bitince
    // ve yarım saniyede bir.
    final key = '${g.moves}|$busy';
    if (key != _checkKey || _t - _checkT > 0.5) {
      _checkKey = key;
      _checkT = _t;
      _afterChange();
    }
  }

  void _persist() => ctx.saveResume({'snap': g.save(), 'secs': _seconds, 'hints': _hints});

  void _afterChange() {
    if (_ended || _asking) return;
    if (g.moves != _lastMoves) {
      _lastMoves = g.moves;
      _persist();
    }
    if (g.won) {
      _ended = true;
      ctx.sfx(Sfx.win);
      final stars = g.stars(_hints);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        ctx.finish(RoundResult(
          won: true,
          score: math.max(g.score, math.max(100, 2000 - _seconds * 2 - _hints * 150)),
          stars: stars,
          seconds: _seconds,
          moves: g.moves,
          hintsUsed: _hints,
          undosUsed: _undos,
          gameStats: {'rounds_won': 1, ...g.stats},
        ));
      });
    } else if (g.lost) {
      _asking = true;
      ctx.sfx(Sfx.lose);
      Future.delayed(const Duration(milliseconds: 400), () async {
        if (!mounted) return;
        final more = await ctx.requestContinue();
        if (!mounted) return;
        _asking = false;
        if (more && g.continueAfterLoss()) {
          setState(() {});
          return;
        }
        _ended = true;
        ctx.finish(RoundResult(
          won: false,
          score: g.score,
          seconds: _seconds,
          moves: g.moves,
          hintsUsed: _hints,
          gameStats: g.stats,
        ));
      });
    }
  }

  void _input(bool Function() f) {
    if (_ended || _asking) return;
    final before = g.undoable ? g.save() : null;
    final m0 = g.moves;
    if (f()) {
      if (before != null && g.moves != m0) {
        _undo.add(before);
        if (_undo.length > 60) _undo.removeAt(0);
      }
      ctx.sfx(Sfx.tap);
      setState(() {});
    }
  }

  void _doUndo() {
    if (_undo.isEmpty || _ended) return;
    setState(() {
      g.load(_undo.removeLast());
      _undos++;
      _lastMoves = g.moves;
    });
    _persist();
  }

  void _restart() {
    if (_ended) return;
    setState(() {
      g.load(_start);
      _undo.clear();
      _lastMoves = g.moves;
    });
    _persist();
  }

  Future<void> _hint() async {
    if (_ended) return;
    if (!await ctx.requestHint()) return;
    setState(() {
      if (g.hint()) _hints++;
    });
  }

  Future<void> _booster() async {
    if (_ended) return;
    if (!await ctx.requestBooster()) return;
    final before = g.save();
    setState(() {
      if (g.booster()) {
        _undo.add(before);
        ctx.sfx(Sfx.coin);
      }
    });
    _persist();
  }

  MPalette _palette(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return MPalette(
      pieces: ctx.pieceColors,
      ink: s.onSurface,
      surface: s.surface,
      accent: s.primary,
      tile: const Color(0xFFFBF6EC),
      tileEdge: const Color(0xFFD9CBB2),
      shadow: const Color(0xFF000000),
      colorBlind: ctx.colorBlind,
      reducedMotion: ctx.reducedMotion,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Oyun alanı (taşlar, kutular) oyunun alışılmış temasıyla çizilir;
    // üst bilgi çubuğu onaylı stüdyo temasıyla.
    final pal = _palette(context);
    return StudioChrome(child: Builder(builder: (context) => _build(context, pal)));
  }

  Widget _build(BuildContext context, MPalette pal) {
    final look = StudioLook.of(context);
    final lang = ctx.lang;
    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
        padding: const EdgeInsetsDirectional.only(start: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(colors: [look.sheet.withValues(alpha: 0.92), look.base.withValues(alpha: 0.92)]),
          border: Border.all(color: look.accent.withValues(alpha: 0.45), width: 1.2),
        ),
        child: Row(children: [
          StudioTag(icon: Icons.timer_outlined, text: '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}'),
          const SizedBox(width: 10),
          Expanded(
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(g.status(lang),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kStudioText, fontWeight: FontWeight.w800)))),
          IconButton(tooltip: ctx.t('undo'), onPressed: _undo.isEmpty ? null : _doUndo, icon: const Icon(Icons.undo)),
          IconButton(tooltip: ctx.t('restart'), onPressed: _restart, icon: const Icon(Icons.restart_alt)),
          if (g.hintable) IconButton(tooltip: ctx.t('hint'), onPressed: _hint, icon: const Icon(Icons.lightbulb_outline)),
          IconButton(
              tooltip: mt(lang, g.boosterKey()),
              onPressed: _booster,
              icon: Icon(g.boosterKey() == 'shuffle' ? Icons.shuffle : Icons.add_box_outlined)),
        ]),
      ),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          final size = Size(box.maxWidth, box.maxHeight);
          g.size = size;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => _input(() => g.down(d.localPosition)),
            onPanUpdate: (d) => _input(() => g.move(d.localPosition)),
            onPanEnd: (d) => _input(() => g.up(Offset.infinite)),
            onPanCancel: () => _input(() => g.up(Offset.infinite)),
            child: CustomPaint(size: size, painter: _Painter(g, pal, _t)),
          );
        }),
      ),
    ]);
  }
}

class _Painter extends CustomPainter {
  final MGame g;
  final MPalette p;
  final double t;
  _Painter(this.g, this.p, this.t);

  @override
  void paint(Canvas canvas, Size size) => g.paint(canvas, size, p, t);

  @override
  bool shouldRepaint(covariant _Painter old) => true;
}
