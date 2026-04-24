import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'path'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [vue()],
  base: './',
  build: {
    target: 'es2015'
  },
  resolve: {
    alias: {
      // 核心：@ 指向 src 文件夹
      '@': path.resolve(__dirname, 'src')
    }
  }
})