import { useMemo, useState } from 'react'

import { useLogStore } from '@/store/logStore'

const levels = ['INFO', 'DEBUG', 'WARN', 'ERROR', 'STDOUT', 'STDERR'] as const

export default function LiveFeedApp() {
  const [paused, setPaused] = useState(false)
  const [selected, setSelected] = useState<string>('ALL')
  const lines = useLogStore((state) => state.lines)

  const filtered = useMemo(() => {
    return selected === 'ALL' ? lines : lines.filter((line) => line.level === selected)
  }, [lines, selected])

  return (
    <div className="flex h-full flex-col gap-3 text-sm">
      <div className="flex items-center justify-between rounded-md border border-surface-3 bg-surface-1 px-3 py-2">
        <div className="flex items-center gap-2">
          <span className="h-2 w-2 animate-pulse rounded-full bg-accent-amber" />
          <span className="font-display text-text-primary">LIVE</span>
          <button className="rounded border border-surface-3 px-2 py-1" onClick={() => setPaused((prev) => !prev)}>
            {paused ? 'Resume' : 'Pause'}
          </button>
        </div>
        <select
          className="rounded border border-surface-3 bg-surface-0 px-2 py-1 font-mono text-xs"
          value={selected}
          onChange={(event) => setSelected(event.target.value)}
        >
          <option value="ALL">ALL</option>
          {levels.map((level) => (
            <option key={level} value={level}>
              {level}
            </option>
          ))}
        </select>
      </div>
      <div className="min-h-0 flex-1 overflow-auto rounded-md border border-surface-3 bg-surface-1 p-3 font-mono text-xs text-text-secondary">
        {(paused ? filtered.slice(0, 150) : filtered).map((line) => (
          <div key={line.id} className="mb-1 grid grid-cols-[95px_65px_1fr] gap-2">
            <span>{line.ts}</span>
            <span className="text-text-mono">{line.level}</span>
            <span>{line.message}</span>
          </div>
        ))}
      </div>
    </div>
  )
}
