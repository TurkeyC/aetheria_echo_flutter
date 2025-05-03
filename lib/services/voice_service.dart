import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart'; // for kDebugMode

class VoiceService {
  // --- Azure 配置 ---
  final String _subscriptionKey = "你的Azure订阅密钥"; // 替换为你的密钥
  final String _region = "你的Azure区域"; // 替换为你的区域
  String? _authToken;
  DateTime? _tokenExpiry;

  // --- 音频播放器 (TTS) ---
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- 音频录制器 (STT) ---
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordingPath;

  bool isInitialized = false;

  // 初始化 (主要获取初始Token)
  Future<bool> initialize() async {
    if (isInitialized) return true;
    try {
      await _refreshAuthTokenIfNeeded();
      // 可以在这里预先检查录音权限等
      isInitialized = _authToken != null;
      return isInitialized;
    } catch (e) {
      debugPrint("Azure语音服务初始化失败: $e");
      return false;
    }
  }

  // 获取或刷新Azure认证Token
  Future<void> _refreshAuthTokenIfNeeded() async {
    if (_authToken == null || (_tokenExpiry != null && DateTime.now().isAfter(_tokenExpiry!))) {
      final tokenUri = Uri.parse('https://${_region}.api.cognitive.microsoft.com/sts/v1.0/issueToken');
      try {
        final response = await http.post(
          tokenUri,
          headers: {
            'Ocp-Apim-Subscription-Key': _subscriptionKey,
            'Content-Type': 'application/x-www-form-urlencoded', // 必须
            'Content-Length': '0', // 必须
          },
        );
        if (response.statusCode == 200) {
          _authToken = response.body;
          // Token有效期通常为10分钟，设置一个稍短的过期时间
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
    if (_authToken == null) {
       debugPrint("无法执行TTS：Auth Token无效");
       return;
    }
    await _refreshAuthTokenIfNeeded(); // 确保Token有效

    final ttsUri = Uri.parse('https://${_region}.tts.speech.microsoft.com/cognitiveservices/v1');
    final ssml = '''
      <speak version='1.0' xml:lang='zh-CN'>
          <voice xml:lang='zh-CN' xml:gender='Female' name='zh-CN-XiaoxiaoNeural'>
              $text
          </voice>
      </speak>
    '''; // 使用SSML格式

    try {
      final response = await http.post(
        ttsUri,
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3', // 请求MP3格式
          'User-Agent': 'AetheriaEchoFlutter',
        },
        body: ssml,
      );

      if (response.statusCode == 200) {
        // 播放接收到的音频数据
        await _audioPlayer.play(BytesSource(response.bodyBytes));
        debugPrint("TTS 播放成功");
      } else {
        debugPrint("Azure TTS API错误: ${response.statusCode} ${response.reasonPhrase}");
        debugPrint("错误详情: ${utf8.decode(response.bodyBytes)}"); // 尝试解码错误信息
      }
    } catch (e) {
      debugPrint("Azure TTS 请求错误: $e");
    }
  }

  // 语音转文字 (STT) - 简单实现，录制完成后发送
  Future<void> listen({
    required Function(String) onResult,
    required Function() onDone, // 注意：REST API通常不是持续监听，此回调会在识别完成后触发
    required Function(String) onError, // 添加错误回调
  }) async {
    if (!isInitialized) await initialize();
     if (_authToken == null) {
       debugPrint("无法执行STT：Auth Token无效");
       onError("认证失败");
       onDone();
       return;
    }

    try {
       // 检查并请求录音权限
      if (!await _audioRecorder.hasPermission()) {
        debugPrint("缺少录音权限");
        onError("缺少录音权限");
        onDone();
        return;
      }

      // 准备录音文件路径
      final directory = await getTemporaryDirectory();
      _recordingPath = '${directory.path}/temp_audio.wav'; // Azure STT REST API 通常接受 WAV

      // 开始录音
      await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.wav), path: _recordingPath!);
      debugPrint("STT 开始录音...");
      // 注意：这里没有实时结果回调，因为REST API是一次性发送文件
      // 你可以在UI层提供一个停止按钮来调用 stopListening

    } catch (e) {
      debugPrint("STT 开始录音失败: $e");
      onError("录音启动失败: $e");
      onDone(); // 确保onDone被调用
    }
  }

  // 停止监听并发送识别请求
  Future<void> stopListening({
      required Function(String) onResult,
      required Function() onDone,
      required Function(String) onError,
  }) async {
    if (!await _audioRecorder.isRecording()) {
      onDone(); // 如果没有在录音，直接结束
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
      await _refreshAuthTokenIfNeeded(); // 确保Token有效

      final audioFile = File(path);
      if (!await audioFile.exists()) {
         debugPrint("录音文件不存在: $path");
         onError("录音文件丢失");
         onDone();
         return;
      }
      final audioBytes = await audioFile.readAsBytes();

      final sttUri = Uri.parse('https://${_region}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=zh-CN&format=detailed'); // 请求详细格式以获取置信度等

      final response = await http.post(
        sttUri,
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000', // 根据录音配置调整
          'Accept': 'application/json;text/xml',
        },
        body: audioBytes,
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        debugPrint("Azure STT 结果: $result");
        if (result['RecognitionStatus'] == 'Success') {
          onResult(result['DisplayText'] ?? ''); // 获取识别文本
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
       // 清理录音文件
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
       onDone(); // 确保onDone在所有情况下都被调用
    }
  }

  // 清理资源
  void dispose() {
    _audioPlayer.dispose();
    _audioRecorder.dispose();
  }
}