<template>
  <div class="container">
    <div class="live2d-container" id="live2d-container"></div>
    
    <!-- 模型选择器 -->
    <div class="model-selector" v-if="availableModels.length > 1">
      <button 
        v-for="model in availableModels" 
        :key="model.id" 
        :class="['model-button', { active: currentModelId === model.id }]"
        @click="changeModel(model.id)"
        :title="model.name"
      >
        <img v-if="model.thumbnail" :src="model.thumbnail" :alt="model.name">
        <span v-else>{{ model.name }}</span>
      </button>
    </div>
    
    <div class="controls">
      <button @click="startListening" :disabled="isListening" class="primary-button">
        <span v-if="isListening" class="loading-dots">正在聆听<span class="dot" v-for="n in 3" :key="n">.</span></span>
        <span v-else>开始对话</span>
      </button>
      <div class="message-box">
        <transition-group name="msg-fade" tag="div">
          <p v-for="(msg, idx) in messageHistory" :key="idx" :class="msg.role">{{ msg.text }}</p>
        </transition-group>
      </div>
      <div v-if="errorMessage" class="error-message">
        <span>{{ errorMessage }}</span>
        <button @click="dismissError" class="dismiss-button">关闭</button>
      </div>
      <div v-if="isListening" class="mic-visual">
        <div class="mic-icon">
          <svg width="32" height="32" viewBox="0 0 24 24"><path fill="#4a8af4" d="M12 15a3 3 0 0 0 3-3V6a3 3 0 0 0-6 0v6a3 3 0 0 0 3 3Zm5-3a1 1 0 1 1 2 0 7 7 0 0 1-6 6.92V21h3a1 1 0 1 1 0 2H8a1 1 0 1 1 0-2h3v-2.08A7 7 0 0 1 5 12a1 1 0 1 1 2 0 5 5 0 0 0 10 0Z"/></svg>
        </div>
        <div class="mic-bar" :style="{width: micLevel + '%'}"></div>
      </div>
    </div>
  </div>
</template>

<script>
import { initLive2dModel, getAvailableModels, switchModel } from './live2d';
import { recognizeSpeech, synthesizeSpeech } from './azure-speech';
import { getChatResponse } from './api';

export default {
  data() {
    return {
      isListening: false,
      messageHistory: [
        { role: 'ai', text: '你好！我是你的AI助手，点击开始对话与我交流。' }
      ],
      live2dModel: null,
      errorMessage: null,
      micLevel: 0,
      lastUserText: '',
      availableModels: [],
      currentModelId: ''
    }
  },
  mounted() {
    this.initializeLive2d();
    window.addEventListener('resize', this.resizeLive2d);
  },
  beforeUnmount() {
    window.removeEventListener('resize', this.resizeLive2d);
  },
  methods: {
    async initializeLive2d() {
      try {
        // 首先加载可用模型列表
        this.availableModels = await getAvailableModels();
        
        // 清理之前的模型（如果存在）
        if (this.live2dModel && typeof this.live2dModel.destroy === 'function') {
          this.live2dModel.destroy();
        }
        
        // 初始化模型
        this.live2dModel = await initLive2dModel('live2d-container');
        this.currentModelId = this.live2dModel.modelId;
        
        if (this.live2dModel) {
          setTimeout(() => {
            this.live2dModel.setRandomExpression();
          }, 1000);
        }
        
        this.resizeLive2d();
      } catch (error) {
        console.error("Live2D模型初始化失败:", error);
        this.errorMessage = "初始化Live2D模型时遇到问题。请刷新页面重试。";
      }
    },
    async changeModel(modelId) {
      if (modelId === this.currentModelId) return;
      
      try {
        // 显示加载状态
        this.errorMessage = "正在切换模型...";
        
        // 清理之前的模型
        if (this.live2dModel && typeof this.live2dModel.destroy === 'function') {
          this.live2dModel.destroy();
        }
        
        // 切换到新模型
        this.live2dModel = await switchModel(modelId, 'live2d-container');
        this.currentModelId = modelId;
        
        // 设置随机表情
        if (this.live2dModel) {
          setTimeout(() => {
            this.live2dModel.setRandomExpression();
          }, 500);
        }
        
        // 清除加载状态
        this.errorMessage = null;
        this.resizeLive2d();
      } catch (error) {
        console.error("模型切换失败:", error);
        this.errorMessage = `切换到模型 ${modelId} 失败`;
      }
    },
    resizeLive2d() {
      // 适配容器大小已经在live2d.js中处理
      const container = document.getElementById('live2d-container');
      if (container && this.live2dModel && this.live2dModel.app) {
        this.live2dModel.app.renderer.resize(container.clientWidth, container.clientHeight);
      }
    },
    dismissError() {
      this.errorMessage = null;
    },
    async startListening() {
      this.isListening = true;
      this.errorMessage = null;
      this.micLevel = 0;
      try {
        if (this.live2dModel) this.live2dModel.setExpression('F07'); // 期待表情
        const userText = await recognizeSpeech((level) => { this.micLevel = level; });
        this.lastUserText = userText;
        this.messageHistory.push({ role: 'user', text: userText });
        if (this.live2dModel) this.live2dModel.setExpression('F08'); // 思考表情
        const response = await getChatResponse(userText);
        this.messageHistory.push({ role: 'ai', text: response });
        if (this.live2dModel) {
          // 根据关键词调整表情
          if (/谢谢|感谢/.test(response)) this.live2dModel.setExpression('F01');
          else if (/再见|拜拜/.test(response)) this.live2dModel.setExpression('F05');
          else this.live2dModel.setRandomExpression();
        }
        await synthesizeSpeech(response);
      } catch (error) {
        if (error.isRecognitionError) {
          this.errorMessage = error.message;
          if (this.live2dModel) this.live2dModel.setExpression('F06');
        } else {
          this.errorMessage = '抱歉，遇到了一些问题，请重试。';
        }
      } finally {
        this.isListening = false;
        this.micLevel = 0;
      }
    }
  }
}
</script>

<style scoped>
.container {
  display: flex;
  flex-direction: column;
  align-items: center;
  min-height: 100vh;
  padding: 2vw;
  box-sizing: border-box;
  background: linear-gradient(135deg, #e3f0ff 0%, #f9f9f9 100%);
}
.live2d-container {
  width: 100vw;
  height: 60vh;
  min-height: 320px;
  max-height: 80vh;
  position: relative;
  margin-bottom: 2vw;
  background: transparent;
  border: none !important;
  border-radius: 0 !important;
  box-shadow: none !important;
  outline: none !important;
  overflow: visible;
  z-index: 2;
  display: flex;
  justify-content: center;
  align-items: center;
}
.model-selector {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  margin-bottom: 15px;
  gap: 10px;
}
.model-button {
  width: 50px;
  height: 50px;
  border-radius: 50%;
  padding: 0;
  overflow: hidden;
  cursor: pointer;
  border: 2px solid #ddd;
  transition: all 0.3s ease;
  background: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
}
.model-button img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.model-button.active {
  border-color: #4a8af4;
  box-shadow: 0 0 0 2px rgba(74, 138, 244, 0.5);
}
.model-button:hover {
  transform: scale(1.1);
}
.controls {
  width: 100%;
  max-width: 500px;
  display: flex;
  flex-direction: column;
  align-items: center;
}
.primary-button {
  padding: 12px 28px;
  background: linear-gradient(90deg, #4a8af4 0%, #8fd3f4 100%);
  color: white;
  border: none;
  border-radius: 24px;
  cursor: pointer;
  margin-bottom: 18px;
  font-size: 18px;
  font-weight: bold;
  box-shadow: 0 2px 8px #b3c6e0;
  transition: background 0.3s, box-shadow 0.3s;
}
.primary-button:hover {
  background: linear-gradient(90deg, #3a7ae4 0%, #6fc3f4 100%);
  box-shadow: 0 4px 16px #8fa8d6;
}
.primary-button:disabled {
  background: #a0b8e0;
  cursor: not-allowed;
}
.message-box {
  width: 100%;
  min-height: 120px;
  border-radius: 8px;
  padding: 12px;
  background: #f9f9f9;
  margin-bottom: 18px;
  box-shadow: 0 1px 4px #e0e6f0;
  font-size: 16px;
  overflow-x: auto;
}
.message-box .user {
  color: #4a8af4;
  text-align: right;
  margin: 4px 0;
}
.message-box .ai {
  color: #222;
  text-align: left;
  margin: 4px 0;
}
.msg-fade-enter-active, .msg-fade-leave-active {
  transition: all 0.3s;
}
.msg-fade-enter-from, .msg-fade-leave-to {
  opacity: 0;
  transform: translateY(10px);
}
.error-message {
  width: 100%;
  padding: 10px;
  background-color: #fee;
  border: 1px solid #faa;
  border-radius: 4px;
  color: #c33;
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.dismiss-button {
  background-color: transparent;
  color: #c33;
  border: 1px solid #c33;
  padding: 2px 8px;
  border-radius: 3px;
  cursor: pointer;
  font-size: 12px;
}
.dismiss-button:hover {
  background-color: #fee;
}
.loading-dots { display: inline-block; }
.loading-dots .dot { animation: blink 1s infinite; opacity: 0.5; }
.loading-dots .dot:nth-child(1) { animation-delay: 0s; }
.loading-dots .dot:nth-child(2) { animation-delay: 0.2s; }
.loading-dots .dot:nth-child(3) { animation-delay: 0.4s; }
@keyframes blink { 0%, 100% { opacity: 0.5; } 50% { opacity: 1; } }
.mic-visual { display: flex; align-items: center; margin-top: 10px; }
.mic-icon { margin-right: 8px; }
.mic-bar { height: 8px; background: linear-gradient(90deg, #4a8af4, #8fd3f4); border-radius: 4px; transition: width 0.2s; min-width: 10px; max-width: 120px; }
@media (max-width: 900px) {
  .live2d-container {
    height: 48vh;
    min-height: 180px;
  }
}
@media (max-width: 600px) {
  .container { padding: 1vw; }
  .live2d-container {
    height: 38vh;
    min-height: 120px;
  }
  .controls { max-width: 98vw; }
  .message-box { font-size: 15px; }
  .primary-button { font-size: 16px; padding: 10px 16px; }
  .model-button { width: 40px; height: 40px; }
}
</style>

<style>
body {
  overflow-x: hidden;
  margin: 0;
  padding: 0;
  background: #f5f7fa;
}
</style>
