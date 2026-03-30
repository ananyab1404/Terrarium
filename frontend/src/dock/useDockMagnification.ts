import { useMemo } from 'react'

export function useDockMagnification(active: boolean): string {
  return useMemo(() => (active ? 'scale-125' : 'scale-100'), [active])
}
