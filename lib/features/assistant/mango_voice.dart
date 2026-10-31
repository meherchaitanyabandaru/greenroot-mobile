/// Mango's greeting and goodbye: clips shipped in assets/audio/mango, so
/// opening and closing Mango never calls the AI provider. Made by
/// greenroot-ai scripts/make_greetings.py; a native speaker's recording can
/// replace any file under the same name.
const mangoLines = {
  'greet_morning_te': 'శుభోదయం! నేను మ్యాంగో. మీకు ఏం సహాయం కావాలి?',
  'greet_day_te': 'నమస్కారం! నేను మ్యాంగో. మీకు ఏం సహాయం కావాలి?',
  'greet_evening_te': 'శుభ సాయంత్రం! నేను మ్యాంగో. మీకు ఏం సహాయం కావాలి?',
  'bye_te': 'సరే, మళ్లీ కలుద్దాం!',
  'greet_morning_en': "Good morning! I'm Mango. How can I help you?",
  'greet_day_en': "Hello! I'm Mango. How can I help you?",
  'greet_evening_en': "Good evening! I'm Mango. How can I help you?",
  'bye_en': 'Okay, see you soon!',
};

/// [lang] is te or en.
String greetingClip(DateTime now, String lang) {
  final part = now.hour < 12 ? 'morning' : (now.hour < 17 ? 'day' : 'evening');
  return 'greet_${part}_$lang';
}

String byeClip(String lang) => 'bye_$lang';

/// Path for audioplayers' AssetSource (it adds the `assets/` prefix).
String clipAsset(String clip) => 'audio/mango/$clip.mp3';
