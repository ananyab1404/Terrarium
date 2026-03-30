import { useEffect, useState } from 'react'

export function useNumberTick(value: number): string {
  const [display, setDisplay] = useState(value)

  useEffect(() => {
    const handle = window.setTimeout(() => setDisplay(value), 120)
    return () => window.clearTimeout(handle)
  }, [value])

  return display.toLocaleString()
}
