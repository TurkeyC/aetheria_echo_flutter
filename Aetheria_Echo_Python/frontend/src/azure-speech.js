// 实现Azure语音服务的前端集成

// 将错误代码映射为用户友好的消息
const errorMessages = {
  'no-speech': '未检测到语音。请确保您的麦克风正常工作，并尝试说话音量大一些。',
  'aborted': '语音识别被中止。',
  'audio-capture': '无法访问麦克风。请确保您已授予浏览器麦克风权限。',
  'network': '网络错误导致语音识别失败。请检查您的网络连接。',
  'not-allowed': '无法访问麦克风。可能的原因：\n1. 浏览器需要通过HTTPS访问\n2. 您拒绝了麦克风权限\n3. 浏览器设置中禁用了麦克风',
  'service-not-allowed': '浏览器或当前环境不允许使用语音识别服务。',
  'bad-grammar': '语音识别语法问题。',
  'language-not-supported': '当前语言不被语音识别服务支持。',
  'no-match': '无法识别您的语音。请尝试重新说话，使用普通话并保持清晰。',
  'not-secure': '此页面未通过HTTPS加载，麦克风访问被阻止。请使用HTTPS或localhost访问。',
  'permission-denied': '麦克风访问权限被拒绝。请在浏览器设置中允许访问麦克风。',
  'default': '发生未知的语音识别错误。请稍后再试。'
};

// 检查浏览器是否在安全上下文中运行
function isSecureContext() {
  // 直接检查全局变量
  if (window.isSecureContext === true) {
    return true;
  }
  
  // 检查协议
  if (location.protocol === 'https:' || location.hostname === 'localhost' || location.hostname === '127.0.0.1') {
    return true;
  }
  
  return false;
}

// 检查所需的API是否可用
function checkApisAvailable() {
  const results = {
    webSpeechApi: false,
    mediaDevices: false,
    getUserMedia: false,
    audioContext: false
  };
  
  // 检查Web Speech API
  results.webSpeechApi = ('webkitSpeechRecognition' in window) || ('SpeechRecognition' in window);
  
  // 检查MediaDevices API
  results.mediaDevices = 'mediaDevices' in navigator;
  
  // 检查getUserMedia
  results.getUserMedia = results.mediaDevices && 'getUserMedia' in navigator.mediaDevices;
  
  // 检查AudioContext
  results.audioContext = ('AudioContext' in window) || ('webkitAudioContext' in window);
  
  return results;
}

// 请求麦克风权限并返回流，这样我们可以重用它
async function requestMicrophonePermission() {
  try {
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      throw new Error('浏览器不支持getUserMedia API');
    }
    
    console.log('请求麦克风权限...');
    const stream = await navigator.mediaDevices.getUserMedia({ 
      audio: {
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true
      } 
    });
    
    console.log('麦克风权限获取成功');
    return { success: true, stream };
  } catch (err) {
    console.error('麦克风权限请求失败:', err);
    return { success: false, error: err };
  }
}

// Web Speech API 语音识别
// 支持音量回调参数
export async function recognizeSpeech(onVolumeChange) {
  // 检查安全上下文
  if (!isSecureContext()) {
    const errorMsg = '此页面需要在HTTPS环境下或本地主机上运行才能访问麦克风。请使用HTTPS或localhost访问。';
    alert(errorMsg);
    throw {
      originalError: 'not-secure',
      message: errorMsg,
      isRecognitionError: true
    };
  }
  
  // 检查API可用性
  const apiStatus = checkApisAvailable();
  if (!apiStatus.webSpeechApi) {
    const errorMsg = '很抱歉，您的浏览器不支持语音识别功能。请尝试使用Chrome或Edge浏览器。';
    alert(errorMsg);
    throw {
      originalError: 'not-supported',
      message: errorMsg,
      isRecognitionError: true
    };
  }
  
  // 请求麦克风权限并获取流
  const micPermission = await requestMicrophonePermission();
  if (!micPermission.success) {
    const errorMsg = '无法访问麦克风。请确保您已授予浏览器麦克风权限。';
    throw {
      originalError: 'not-allowed',
      message: errorMsg,
      isRecognitionError: true
    };
  }

  // 获取麦克风流
  const micStream = micPermission.stream;
  return new Promise((resolve, reject) => {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    const recognition = new SpeechRecognition();

    // 设置识别选项
    recognition.lang = 'zh-CN';
    recognition.interimResults = false;
    recognition.maxAlternatives = 1;
    recognition.continuous = false;

    // 显示正在监听的视觉反馈
    const feedbackDiv = document.createElement('div');
    feedbackDiv.style.position = 'fixed';
    feedbackDiv.style.top = '20px';
    feedbackDiv.style.left = '50%';
    feedbackDiv.style.transform = 'translateX(-50%)';
    feedbackDiv.style.padding = '10px 20px';
    feedbackDiv.style.backgroundColor = 'rgba(0, 0, 0, 0.7)';
    feedbackDiv.style.color = 'white';
    feedbackDiv.style.borderRadius = '5px';
    feedbackDiv.style.zIndex = '9999';
    feedbackDiv.textContent = '正在聆听...请说话';
    document.body.appendChild(feedbackDiv);

    // 显示麦克风音量反馈（仅当API可用时）
    let animationFrame;
    let audioContext;
    let isAudioContextClosed = false; // 标记AudioContext是否已关闭
    
    if (apiStatus.audioContext && micStream) {
      try {
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        audioContext = new AudioContext();
        
        // 确保AudioContext处于running状态
        if (audioContext.state === 'suspended') {
          console.log('尝试恢复AudioContext...');
          audioContext.resume().then(() => {
            console.log('AudioContext已恢复');
          }).catch(err => {
            console.warn('恢复AudioContext失败:', err);
          });
        }
        
        // 使用已获取的流而不是重新请求
        const source = audioContext.createMediaStreamSource(micStream);
        const analyser = audioContext.createAnalyser();
        analyser.fftSize = 256;
        source.connect(analyser);
        
        const volumeMeter = document.createElement('div');
        volumeMeter.style.width = '100%';
        volumeMeter.style.height = '5px';
        volumeMeter.style.backgroundColor = '#333';
        volumeMeter.style.marginTop = '5px';
        volumeMeter.style.position = 'relative';
        feedbackDiv.appendChild(volumeMeter);
        
        const volumeLevel = document.createElement('div');
        volumeLevel.style.height = '100%';
        volumeLevel.style.width = '0%';
        volumeLevel.style.backgroundColor = '#4CAF50';
        volumeLevel.style.transition = 'width 0.1s';
        volumeMeter.appendChild(volumeLevel);
        
        const dataArray = new Uint8Array(analyser.frequencyBinCount);
        
        // 调试信息
        const debugInfo = document.createElement('div');
        debugInfo.style.fontSize = '10px';
        debugInfo.style.marginTop = '5px';
        feedbackDiv.appendChild(debugInfo);
        
        const updateVolume = () => {
          analyser.getByteFrequencyData(dataArray);
          let sum = 0;
          for (let i = 0; i < dataArray.length; i++) {
            sum += dataArray[i];
          }
          const average = sum / dataArray.length;
          const volume = Math.min(100, average * 2);
          volumeLevel.style.width = volume + '%';
          // 新增：回调通知App.vue实时音量
          if (typeof onVolumeChange === 'function') {
            onVolumeChange(volume);
          }
          // 显示音频数据调试信息
          debugInfo.textContent = `平均音量: ${average.toFixed(2)}, 音轨状态: ${micStream.getAudioTracks()[0].readyState}`;
          
          animationFrame = requestAnimationFrame(updateVolume);
        };
        
        animationFrame = requestAnimationFrame(updateVolume);
      } catch (e) {
        console.warn('AudioContext初始化失败:', e);
        
        // 如果音量可视化失败，添加简单的动画
        const loadingDots = document.createElement('div');
        loadingDots.style.marginTop = '10px';
        feedbackDiv.appendChild(loadingDots);
        
        let dots = '';
        const updateDots = () => {
          dots = dots.length >= 3 ? '' : dots + '.';
          loadingDots.textContent = '监听中' + dots;
          setTimeout(updateDots, 500);
        };
        updateDots();
      }
    } else {
      // 如果不支持音量可视化，添加一个简单的加载动画
      const loadingDots = document.createElement('div');
      loadingDots.style.marginTop = '10px';
      feedbackDiv.appendChild(loadingDots);
      
      let dots = '';
      const updateDots = () => {
        dots = dots.length >= 3 ? '' : dots + '.';
        loadingDots.textContent = '监听中' + dots;
        setTimeout(updateDots, 500);
      };
      updateDots();
    }

    // 识别结束时重置音量
    const safeCloseAudioContext = () => {
      if (typeof onVolumeChange === 'function') onVolumeChange(0);
      if (audioContext && !isAudioContextClosed && audioContext.state !== 'closed') {
        isAudioContextClosed = true;
        try {
          audioContext.close();
        } catch (err) {
          console.warn('关闭AudioContext失败:', err);
        }
      }
    };

    // 开始录音
    try {
      console.log('开始语音识别...');
      recognition.start();
    } catch (e) {
      document.body.removeChild(feedbackDiv);
      console.error('启动语音识别失败:', e);
      reject({
        originalError: 'start-failed',
        message: '启动语音识别失败：' + e.message,
        isRecognitionError: true
      });
      
      // 确保释放资源
      if (micStream) {
        micStream.getTracks().forEach(track => track.stop());
      }
      
      safeCloseAudioContext();
      return;
    }

    recognition.onresult = (event) => {
      console.log('收到语音识别结果:', event.results[0][0].transcript);
      const speechResult = event.results[0][0].transcript;
      if (feedbackDiv && document.body.contains(feedbackDiv)) {
        document.body.removeChild(feedbackDiv);
      }
      if (animationFrame) {
        cancelAnimationFrame(animationFrame);
      }
      
      // 关闭音频上下文
      safeCloseAudioContext();
      
      // 停止所有音轨
      if (micStream) {
        micStream.getTracks().forEach(track => track.stop());
      }
      
      resolve(speechResult);
    };

    recognition.onerror = (event) => {
      console.error('语音识别错误:', event.error);
      
      if (feedbackDiv && document.body.contains(feedbackDiv)) {
        document.body.removeChild(feedbackDiv);
      }
      if (animationFrame) {
        cancelAnimationFrame(animationFrame);
      }
      
      // 关闭音频上下文
      safeCloseAudioContext();
      
      // 停止所有音轨
      if (micStream) {
        micStream.getTracks().forEach(track => track.stop());
      }
      
      const errorMessage = errorMessages[event.error] || errorMessages['default'];
      console.warn(`语音识别错误 (${event.error}): ${errorMessage}`);
      
      reject({
        originalError: event.error,
        message: errorMessage,
        isRecognitionError: true
      });
    };

    recognition.onend = () => {
      console.log('语音识别结束');
      
      // 如果没有通过onresult或onerror处理，则这里处理超时情况
      if (feedbackDiv && document.body.contains(feedbackDiv)) {
        document.body.removeChild(feedbackDiv);
      }
      if (animationFrame) {
        cancelAnimationFrame(animationFrame);
      }
      
      // 关闭音频上下文
      safeCloseAudioContext();
      
      // 停止所有音轨
      if (micStream) {
        micStream.getTracks().forEach(track => track.stop());
      }
    };

    // 如果用户没说话或识别超时，10秒后自动停止
    setTimeout(() => {
      try {
        recognition.stop();
      } catch(e) {
        // 忽略已经停止的错误
        console.log('停止语音识别失败 (可能已经停止):', e);
      }
    }, 10000);
  });
}

export async function synthesizeSpeech(text) {
  try {
    // 调用后端API合成语音
    const response = await fetch('/api/speech/synthesize', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ text })
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const data = await response.json();
    
    if (data.success && data.audio_data) {
      // 播放返回的音频数据
      const audio = new Audio(data.audio_data);
      await audio.play();
      return true;
    } else {
      throw new Error('语音合成失败');
    }
  } catch (error) {
    console.error('语音合成出错:', error);
    throw error;
  }
}
