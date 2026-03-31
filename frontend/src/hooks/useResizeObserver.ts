import { useMemo } from 'react'
import useResizeObserver from 'use-resize-observer'

export function useCanvasResizeObserver() {
  const { ref, width = 0, height = 0 } = useResizeObserver<HTMLDivElement>()

  return useMemo(
    () => ({
      ref,
      width,
      height,
    }),
    [height, ref, width],
  )
}
