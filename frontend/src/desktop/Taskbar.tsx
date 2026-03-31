import { format } from 'date-fns'
import { LayoutGrid } from 'lucide-react'
import { useEffect, useState } from 'react'

import { useWindowManager } from '@/wm/useWindowManager'
import { useWsStore } from '@/ws/wsStore'

export function Taskbar() {
  const [clock, setClock] = useState(new Date())
  const status = useWsStore((state) => state.status)
  const windows = useWindowManager().windows

  useEffect(() => {
    const timer = window.setInterval(() => setClock(new Date()), 1000)
    return () => window.clearInterval(timer)
  }, [])

  const openWindows = Object.values(windows).filter((window) => window.mode !== 'minimized').length

  return (
    <div className="absolute inset-x-0 bottom-0 z-40 flex h-12 items-center justify-between border-t border-surface-3 bg-surface-1 px-3 text-text-primary">
      <div className="flex items-center gap-3">
        <button
          type="button"
          className="flex h-8 items-center gap-2 rounded border border-surface-3 bg-surface-0 px-3 text-xs text-text-primary"
        >
          <LayoutGrid className="h-3.5 w-3.5" />
          <span>Start</span>
        </button>
        <span className="text-xs text-text-secondary">{openWindows} open</span>
      </div>

      <div className="flex items-center gap-2 text-xs text-text-primary">
        <span className={`h-2 w-2 rounded-full ${status === 'connected' ? 'bg-emerald-400' : status === 'failed' ? 'bg-red-400' : 'bg-amber-400'}`} />
        <span className="font-medium">{format(clock, 'HH:mm:ss')}</span>
      </div>
    </div>
  )
}
