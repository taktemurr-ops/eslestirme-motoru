import 'package:flutter/material.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/core/strings.dart';

/// eslestirme-motoru'nun kısa metinleri (33 dil). Sıra:
/// tr en de es fr ar fa he ur ru uk pl cs ro hu el it pt nl sv da nb fi ja ko zh hi bn id ms th vi fil
const Map<String, String> _raw = {
  'pairs': 'Kalan çift|Pairs left|Paare übrig|Parejas restantes|Paires restantes|الأزواج المتبقية|جفت‌های باقی|זוגות שנותרו|باقی جوڑے|Осталось пар|Залишилось пар|Pozostałe pary|Zbývající páry|Perechi rămase|Hátralévő párok|Ζεύγη που μένουν|Coppie rimaste|Pares restantes|Paren over|Par kvar|Par tilbage|Par igjen|Pareja jäljellä|残りのペア|남은 짝|剩余对数|बचे जोड़े|বাকি জোড়া|Sisa pasangan|Pasangan berbaki|คู่ที่เหลือ|Cặp còn lại|Natitirang pares',
  'tiles': 'Kalan taş|Tiles left|Steine übrig|Fichas restantes|Tuiles restantes|البلاطات المتبقية|کاشی‌های باقی|אריחים שנותרו|باقی ٹائلیں|Осталось плиток|Залишилось плиток|Pozostałe kafelki|Zbývající kostky|Piese rămase|Hátralévő lapok|Πλακίδια που μένουν|Tessere rimaste|Peças restantes|Stenen over|Brickor kvar|Brikker tilbage|Brikker igjen|Laattoja jäljellä|残りの牌|남은 타일|剩余方块|बची टाइलें|বাকি টাইল|Sisa ubin|Jubin berbaki|ไพ่ที่เหลือ|Ô còn lại|Natitirang tile',
  'moves': 'Kalan hamle|Moves left|Züge übrig|Movimientos restantes|Coups restants|الحركات المتبقية|حرکت‌های باقی|מהלכים שנותרו|باقی چالیں|Осталось ходов|Залишилось ходів|Pozostałe ruchy|Zbývající tahy|Mutări rămase|Hátralévő lépések|Κινήσεις που μένουν|Mosse rimaste|Jogadas restantes|Zetten over|Drag kvar|Træk tilbage|Trekk igjen|Siirtoja jäljellä|残り手数|남은 이동|剩余步数|बची चालें|বাকি চাল|Sisa langkah|Langkah berbaki|ตาที่เหลือ|Lượt còn lại|Natitirang galaw',
  'score': 'Puan|Score|Punkte|Puntos|Score|النقاط|امتیاز|ניקוד|اسکور|Очки|Очки|Wynik|Skóre|Scor|Pont|Πόντοι|Punti|Pontos|Score|Poäng|Point|Poeng|Pisteet|スコア|점수|分数|अंक|স্কোর|Skor|Mata|คะแนน|Điểm|Puntos',
  'target': 'Hedef|Target|Ziel|Meta|Objectif|الهدف|هدف|יעד|ہدف|Цель|Мета|Cel|Cíl|Țintă|Cél|Στόχος|Obiettivo|Meta|Doel|Mål|Mål|Mål|Tavoite|目標|목표|目标|लक्ष्य|লক্ষ্য|Target|Sasaran|เป้าหมาย|Mục tiêu|Layunin',
  'found': 'Bulunan|Found|Gefunden|Encontrados|Trouvés|تم العثور|پیدا شده|נמצאו|ملے|Найдено|Знайдено|Znalezione|Nalezeno|Găsite|Megtalálva|Βρέθηκαν|Trovati|Encontrados|Gevonden|Hittade|Fundet|Funnet|Löydetty|発見|찾음|已找到|मिले|পাওয়া গেছে|Ditemukan|Dijumpai|พบแล้ว|Đã tìm|Nahanap',
  'shuffle': 'Karıştır|Shuffle|Mischen|Mezclar|Mélanger|خلط|بُر زدن|ערבוב|ملائیں|Перемешать|Перемішати|Tasuj|Zamíchat|Amestecă|Keverés|Ανακάτεμα|Mescola|Embaralhar|Schudden|Blanda|Bland|Stokk|Sekoita|シャッフル|섞기|洗牌|फेंटें|এলোমেলো|Acak|Kocok|สับ|Xáo trộn|I-shuffle',
  'slot': 'Ek yer|Extra slot|Extra-Platz|Hueco extra|Place en plus|خانة إضافية|جای اضافه|משבצת נוספת|اضافی جگہ|Доп. место|Дод. місце|Dodatkowe miejsce|Místo navíc|Loc în plus|Extra hely|Επιπλέον θέση|Posto extra|Espaço extra|Extra plek|Extra plats|Ekstra plads|Ekstra plass|Lisäpaikka|追加スロット|추가 칸|额外格|अतिरिक्त जगह|অতিরিক্ত ঘর|Slot ekstra|Slot tambahan|ช่องพิเศษ|Ô thêm|Dagdag na puwesto',
  'level_goal': 'Hepsini temizle|Clear them all|Alles abräumen|Despéjalo todo|Tout dégager|أزل الكل|همه را پاک کن|נקו הכול|سب صاف کریں|Убери всё|Прибери все|Wyczyść wszystko|Vyčisti vše|Curăță tot|Tisztítsd meg mind|Καθάρισέ τα όλα|Liberali tutti|Limpe tudo|Ruim alles op|Rensa allt|Ryd det hele|Rydd alt|Tyhjennä kaikki|全部消そう|모두 없애기|全部消除|सब हटाएँ|সব সরাও|Bersihkan semua|Kosongkan semua|เคลียร์ให้หมด|Xóa hết|Linisin lahat',
  'stuck': 'Hamle kalmadı|No moves left|Keine Züge mehr|No quedan movimientos|Plus de coups|لا حركات متبقية|حرکتی نمانده|אין מהלכים|کوئی چال نہیں|Ходов нет|Ходів немає|Brak ruchów|Žádné tahy|Nicio mutare|Nincs több lépés|Δεν υπάρχουν κινήσεις|Nessuna mossa|Sem jogadas|Geen zetten meer|Inga drag kvar|Ingen træk|Ingen trekk|Ei siirtoja|手詰まり|이동 불가|无路可走|कोई चाल नहीं|কোনো চাল নেই|Tidak ada langkah|Tiada langkah|ไม่มีตาเดิน|Hết nước đi|Wala nang galaw',
  'tray_full': 'Tepsi doldu|Tray is full|Ablage voll|Bandeja llena|Plateau plein|الصينية ممتلئة|سینی پر شد|המגש מלא|ٹرے بھر گئی|Лоток полон|Лоток повний|Taca pełna|Zásobník plný|Tava e plină|Megtelt a tálca|Ο δίσκος γέμισε|Vassoio pieno|Bandeja cheia|Bakje vol|Brickan är full|Bakken er fuld|Brettet er fullt|Tarjotin täynnä|トレイが満杯|트레이가 가득 참|托盘已满|ट्रे भर गई|ট্রে ভরে গেছে|Baki penuh|Dulang penuh|ถาดเต็ม|Khay đã đầy|Puno na ang tray',
  'colors': 'Renk|Colors|Farben|Colores|Couleurs|الألوان|رنگ‌ها|צבעים|رنگ|Цвета|Кольори|Kolory|Barvy|Culori|Színek|Χρώματα|Colori|Cores|Kleuren|Färger|Farver|Farger|Värit|色|색|颜色|रंग|রং|Warna|Warna|สี|Màu|Mga kulay',
  'differences': 'Fark|Differences|Unterschiede|Diferencias|Différences|الفروق|تفاوت‌ها|הבדלים|فرق|Отличия|Відмінності|Różnice|Rozdíly|Diferențe|Különbségek|Διαφορές|Differenze|Diferenças|Verschillen|Skillnader|Forskelle|Forskjeller|Eroja|違い|차이|不同|अंतर|পার্থক্য|Perbedaan|Perbezaan|จุดต่าง|Điểm khác|Pagkakaiba',
  'find': 'Bul|Find|Finde|Encuentra|Trouve|ابحث عن|پیدا کن|מצאו|ڈھونڈیں|Найди|Знайди|Znajdź|Najdi|Găsește|Keresd|Βρες|Trova|Encontre|Zoek|Hitta|Find|Finn|Etsi|探す|찾기|寻找|ढूँढें|খোঁজো|Temukan|Cari|หา|Tìm|Hanapin',
  'time': 'Süre|Time|Zeit|Tiempo|Temps|الوقت|زمان|זמן|وقت|Время|Час|Czas|Čas|Timp|Idő|Χρόνος|Tempo|Tempo|Tijd|Tid|Tid|Tid|Aika|時間|시간|时间|समय|সময়|Waktu|Masa|เวลา|Thời gian|Oras',
  'next': 'Sıradaki|Next|Nächstes|Siguiente|Suivant|التالي|بعدی|הבא|اگلا|Следующий|Наступний|Następny|Další|Următorul|Következő|Επόμενο|Prossimo|Próximo|Volgende|Nästa|Næste|Neste|Seuraava|次|다음|下一个|अगला|পরের|Berikutnya|Seterusnya|ถัดไป|Tiếp theo|Susunod',
  'pixels': 'Kalan piksel|Pixels left|Pixel übrig|Píxeles restantes|Pixels restants|البكسلات المتبقية|پیکسل‌های باقی|פיקסלים שנותרו|باقی پکسل|Осталось пикселей|Залишилось пікселів|Pozostałe piksele|Zbývající pixely|Pixeli rămași|Hátralévő pixelek|Εικονοστοιχεία που μένουν|Pixel rimasti|Píxeis restantes|Pixels over|Pixlar kvar|Pixels tilbage|Piksler igjen|Pikseleitä jäljellä|残りのピクセル|남은 픽셀|剩余像素|बचे पिक्सेल|বাকি পিক্সেল|Sisa piksel|Piksel berbaki|พิกเซลที่เหลือ|Điểm ảnh còn lại|Natitirang pixel',
  'grains': 'Kalan tane|Grains left|Körner übrig|Granos restantes|Grains restants|الحبات المتبقية|دانه‌های باقی|גרגירים שנותרו|باقی دانے|Осталось крупинок|Залишилось крупинок|Pozostałe ziarna|Zbývající zrnka|Boabe rămase|Hátralévő szemek|Κόκκοι που μένουν|Granelli rimasti|Grãos restantes|Korrels over|Korn kvar|Korn tilbage|Korn igjen|Jyviä jäljellä|残りの粒|남은 알갱이|剩余颗粒|बचे दाने|বাকি দানা|Sisa butiran|Butiran berbaki|เม็ดที่เหลือ|Hạt còn lại|Natitirang butil',
};

final Map<String, List<String>> kMatchTexts = {
  for (final e in _raw.entries) e.key: e.value.split('|'),
};

/// Kısa metni dile göre seç.
String mt(String lang, String key) => Strings.pick(kMatchTexts[key]!, lang);

/// Eşleştirme ailesinin ortak kullanım anlatımı (33 dil).
const kMatchHowTo = TutorialStep(Icons.touch_app, [
  'Üstte durum, geri al, baştan başla, ipucu ve güçlendirici düğmeleri var. İpucu yararlı bir hamleyi parlatır; güçlendirici takıldığında yolu açar.',
  'The top bar shows the status plus undo, restart, hint and booster buttons. A hint lights up a useful move; the booster gets you unstuck.',
  'Oben siehst du den Stand sowie Rückgängig, Neustart, Tipp und Booster. Ein Tipp hebt einen guten Zug hervor; der Booster hilft, wenn du feststeckst.',
  'Arriba ves el estado y los botones de deshacer, reiniciar, pista y potenciador. La pista resalta una jugada útil; el potenciador te desatasca.',
  'En haut : l\'état et les boutons annuler, recommencer, indice et bonus. L\'indice éclaire un coup utile ; le bonus vous débloque.',
  'في الأعلى الحالة وأزرار التراجع والإعادة والتلميح والمعزز. التلميح يضيء حركة مفيدة، والمعزز يفك الانسداد.',
  'بالا وضعیت و دکمه‌های واگرد، از نو، راهنما و تقویت‌کننده است. راهنما حرکتی مفید را روشن می‌کند؛ تقویت‌کننده گره را باز می‌کند.',
  'למעלה: מצב, ביטול, התחלה מחדש, רמז ומגבר. רמז מאיר מהלך מועיל; המגבר משחרר כשנתקעים.',
  'اوپر حالت کے ساتھ واپس، دوبارہ، اشارہ اور بوسٹر کے بٹن ہیں۔ اشارہ مفید چال روشن کرتا ہے؛ بوسٹر پھنسنے پر راستہ کھولتا ہے۔',
  'Вверху — состояние и кнопки отмены, перезапуска, подсказки и бонуса. Подсказка подсвечивает полезный ход, бонус выручает в тупике.',
  'Угорі — стан і кнопки скасування, перезапуску, підказки та бонусу. Підказка підсвічує корисний хід, бонус рятує в глухому куті.',
  'U góry: stan oraz cofnij, od nowa, podpowiedź i wzmocnienie. Podpowiedź podświetla dobry ruch; wzmocnienie pomaga, gdy utkniesz.',
  'Nahoře je stav a tlačítka zpět, znovu, nápověda a posila. Nápověda zvýrazní užitečný tah, posila pomůže, když se zasekneš.',
  'Sus vezi starea și butoanele anulare, reluare, indiciu și bonus. Indiciul luminează o mutare utilă; bonusul te deblochează.',
  'Fent az állapot, valamint a visszavonás, újrakezdés, tipp és erősítő gomb. A tipp kiemel egy jó lépést, az erősítő kisegít, ha elakadsz.',
  'Πάνω φαίνεται η κατάσταση με αναίρεση, επανεκκίνηση, βοήθεια και ενίσχυση. Η βοήθεια φωτίζει μια χρήσιμη κίνηση· η ενίσχυση σε ξεκολλάει.',
  'In alto c\'è lo stato con annulla, ricomincia, aiuto e potenziamento. L\'aiuto illumina una mossa utile; il potenziamento ti sblocca.',
  'No topo: estado, desfazer, recomeçar, dica e reforço. A dica destaca uma jogada útil; o reforço desbloqueia quando você empaca.',
  'Bovenaan zie je de stand plus ongedaan maken, opnieuw, hint en booster. Een hint licht een goede zet op; de booster helpt als je vastzit.',
  'Överst syns läget och knappar för ångra, börja om, ledtråd och boost. Ledtråden lyser upp ett bra drag; boosten hjälper när du kör fast.',
  'Øverst ser du status og knapper til fortryd, forfra, hint og booster. Et hint fremhæver et godt træk; boosteren hjælper, når du sidder fast.',
  'Øverst ser du status og knapper for angre, start på nytt, hint og booster. Et hint lyser opp et godt trekk; boosteren hjelper når du står fast.',
  'Ylhäällä näkyy tilanne sekä kumoa, alusta, vihje ja tehoste. Vihje korostaa hyvän siirron; tehoste auttaa jumissa.',
  '上部に状況と、戻す・やり直し・ヒント・ブースターのボタン。ヒントは役立つ手を光らせ、ブースターは手詰まりを解消します。',
  '위에 상태와 되돌리기·다시 시작·힌트·부스터 버튼이 있어요. 힌트는 쓸모 있는 수를 비추고, 부스터는 막혔을 때 길을 열어 줘요.',
  '上方显示状态，以及撤销、重来、提示和道具按钮。提示会点亮一步好棋，道具帮你解围。',
  'ऊपर स्थिति के साथ वापस, फिर से, संकेत और बूस्टर बटन हैं। संकेत उपयोगी चाल चमकाता है; बूस्टर अटकने पर रास्ता खोलता है।',
  'উপরে অবস্থা আর ফেরত, আবার, সংকেত ও বুস্টার বোতাম। সংকেত কাজের চাল দেখায়; বুস্টার আটকে গেলে পথ খোলে।',
  'Di atas ada status serta tombol urungkan, ulangi, petunjuk, dan booster. Petunjuk menyorot langkah berguna; booster membantu saat buntu.',
  'Di atas ada status serta butang buat asal, mula semula, petunjuk dan penggalak. Petunjuk menyerlahkan langkah berguna; penggalak membantu ketika tersekat.',
  'ด้านบนมีสถานะและปุ่มเลิกทำ เริ่มใหม่ คำใบ้ และตัวช่วย คำใบ้จะไฮไลต์ตาที่ดี ตัวช่วยใช้เมื่อติด',
  'Phía trên có trạng thái cùng nút hoàn tác, chơi lại, gợi ý và trợ giúp. Gợi ý làm sáng một nước hay; trợ giúp gỡ khi bế tắc.',
  'Nasa itaas ang status at ang mga button na undo, ulitin, pahiwatig at booster. Pinapailaw ng pahiwatig ang magandang galaw; tumutulong ang booster kapag na-stuck.',
]);
