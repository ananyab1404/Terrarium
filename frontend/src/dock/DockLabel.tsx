type DockLabelProps = {
  label: string
}

export function DockLabel({ label }: DockLabelProps) {
  return (
    <div className="pointer-events-none absolute -top-9 left-1/2 -translate-x-1/2 rounded-md border border-surface-3 bg-chrome px-2 py-1 text-xs font-display text-text-primary backdrop-blur-lg">
      {label}
    </div>
  )
}
