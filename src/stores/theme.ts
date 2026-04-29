import { defineStore } from 'pinia'
import { ref, watch } from 'vue'

// Theme preset definitions
export interface ThemePreset {
  name: string
  label: string
  primary: string
  primaryRgb: string
}

export const themePresets: Record<string, ThemePreset> = {
  blue: {
    name: 'blue',
    label: '经典蓝',
    primary: '#409EFF',
    primaryRgb: '64, 158, 255',
  },
  green: {
    name: 'green',
    label: '原谅绿',
    primary: '#67c23a',
    primaryRgb: '103, 194, 58',
  },
  purple: {
    name: 'purple',
    label: '韵味紫',
    primary: '#7c3aed',
    primaryRgb: '124, 58, 237',
  },
  orange: {
    name: 'orange',
    label: '活力橙',
    primary: '#e6a23c',
    primaryRgb: '230, 162, 60',
  },
  pink: {
    name: 'pink',
    label: '猛男粉',
    primary: '#ec88e7ff',
    primaryRgb: '245, 136, 231',
  },
  dark: {
    name: 'dark',
    label: '沉稳黑',
    primary: '#303133',
    primaryRgb: '48, 49, 51',
  },
}

const STORAGE_KEY = 'app-theme'

function applyThemeToDom(theme: ThemePreset) {
  const root = document.documentElement
  root.style.setProperty('--app-primary-color', theme.primary)
  root.style.setProperty('--app-primary-rgb', theme.primaryRgb)
}

export const useThemeStore = defineStore('theme', () => {
  // Load saved theme or default to blue
  const savedTheme = localStorage.getItem(STORAGE_KEY)
  const currentThemeName = ref<string>(savedTheme && themePresets[savedTheme] ? savedTheme : 'blue')

  const currentTheme = ref<ThemePreset>(themePresets[currentThemeName.value])

  // Apply theme on initialization
  if (typeof document !== 'undefined') {
    applyThemeToDom(currentTheme.value)
  }

  // Watch for theme changes and apply
  watch(currentThemeName, (name) => {
    if (themePresets[name]) {
      currentTheme.value = themePresets[name]
      applyThemeToDom(themePresets[name])
      localStorage.setItem(STORAGE_KEY, name)
    }
  })

  function setTheme(name: string) {
    if (themePresets[name]) {
      currentThemeName.value = name
    }
  }

  function getAllPresets(): ThemePreset[] {
    return Object.values(themePresets)
  }

  return {
    currentThemeName,
    currentTheme,
    setTheme,
    getAllPresets,
  }
})
