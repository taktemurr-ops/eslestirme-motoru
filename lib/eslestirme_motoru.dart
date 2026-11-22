/// Eşleştirme ailesinin ortak motoru: sıra tabanlı eşleştirme türleri
/// (mahjong, üçlü tepsi, bağlantılı eşleştirme, sıralama, sahneler...)
/// ve gerçek zamanlı olanlar (balon patlatıcı, top zinciri, meyve
/// birleştirme).
library;

export 'src/arcade/bubble_engine.dart' show BubbleLevel, BubbleSim, generateBubbleLevel, bubbleBot;
export 'src/arcade/bubble_paint.dart';
export 'src/arcade/casual_engine.dart' show CasualLevel, CasualSim, casualBot;
export 'src/arcade/casual_view.dart' show paintCasual, casualSound;
export 'src/arcade/rules.dart';
export 'src/arcade/zuma_engine.dart' show ZumaLevel, ZumaSim, generateZuma, zumaBot;
export 'src/arcade/zuma_paint.dart';
export 'src/catalog.dart';
export 'src/core.dart';
export 'src/glyphs.dart';
export 'src/kinds/misc.dart' show symbolCards;
export 'src/texts.dart';
export 'src/view.dart';
