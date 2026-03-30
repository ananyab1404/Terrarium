import { Minus, Square, X } from 'lucide-react'

import type { WindowInstance } from '@/types/window'
import { cn } from '@/lib/utils'

type TitleBarProps = {
  window: WindowInstance
  onClose: () => void
  onMinimize: () => void
  onMaximizeRestore: () => void
  onDragStart: (event: React.PointerEvent<HTMLDivElement>) => void
}

export function TitleBar({ window, onClose, onMinimize, onMaximizeRestore, onDragStart }: TitleBarProps) {
  return (
    <div
      data-titlebar="true"
      onPointerDown={onDragStart}
      className={cn(
        'flex h-8 cursor-grab items-center justify-between border-b border-surface-3 px-3 backdrop-blur-xl active:cursor-grabbing',
        'bg-chrome text-text-secondary',
      )}
    >
      <div className="flex items-center gap-2">
        <button
          type="button"
          aria-label="close"
          className="h-3 w-3 rounded-full bg-accent-red transition-opacity hover:opacity-100"
          onClick={onClose}
        />
        <button
          type="button"
          aria-label="minimize"
          className="h-3 w-3 rounded-full bg-accent-amber transition-opacity hover:opacity-100"
          onClick={onMinimize}
        />
        <button
          type="button"
          aria-label="maximize"
          className="h-3 w-3 rounded-full bg-accent-green transition-opacity hover:opacity-100"
          onClick={onMaximizeRestore}
        />
      </div>

      <span className="pointer-events-none truncate px-2 font-display text-xs">{window.title}</span>

      <div className="flex items-center gap-1">
        <button
          type="button"
          className="grid h-6 w-6 place-items-center rounded-md text-text-secondary transition hover:bg-surface-2"
          onClick={onMinimize}
        >
          <Minus className="h-3.5 w-3.5" />
        </button>
        <button
          type="button"
          className="grid h-6 w-6 place-items-center rounded-md text-text-secondary transition hover:bg-surface-2"
          onClick={onMaximizeRestore}
        >
          <Square className="h-3.5 w-3.5" />
        </button>
        <button
          type="button"
          className="grid h-6 w-6 place-items-center rounded-md text-text-secondary transition hover:bg-surface-2"
          onClick={onClose}
        >
          <X className="h-3.5 w-3.5" />
        </button>
      </div>
    </div>
  )
}
