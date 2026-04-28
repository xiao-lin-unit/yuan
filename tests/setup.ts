import { vi } from 'vitest'
import { setupLocalStorageMock } from './utils/testDb'

// Mock Capacitor for jsdom environment
vi.mock('@capacitor/core', () => ({
  Capacitor: {
    isNativePlatform: () => false,
  },
}))

vi.mock('@capacitor-community/sqlite', () => ({
  CapacitorSQLite: {},
  SQLiteConnection: class {},
  SQLiteDBConnection: class {},
}))

setupLocalStorageMock()
