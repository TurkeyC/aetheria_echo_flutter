import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart'; // for kDebugMode
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 导入 dotenv

class VoiceService {
  // --- Azure 配置 (从 .env 加载) ---
  String? _subscriptionKey;
  String? _region;
  String? _authToken;
  DateTime? _tokenExpiry;

  // --- 音频播放器 (TTS) ---
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- 音频录制器 (STT) ---
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordingPath;

  bool isInitialized = false;

  // 初始化 (加载配置并获取初始Token)
  Future<bool> initialize() async {
    if (isInitialized) return true;

    // 从 dotenv 加载配置
    _subscriptionKey = dotenv.env['AZURE_SUBSCRIPTION_KEY'];
    _region = dotenv.env['AZURE_REGION'];

    if (_subscriptionKey == null || _region == null) {
      debugPrint("错误：未在 .env 文件中找到 AZURE_SUBSCRIPTION_KEY 或 AZURE_REGION");
      isInitialized = false;
      return false;
    }

    try {
      await _refreshAuthTokenIfNeeded();
      isInitialized = _authToken != null;
      if (isInitialized) {
        debugPrint("Azure语音服务初始化成功 (使用 .env 配置)");
      }
      return isInitialized;
    } catch (e) {
      debugPrint("Azure语音服务初始化失败: $e");
      isInitialized = false;
      return false;
    }
  }

  // 获取或刷新Azure认证Token
  Future<void> _refreshAuthTokenIfNeeded() async {
    // 确保 key 和 region 已加载
    if (_subscriptionKey == null || _region == null) {
      throw Exception("Azure 配置未加载");
    }

    if (_authToken == null || (_tokenExpiry != null && DateTime.now().isAfter(_tokenExpiry!))) {
      // 使用 _region! 和 _subscriptionKey! 因为我们已在 initialize 中检查非空
      final tokenUri = Uri.parse('https://${_region!}.api.cognitive.microsoft.com/sts/v1.0/issueToken');
      try {
        final response = await http.post(
          tokenUri,
          headers: {
            'Ocp-Apim-Subscription-Key': _subscriptionKey!, // 使用加载的 key
            'Content-Type': 'application/x-www-form-urlencoded',
            'Content-Length': '0',
          },
        );
        if (response.statusCode == 200) {
          _authToken = response.body;
          _tokenExpiry = DateTime.now().add(const Duration(minutes: 9));
          debugPrint("Azure Auth Token 获取成功");
        } else {
          _authToken = null;
          _tokenExpiry = null;
          debugPrint("获取Azure Auth Token失败: ${response.statusCode} ${response.body}");
          throw Exception("获取Azure Auth Token失败: ${response.statusCode}");
        }
      } catch (e) {
        debugPrint("获取Azure Auth Token网络错误: $e");
        _authToken = null;
        _tokenExpiry = null;
        throw Exception("获取Azure Auth Token网络错误: $e");
      }
    }
  }

  // 文字转语音 (TTS)
  Future<void> speak(String text) async {
    if (!isInitialized) await initialize();
    if (_authToken == null || _region == null) { // 检查 region
      debugPrint("无法执行TTS：Auth Token 或 Region 无效");
      return;
    }
    await _refreshAuthTokenIfNeeded(); // 确保Token有效

    // 使用 _region!
    final ttsUri = Uri.parse('https://${_region!}.tts.speech.microsoft.com/cognitiveservices/v1');
    final ssml = '''
      <speak version='1.0' xml:lang='zh-CN'>
          <voice xml:lang='zh-CN' xml:gender='Female' name='zh-CN-XiaoxiaoNeural'>
              $text
          </voice>
      </speak>
    ''';

    try {
      final response = await http.post(
        ttsUri,
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
          'User-Agent': 'AetheriaEchoFlutter',
        },
        body: ssml,
      );

      if (response.statusCode == 200) {
        await _audioPlayer.play(BytesSource(response.bodyBytes));
        debugPrint("TTS 播放成功");
      } else {
        debugPrint("Azure TTS API错误: ${response.statusCode} ${response.reasonPhrase}");
        debugPrint("错误详情: ${utf8.decode(response.bodyBytes)}");
      }
    } catch (e) {
      debugPrint("Azure TTS 请求错误: $e");
    }
  }

  // 语音转文字 (STT) - 简单实现，录制完成后发送
  Future<void> listen({
    required Function(String) onResult,
    required Function() onDone,
    required Function(String) onError,
  }) async {
    if (!isInitialized) await initialize();
    if (_authToken == null) {
      debugPrint("无法执行STT：Auth Token无效");
      onError("认证失败");
      onDone();
      return;
    }

    try {
      if (!await _audioRecorder.hasPermission()) {
        debugPrint("缺少录音权限");
        onError("缺少录音权限");
        onDone();
        return;
      }

      final directory = await getTemporaryDirectory();
      _recordingPath = '${directory.path}/temp_audio.wav';

      await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.wav), path: _recordingPath!);
      debugPrint("STT 开始录音...");

    } catch (e) {
      debugPrint("STT 开始录音失败: $e");
      onError("录音启动失败: $e");
      onDone();
    }
  }

  // 停止监听并发送识别请求
  Future<void> stopListening({
    required Function(String) onResult,
    required Function() onDone,
    required Function(String) onError,
  }) async {
    if (!await _audioRecorder.isRecording()) {
      onDone();
      return;
    }
    // 确保 region 已加载
    if (_region == null) {
      onError("Azure 配置未加载");
      onDone();
      return;
    }

    try {
      final path = await _audioRecorder.stop();
      debugPrint("STT 录音结束: $path");

      if (path == null || _authToken == null) {
        debugPrint("录音文件路径为空或Auth Token无效");
        onError("录音失败或认证无效");
        onDone();
        return;
      }
      await _refreshAuthTokenIfNeeded();

      final audioFile = File(path);
      if (!await audioFile.exists()) {
        debugPrint("录音文件不存在: $path");
        onError("录音文件丢失");
        onDone();
        return;
      }
      final audioBytes = await audioFile.readAsBytes();

      // 使用 _region!
      final sttUri = Uri.parse('https://${_region!}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=zh-CN&format=detailed');

      final response = await http.post(
        sttUri,
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
          'Accept': 'application/json;text/xml',
        },
        body: audioBytes,
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        debugPrint("Azure STT 结果: $result");
        if (result['RecognitionStatus'] == 'Success') {
          onResult(result['DisplayText'] ?? '');
        } else {
          debugPrint("Azure STT 识别失败: ${result['RecognitionStatus']}");
          onError("识别失败: ${result['RecognitionStatus']}");
        }
      } else {
        debugPrint("Azure STT API错误: ${response.statusCode} ${response.reasonPhrase}");
        debugPrint("错误详情: ${response.body}");
        onError("API错误: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Azure STT 请求或处理错误: $e");
      onError("请求错误: $e");
    } finally {
      if (_recordingPath != null) {
        try {
          final file = File(_recordingPath!);
          if (await file.exists()) {
            await file.delete();
            debugPrint("临时录音文件已删除");
          }
        } catch (e) {
          debugPrint("删除临时录音文件失败: $e");
        }
        _recordingPath = null;
      }
      onDone();
    }
  }

  // 清理资源
  void dispose() {
    _audioPlayer.dispose();
    _audioRecorder.dispose();
  }
}