import { useNodeStore } from '@/store/nodeStore'

export default function NetworkApp() {
  const nodes = useNodeStore((state) => state.nodes)

  return (
    <div className="flex h-full flex-col gap-3 rounded-lg border border-surface-3 bg-surface-1 p-3">
      <div className="text-xs uppercase tracking-wide text-text-secondary">Network Topology</div>
      <div className="grid min-h-0 flex-1 grid-cols-1 gap-2 overflow-auto md:grid-cols-2">
        {nodes.map((node) => (
          <div key={node.nodeId} className="rounded-lg border border-surface-3 bg-surface-0 p-3">
            <div className="font-mono text-text-primary">{node.nodeId}</div>
            <div className="text-xs text-text-secondary">Throughput shape placeholder</div>
            <div className="mt-2 text-xs text-text-mono">gossip: active</div>
          </div>
        ))}
      </div>
    </div>
  )
}
