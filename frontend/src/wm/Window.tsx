import { motion, useDragControls, type PanInfo } from 'framer-motion'
import { Suspense } from 'react'

import { appRegistry } from '@/apps/registry'
import type { WindowInstance } from '@/types/window'
import { resolveSnapZone } from '@/wm/useWindowDrag'
import { useWindowResize } from '@/wm/useWindowResize'
import { ResizeHandles } from '@/wm/ResizeHandles'
import { TitleBar } from '@/wm/TitleBar'

type WindowProps = {
  window: WindowInstance
  onClose: () => void
  onFocus: () => void
  onMinimize: () => void
  onMaximizeRestore: () => void
  onMove: (x: number, y: number) => void
  onSnap: (zone: import('@/types/app').TileZone) => void
  onPreview: (zone: import('@/types/app').TileZone | null) => void
  onResize: (width: number, height: number, x?: number, y?: number) => void
}

export function Window({
  window,
  onClose,
  onFocus,
  onMinimize,
  onMaximizeRestore,
  onMove,
  onSnap,
  onPreview,
  onResize,
}: WindowProps) {
  const app = appRegistry[window.appId]
  const { startResize } = useWindowResize(window, onResize)
  const dragControls = useDragControls()

  function handleDragStart(event: React.PointerEvent<HTMLDivElement>) {
    const target = event.target as HTMLElement
    if (target.closest('button')) {
      return
    }
    dragControls.start(event)
  }

  function handleDrag(_: MouseEvent | TouchEvent | PointerEvent, info: PanInfo) {
    onMove(window.x + info.offset.x, window.y + info.offset.y)
    onPreview(resolveSnapZone(info, window.mode))
  }

  function handleDragEnd(_: MouseEvent | TouchEvent | PointerEvent, info: PanInfo) {
    const zone = resolveSnapZone(info, window.mode)
    onPreview(null)
    if (zone) {
      onSnap(zone)
    }
  }

  return (
    <motion.div
      role="dialog"
      aria-label={window.title}
      initial={{ opacity: 0, scale: 0.85, y: 40 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
      exit={{ opacity: 0, scale: 0.9, y: 20 }}
      transition={{ type: 'spring', stiffness: 400, damping: 30 }}
      drag
      dragControls={dragControls}
      dragMomentum={false}
      dragListener={false}
      onPointerDown={onFocus}
      onDrag={handleDrag}
      onDragEnd={handleDragEnd}
      style={{
        left: window.x,
        top: window.y,
        width: window.width,
        height: window.height,
        zIndex: 20 + window.zIndex,
      }}
      className="absolute overflow-hidden rounded-xl border border-surface-3 bg-surface-0 text-text-primary shadow-glass"
    >
      <div className="h-full w-full">
        <TitleBar
          window={window}
          onClose={onClose}
          onMinimize={onMinimize}
          onMaximizeRestore={onMaximizeRestore}
          onDragStart={handleDragStart}
        />

        <div className="h-[calc(100%-2rem)] overflow-auto p-4">
          <Suspense fallback={<div className="animate-pulse text-text-secondary">Loading app...</div>}>
            <app.component />
          </Suspense>
        </div>

        <ResizeHandles onStartResize={startResize} />
      </div>
    </motion.div>
  )
}
