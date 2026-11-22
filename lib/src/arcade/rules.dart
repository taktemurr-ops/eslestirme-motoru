import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/stats.dart';

import 'bubble_engine.dart';
import 'casual_engine.dart';
import 'zuma_engine.dart';

/// Balon patlatıcı. [forced]: çeşit paketlerinde her bölümde açık mekanikler.
class BubbleRules extends ArcadeRules<BubbleLevel> {
  @override
  final String gameId;
  final List<String> forced;
  BubbleRules(this.gameId, {this.forced = const []});

  @override
  int get levelCount => 100000;

  @override
  List<String> get optionalMechanics => forced.isEmpty ? const ['bomb', 'rainbow', 'stone', 'descend', 'colors'] : const [];

  @override
  List<GameStat> get gameStats => const [
        GameStat('bubbles_popped', 'Patlayan balon', 'Bubbles popped', scale: 200),
        GameStat('bubbles_dropped', 'Düşen balon', 'Bubbles dropped', scale: 50),
        GameStat('bank_shots', 'Duvar atışı', 'Bank shots', scale: 10),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('bubbles_popped', 'bubbles_popped', [66, 133, 200]),
        MissionTemplate('bubbles_dropped', 'bubbles_dropped', [16, 33, 50]),
      ];

  @override
  BubbleLevel generate(LevelSpec spec) =>
      generateBubbleLevel(forced.isEmpty ? spec : spec.copyWith(mechanics: {...spec.mechanics, ...forced}.toList()));

  @override
  ArcadeMeta metaOf(BubbleLevel l) => l.meta;

  @override
  ArcadeSim createSim(BubbleLevel l) => BubbleSim(l);

  @override
  ArcadeInput bot(ArcadeSim sim) => bubbleBot(sim);
}

/// Meyve birleştirme (fizik).
class FruitRules extends ArcadeRules<CasualLevel> {
  @override
  final String gameId;
  FruitRules(this.gameId);

  @override
  int get levelCount => 100000;

  @override
  List<String> get optionalMechanics => const [];

  @override
  List<GameStat> get gameStats => const [
        GameStat('merges', 'Birleştirme', 'Merges', scale: 1500),
        GameStat('big_fruits', 'Dev meyve', 'Big fruits', scale: 40),
        GameStat('best_fruit', 'En büyük meyve', 'Biggest fruit', scale: 11),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('merges', 'merges', [375, 750, 1500]),
        MissionTemplate('big_fruits', 'big_fruits', [5, 10, 20], coinReward: 80),
      ];

  @override
  CasualLevel generate(LevelSpec spec) => generateCasual(CasualKind.merge, spec);

  @override
  ArcadeMeta metaOf(CasualLevel l) => l.meta;

  @override
  ArcadeSim createSim(CasualLevel l) => CasualSim(l);

  @override
  ArcadeInput bot(ArcadeSim sim) => casualBot(sim);
}

/// Top zinciri: raydaki toplar deliğe ulaşmadan aynı renkleri üçleyerek patlat.
class ZumaRules extends ArcadeRules<ZumaLevel> {
  @override
  final String gameId;
  ZumaRules(this.gameId);

  @override
  int get levelCount => 100000;

  @override
  List<String> get optionalMechanics => const ['reverse', 'slowball'];

  @override
  List<GameStat> get gameStats => const [
        GameStat('balls_popped', 'Patlayan top', 'Balls popped', scale: 3000),
        GameStat('combos', 'Zincirleme', 'Chain combos', scale: 100),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('balls_popped', 'balls_popped', [150, 400, 900]),
        MissionTemplate('combos', 'combos', [5, 15, 40], coinReward: 80),
      ];

  @override
  ZumaLevel generate(LevelSpec spec) => generateZuma(spec);

  @override
  ArcadeMeta metaOf(ZumaLevel l) => l.meta;

  @override
  ArcadeSim createSim(ZumaLevel l) => ZumaSim(l);

  @override
  ArcadeInput bot(ArcadeSim sim) => zumaBot(sim);
}
