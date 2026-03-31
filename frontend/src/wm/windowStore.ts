import { nanoid } from 'nanoid'
import { create } from 'zustand'
import { immer } from 'zustand/middleware/immer'

import { appRegistry } from '@/apps/registry'
import type { AppId, Geometry, TileZone } from '@/types/app'
import type { WindowInstance, WindowManagerState } from '@/types/window'
import { getCanvasGeometry } from '@/wm/tileGeometry'

function getDefaultGeometry(appId: AppId, existingCount: number): Geometry {
  const canvas = getCanvasGeometry()
  const app = appRegistry[appId]

  const width = Math.min(app.defaultSize.width, canvas.width - 48)
  const height = Math.min(app.defaultSize.height, canvas.height - 48)

  if (app.defaultPosition === 'center') {
    return {
      x: canvas.x + Math.floor((canvas.width - width) / 2),
      y: Math.max(canvas.y + Math.floor((canvas.height - height) / 2), canvas.y),
      width,
      height,
    }
  }

  const offset = existingCount * 24
  return {
    x: Math.min(canvas.x + 56 + offset, Math.max(canvas.x + canvas.width - width - 16, canvas.x)),
    y: Math.min(canvas.y + 48 + offset, Math.max(canvas.y + canvas.height - height - 16, canvas.y)),
    width,
    height,
  }
}

function nextTitle(baseTitle: string, appId: AppId, windows: Record<string, WindowInstance>): string {
  const current = Object.values(windows).filter((w) => w.appId === appId)
  if (current.length === 0) {
    return baseTitle
  }

  return `${baseTitle} ${current.length + 1}`
}

export const useWindowStore = create<WindowManagerState>()(
  immer((set, get) => ({
    windows: {},
    focusOrder: 0,
    activeWindowId: null,
    tilePreviewZone: null,

    openWindow: (appId, overrides) => {
      const app = appRegistry[appId]

      if (!app.multiInstance) {
        const existing = Object.values(get().windows).find((window) => window.appId === appId)
        if (existing) {
          get().focusWindow(existing.id)
          return existing.id
        }
      }

      const existingCount = Object.values(get().windows).filter((window) => window.appId === appId).length
      const geometry = getDefaultGeometry(appId, existingCount)
      const id = nanoid()

      set((state) => {
        state.focusOrder += 1

        for (const w of Object.values(state.windows)) {
          w.isActive = false
        }

        state.windows[id] = {
          id,
          appId,
          title: nextTitle(app.title, appId, state.windows),
          mode: 'normal',
          x: overrides?.x ?? geometry.x,
          y: overrides?.y ?? geometry.y,
          width: overrides?.width ?? geometry.width,
          height: overrides?.height ?? geometry.height,
          minWidth: overrides?.minWidth ?? app.minSize.width,
          minHeight: overrides?.minHeight ?? app.minSize.height,
          zIndex: state.focusOrder,
          isActive: true,
          prevGeometry: null,
        }

        state.activeWindowId = id
      })

      return id
    },

    closeWindow: (id) => {
      set((state) => {
        delete state.windows[id]
        if (state.activeWindowId === id) {
          const fallback = Object.values(state.windows).sort((a, b) => b.zIndex - a.zIndex)[0]
          state.activeWindowId = fallback?.id ?? null
          if (fallback) {
            fallback.isActive = true
          }
        }
      })
    },

    minimizeWindow: (id) => {
      set((state) => {
        const window = state.windows[id]
        if (!window) {
          return
        }
        window.mode = 'minimized'
        window.isActive = false
        state.activeWindowId = null
      })
    },

    maximizeWindow: (id) => {
      set((state) => {
        const window = state.windows[id]
        if (!window) {
          return
        }

        if (!window.prevGeometry) {
          window.prevGeometry = { x: window.x, y: window.y, width: window.width, height: window.height }
        }

        const canvas = getCanvasGeometry()
        window.x = canvas.x
        window.y = canvas.y
        window.width = canvas.width
        window.height = canvas.height
        window.mode = 'maximized'
      })
    },

    restoreWindow: (id) => {
      set((state) => {
        const window = state.windows[id]
        if (!window) {
          return
        }

        if (window.prevGeometry) {
          window.x = window.prevGeometry.x
          window.y = window.prevGeometry.y
          window.width = window.prevGeometry.width
          window.height = window.prevGeometry.height
        }

        window.mode = 'normal'
        window.prevGeometry = null
      })
    },

    focusWindow: (id) => {
      set((state) => {
        const window = state.windows[id]
        if (!window) {
          return
        }

        state.focusOrder += 1
        for (const item of Object.values(state.windows)) {
          item.isActive = false
        }

        window.zIndex = state.focusOrder
        window.isActive = true
        if (window.mode === 'minimized') {
          window.mode = 'normal'
        }

        state.activeWindowId = id
      })
    },

    moveWindow: (id, x, y) => {
      set((state) => {
        const window = state.windows[id]
        if (!window) {
          return
        }

        if (window.mode !== 'normal') {
          if (window.prevGeometry) {
            window.width = window.prevGeometry.width
            window.height = window.prevGeometry.height
          }
          window.mode = 'normal'
          window.prevGeometry = null
        }

        const canvas = getCanvasGeometry()
        const minX = canvas.x - window.width + 120
        const maxX = canvas.x + canvas.width - 120
        const maxY = Math.max(canvas.y, canvas.y + canvas.height - 32)

        window.x = Math.min(Math.max(x, minX), maxX)
        window.y = Math.min(Math.max(y, canvas.y), maxY)
      })
    },

    resizeWindow: (id, width, height, x, y) => {
      set((state) => {
        const window = state.windows[id]
        if (!window) {
          return
        }

        const canvas = getCanvasGeometry()

        window.width = Math.max(Math.min(width, canvas.width), window.minWidth)
        window.height = Math.max(Math.min(height, canvas.height), window.minHeight)

        if (typeof x === 'number') {
          const maxX = Math.max(canvas.x, canvas.x + canvas.width - window.width)
          window.x = Math.min(Math.max(x, canvas.x), maxX)
        }
        if (typeof y === 'number') {
          const maxY = Math.max(canvas.y, canvas.y + canvas.height - 32)
          window.y = Math.min(Math.max(y, canvas.y), maxY)
        }
      })
    },

    tileWindow: (id, _zone) => {
      set((state) => {
        const window = state.windows[id]
        if (!window) {
          return
        }

        if (window.mode !== 'normal' && window.mode !== 'maximized' && window.prevGeometry) {
          window.x = window.prevGeometry.x
          window.y = window.prevGeometry.y
          window.width = window.prevGeometry.width
          window.height = window.prevGeometry.height
          window.prevGeometry = null
        }

        if (window.mode !== 'minimized') {
          window.mode = 'normal'
        }

        state.tilePreviewZone = null
      })
    },

    snapToTile: (_id, _zone) => {
      set((state) => {
        state.tilePreviewZone = null
      })
    },

    setTilePreviewZone: (_zone: TileZone | null) => {
      set((state) => {
        state.tilePreviewZone = null
      })
    },
  })),
)

