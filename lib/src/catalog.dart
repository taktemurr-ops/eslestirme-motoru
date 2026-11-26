import 'core.dart';
import 'kinds/flow.dart';
import 'kinds/grids.dart';
import 'kinds/match3.dart';
import 'kinds/misc.dart';
import 'kinds/sorts.dart';
import 'kinds/tiles.dart';

/// Sıra tabanlı eşleştirme türleri (tür kimliği → tür).
final Map<String, MatchKind> kMatchKinds = {
  'match3': const Match3Kind('match3'),
  'mucevher': const Match3Kind('mucevher', timed: true),
  'mahjong': const PairTilesKind('mahjong'),
  'tas-cikarma': const PairTilesKind('tas-cikarma', mode: 1),
  'domino': const PairTilesKind('domino', mode: 2),
  'uclu-tas': const TrayKind('uclu-tas'),
  '3b-nesne': const TrayKind('3b-nesne', pile: true),
  'onet': const OnetKind(),
  'samegame': const SameKind(),
  'grup-patlatma': const BlastKind(),
  'altigen-esle': const BlastKind(id: 'altigen-esle', hex: true),
  'renk-doldurma': const FloodKind(),
  'cift-bul': const PairsKind(),
  'kart-siralama': const BinsKind('kart-siralama', run: true, vanish: true, style: 1),
  'iplik-siralama': const BinsKind('iplik-siralama', run: true, vanish: false, style: 0, varCap: true),
  'icecek-siralama': const BinsKind('icecek-siralama', run: false, vanish: true, style: 2),
  'urun-siralama': const ShelfKind(),
  'uclu-birlestirme': const MergeKind(),
  'ortak-sembol': const SymbolKind(),
  'farki-bul': const DiffKind(),
  'gizli-nesne': const HiddenKind(),
  'piksel-akisi': const PixelFlowKind(),
  'renk-dongusu': const ColorLoopKind(),
  'tatli-tepsisi': const DessertTrayKind(),
  for (var i = 0; i < 10; i++) 'mahjong-dz-$i': PairTilesKind('mahjong-dz-$i', style: i),
};

/// Oyun deposu için kurallar: tür kimliğiyle.
MatchRules matchRulesFor(String gameId, String kind) => MatchRules(gameId: gameId, kindFor: (_) => kMatchKinds[kind]!);
