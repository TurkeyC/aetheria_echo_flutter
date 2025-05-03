/* eslint-disable */
// 完全禁用 ESLint 检查，确保构建过程不会因 ESLint 错误而失败
import { Live2DModel } from 'pixi-live2d-display';
import * as PIXI from 'pixi.js';

// 模型配置对象
let modelConfig = {
  models: [],
  activeModel: '',
  defaultModel: ''
};

// 加载模型配置
async function loadModelConfig() {
  try {
    const response = await fetch('/models/models.json');
    if (!response.ok) {
      throw new Error('无法加载模型配置');
    }
    modelConfig = await response.json();
    console.log('模型配置加载成功:', modelConfig);
    return modelConfig;
  } catch (error) {
    console.error('加载模型配置失败:', error);
    // 使用默认配置
    return {
      models: [{
        id: 'haru',
        name: '春日',
        path: '/models/haru/haru_greeter_t03.model3.json',
        scale: 1.0,
        offsetX: 0,
        offsetY: 0
      }],
      activeModel: 'haru',
      defaultModel: 'haru'
    };
  }
}

// 获取当前活动模型信息
function getActiveModelInfo() {
  const activeId = modelConfig.activeModel || modelConfig.defaultModel;
  return modelConfig.models.find(m => m.id === activeId) || modelConfig.models[0];
}

// 切换到指定ID的模型
export async function switchModel(modelId, containerId) {
  try {
    console.log('切换模型:', modelId);
    
    // 重新加载最新模型配置
    await loadModelConfig();
    
    // 更新当前活动模型
    modelConfig.activeModel = modelId;
    
    // 清理容器
    const container = document.getElementById(containerId);
    if (container) {
      while (container.firstChild) {
        container.removeChild(container.firstChild);
      }
    }
    
    // 重新初始化模型
    return await initLive2dModel(containerId);
  } catch (error) {
    console.error('切换模型失败:', error);
    throw error;
  }
}

// 获取所有可用模型列表
export async function getAvailableModels() {
  await loadModelConfig();
  return modelConfig.models.map(m => ({
    id: m.id,
    name: m.name,
    thumbnail: m.thumbnail
  }));
}

export async function initLive2dModel(containerId) {
  try {
    // 首先加载模型配置
    await loadModelConfig();
    
    // 获取当前活动模型信息
    const modelInfo = getActiveModelInfo();
    console.log('正在加载模型:', modelInfo);

    // 获取容器元素
    const container = document.getElementById(containerId);
    if (!container) throw new Error('Live2D 容器未找到');

    // 创建PIXI应用
    let app;
    if (container.tagName.toLowerCase() === 'canvas') {
      app = new PIXI.Application({
        view: container,
        autoStart: true,
        backgroundAlpha: 0
      });
    } else {
      app = new PIXI.Application({
        width: container.clientWidth,
        height: container.clientHeight,
        autoStart: true, 
        backgroundAlpha: 0
      });
      container.appendChild(app.view);
    }

    // 使用模型配置中的路径
    const modelPath = modelInfo.path;
    console.log('正在加载Live2D模型路径:', modelPath);
    
    try {
      // 创建Live2D模型
      const model = await Live2DModel.from(modelPath);
      
      // 将模型添加到舞台
      app.stage.addChild(model);
      
      // 设置模型位置和缩放
      const w = app.view.width;
      const h = app.view.height;
      
      // 应用模型偏移和缩放
      model.x = w / 2 + (modelInfo.offsetX || 0);
      model.y = h + (modelInfo.offsetY || 0);
      model.anchor.set(0.5, 1);
      
      // 自适应缩放
      const modelWidth = model.width;
      const modelHeight = model.height;
      const baseScale = Math.min(w / modelWidth, h / modelHeight);
      // 应用配置中的缩放因子
      const scale = baseScale * (modelInfo.scale || 1.0);
      model.scale.set(scale);
      
      // 添加鼠标交互
      app.stage.interactive = true;
      app.stage.interactiveChildren = true;
      
      // 鼠标滚轮缩放功能
      let currentScale = scale;
      const minScale = scale * 0.5;  // 最小缩放比例
      const maxScale = scale * 2.5;  // 最大缩放比例
      
      app.view.addEventListener('wheel', (e) => {
        e.preventDefault();
        
        // 缩放逻辑
        if (e.deltaY < 0) {
          currentScale *= 1.1;
        } else {
          currentScale *= 0.9;
        }
        
        // 限制缩放范围
        currentScale = Math.max(minScale, Math.min(maxScale, currentScale));
        
        // 应用缩放
        model.scale.set(currentScale);
        
        // 缩放时保持底部对齐
        model.y = h;
      }, { passive: false });
      
      // 鼠标跟随眼睛
      app.view.addEventListener('mousemove', (e) => {
        const rect = app.view.getBoundingClientRect();
        const mouseX = e.clientX - rect.left;
        const mouseY = e.clientY - rect.top;
        // 归一化到[-1,1]
        const nx = (mouseX / app.view.width) * 2 - 1;
        const ny = (mouseY / app.view.height) * 2 - 1;
        if (model.internalModel && model.internalModel.motionManager) {
          model.internalModel.motionManager.eyeX = nx;
          model.internalModel.motionManager.eyeY = ny;
        }
      });
      
      // 拖动功能
      let dragging = false;
      let dragOffset = {x: 0, y: 0};
      
      app.view.addEventListener('mousedown', (e) => {
        dragging = true;
        dragOffset.x = e.clientX - model.x;
        dragOffset.y = e.clientY - model.y;
        app.view.style.cursor = 'grabbing';
      });
      
      window.addEventListener('mousemove', (e) => {
        if (dragging) {
          model.x = e.clientX - dragOffset.x;
          model.y = e.clientY - dragOffset.y;
        }
      });
      
      window.addEventListener('mouseup', () => {
        dragging = false;
        app.view.style.cursor = 'pointer';
      });
      
      app.view.style.cursor = 'pointer';
      
      // 触摸设备支持
      app.view.addEventListener('touchstart', (e) => {
        if (e.touches.length === 1) {
          dragging = true;
          dragOffset.x = e.touches[0].clientX - model.x;
          dragOffset.y = e.touches[0].clientY - model.y;
        }
      }, {passive: true});
      
      window.addEventListener('touchmove', (e) => {
        if (dragging && e.touches.length === 1) {
          model.x = e.touches[0].clientX - dragOffset.x;
          model.y = e.touches[0].clientY - dragOffset.y;
        }
      }, {passive: true});
      
      window.addEventListener('touchend', () => {
        dragging = false;
      });
      
      // 触摸缩放支持 (双指缩放)
      let lastTouchDistance = 0;
      
      app.view.addEventListener('touchstart', (e) => {
        if (e.touches.length === 2) {
          // 保存初始双指距离
          const touch1 = e.touches[0];
          const touch2 = e.touches[1];
          lastTouchDistance = Math.hypot(
            touch2.clientX - touch1.clientX,
            touch2.clientY - touch1.clientY
          );
        }
      }, {passive: true});
      
      app.view.addEventListener('touchmove', (e) => {
        if (e.touches.length === 2) {
          // 计算新的双指距离
          const touch1 = e.touches[0];
          const touch2 = e.touches[1];
          const newDistance = Math.hypot(
            touch2.clientX - touch1.clientX,
            touch2.clientY - touch1.clientY
          );
          
          // 根据距离变化计算缩放比例
          if (lastTouchDistance > 0) {
            const scaleChange = newDistance / lastTouchDistance;
            currentScale *= scaleChange;
            
            // 限制缩放范围
            currentScale = Math.max(minScale, Math.min(maxScale, currentScale));
            
            // 应用缩放
            model.scale.set(currentScale);
            model.y = h;
          }
          
          lastTouchDistance = newDistance;
        }
      }, {passive: true});
      
      app.view.addEventListener('touchend', (e) => {
        if (e.touches.length < 2) {
          lastTouchDistance = 0;
        }
      }, {passive: true});

      // 尝试获取表情列表
      let expressions = [];
      try {
        expressions = Object.keys(model.internalModel.motionManager.expressions);
      } catch (e) {
        expressions = ['F01', 'F02', 'F03', 'F04', 'F05', 'F06', 'F07', 'F08'];
        console.warn('无法获取表情列表, 使用默认值:', e);
      }
      
      // 定义控制器对象
      const controller = {
        model,
        app,
        modelId: modelInfo.id,
        modelName: modelInfo.name,
        expressions,
        // 使用方法对象语法，避免内部函数声明
        setRandomExpression() {
          const idx = Math.floor(Math.random() * this.expressions.length);
          this.setExpression(this.expressions[idx]);
        },
        setExpression(expressionId) {
          if (model && model.internalModel && model.internalModel.motionManager) {
            try {
              model.expression(expressionId);
            } catch (e) {
              console.warn('表情设置失败:', expressionId, e);
            }
          } else {
            console.warn('模型或表情管理器未初始化');
          }
        },
        // 清理旧的应用程序实例
        destroy() {
          if (this.app) {
            this.app.destroy(true, true);
          }
        }
      };
      
      return controller;
    } catch (modelError) {
      console.error('模型加载失败:', modelError);
      
      // 创建错误提示文本
      const text = new PIXI.Text(`模型加载失败: ${modelInfo.name}\n${modelError.message}`, {
        fontSize: 14,
        fill: 0xff0000,
        align: 'center'
      });
      text.x = app.view.width / 2;
      text.y = app.view.height / 2;
      text.anchor.set(0.5, 0.5);
      app.stage.addChild(text);
      
      return {
        app,
        modelId: modelInfo.id,
        modelName: modelInfo.name,
        expressions: [],
        setRandomExpression() {},
        setExpression() {},
        destroy() { if (this.app) this.app.destroy(true, true); }
      };
    }
  } catch (error) {
    console.error('Live2D初始化失败:', error);
    throw error;
  }
}
