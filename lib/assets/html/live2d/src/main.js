// lib/assets/html/live2d/src/main.js

// 全局变量
let canvas = null;
let gl = null;
let frameId = null;

// 初始化渲染环境
function initializeGlCanvas() {
  canvas = document.createElement('canvas');
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;
  document.getElementById('live2d-container').appendChild(canvas);

  // 获取WebGL上下文
  gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');
  if (!gl) {
    throw new Error('WebGL初始化失败');
  }

  // 设置WebGL
  gl.enable(gl.BLEND);
  gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
  gl.clearColor(0.0, 0.0, 0.0, 0.0);

  // 窗口大小调整处理
  window.addEventListener('resize', onResize);
}

// 处理窗口大小变化
function onResize() {
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;
  gl.viewport(0, 0, canvas.width, canvas.height);

  if (live2DModel) {
    const viewWidth = canvas.width;
    const viewHeight = canvas.height;
    adjustModelMatrix(viewWidth, viewHeight);
  }
}

// 渲染循环
function startRenderLoop() {
  const loop = () => {
    // 清除画布
    gl.clear(gl.COLOR_BUFFER_BIT);

    if (live2DModel) {
      // 更新模型
      live2DModel.update();
      // 绘制模型
      live2DModel.draw();
    }

    // 继续循环
    frameId = requestAnimationFrame(loop);
  };

  loop();
}

// 停止渲染循环
function stopRenderLoop() {
  if (frameId) {
    cancelAnimationFrame(frameId);
    frameId = null;
  }
}

// 调整模型矩阵以适应视图
function adjustModelMatrix(viewWidth, viewHeight) {
  // 根据模型大小和画布比例调整
  const modelMatrix = live2DModel.getModelMatrix();
  modelMatrix.scale(1.0, viewWidth / viewHeight);
  // 可以根据需要添加更多调整
}