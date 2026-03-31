import { create } from 'zustand'

export type JobState = 'PENDING' | 'RUNNING' | 'TERMINAL' | 'ERROR'

export interface JobRecord {
  jobId: string
  functionName: string
  state: JobState
  nodeId: string
  durationMs: number | null
  createdAt: string
}

type JobStoreState = {
  jobs: JobRecord[]
  upsertJob: (job: JobRecord) => void
}

export const useJobStore = create<JobStoreState>((set) => ({
  jobs: [],
  upsertJob: (job) =>
    set((state) => {
      const index = state.jobs.findIndex((item) => item.jobId === job.jobId)
      if (index === -1) {
        return { jobs: [job, ...state.jobs].slice(0, 5000) }
      }

      const jobs = [...state.jobs]
      jobs[index] = job
      return { jobs }
    }),
}))
