const { defineConfig } = require('@vue/cli-service')
const fs = require('fs')
const path = require('path')

module.exports = defineConfig({
  transpileDependencies: true,
  devServer: {
    // 配置开发服务器
    port: 8080, // 前端开发服务器端口
    // 为开发服务器启用HTTPS（可选但推荐，解决麦克风权限问题）
    https: false, // 设置为true会使用自签名证书，您也可以提供自己的证书
    
    // 代理API请求到后端服务器
    proxy: {
      '/api': {
        target: 'http://localhost:14515', // 本地开发时代理到本机后端
        changeOrigin: true
      }
    }
  },
  
  // 配置构建输出
  outputDir: 'dist',
  
  // PWA选项（可选）
  pwa: {
    name: 'Aetheria Echo',
    themeColor: '#4a8af4'
  }
})