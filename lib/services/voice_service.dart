import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceService {
  final FlutterTts tts = FlutterTts();
  final SpeechToText speech = SpeechToText();
  bool isInitialized = false;

  // 初始化
  Future<bool> initialize() async {
    if (isInitialized) return true;

    // 初始化TTS
    await tts.setLanguage('zh-CN');
    await tts.setSpeechRate(0.5);
    await tts.setVolume(1.0);

    // 初始化STT
    final speechInitialized = await speech.initialize();

    isInitialized = speechInitialized;
    return isInitialized;
  }

  // 文字转语音
  Future<void> speak(String text) async {
    if (!isInitialized) await initialize();
    await tts.speak(text);
  }

  // 语音转文字
  Future<void> listen({
    required Function(String) onResult,
    required Function() onDone,
  }) async {
    if (!isInitialized) await initialize();

    if (speech.isAvailable) {
      await speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
        localeId: 'zh_CN',
      );
    }
  }

  // 停止监听
  Future<void> stopListening() async {
    await speech.stop();
  }
}