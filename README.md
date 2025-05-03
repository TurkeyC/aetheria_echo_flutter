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

```
lib/
├── assets/
│   ├── html/           # Live2D WebView相关文件
│   │   └── live2d/     # Live2D模型和框架文件
│   └── live2d/         # 模型资源目录
├── services/
│   ├── api_service.dart    # AI对话API服务
│   └── voice_service.dart  # 语音服务
├── widgets/
│   └── live2d_webview.dart # Live2D WebView组件
└── main.dart               # 应用入口
```

## 技术架构

- **前端框架**: Flutter
- **Live2D渲染**: WebView + Javascript
- **语音服务**: flutter_tts + speech_to_text
- **AI通信**: HTTP API接口
- **状态管理**: Provider

## 后端服务

本应用需要配合后端大模型API使用，后端应该提供以下功能:

- HTTP接口：`/api/chat`
- 输入格式：`{"message": "用户消息"}`
- 输出格式：`{"response": "AI回复"}`

## 常见问题

- **模型无法加载**: 检查模型路径配置和文件完整性
- **API连接失败**: 确认API服务地址和端口配置正确
- **语音识别不工作**: 检查应用权限和麦克风设置
