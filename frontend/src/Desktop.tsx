import { useEffect, useRef } from 'react'
import { Activity, Command } from 'lucide-react'

import { Dock } from '@/dock/Dock'
import { useKeyboardShortcuts } from '@/hooks/useKeyboardShortcuts'
import { useWindowManager } from '@/wm/useWindowManager'
import { WindowManager } from '@/wm/WindowManager'
import { routeEvent } from '@/ws/eventRouter'
import { useWebSocket } from '@/ws/useWebSocket'
import { useWsStore } from '@/ws/wsStore'

function bootstrapMockStream() {
  routeEvent({
    type: 'node.snapshot',
    payload: [
      { node_id: 'node-a', active_slots: 3, total_slots: 8, p99_ms: 41, error_rate_pct: 0.2 },
      { node_id: 'node-b', active_slots: 5, total_slots: 8, p99_ms: 52, error_rate_pct: 0.35 },
      { node_id: 'node-c', active_slots: 2, total_slots: 6, p99_ms: 38, error_rate_pct: 0.1 },
      { node_id: 'node-d', active_slots: 4, total_slots: 10, p99_ms: 49, error_rate_pct: 0.45 },
    ],
  })
}

export function Desktop() {
  const wsUrl = (import.meta.env.VITE_WS_URL as string | undefined) ?? ''
  const seededRef = useRef(false)

  const openWindow = useWindowManager().openWindow
  const setStatus = useWsStore((state) => state.setStatus)

  useKeyboardShortcuts()
  useWebSocket(wsUrl)

  useEffect(() => {
    if (seededRef.current) {
      return
    }

    openWindow('cluster')
    openWindow('jobs')
    openWindow('live-feed')
    seededRef.current = true
  }, [openWindow])

  useEffect(() => {
    if (wsUrl) {
      return
    }

    setStatus('connected')
    bootstrapMockStream()

    const interval = window.setInterval(() => {
      const now = new Date()
      const runningJobs = Math.floor(8 + Math.random() * 32)
      const jobsPerSecond = 90 + Math.random() * 35
      const p99Ms = 30 + Math.random() * 40
      const errorRate = Math.max(0, 0.2 + Math.random() * 1.5)
      const queueDepth = Math.floor(Math.random() * 80)

      routeEvent({
        type: 'metrics.update',
        payload: {
          running_jobs: runningJobs,
          jobs_per_second: jobsPerSecond,
          p99_ms: p99Ms,
          error_rate_pct: errorRate,
          queue_depth: queueDepth,
        },
      })

      routeEvent({
        type: 'job.created',
        payload: {
          job_id: `job_${Math.floor(Math.random() * 10_000)}`,
          function_name: ['transcode', 'vectorize', 'infer', 'thumbnail'][Math.floor(Math.random() * 4)],
          node_id: ['node-a', 'node-b', 'node-c', 'node-d'][Math.floor(Math.random() * 4)],
        },
      })

      routeEvent({
        type: 'log.line',
        payload: {
          ts: now.toISOString().slice(11, 19),
          level: ['INFO', 'DEBUG', 'WARN', 'STDOUT'][Math.floor(Math.random() * 4)] as
            | 'INFO'
            | 'DEBUG'
            | 'WARN'
            | 'STDOUT',
          message: 'Worker heartbeat and scheduler telemetry packet received',
        },
      })
    }, 1200)

    return () => window.clearInterval(interval)
  }, [setStatus, wsUrl])

  return (
    <div className="desktop-atmosphere relative h-dvh w-full overflow-hidden font-body text-text-primary">
      <div className="desktop-grid absolute inset-0 opacity-40" />
      <div className="pointer-events-none absolute -left-24 -top-20 h-72 w-72 rounded-full bg-accent-blue/20 blur-3xl" />
      <div className="pointer-events-none absolute -right-20 top-12 h-80 w-80 rounded-full bg-accent-cyan/20 blur-3xl" />

      <header className="absolute inset-x-0 top-0 z-30 flex h-10 items-center justify-between border-b border-surface-3 bg-chrome px-4 text-xs backdrop-blur-xl">
        <div className="flex items-center gap-2 text-text-secondary">
          <Command className="h-3.5 w-3.5" />
          <span className="font-display tracking-wide text-text-primary">INFINITY NODE DESKTOP</span>
        </div>
        <div className="flex items-center gap-2 text-text-secondary">
          <Activity className="h-3.5 w-3.5 text-accent-cyan" />
          <span>Runtime Overlay v2.0</span>
        </div>
      </header>

      <WindowManager />
      <Dock />
    </div>
  )
}
