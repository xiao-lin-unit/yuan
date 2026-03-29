import { createApp } from 'vue'
import { createPinia } from 'pinia'
import ElementPlus from 'element-plus'
import 'element-plus/dist/index.css'
import App from './App.vue'

// 初始化Capacitor
import { Capacitor } from '@capacitor/core'
if (Capacitor.isNativePlatform()) {
  console.log('Running on native platform')
}

const app = createApp(App)
app.use(createPinia())
app.use(ElementPlus)
app.mount('#app')