# 多阶段构建以减小镜像大小
# 第一阶段：前端构建
FROM node:18-alpine AS frontend-builder
WORKDIR /app/frontend

# 使用正确的相对路径
COPY ./frontend/package*.json ./
RUN npm install
COPY ./frontend/ ./

# 注意：不再从网络下载Live2D库，因为我们已经将文件保存在本地
# 我们只需确保目录存在即可
RUN mkdir -p public/lib public/models

# 显示库文件和模型文件的存在
RUN ls -la public/lib/
RUN ls -la public/models/

# 构建前端应用
RUN npm run build -- --skip-plugin=eslint || npm run build

# 显示构建产物
RUN ls -la dist

# 第二阶段：后端构建
FROM python:3.9-slim AS backend-builder
WORKDIR /app
# 使用正确的相对路径
COPY ./backend/requirements.txt .
# 安装包，包括uvicorn可执行文件
RUN pip install --no-cache-dir -r requirements.txt

# 最终阶段
FROM python:3.9-slim
WORKDIR /app

# 安装curl用于健康检查
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 从backend-builder复制整个Python安装环境（包括库和可执行文件）
COPY --from=backend-builder /usr/local/ /usr/local/

# 确保创建静态目录
RUN mkdir -p /app/static

# 明确复制构建好的前端静态文件
COPY --from=frontend-builder /app/frontend/dist/. /app/static/

# 确保模型和库文件被复制
COPY --from=frontend-builder /app/frontend/public/models /app/static/models
COPY --from=frontend-builder /app/frontend/public/lib /app/static/lib

# 复制后端应用代码
COPY ./backend/ /app

# 验证静态目录内容
RUN ls -la /app/static || echo "Static directory contents check"

EXPOSE 80

# 使用端口80与app.py中的设置保持一致
CMD ["python", "app.py"]
