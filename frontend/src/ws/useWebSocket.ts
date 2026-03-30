import { useEffect, useRef } from 'react'

import { routeEvent } from '@/ws/eventRouter'
import { useWsStore } from '@/ws/wsStore'

const MAX_BACKOFF_MS = 30_000

export function useWebSocket(url: string): void {
  const retryRef = useRef(0)

  const setStatus = useWsStore((state) => state.setStatus)
  const setRetryCount = useWsStore((state) => state.setRetryCount)

  useEffect(() => {
    if (!url) {
      return
    }

    let closed = false
    let socket: WebSocket | null = null
    let timer: number | null = null

    const connect = () => {
      setStatus('reconnecting')
      socket = new WebSocket(url)

      socket.onopen = () => {
        retryRef.current = 0
        setRetryCount(0)
        setStatus('connected')
      }

      socket.onmessage = (event) => {
        try {
          routeEvent(JSON.parse(event.data) as Parameters<typeof routeEvent>[0])
        } catch {
          // Ignore malformed event payloads from unstable streams.
        }
      }

      socket.onclose = () => {
        if (closed) {
          return
        }

        retryRef.current += 1
        setRetryCount(retryRef.current)
        const base = Math.min(500 * 2 ** retryRef.current, MAX_BACKOFF_MS)
        const jitter = Math.floor(Math.random() * 300)

        if (retryRef.current > 5) {
          setStatus('failed')
        } else {
          setStatus('reconnecting')
        }

        timer = window.setTimeout(connect, base + jitter)
      }
    }

    connect()

    return () => {
      closed = true
      if (timer !== null) {
        window.clearTimeout(timer)
      }
      socket?.close()
    }
  }, [setRetryCount, setStatus, url])
}
