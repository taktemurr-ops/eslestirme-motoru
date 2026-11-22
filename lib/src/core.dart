import 'dart:ui';

import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/rng.dart';
import 'package:studio_core/core/stats.dart';

/// Eşleştirme bölümü: türe özgü veriler JSON uyumlu bir sözlükte durur.
class MLevel {
  final String kind;
  final int difficulty;
  final int seed;
  final Map<String, Object?> data;

  const MLevel(this.kind, this.difficulty, this.seed, this.data);

  List<int> ints(String k) => [for (final v in (data[k] as List? ?? const [])) (v as num).toInt()];
  int i(String k, [int def = 0]) => (data[k] as num?)?.toInt() ?? def;

  Map<String, Object?> toJson() => {'k': kind, 'd': difficulty, 's': seed, 'x': data};

  factory MLevel.fromJson(Map<String, Object?> j) =>
      MLevel(j['k'] as String, (j['d'] as num).toInt(), (j['s'] as num).toInt(), Map<String, Object?>.from(j['x'] as Map));
}

/// Ekrana verilen renkler ve seçenekler.
class MPalette {
  final List<Color> pieces;
  final Color ink, surface, accent, tile, tileEdge, shadow;
  final bool colorBlind, reducedMotion;
  const MPalette({
    required this.pieces,
    required this.ink,
    required this.surface,
    required this.accent,
    required this.tile,
    required this.tileEdge,
    required this.shadow,
    required this.colorBlind,
    required this.reducedMotion,
  });

  Color piece(int i) => pieces[i % pieces.length];
}

/// Oynanan bir eşleştirme oyunu (değişebilir durum). Ortak ekran
/// [MatchView] dokunuşları buraya iletir, her karede çizdirir.
abstract class MGame {
  final MLevel lv;
  MGame(this.lv);

  /// Son çizimdeki alan (dokunuş hesapları için).
  Size size = Size.zero;

  int moves = 0;
  int score = 0;
  final Map<String, int> stats = {};

  void bump(String k, [int n = 1]) => stats[k] = (stats[k] ?? 0) + n;

  // ---- giriş
  /// Parmak değdi. true: durum değişti (geri alma kaydı için önce [snapshot] alınır).
  bool down(Offset p) => false;
  bool move(Offset p) => false;
  bool up(Offset p) => false;

  /// Bu dokunuş geri alınabilir bir hamle mi (ekran önce anlık görüntü alır).
  bool get undoable => true;

  // ---- durum
  bool get won;
  bool get lost => false;

  /// Üst satırdaki kısa durum ("Kalan çift: 12").
  String status(String lang);

  /// Kaybedince "devam" verilirse oyunu sürdürülebilir kıl (ör. +5 hamle).
  bool continueAfterLoss() => false;

  /// İpucu: yararlı bir hamleyi işaretle. false: gösterecek hamle yok.
  bool hint() => false;
  bool get hintable => true;

  /// Güçlendirici (karıştır / ek alan). false: kullanılamıyor.
  bool booster() => false;
  String boosterKey() => 'shuffle';

  /// Animasyon: saniye cinsinden ilerlet; true ise çizim sürsün.
  bool step(double dt) => false;

  void paint(Canvas c, Size size, MPalette p, double t);

  // ---- kayıt
  Map<String, Object?> save();
  void load(Map<String, Object?> j);

  /// 1..3 yıldız (kazanınca).
  int stars(int hints) => hints == 0 ? 3 : (hints <= 2 ? 2 : 1);
}

/// Bir eşleştirme türü: bölüm üretir, oyun kurar, bölümü doğrular.
abstract class MatchKind {
  const MatchKind();
  String get id;

  MLevel make(int d, SeededRandom r);
  MGame start(MLevel lv);

  /// Bölüm çözülebilir mi (kendi botuyla oynayarak).
  bool solvable(MLevel lv);

  List<GameStat> get stats => const [
        GameStat('rounds_won', 'Kazanılan bölüm', 'Levels won', scale: 10),
        GameStat('pairs_matched', 'Eşleşme', 'Matches made', scale: 200),
      ];
  List<MissionTemplate> get missions => const [
        MissionTemplate('win', 'rounds_won', [3, 10, 25]),
        MissionTemplate('match', 'pairs_matched', [40, 120, 300]),
      ];
}

/// Bütün eşleştirme oyunlarının kuralları.
class MatchRules extends GameRules<MLevel> {
  @override
  final String gameId;
  final MatchKind Function(int d) kindFor;
  final int levels;
  final int Function(int d)? diffMap;
  final List<GameModeId>? modeList;

  MatchRules({required this.gameId, required this.kindFor, this.levels = 100000, this.diffMap, this.modeList});

  int mapDifficulty(int d) => (diffMap?.call(d) ?? d).clamp(1, 10);
  MatchKind kindForLevel(int d) => kindFor(mapDifficulty(d));

  @override
  int get levelCount => levels;

  @override
  List<String> get optionalMechanics => const [];

  @override
  List<GameModeId> get modes =>
      modeList ?? const [GameModeId.campaign, GameModeId.daily, GameModeId.weekly, GameModeId.challenge];

  @override
  List<GameStat> get gameStats => kindFor(5).stats;

  @override
  List<MissionTemplate> get missionTemplates => kindFor(5).missions;

  @override
  MLevel generate(LevelSpec spec) {
    final d = mapDifficulty(spec.difficulty);
    final k = kindFor(d);
    try {
      return k.make(d, SeededRandom(mixSeed([spec.seed, 6173])));
    } catch (_) {
      // Üretim tıkanırsa aynı türün en kolay biçimi.
      return k.make(1, SeededRandom(mixSeed([spec.seed, 6174])));
    }
  }

  @override
  Validation validate(MLevel puzzle, LevelSpec spec) {
    final k = kindFor(mapDifficulty(spec.difficulty));
    if (k.id != puzzle.kind) return const Validation.fail('kind mismatch');
    return k.solvable(puzzle) ? const Validation.ok() : const Validation.fail('not solvable');
  }
}

MatchRules matchRules(String gameId, MatchKind Function(int d) kindFor, {int Function(int d)? diffMap}) =>
    MatchRules(gameId: gameId, kindFor: kindFor, diffMap: diffMap);
