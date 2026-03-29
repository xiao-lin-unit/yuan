/**
 * Electron主进程
 * 负责创建和管理应用窗口，处理与渲染进程的通信
 */
import { app, BrowserWindow, ipcMain } from 'electron'
import path from 'path'
import { fileURLToPath } from 'url'

// 获取当前文件路径
const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

// 主窗口实例
let mainWindow

/**
 * 创建应用窗口
 */
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,  // 窗口宽度
    height: 800,  // 窗口高度
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),  // 预加载脚本
      nodeIntegration: true,  // 启用Node.js集成
      contextIsolation: false  // 禁用上下文隔离
    }
  })

  // 根据环境加载不同的URL
  if (process.env.NODE_ENV === 'development') {
    // 开发环境加载本地开发服务器
    mainWindow.loadURL('http://localhost:5173')
    // 打开开发者工具
    mainWindow.webContents.openDevTools()
  } else {
    // 生产环境加载打包后的HTML文件
    mainWindow.loadFile(path.join(__dirname, '../dist/index.html'))
  }

  // 窗口关闭时的处理
  mainWindow.on('closed', function () {
    mainWindow = null
  })
}

// 应用就绪时创建窗口
app.whenReady().then(() => {
  createWindow()

  // 应用激活时的处理（macOS）
  app.on('activate', function () {
    if (mainWindow === null) createWindow()
  })
})

// 所有窗口关闭时的处理
app.on('window-all-closed', function () {
  // 在macOS上，应用和菜单栏会保持活跃
  if (process.platform !== 'darwin') app.quit()
})

/**
 * 处理IPC通信
 * 示例：处理渲染进程发送的ping消息
 */
ipcMain.on('ping', (event, arg) => {
  event.reply('pong', 'Hello from Electron')
})
