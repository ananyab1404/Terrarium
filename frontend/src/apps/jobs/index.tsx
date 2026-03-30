import { useMemo, useState } from 'react'

import { useJobStore } from '@/store/jobStore'

export default function JobsApp() {
  const jobs = useJobStore((state) => state.jobs)
  const [query, setQuery] = useState('')
  const [selectedId, setSelectedId] = useState<string | null>(null)

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    if (!q) {
      return jobs
    }
    return jobs.filter((job) => job.jobId.toLowerCase().includes(q) || job.functionName.toLowerCase().includes(q))
  }, [jobs, query])

  const selected = filtered.find((job) => job.jobId === selectedId) ?? null

  return (
    <div className="grid h-full grid-rows-[auto_1fr] gap-3 text-sm">
      <input
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        placeholder="Search jobs"
        className="rounded-md border border-surface-3 bg-surface-1 px-3 py-2 text-text-primary outline-none"
      />

      <div className="grid min-h-0 grid-cols-1 gap-3 lg:grid-cols-[2fr_1fr]">
        <div className="min-h-0 overflow-auto rounded-lg border border-surface-3 bg-surface-1 p-2">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="text-text-secondary">
                <th className="px-2 py-1">STATE</th>
                <th className="px-2 py-1">JOB</th>
                <th className="px-2 py-1">FUNCTION</th>
                <th className="px-2 py-1">NODE</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((job) => (
                <tr
                  key={job.jobId}
                  className="cursor-pointer border-t border-surface-3 text-text-primary hover:bg-surface-2"
                  onClick={() => setSelectedId(job.jobId)}
                >
                  <td className="px-2 py-1 font-mono text-text-mono">{job.state}</td>
                  <td className="px-2 py-1 font-mono">{job.jobId}</td>
                  <td className="px-2 py-1">{job.functionName}</td>
                  <td className="px-2 py-1">{job.nodeId}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="rounded-lg border border-surface-3 bg-surface-1 p-3">
          <div className="mb-2 text-xs uppercase tracking-wide text-text-secondary">Job Detail</div>
          {selected ? (
            <div className="space-y-1 text-xs text-text-primary">
              <div className="font-mono">{selected.jobId}</div>
              <div>Function: {selected.functionName}</div>
              <div>State: {selected.state}</div>
              <div>Node: {selected.nodeId}</div>
              <div>Duration: {selected.durationMs ?? '--'} ms</div>
            </div>
          ) : (
            <div className="text-xs text-text-secondary">Select a job row to inspect details.</div>
          )}
        </div>
      </div>
    </div>
  )
}






