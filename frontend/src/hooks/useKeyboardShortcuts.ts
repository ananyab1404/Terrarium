import { useEffect } from 'react'

import { appDefinitions } from '@/apps/registry'
import { useWindowManager } from '@/wm/useWindowManager'

export function useKeyboardShortcuts(): void {
  const {
    activeWindowId,
    openWindow,
    closeWindow,
    minimizeWindow,
    maximizeWindow,
    restoreWindow,
    tileWindow,
  } = useWindowManager()

  useEffect(() => {
    const handler = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null
      if (target && ['INPUT', 'TEXTAREA'].includes(target.tagName)) {
        return
      }

      const isSuper = event.metaKey || event.ctrlKey
      if (!isSuper) {
        return
      }

      if (event.key >= '1' && event.key <= '9') {
        const index = Number(event.key) - 1
        if (index < appDefinitions.length) {
          openWindow(appDefinitions[index].id)
          event.preventDefault()
        }
        return
      }

      if (!activeWindowId) {
        return
      }

      switch (event.key) {
        case 'ArrowLeft': {
          tileWindow(activeWindowId, event.shiftKey ? 'tiled-tl' : 'tiled-left')
          event.preventDefault()
          break
        }
        case 'ArrowRight': {
          tileWindow(activeWindowId, event.shiftKey ? 'tiled-tr' : 'tiled-right')
          event.preventDefault()
          break
        }
        case 'ArrowUp': {
          if (event.shiftKey) {
            tileWindow(activeWindowId, 'tiled-bl')
          } else {
            maximizeWindow(activeWindowId)
          }
          event.preventDefault()
          break
        }
        case 'ArrowDown': {
          if (event.shiftKey) {
            tileWindow(activeWindowId, 'tiled-br')
          } else {
            restoreWindow(activeWindowId)
          }
          event.preventDefault()
          break
        }
        case 'w':
        case 'W': {
          closeWindow(activeWindowId)
          event.preventDefault()
          break
        }
        case 'm':
        case 'M': {
          minimizeWindow(activeWindowId)
          event.preventDefault()
          break
        }
        default:
          break
      }
    }

    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [activeWindowId, closeWindow, maximizeWindow, minimizeWindow, openWindow, restoreWindow, tileWindow])
}
