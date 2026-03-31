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
        'flex h-8 cursor-grab items-center justify-between border-b border-[#8f6d50] px-2 active:cursor-grabbing',
        'bg-[#6b4b34] text-[#fff6eb]',
      )}
    >
      <div className="min-w-0 px-2">
        <span className="pointer-events-none truncate text-xs font-medium">{window.title}</span>
      </div>

      <div className="flex items-center gap-1">
        <button
          type="button"
          aria-label="minimize"
          className="grid h-7 w-8 place-items-center rounded text-[#fff6eb] transition hover:bg-[#7b5a43]"
          onClick={onMinimize}
        >
          <Minus className="h-3.5 w-3.5" />
        </button>
        <button
          type="button"
          aria-label="maximize"
          className="grid h-7 w-8 place-items-center rounded text-[#fff6eb] transition hover:bg-[#7b5a43]"
          onClick={onMaximizeRestore}
        >
          <Square className="h-3.5 w-3.5" />
        </button>
        <button
          type="button"
          aria-label="close"
          className="grid h-7 w-8 place-items-center rounded text-[#fff6eb] transition hover:bg-[#9b3f2f] hover:text-[#fff7ee]"
          onClick={onClose}
        >
          <X className="h-3.5 w-3.5" />
        </button>
      </div>
    </div>
  )
}
