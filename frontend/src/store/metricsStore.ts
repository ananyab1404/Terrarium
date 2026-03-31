import { create } from 'zustand'

export interface MetricsSnapshot {
  runningJobs: number
  jobsPerSecond: number
  p99Ms: number
  errorRatePct: number
  queueDepth: number
}

export interface MetricsHistoryPoint extends MetricsSnapshot {
  label: string
}

type MetricsStoreState = {
  snapshot: MetricsSnapshot
  history: MetricsHistoryPoint[]
  setSnapshot: (snapshot: MetricsSnapshot) => void
}

export const useMetricsStore = create<MetricsStoreState>((set) => ({
  snapshot: {
    runningJobs: 0,
    jobsPerSecond: 0,
    p99Ms: 0,
    errorRatePct: 0,
    queueDepth: 0,
  },
  history: [],
  setSnapshot: (snapshot) =>
    set((state) => ({
      snapshot,
      history: [
        ...state.history,
        {
          ...snapshot,
          label: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' }),
        },
      ].slice(-80),
    })),
}))
