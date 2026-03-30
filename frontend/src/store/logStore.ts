import { create } from 'zustand'

export interface LogLine {
  id: string
  ts: string
  level: 'INFO' | 'DEBUG' | 'WARN' | 'ERROR' | 'STDOUT' | 'STDERR'
  message: string
  jobId?: string
}

type LogStoreState = {
  lines: LogLine[]
  pushLine: (line: LogLine) => void
  clear: () => void
}

const MAX_LOG_LINES = 50000

export const useLogStore = create<LogStoreState>((set) => ({
  lines: [],
  pushLine: (line) =>
    set((state) => {
      const lines = [line, ...state.lines]
      return { lines: lines.slice(0, MAX_LOG_LINES) }
    }),
  clear: () => set({ lines: [] }),
}))
