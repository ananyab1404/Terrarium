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
  const originRef = useRef<{ x: number; y: number; w: number; h: number } | null>(null)

  function startResize(edge: string, event: React.PointerEvent<HTMLDivElement>) {
    event.preventDefault()
    event.stopPropagation()

    originRef.current = { x: event.clientX, y: event.clientY, w: instance.width, h: instance.height }

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

      if (edge.includes('e')) result.width = originRef.current.w + dx
      if (edge.includes('s')) result.height = originRef.current.h + dy

      if (edge.includes('w')) {
        result.width = originRef.current.w - dx
        result.x = instance.x + dx
      }

      if (edge.includes('n')) {
        result.height = originRef.current.h - dy
        result.y = instance.y + dy
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
