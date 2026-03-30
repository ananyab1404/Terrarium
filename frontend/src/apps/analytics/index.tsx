import { Area, AreaChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'

import { useMetricsStore } from '@/store/metricsStore'

export default function AnalyticsApp() {
  const history = useMetricsStore((state) => state.history)

  return (
    <div className="grid h-full grid-rows-[1fr] gap-3">
      <div className="rounded-lg border border-surface-3 bg-surface-1 p-3">
        <div className="mb-2 text-xs uppercase tracking-wide text-text-secondary">Throughput Over Time</div>
        <div className="h-[280px]">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={history}>
              <CartesianGrid stroke="rgba(255,255,255,0.08)" />
              <XAxis dataKey="label" stroke="#7f90aa" tick={{ fontSize: 11 }} />
              <YAxis stroke="#7f90aa" tick={{ fontSize: 11 }} />
              <Tooltip />
              <Area type="monotone" dataKey="jobsPerSecond" stroke="#53e2df" fill="#53e2df44" />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  )
}
