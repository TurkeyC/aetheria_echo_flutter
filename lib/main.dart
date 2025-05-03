import 'package:flutter/material.dart';
import 'dart:convert';
import 'widgets/live2d_webview.dart'; // 导入Live2dWebView组件
import 'services/api_service.dart';   // 如果需要使用API服务

void main() {
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

  // 添加API服务
  final ApiService _apiService = ApiService();

  // 添加Live2D控制器引用
  final GlobalKey<Live2dWebViewState> _live2dKey = GlobalKey();
  bool _modelLoaded = false;

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
                  initialUrl: 'asset:///lib/assets/html/live2d.html',  // 本地Web服务或assets路径
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
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  onPressed: _isListening ? _stopListening : _startListening,
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.red : null,
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  onPressed: _handleSubmit,
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

      // 处理模型加载完成的消息
      if (data['action'] == 'modelLoaded' && data['success'] == true) {
        setState(() {
          _modelLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('处理Live2D消息错误: $e');
    }
  }

  // 发送消息
  void _handleSubmit() async {
    if (_textController.text.isEmpty) return;
    final message = _textController.text;

    setState(() {
      _messages.add(ChatMessage(text: message, isUser: true));
    });

    _textController.clear();

    try {
      // 调用API获取回复
      final response = await _apiService.sendMessage(message);

      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false));
      });

      // 如果模型已加载，则让Live2D模型说话
      if (_modelLoaded && _live2dKey.currentState != null) {
        _live2dKey.currentState?.sendMessageToLive2d('speak', response);
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: '发生错误: $e',
          isUser: false,
        ));
      });
    }
  }

  void _startListening() {
    setState(() {
      _isListening = true;
    });
    // 这里添加语音识别逻辑
    Future.delayed(const Duration(seconds: 2), () {
      _stopListening();
    });
  }

  void _stopListening() {
    setState(() {
      _isListening = false;
      // 模拟语音输入
      _textController.text = '这是语音识别的文本';
    });
  }
}

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
        children: [
          if (!isUser)
            const CircleAvatar(child: Text('AI')),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: isUser
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300],
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black,
              ),
            ),
          ),
          if (isUser)
            const CircleAvatar(child: Text('我')),
        ],
      ),
    );
  }
}