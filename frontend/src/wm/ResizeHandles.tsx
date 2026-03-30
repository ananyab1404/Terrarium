type ResizeHandlesProps = {
  onStartResize: (edge: string, event: React.PointerEvent<HTMLDivElement>) => void
}

const handles = [
  { edge: 'n', className: 'cursor-n-resize inset-x-2 top-0 h-2' },
  { edge: 's', className: 'cursor-s-resize inset-x-2 bottom-0 h-2' },
  { edge: 'e', className: 'cursor-e-resize inset-y-2 right-0 w-2' },
  { edge: 'w', className: 'cursor-w-resize inset-y-2 left-0 w-2' },
  { edge: 'ne', className: 'cursor-ne-resize top-0 right-0 h-3 w-3' },
  { edge: 'nw', className: 'cursor-nw-resize top-0 left-0 h-3 w-3' },
  { edge: 'se', className: 'cursor-se-resize right-0 bottom-0 h-3 w-3' },
  { edge: 'sw', className: 'cursor-sw-resize bottom-0 left-0 h-3 w-3' },
]

export function ResizeHandles({ onStartResize }: ResizeHandlesProps) {
  return (
    <>
      {handles.map((handle) => (
        <div
          key={handle.edge}
          className={`absolute z-20 ${handle.className}`}
          onPointerDown={(event) => onStartResize(handle.edge, event)}
        />
      ))}
    </>
  )
}
