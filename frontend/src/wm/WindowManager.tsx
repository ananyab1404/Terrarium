import { AnimatePresence } from 'framer-motion'

import { useWindowManager } from '@/wm/useWindowManager'
import { Window } from '@/wm/Window'

export function WindowManager() {
  const {
    windows,
    closeWindow,
    focusWindow,
    minimizeWindow,
    maximizeWindow,
    restoreWindow,
    moveWindow,
    resizeWindow,
  } = useWindowManager()

  const ordered = Object.values(windows)
    .filter((window) => window.mode !== 'minimized')
    .sort((a, b) => a.zIndex - b.zIndex)

  return (
    <div className="pointer-events-none absolute inset-0 z-20 overflow-hidden">
      <AnimatePresence>
        {ordered.map((window) => (
          <Window
            key={window.id}
            window={window}
            onClose={() => closeWindow(window.id)}
            onFocus={() => focusWindow(window.id)}
            onMinimize={() => minimizeWindow(window.id)}
            onMaximizeRestore={() => (window.mode === 'maximized' ? restoreWindow(window.id) : maximizeWindow(window.id))}
            onMove={(x, y) => moveWindow(window.id, x, y)}
            onResize={(width, height, x, y) => resizeWindow(window.id, width, height, x, y)}
          />
        ))}
      </AnimatePresence>
    </div>
  )
}
