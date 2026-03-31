import { useMemo } from 'react'

import { useNodeStore } from '@/store/nodeStore'

export default function HeatmapApp() {
  const nodes = useNodeStore((state) => state.nodes)

  const rows = useMemo(() => {
    return nodes.map((node) => ({
      id: node.nodeId,
      utilization: node.totalSlots === 0 ? 0 : node.activeSlots / node.totalSlots,
    }))
  }, [nodes])

  return (
    <div className="h-full overflow-auto rounded-lg border border-surface-3 bg-surface-1 p-3">
      <div className="mb-3 text-xs uppercase tracking-wide text-text-secondary">Node Heatmap</div>
      <div className="space-y-2">
        {rows.map((row) => (
          <div key={row.id} className="grid grid-cols-[180px_1fr_60px] items-center gap-3 text-xs">
            <span className="font-mono text-text-primary">{row.id}</span>
            <div className="h-4 rounded bg-surface-2">
              <div
                className="h-full rounded bg-gradient-to-r from-[#6b4228] via-accent-amber to-accent-red"
                style={{ width: `${Math.round(row.utilization * 100)}%` }}
              />
            </div>
            <span className="font-mono text-text-mono">{Math.round(row.utilization * 100)}%</span>
          </div>
        ))}
      </div>
    </div>
  )
}
