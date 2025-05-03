# Aetheria Echo Flutter

Aetheria Echo是一个基于Flutter开发的AI虚拟助手应用，集成了Live2D模型动画和语音交互功能。通过与AI大模型的对话，为用户提供沉浸式的交互体验。

## 功能特点

- **Live2D模型交互**：集成可动态交互的虚拟形象
- **语音识别与合成**：支持语音交互，实现听说功能
- **AI大模型对话**：连接大语言模型API，进行智能对话
- **沉浸式体验**：模型表情、动作与对话内容同步

## 环境要求

- Flutter SDK ≥ 3.7.2
- Dart ≥ 3.0.0
- 后端大模型API服务

## 安装步骤

1. 克隆仓库
   ```bash
   git clone https://github.com/turkeyc/aetheria_echo_flutter.git
   cd aetheria_echo_flutter
   ```

2. 安装依赖
   ```bash
   flutter pub get
   ```

3. 运行应用
   ```bash
   flutter run
   ```

## 配置说明

### Live2D模型配置

Live2D模型路径位于 `lib/assets/html/live2d.html` 中配置:

```javascript
const modelPath = './live2d/models/模型名称';
```

相对应的物理路径为 `lib/assets/live2d/models/[模型名称]` 目录。请确保模型文件夹包含所需的全部文件。

### 大模型API配置

API服务器配置位于 `lib/services/api_service.dart` 中:

```dart
ApiService({this.baseUrl = 'http://localhost:14515'});
```

默认连接本地端口14515，可根据实际部署情况修改。API端点为 `/api/chat`。

### 语音服务配置

语音服务配置位于 `lib/services/voice_service.dart`:

- 文字转语音(TTS)：中文、语速0.5、音量1.0
- 语音识别(STT)：使用中文(zh_CN)

## 项目结构

An application for AI Live2D Chater

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
