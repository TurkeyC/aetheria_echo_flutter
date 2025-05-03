import os
import base64
import tempfile
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import httpx
import azure.cognitiveservices.speech as speechsdk
from pydantic import BaseModel

# 加载环境变量
AZURE_SPEECH_KEY = os.getenv("AZURE_SPEECH_KEY", "")
# 标准化默认区域为 eastus，与文档和 .env.example 保持一致
AZURE_SPEECH_REGION = os.getenv("AZURE_SPEECH_REGION", "eastus") 
API_KEY = os.getenv("DEEPSEEK_API_KEY", "")
OPENAI_API_BASE = os.getenv("OPENAI_API_BASE", "https://api.deepseek.com")

# 检查必要的环境变量
if not AZURE_SPEECH_KEY:
    print("警告: AZURE_SPEECH_KEY 未设置，语音功能将不可用")
if not API_KEY:
    print("警告: DEEPSEEK_API_KEY 未设置，聊天功能将不可用")

app = FastAPI(title="Aetheria Echo API", 
              description="Live2D虚拟助手后端API",
              version="1.0.0")

# 配置CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 创建临时文件夹用于存储音频文件
os.makedirs("./temp", exist_ok=True)

# 模型定义
class ChatRequest(BaseModel):
    message: str

class SpeechRequest(BaseModel):
    text: str

@app.get("/api/health")
async def health_check():
    """健康检查接口"""
    return {"status": "ok", "message": "服务运行正常"}

@app.post("/api/chat")
async def chat(request: ChatRequest):
    """处理用户消息并返回AI回复 (使用通用 OpenAI 格式 API)"""
    try:
        # 构建 OpenAI 兼容的 API 端点
        api_endpoint = f"{OPENAI_API_BASE.rstrip('/')}/v1/chat/completions"
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                api_endpoint, # 使用环境变量中的基础 URL
                json={
                    "model": "deepseek-chat", # 或替换为你的模型名称
                    "messages": [{"role": "user", "content": request.message}],
                    "temperature": 0.7,
                    "max_tokens": 150
                },
                headers={
                    "Authorization": f"Bearer {API_KEY}" # 使用 API Key
                },
                timeout=20.0 # 增加超时时间以防网络延迟
            )
            
            response.raise_for_status() # 检查 HTTP 错误
            
            data = response.json()
            # 确保从正确的路径获取回复内容
            if data.get("choices") and len(data["choices"]) > 0 and data["choices"][0].get("message"):
                content = data["choices"][0]["message"].get("content", "")
                return JSONResponse(content={"response": content})
            else:
                 return JSONResponse(
                    status_code=500,
                    content={"error": "未能从 API 响应中提取有效回复", "details": data}
                )

    except httpx.HTTPStatusError as e:
         return JSONResponse(
            status_code=e.response.status_code,
            content={"error": f"API 请求失败: {e.response.status_code}", "details": str(e)}
        )
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"error": "处理聊天请求时发生内部错误", "details": str(e)}
        )


@app.post("/api/speech/recognize")
async def recognize_speech():
    """使用Azure语音识别服务"""
    try:
        speech_config = speechsdk.SpeechConfig(
            subscription=AZURE_SPEECH_KEY,
            region=AZURE_SPEECH_REGION
        )
        speech_config.speech_recognition_language = "zh-CN"
        
        # 对于Web应用，我们不能直接使用麦克风
        # 这里返回一个提示，前端将使用浏览器API来处理实际的语音输入
        return JSONResponse(content={
            "message": "请在前端使用浏览器的语音API", 
            "text": "这是示例文本，实际使用时请在前端实现语音识别。"
        })
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"error": str(e)}
        )


@app.post("/api/speech/synthesize")
async def synthesize_speech(request: SpeechRequest):
    """使用Azure语音合成服务"""
    try:
        speech_config = speechsdk.SpeechConfig(
            subscription=AZURE_SPEECH_KEY,
            region=AZURE_SPEECH_REGION
        )
        speech_config.speech_synthesis_voice_name = "zh-CN-XiaoxiaoNeural"
        
        # 创建一个临时文件来存储合成的语音
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".wav", dir="./temp")
        temp_file_path = temp_file.name
        temp_file.close()
        
        # 配置音频输出
        audio_config = speechsdk.audio.AudioOutputConfig(filename=temp_file_path)
        
        # 创建语音合成器
        speech_synthesizer = speechsdk.SpeechSynthesizer(
            speech_config=speech_config, 
            audio_config=audio_config
        )
        
        # 合成语音
        result = speech_synthesizer.speak_text_async(request.text).get()
        
        if result.reason == speechsdk.ResultReason.SynthesizingAudioCompleted:
            # 读取音频文件并转换为base64
            with open(temp_file_path, "rb") as audio_file:
                audio_data = base64.b64encode(audio_file.read()).decode("utf-8")
            
            # 清理临时文件
            os.unlink(temp_file_path)
            
            return JSONResponse(content={
                "success": True, 
                "audio_data": f"data:audio/wav;base64,{audio_data}"
            })
        else:
            if os.path.exists(temp_file_path):
                os.unlink(temp_file_path)
            return JSONResponse(
                status_code=400, 
                content={"error": "语音合成失败", "details": result.reason}
            )
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"error": str(e)}
        )

# 注意：将静态文件挂载放在最后，确保API路由优先被处理
# 自动创建静态文件目录，防止缺失导致启动失败
os.makedirs("./static", exist_ok=True)
app.mount("/", StaticFiles(directory="./static", html=True), name="static")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=80)
