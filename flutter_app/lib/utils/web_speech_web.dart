import 'package:web/web.dart' as web;

void speakWebTamil(String text) {
  try {
    final synth = web.window.speechSynthesis;
    synth.cancel();
    final utterance = web.SpeechSynthesisUtterance(text);
    utterance.lang = 'ta-IN';
    utterance.rate = 0.9;
    synth.speak(utterance);
  } catch (_) {}
}

void stopWebSpeech() {
  try {
    web.window.speechSynthesis.cancel();
  } catch (_) {}
}

