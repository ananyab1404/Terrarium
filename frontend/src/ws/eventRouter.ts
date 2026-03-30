import { nanoid } from 'nanoid'

import { useJobStore } from '@/store/jobStore'
import { useLogStore } from '@/store/logStore'
import { useMetricsStore } from '@/store/metricsStore'
import { useNodeStore } from '@/store/nodeStore'

type WSEvent =
  | { type: 'job.created'; payload: { job_id: string; function_name: string; node_id: string } }
  | { type: 'job.updated'; payload: { job_id: string; state: 'PENDING' | 'RUNNING' | 'TERMINAL' | 'ERROR' } }
  | { type: 'metrics.update'; payload: { running_jobs: number; jobs_per_second: number; p99_ms: number; error_rate_pct: number; queue_depth: number } }
  | { type: 'log.line'; payload: { ts: string; level: 'INFO' | 'DEBUG' | 'WARN' | 'ERROR' | 'STDOUT' | 'STDERR'; message: string; job_id?: string } }
  | { type: 'node.snapshot'; payload: Array<{ node_id: string; active_slots: number; total_slots: number; p99_ms: number; error_rate_pct: number }> }

export function routeEvent(event: WSEvent): void {
  if (event.type === 'job.created') {
    useJobStore.getState().upsertJob({
      jobId: event.payload.job_id,
      functionName: event.payload.function_name,
      state: 'PENDING',
      nodeId: event.payload.node_id,
      durationMs: null,
      createdAt: new Date().toISOString(),
    })
    return
  }

  if (event.type === 'job.updated') {
    const current = useJobStore.getState().jobs.find((job) => job.jobId === event.payload.job_id)
    if (current) {
      useJobStore.getState().upsertJob({ ...current, state: event.payload.state })
    }
    return
  }

  if (event.type === 'metrics.update') {
    useMetricsStore.getState().setSnapshot({
      runningJobs: event.payload.running_jobs,
      jobsPerSecond: event.payload.jobs_per_second,
      p99Ms: event.payload.p99_ms,
      errorRatePct: event.payload.error_rate_pct,
      queueDepth: event.payload.queue_depth,
    })
    return
  }

  if (event.type === 'log.line') {
    useLogStore.getState().pushLine({
      id: nanoid(),
      ts: event.payload.ts,
      level: event.payload.level,
      message: event.payload.message,
      jobId: event.payload.job_id,
    })
    return
  }

  useNodeStore.getState().setNodes(
    event.payload.map((node) => ({
      nodeId: node.node_id,
      activeSlots: node.active_slots,
      totalSlots: node.total_slots,
      p99Ms: node.p99_ms,
      errorRatePct: node.error_rate_pct,
    })),
  )
}
