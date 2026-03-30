import { create } from 'zustand'

export type WsStatus = 'connected' | 'reconnecting' | 'failed'

type WsState = {
  status: WsStatus
  retryCount: number
  setStatus: (status: WsStatus) => void
  setRetryCount: (count: number) => void
}

export const useWsStore = create<WsState>((set) => ({
  status: 'reconnecting',
  retryCount: 0,
  setStatus: (status) => set({ status }),
  setRetryCount: (retryCount) => set({ retryCount }),
}))
