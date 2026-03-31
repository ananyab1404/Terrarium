import { useNodeStore } from '@/store/nodeStore'

export default function ContainersApp() {
  const nodes = useNodeStore((state) => state.nodes)

  return (
    <div className="grid h-full grid-rows-[auto_1fr] gap-3 text-sm">
      <div className="rounded-lg border border-surface-3 bg-surface-1 px-3 py-2 text-xs uppercase tracking-wide text-text-secondary">
        Firecracker MicroVM Inventory
      </div>
      <div className="min-h-0 overflow-auto rounded-lg border border-surface-3 bg-surface-1 p-3">
        {nodes.map((node) => (
          <div key={node.nodeId} className="mb-2 rounded border border-surface-3 bg-surface-0 p-3">
            <div className="font-mono text-text-primary">{node.nodeId}</div>
            <div className="text-xs text-text-secondary">{node.activeSlots} active VMs</div>
          </div>
        ))}
      </div>
    </div>
  )
}
