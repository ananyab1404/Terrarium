import { useMetricsStore } from '@/store/metricsStore'
import { useNodeStore } from '@/store/nodeStore'
import { useNumberTick } from '@/hooks/useNumberTick'

function MetricCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-surface-3 bg-surface-1 p-3">
      <div className="text-xs uppercase tracking-wide text-text-secondary">{label}</div>
      <div className="mt-1 font-mono text-lg text-text-primary">{value}</div>
    </div>
  )
}

export default function ClusterApp() {
  const snapshot = useMetricsStore((state) => state.snapshot)
  const nodes = useNodeStore((state) => state.nodes)

  const running = useNumberTick(snapshot.runningJobs)
  const queue = useNumberTick(snapshot.queueDepth)

  return (
    <div className="grid h-full grid-rows-[auto_1fr] gap-3 text-sm">
      <div className="grid grid-cols-2 gap-2 md:grid-cols-5">
        <MetricCard label="RUNNING" value={running} />
        <MetricCard label="JOBS/SEC" value={snapshot.jobsPerSecond.toFixed(1)} />
        <MetricCard label="P99" value={`${snapshot.p99Ms.toFixed(0)}ms`} />
        <MetricCard label="ERROR" value={`${snapshot.errorRatePct.toFixed(2)}%`} />
        <MetricCard label="QUEUE" value={queue} />
      </div>

      <div className="grid min-h-0 grid-cols-1 gap-3 lg:grid-cols-[2fr_1fr]">
        <div className="min-h-0 overflow-auto rounded-lg border border-surface-3 bg-surface-1 p-3">
          <div className="mb-3 text-xs uppercase tracking-wide text-text-secondary">Node Grid</div>
          <div className="grid grid-cols-1 gap-2 md:grid-cols-2">
            {nodes.map((node) => (
              <div key={node.nodeId} className="rounded-lg border border-surface-3 bg-surface-0 p-3">
                <div className="font-mono text-text-primary">{node.nodeId}</div>
                <div className="text-xs text-text-secondary">
                  {node.activeSlots}/{node.totalSlots} slots active
                </div>
                <div className="mt-2 h-2 overflow-hidden rounded bg-surface-2">
                  <div
                    className="h-full bg-accent-amber"
                    style={{ width: `${Math.round((node.activeSlots / Math.max(node.totalSlots, 1)) * 100)}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-lg border border-surface-3 bg-surface-1 p-3">
          <div className="mb-2 text-xs uppercase tracking-wide text-text-secondary">Autoscaler</div>
          <div className="space-y-2 text-sm text-text-primary">
            <div>State: STABLE</div>
            <div>Target: {Math.max(nodes.length, 1)} nodes</div>
            <div>Queue Depth: {snapshot.queueDepth}</div>
          </div>
        </div>
      </div>
    </div>
  )
}
