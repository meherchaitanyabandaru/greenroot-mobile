/// Mango's greeting and goodbye: clips shipped in assets/audio/mango, so
/// opening and closing Mango never calls the AI provider. Made by
/// greenroot-ai scripts/make_greetings.py; a native speaker's recording can
/// replace any file under the same name.
/// The languages Mango speaks. English always works too: whatever the
/// choice, a question in English gets an English answer.
class MangoLanguage {
  final String code;
  final String native;
  final String english;
  const MangoLanguage(this.code, this.native, this.english);
}

const mangoLanguages = [
  MangoLanguage('te', 'తెలుగు', 'Telugu'),
  MangoLanguage('hi', 'हिन्दी', 'Hindi'),
  MangoLanguage('kn', 'ಕನ್ನಡ', 'Kannada'),
  MangoLanguage('mr', 'मराठी', 'Marathi'),
  MangoLanguage('ta', 'தமிழ்', 'Tamil'),
  MangoLanguage('ur', 'اردو', 'Urdu'),
  MangoLanguage('en', 'English', 'English'),
];

MangoLanguage mangoLanguage(String code) => mangoLanguages.firstWhere((l) => l.code == code, orElse: () => mangoLanguages.first);

/// A sample question in each language (English samples are always shown).
const mangoSampleQuestion = {
  'te': 'ఈరోజు పెండింగ్ ఆర్డర్లు ఎన్ని?',
  'hi': 'आज कितने ऑर्डर पेंडिंग हैं?',
  'kn': 'ಇಂದು ಎಷ್ಟು ಆರ್ಡರ್‌ಗಳು ಬಾಕಿ ಇವೆ?',
  'mr': 'आज किती ऑर्डर बाकी आहेत?',
  'ta': 'இன்று எத்தனை ஆர்டர்கள் நிலுவையில் உள்ளன?',
  'ur': 'آج کتنے آرڈر باقی ہیں؟',
};

/// Lines other than Telugu and English were written by the developer:
/// have a native speaker check them (and the clips) before launch.
const mangoLines = {
  'greet_morning_te': 'శుభోదయం! నేను మ్యాంగో. మీకు ఏం సహాయం కావాలి?',
  'greet_day_te': 'నమస్కారం! నేను మ్యాంగో. మీకు ఏం సహాయం కావాలి?',
  'greet_evening_te': 'శుభ సాయంత్రం! నేను మ్యాంగో. మీకు ఏం సహాయం కావాలి?',
  'bye_te': 'సరే, మళ్లీ కలుద్దాం!',
  'greet_morning_hi': 'सुप्रभात! मैं मैंगो हूँ। बताइए, मैं आपकी क्या मदद करूँ?',
  'greet_day_hi': 'नमस्ते! मैं मैंगो हूँ। बताइए, मैं आपकी क्या मदद करूँ?',
  'greet_evening_hi': 'शुभ संध्या! मैं मैंगो हूँ। बताइए, मैं आपकी क्या मदद करूँ?',
  'bye_hi': 'ठीक है, फिर मिलते हैं!',
  'greet_morning_kn': 'ಶುಭೋದಯ! ನಾನು ಮ್ಯಾಂಗೋ. ನಿಮಗೆ ಏನು ಸಹಾಯ ಬೇಕು?',
  'greet_day_kn': 'ನಮಸ್ಕಾರ! ನಾನು ಮ್ಯಾಂಗೋ. ನಿಮಗೆ ಏನು ಸಹಾಯ ಬೇಕು?',
  'greet_evening_kn': 'ಶುಭ ಸಂಜೆ! ನಾನು ಮ್ಯಾಂಗೋ. ನಿಮಗೆ ಏನು ಸಹಾಯ ಬೇಕು?',
  'bye_kn': 'ಸರಿ, ಮತ್ತೆ ಸಿಗೋಣ!',
  'greet_morning_mr': 'सुप्रभात! मी मँगो. सांगा, मी तुम्हाला कशी मदत करू?',
  'greet_day_mr': 'नमस्कार! मी मँगो. सांगा, मी तुम्हाला कशी मदत करू?',
  'greet_evening_mr': 'शुभ संध्याकाळ! मी मँगो. सांगा, मी तुम्हाला कशी मदत करू?',
  'bye_mr': 'ठीक आहे, पुन्हा भेटू!',
  'greet_morning_ta': 'காலை வணக்கம்! நான் மேங்கோ. உங்களுக்கு என்ன உதவி வேண்டும்?',
  'greet_day_ta': 'வணக்கம்! நான் மேங்கோ. உங்களுக்கு என்ன உதவி வேண்டும்?',
  'greet_evening_ta': 'மாலை வணக்கம்! நான் மேங்கோ. உங்களுக்கு என்ன உதவி வேண்டும்?',
  'bye_ta': 'சரி, மீண்டும் சந்திப்போம்!',
  'greet_morning_ur': 'صبح بخیر! میں مینگو ہوں۔ بتائیے، میں آپ کی کیا مدد کروں؟',
  'greet_day_ur': 'آداب! میں مینگو ہوں۔ بتائیے، میں آپ کی کیا مدد کروں؟',
  'greet_evening_ur': 'شام بخیر! میں مینگو ہوں۔ بتائیے، میں آپ کی کیا مدد کروں؟',
  'bye_ur': 'ٹھیک ہے، پھر ملیں گے!',
  'greet_morning_en': "Good morning! I'm Mango. How can I help you?",
  'greet_day_en': "Hello! I'm Mango. How can I help you?",
  'greet_evening_en': "Good evening! I'm Mango. How can I help you?",
  'bye_en': 'Okay, see you soon!',
};

/// [lang] is one of [mangoLanguages] codes.
String greetingClip(DateTime now, String lang) {
  final part = now.hour < 12 ? 'morning' : (now.hour < 17 ? 'day' : 'evening');
  return 'greet_${part}_$lang';
}

String byeClip(String lang) => 'bye_$lang';

/// Path for audioplayers' AssetSource (it adds the `assets/` prefix).
String clipAsset(String clip) => 'audio/mango/$clip.mp3';
