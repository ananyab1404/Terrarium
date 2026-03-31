import { useState } from 'react'

import type { AppDefinition } from '@/apps/registry'
import { cn } from '@/lib/utils'
import { useDockMagnification } from '@/dock/useDockMagnification'
import { DockLabel } from '@/dock/DockLabel'

type DockIconProps = {
  app: AppDefinition
  running: boolean
  onOpen: () => void
}

export function DockIcon({ app, running, onOpen }: DockIconProps) {
  const [hovered, setHovered] = useState(false)
  const scaleClass = useDockMagnification(hovered)
  const Icon = app.icon

  return (
    <button
      type="button"
      className="relative"
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onClick={onOpen}
    >
      {hovered ? <DockLabel label={app.title} /> : null}
      <div
        className={cn(
          'grid h-11 w-11 place-items-center rounded-xl border border-surface-3 bg-surface-1 text-text-primary transition-transform',
          scaleClass,
        )}
      >
        <Icon className="h-5 w-5" />
      </div>
      {running ? <span className="mx-auto mt-1 block h-1 w-1 rounded-full bg-accent-walnut" /> : <span className="mt-1 block h-1 w-1" />}
    </button>
  )
}
