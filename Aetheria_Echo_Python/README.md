# Aetheria Echo 虚拟助手

## 快速部署（适配1核1G服务器）

1. 安装 Docker & Docker Compose
2. 复制 `.env.example` 为 `.env` 并填写密钥
3. 构建并启动服务：
   ```bash
   docker compose up --build -d
   ```
4. 访问前端：http://服务器IP:14514

## 性能优化建议
- 已为前后端容器设置 CPU/内存限制，适配低配服务器
- 前端已优化构建，后端采用 FastAPI + Uvicorn，轻量高效

## 健康检查
- 后端健康检查脚本：`python backend/health_check.py`

## 用户体验优化
- 语音识别时有动态加载动画和麦克风音量可视化
- Live2D 交互流畅，支持多表情

## 开发建议
- 本地开发前端：`cd frontend && npm install && npm run serve`
- 本地开发后端：`cd backend && uvicorn app:app --reload --host 0.0.0.0 --port 14515`
- 前端已配置 API 代理，无需手动切换

## 目录结构说明
- frontend/  前端 Vue3 + Live2D
- backend/   FastAPI 后端
- live2d/    资源模型

## 常见问题
- 端口占用/内存不足：请检查服务器资源，或调整 compose 资源限制
- 语音识别异常：请确保 HTTPS 或 localhost 访问，浏览器需授权麦克风
