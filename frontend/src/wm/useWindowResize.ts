import { useRef } from 'react'

import type { WindowInstance } from '@/types/window'

type ResizeAction = {
  width: number
  height: number
  x?: number
  y?: number
}

export function useWindowResize(
  instance: WindowInstance,
  resizeWindow: (width: number, height: number, x?: number, y?: number) => void,
) {
  const originRef = useRef<{ x: number; y: number; w: number; h: number; left: number; top: number } | null>(null)

  function startResize(edge: string, event: React.PointerEvent<HTMLDivElement>) {
    event.preventDefault()
    event.stopPropagation()

    originRef.current = {
      x: event.clientX,
      y: event.clientY,
      w: instance.width,
      h: instance.height,
      left: instance.x,
      top: instance.y,
    }

    const handleMove = (moveEvent: PointerEvent) => {
      if (!originRef.current) {
        return
      }

      const dx = moveEvent.clientX - originRef.current.x
      const dy = moveEvent.clientY - originRef.current.y

      const result: ResizeAction = {
        width: originRef.current.w,
        height: originRef.current.h,
      }

      if (edge.includes('e')) {
        result.width = originRef.current.w + dx
      }
      if (edge.includes('s')) {
        result.height = originRef.current.h + dy
      }

      if (edge.includes('w')) {
        const proposedWidth = originRef.current.w - dx
        result.width = Math.max(proposedWidth, instance.minWidth)
        result.x = originRef.current.left + (originRef.current.w - result.width)
      }

      if (edge.includes('n')) {
        const proposedHeight = originRef.current.h - dy
        result.height = Math.max(proposedHeight, instance.minHeight)
        result.y = originRef.current.top + (originRef.current.h - result.height)
      }

      resizeWindow(result.width, result.height, result.x, result.y)
    }

    const handleUp = () => {
      originRef.current = null
      window.removeEventListener('pointermove', handleMove)
      window.removeEventListener('pointerup', handleUp)
    }

    window.addEventListener('pointermove', handleMove)
    window.addEventListener('pointerup', handleUp)
  }

  return { startResize }
}
