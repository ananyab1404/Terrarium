import { format } from 'date-fns'
import { useEffect, useMemo, useState } from 'react'

import { appDefinitions } from '@/apps/registry'
import { DockIcon } from '@/dock/DockIcon'
import { useWindowManager } from '@/wm/useWindowManager'
import { useWsStore } from '@/ws/wsStore'

export function Dock() {
  const [clock, setClock] = useState(new Date())
  const status = useWsStore((state) => state.status)
  const windows = useWindowManager().windows
  const openWindow = useWindowManager().openWindow

  useEffect(() => {
    const timer = window.setInterval(() => setClock(new Date()), 1000)
    return () => window.clearInterval(timer)
  }, [])

  const runningApps = useMemo(() => {
    const set = new Set<string>()
    for (const window of Object.values(windows)) {
      set.add(window.appId)
    }
    return set
  }, [windows])

  const statusColor = status === 'connected' ? 'bg-accent-walnut animate-pulse' : status === 'failed' ? 'bg-accent-red' : 'bg-accent-amber'

  return (
    <div className="absolute inset-x-0 bottom-0 z-[200] border-t border-surface-3 p-2">
      <div className="mx-auto flex h-14 w-fit items-center gap-3 rounded-2xl border border-surface-3 bg-chrome-dock px-4 backdrop-blur-xl">
        <div className="flex max-w-[70vw] items-center gap-2 overflow-x-auto md:max-w-none">
          {appDefinitions.map((app) => (
            <DockIcon key={app.id} app={app} running={runningApps.has(app.id)} onOpen={() => openWindow(app.id)} />
          ))}
        </div>
        <div className="mx-2 h-7 w-px bg-surface-3" />
        <div className="flex items-center gap-3 text-xs text-text-secondary">
          <span className={`h-2 w-2 rounded-full ${statusColor}`} />
          <span className="font-mono text-text-primary">{format(clock, 'HH:mm:ss')}</span>
        </div>
      </div>
    </div>
  )
}
