import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aetheria Echo 虚拟助手'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Live2D区域
          Expanded(
            flex: 3,
            child: Live2dWebView(
              initialUrl: 'asset:///assets/html/live2d.html',
              onMessageReceived: (message) {
                // 处理从Live2D接收的消息
              },
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

  void _handleSubmit() {
    if (_textController.text.isEmpty) return;

    setState(() {
      _messages.add(
        ChatMessage(
          text: _textController.text,
          isUser: true,
        ),
      );
      // 模拟回复
      _messages.add(
        ChatMessage(
          text: '这是一个模拟回复。之后你需要接入API获取真实回复。',
          isUser: false,
        ),
      );
    });

    _textController.clear();
  }

  void _startListening() {
    setState(() {
      _isListening = true;
    });
    // 之后添加语音识别逻辑
  }

  void _stopListening() {
    setState(() {
      _isListening = false;
      // 模拟语音输入
      _textController.text = '这是语音识别的文本';
    });
    // 之后添加语音识别结果处理逻辑
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