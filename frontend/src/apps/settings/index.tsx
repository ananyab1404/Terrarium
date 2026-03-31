import { useState } from 'react'

export default function SettingsApp() {
  const [opacity, setOpacity] = useState(0.5)
  const [reduceMotion, setReduceMotion] = useState(false)

  return (
    <div className="grid h-full grid-rows-[auto_1fr] gap-3 text-sm">
      <div className="rounded-lg border border-surface-3 bg-surface-1 px-3 py-2 text-xs uppercase tracking-wide text-text-secondary">
        UI and Runtime Preferences
      </div>

      <div className="space-y-4 rounded-lg border border-surface-3 bg-surface-1 p-4">
        <label className="block text-xs text-text-secondary">
          Glass Opacity: {opacity.toFixed(2)}
          <input
            type="range"
            min={0.2}
            max={0.9}
            step={0.05}
            value={opacity}
            onChange={(event) => {
              const next = Number(event.target.value)
              setOpacity(next)
              document.documentElement.style.setProperty('--overlay-opacity', String(next))
            }}
            className="mt-2 w-full"
          />
        </label>

        <label className="flex items-center gap-2 text-xs text-text-primary">
          <input
            type="checkbox"
            checked={reduceMotion}
            onChange={(event) => {
              const next = event.target.checked
              setReduceMotion(next)
              document.documentElement.dataset.reduceMotion = next ? 'true' : 'false'
            }}
          />
          Reduce Motion
        </label>
      </div>
    </div>
  )
}
