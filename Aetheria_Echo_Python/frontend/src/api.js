// 实现与DeepSeek API的交互

export async function getChatResponse(message) {
  try {
    const response = await fetch('/api/chat', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ message })
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const data = await response.json();
    return data.response || '抱歉，我无法理解您的问题。';
  } catch (error) {
    console.error('获取AI响应出错:', error);
    throw error;
  }
}
