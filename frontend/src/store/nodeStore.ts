import { create } from 'zustand'

export interface NodeRecord {
  nodeId: string
  activeSlots: number
  totalSlots: number
  p99Ms: number
  errorRatePct: number
}

type NodeStoreState = {
  nodes: NodeRecord[]
  setNodes: (nodes: NodeRecord[]) => void
}

export const useNodeStore = create<NodeStoreState>((set) => ({
  nodes: [],
  setNodes: (nodes) => set({ nodes }),
}))
