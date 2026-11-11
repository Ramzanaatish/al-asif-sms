/// Urdu auto-fill for student names, ported 1:1 from the HTML
/// (Complete v7) transliterator: the same NAME_URDU dictionary
/// and the same rule engine, so the app auto-fills exactly what
/// the HTML auto-fills when a name is typed. The teacher can
/// always correct the Urdu text by hand in the form.

const Map<String, String> nameUrdu = {
  'abbas': 'عباس',
  'abdul': 'عبد',
  'abdullah': 'عبداللہ',
  'abid': 'عابد',
  'adil': 'عادل',
  'adnan': 'عدنان',
  'ahad': 'احد',
  'ahmed': 'احمد',
  'ahsan': 'احسن',
  'aisha': 'عائشہ',
  'akbar': 'اکبر',
  'akeela': 'عقیلہ',
  'akhtar': 'اختر',
  'akram': 'اکرم',
  'ali': 'علی',
  'alisha': 'علیشہ',
  'amina': 'آمینہ',
  'amir': 'عامر',
  'amna': 'آمنہ',
  'anam': 'انعم',
  'anwar': 'انور',
  'areeba': 'اریبہ',
  'arham': 'ارحم',
  'arif': 'عارف',
  'arslan': 'ارسلان',
  'asad': 'اسد',
  'ashfaq': 'اشفاق',
  'ashiq': 'عاشق',
  'asia': 'آسیہ',
  'asif': 'آصف',
  'aslam': 'اسلم',
  'atta': 'عطا',
  'awais': 'اویس',
  'ayaan': 'ایان',
  'ayan': 'ایان',
  'ayesha': 'عائشہ',
  'azhar': 'اظہر',
  'babar': 'بابر',
  'bashir': 'بشیر',
  'bibi': 'بی بی',
  'bilal': 'بلال',
  'danish': 'دانش',
  'dawood': 'داؤد',
  'dilshad': 'دلشاد',
  'dua': 'دعا',
  'eman': 'ایمان',
  'fahad': 'فہد',
  'faisal': 'فیصل',
  'farhan': 'فرحان',
  'farooq': 'فاروق',
  'farooque': 'فاروق',
  'fatima': 'فاطمہ',
  'ghafoor': 'غفور',
  'ghulam': 'غلام',
  'habib': 'حبیب',
  'haider': 'حیدر',
  'hameed': 'حمید',
  'hamid': 'حامد',
  'hamza': 'حمزہ',
  'haroon': 'ہارون',
  'hassan': 'حسن',
  'hina': 'حنا',
  'hira': 'حرا',
  'hoor': 'حور',
  'hussain': 'حسین',
  'huzaifa': 'حذیفہ',
  'ibrahim': 'ابراہیم',
  'idrees': 'ادریس',
  'ifran': 'عرفان',
  'imran': 'عمران',
  'iqbal': 'اقبال',
  'irfan': 'عرفان',
  'ismail': 'اسماعیل',
  'jabbar': 'جبار',
  'jafar': 'جعفر',
  'jameel': 'جمیل',
  'jamil': 'جمیل',
  'jannat': 'جنت',
  'javed': 'جاوید',
  'jawad': 'جواد',
  'junaid': 'جنید',
  'kamran': 'کامران',
  'kareem': 'کریم',
  'kashif': 'کاشف',
  'khadija': 'خدیجہ',
  'khalid': 'خالد',
  'khan': 'خان',
  'laiba': 'لائبہ',
  'latif': 'لطیف',
  'maham': 'ماہم',
  'mahmood': 'محمود',
  'mahnoor': 'مہ نور',
  'majid': 'ماجد',
  'malik': 'ملک',
  'maryam': 'مریم',
  'mehmood': 'محمود',
  'mehwish': 'مہوش',
  'mohammad': 'محمد',
  'mohammed': 'محمد',
  'mubeen': 'مبین',
  'muhammad': 'محمد',
  'munir': 'منیر',
  'musa': 'موسیٰ',
  'mustafa': 'مصطفیٰ',
  'nadeem': 'ندیم',
  'nadia': 'نادیہ',
  'naeem': 'نعیم',
  'nasir': 'ناصر',
  'naveed': 'نوید',
  'niaz': 'نیاز',
  'nimra': 'نمرہ',
  'noman': 'نعمان',
  'noor': 'نور',
  'omar': 'عمر',
  'owais': 'اویس',
  'qadir': 'قادر',
  'qasim': 'قاسم',
  'rabia': 'رابعہ',
  'rafiq': 'رفیق',
  'raheem': 'رحیم',
  'rahman': 'رحمان',
  'rasheed': 'رشید',
  'rashid': 'راشد',
  'rauf': 'رؤف',
  'rayan': 'ریان',
  'raza': 'رضا',
  'rehan': 'ریحان',
  'rehman': 'رحمان',
  'rizwan': 'رضوان',
  'saad': 'سعد',
  'sadiq': 'صادق',
  'saeed': 'سعید',
  'saima': 'صائمہ',
  'sajid': 'ساجد',
  'sajjad': 'سجاد',
  'saleem': 'سلیم',
  'salman': 'سلمان',
  'sami': 'سامی',
  'sana': 'ثنا',
  'saqib': 'ثاقب',
  'sara': 'سارہ',
  'sattar': 'ستار',
  'shabbir': 'شبیر',
  'shafiq': 'شفیق',
  'shahbaz': 'شہباز',
  'shaheen': 'شاہین',
  'shahid': 'شاہد',
  'shahzad': 'شہزاد',
  'shakeel': 'شکیل',
  'shakila': 'شکیلہ',
  'sharif': 'شریف',
  'shoaib': 'شعیب',
  'siddiq': 'صدیق',
  'siddique': 'صدیق',
  'siddiqui': 'صدیقی',
  'sohail': 'سہیل',
  'subhan': 'سبحان',
  'tahir': 'طاہر',
  'talha': 'طلحہ',
  'tariq': 'طارق',
  'umair': 'عمیر',
  'umar': 'عمر',
  'umer': 'عمر',
  'unzila': 'انزلہ',
  'usama': 'اسامہ',
  'usman': 'عثمان',
  'uzair': 'عزیر',
  'uzma': 'عظمیٰ',
  'waheed': 'وحید',
  'waleed': 'ولید',
  'waqar': 'وقار',
  'waqas': 'وقاص',
  'waseem': 'وسیم',
  'wasim': 'وسیم',
  'yaqoob': 'یعقوب',
  'younis': 'یونس',
  'yousuf': 'یوسف',
  'yusuf': 'یوسف',
  'zahid': 'زاہد',
  'zahir': 'ظاہر',
  'zahra': 'زہرا',
  'zain': 'زین',
  'zainab': 'زینب',
  'zakir': 'ذاکر',
  'zayan': 'زیان',
  'zeeshan': 'ذیشان',
  'zeshan': 'ذیشان',
  'zunaira': 'زنیرہ',
};

const Map<String, String> _digraphs = {
  'kh': 'خ',
  'gh': 'غ',
  'ch': 'چ',
  'sh': 'ش',
  'th': 'تھ',
  'ph': 'پھ',
  'bh': 'بھ',
  'dh': 'دھ',
  'zh': 'ژ',
  'ng': 'ں',
  'aa': 'آ',
  'ee': 'ی',
  'oo': 'و',
  'ai': 'ای',
  'au': 'او',
  'ou': 'و',
  'ei': 'ای',
  'ie': 'ی',
  'ay': 'ے',
  'ey': 'ے',
};

const Map<String, String> _single = {
  'b': 'ب',
  'c': 'ک',
  'd': 'د',
  'f': 'ف',
  'g': 'گ',
  'j': 'ج',
  'k': 'ک',
  'l': 'ل',
  'm': 'م',
  'n': 'ن',
  'p': 'پ',
  'q': 'ق',
  'r': 'ر',
  's': 'س',
  't': 'ت',
  'v': 'و',
  'w': 'و',
  'x': 'کس',
  'y': 'ی',
  'z': 'ز',
};

String transliterateWord(String word) {
  final low = word.toLowerCase();
  final known = nameUrdu[low];
  if (known != null) return known;
  final out = StringBuffer();
  var i = 0;
  while (i < low.length) {
    final two = i + 2 <= low.length ? low.substring(i, i + 2) : null;
    final dig = two == null ? null : _digraphs[two];
    if (dig != null) {
      out.write(dig);
      i += 2;
      continue;
    }
    final ch = low[i];
    if (ch == 'a') {
      out.write(i == low.length - 1 ? 'ہ' : 'ا');
    } else if (ch == 'e') {
      out.write(i == low.length - 1 ? 'ے' : '');
    } else if (ch == 'i') {
      out.write('ی');
    } else if (ch == 'o' || ch == 'u') {
      out.write(i == 0 ? 'ع' : '');
    } else if (ch == 'h') {
      if (i == 0) {
        out.write('ح');
      } else if (low[i - 1] == 'a' &&
          i + 1 < low.length && low[i + 1] == 'm') {
        out.write('ح');
      } else {
        out.write('ہ');
      }
    } else if (_single.containsKey(ch)) {
      out.write(_single[ch]!);
    } else {
      out.write(ch);
    }
    i++;
  }
  return out.toString();
}

/// Transliterates a full name (words split on spaces and hyphens,
/// exactly like the HTML).
String transliterate(String? name) {
  if (name == null || name.isEmpty) return '';
  return name
      .split(RegExp(r'[\s\-]+'))
      .map((w) => w.isEmpty ? '' : transliterateWord(w))
      .join(' ');
}

/// The Urdu text to show for a student: the stored Urdu name when
/// the teacher typed or corrected one, otherwise the
/// transliteration of the English name.
String urduName(String? stored, String english) {
  if (stored != null && stored.isNotEmpty) return stored;
  return transliterate(english);
}
