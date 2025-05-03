import 'package:flutter/material.dart';
import 'dart:convert';
import 'widgets/live2d_webview.dart'; // 导入Live2dWebView组件
import 'services/api_service.dart';   // 使用API服务
import 'services/voice_service.dart'; // 使用语音服务

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // 确保Flutter绑定已初始化
  runApp(const AetheriaEchoApp());
}

class AetheriaEchoApp extends StatelessWidget {
  const AetheriaEchoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aetheria Echo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isListening = false;
  bool _isProcessing = false; // 用于跟踪API调用和语音处理状态

  // 添加API服务
  final ApiService _apiService = ApiService();

  // 添加语音服务
  final VoiceService _voiceService = VoiceService();

  // 添加Live2D控制器引用
  final GlobalKey<Live2dWebViewState> _live2dKey = GlobalKey();
  bool _modelLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    _textController.dispose();
    _voiceService.dispose(); // 清理VoiceService资源
    super.dispose();
  }

  Future<void> _initializeServices() async {
    // 初始化语音服务
    bool initialized = await _voiceService.initialize();
    if (!initialized) {
      // 处理初始化失败的情况，例如显示错误消息
      _showErrorSnackbar("语音服务初始化失败，请检查网络和配置。");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aetheria Echo 虚拟助手'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Live2D区域 - 添加key引用
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Live2dWebView(
                  key: _live2dKey,
                  // 确保这里的路径正确指向你的html文件
                  // 如果使用asset，路径通常是 'asset:///flutter_assets/lib/assets/html/live2d.html'
                  // 或者你可以启动一个本地服务器并使用 http://localhost:port/path/to/live2d.html
                  initialUrl: 'asset:///flutter_assets/lib/assets/html/live2d.html',
                  onMessageReceived: _handleLive2dMessage,
                ),
                if (!_modelLoaded)
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('正在加载Live2D模型...')
                      ],
                    ),
                  )
              ],
            ),
          ),
          // 聊天消息区域
          Expanded(
            flex: 2,
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _messages[index],
            ),
          ),
          // 输入区域
          Container(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: '发送消息...',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !_isListening && !_isProcessing, // 禁用输入框当正在监听或处理时
                  ),
                ),
                const SizedBox(width: 8.0),
                // 语音按钮
                IconButton(
                  // 禁用按钮当正在处理消息时
                  onPressed: _isProcessing ? null : (_isListening ? _stopListening : _startListening),
                  icon: _isListening
                      ? const Icon(Icons.stop_circle_outlined, color: Colors.red) // 停止图标
                      : const Icon(Icons.mic),
                  tooltip: _isListening ? '停止录音' : '开始录音',
                ),
                const SizedBox(width: 8.0),
                // 发送按钮
                IconButton(
                  // 禁用按钮当正在监听或处理时
                  onPressed: (_isListening || _isProcessing) ? null : _handleSubmit,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 处理从Live2D接收的消息
  void _handleLive2dMessage(String message) {
    try {
      final data = jsonDecode(message);
      debugPrint('收到Live2D消息: $data');

      if (data['action'] == 'modelLoaded') {
        setState(() {
          _modelLoaded = data['success'] ?? false;
        });
        if (!_modelLoaded) {
           _showErrorSnackbar("Live2D模型加载失败: ${data['error'] ?? '未知错误'}");
        }
      }
      // 可以根据需要处理来自WebView的其他消息
    } catch (e) {
      debugPrint('处理Live2D消息错误: $e');
       _showErrorSnackbar("处理Live2D消息时出错");
    }
  }

  // 发送文本消息
  void _handleSubmit() async {
    if (_textController.text.isEmpty || _isProcessing) return;
    final message = _textController.text;

    _addMessage(message, true); // 添加用户消息
    _textController.clear();
    await _processAndRespond(message); // 处理并获取AI回复
  }

  // 处理消息并获取AI回复
  Future<void> _processAndRespond(String userMessage) async {
    setState(() {
      _isProcessing = true; // 开始处理
      _addMessage('正在思考...', false); // 显示AI思考状态
    });

    try {
      // 调用API获取回复
      final response = await _apiService.sendMessage(userMessage);

      // 移除"正在思考"并添加实际回复
      setState(() {
        _messages.removeLast();
        _addMessage(response, false);
      });

      // 语音朗读回复
      await _voiceService.speak(response);

      // Live2D说话动画
      if (_modelLoaded && _live2dKey.currentState != null) {
        _live2dKey.currentState?.sendMessageToLive2d('speak', response);
      }
    } catch (e) {
      debugPrint('API或语音处理错误: $e');
      // 移除"正在思考"并添加错误消息
      setState(() {
         if (_messages.isNotEmpty && !_messages.last.isUser && _messages.last.text == '正在思考...') {
           _messages.removeLast();
         }
        _addMessage('抱歉，处理时遇到问题: $e', false);
      });
       _showErrorSnackbar("处理消息时出错: $e");
    } finally {
      setState(() {
        _isProcessing = false; // 结束处理
      });
    }
  }


  // 开始语音识别
  void _startListening() async {
     if (!await _voiceService.initialize()) {
       _showErrorSnackbar("语音服务未初始化。");
       return;
     }

    setState(() {
      _isListening = true;
      _textController.text = "正在录音..."; // 提示用户
    });

    await _voiceService.listen(
      // Azure REST API 的 listen 不会实时返回结果
      onResult: (text) {
        // 这个回调在Azure REST API的简单实现中不会被调用
        // 结果在 stopListening 中处理
      },
      onDone: () {
        // 这个回调在Azure REST API的简单实现中可能不会被调用，或者在录音硬件停止时调用
        // 主要逻辑移到 stopListening
         if (_isListening) { // 避免在手动停止后再次触发
           _stopListening();
         }
      },
      onError: (error) {
        debugPrint("STT 录音错误: $error");
        _showErrorSnackbar("录音错误: $error");
        setState(() {
          _isListening = false;
          _textController.clear(); // 清除提示
        });
      },
    );
  }

  // 停止语音识别并处理结果
  void _stopListening() async {
    if (!_isListening) return; // 防止重复调用

    setState(() {
      _isListening = false;
      _textController.text = "正在识别..."; // 提示用户正在处理
    });

    await _voiceService.stopListening(
      onResult: (text) {
        debugPrint("STT 识别结果: $text");
        setState(() {
          _textController.text = text; // 将识别结果放入输入框
        });
        // 识别成功后自动提交
        if (text.isNotEmpty) {
          _handleSubmit();
        } else {
           _textController.clear(); // 如果没有识别到内容，则清空
           _showErrorSnackbar("未能识别到语音内容");
        }
      },
      onDone: () {
        debugPrint("STT 处理完成");
        // 可以在这里添加一些完成后的逻辑，但主要结果在onResult处理
        if (_textController.text == "正在识别...") {
           _textController.clear(); // 如果没有结果，清除提示
        }
      },
      onError: (error) {
        debugPrint("STT 识别或API错误: $error");
        _showErrorSnackbar("语音识别失败: $error");
        setState(() {
          _textController.clear(); // 清除提示
        });
      },
    );
  }

  // 辅助函数：添加消息到列表
  void _addMessage(String text, bool isUser) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: isUser));
    });
    // 可以添加滚动到底部的逻辑
  }

  // 辅助函数：显示底部错误提示
  void _showErrorSnackbar(String message) {
    if (mounted) { // 检查widget是否还在树中
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ChatMessage Widget保持不变
class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start, // 垂直对齐方式
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                child: const Text('AI'),
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black,
              ),
            ),
          Flexible( // 使用Flexible防止文本过长导致溢出
            child: Container(
              margin: EdgeInsets.only(
                left: isUser ? 40.0 : 0, // 给用户消息留出左边距
                right: isUser ? 0 : 40.0, // 给AI消息留出右边距
              ),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: isUser
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[200], // AI消息用浅灰色
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87, // AI文本用深灰色
                ),
              ),
            ),
          ),
          if (isUser)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: CircleAvatar(
                child: const Text('我'),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
        ],
      ),
    );
  }
}