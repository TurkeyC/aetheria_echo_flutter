// lib/widgets/live2d_webview.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

class Live2dWebView extends StatefulWidget {
  final Function(String)? onMessageReceived;
  final String initialUrl;

  const Live2dWebView({
    super.key,
    this.onMessageReceived,
    required this.initialUrl,
  });

  @override
  Live2dWebViewState createState() => Live2dWebViewState();
}

class Live2dWebViewState extends State<Live2dWebView> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView错误: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterApp',
        onMessageReceived: (JavaScriptMessage message) {
          if (widget.onMessageReceived != null) {
            widget.onMessageReceived!(message.message);
          }
        },
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: controller),
        if (isLoading)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  // 向Live2D发送消息的方法
  Future<void> sendMessageToLive2d(String action, dynamic data) async {
    final message = jsonEncode({
      'action': action,
      'data': data,
    });

    await controller.runJavaScript(
      "window.receiveMsgFromFlutter('$message')",
    );
  }
}