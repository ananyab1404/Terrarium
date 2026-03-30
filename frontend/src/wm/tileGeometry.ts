import type { Geometry, TileZone } from '@/types/app'

export function getCanvasGeometry(): Geometry {
  const dockHeight = 64
  const width = window.innerWidth
  const height = Math.max(window.innerHeight - dockHeight, 0)
  return { x: 0, y: 0, width, height }
}

export function getTileGeometry(zone: TileZone, canvas = getCanvasGeometry()): Geometry {
  const { width, height } = canvas
  const halfW = Math.floor(width / 2)
  const halfH = Math.floor(height / 2)

  switch (zone) {
    case 'tiled-left':
      return { x: 0, y: 0, width: halfW, height }
    case 'tiled-right':
      return { x: halfW, y: 0, width: width - halfW, height }
    case 'tiled-top':
      return { x: 0, y: 0, width, height: halfH }
    case 'tiled-bottom':
      return { x: 0, y: halfH, width, height: height - halfH }
    case 'tiled-tl':
      return { x: 0, y: 0, width: halfW, height: halfH }
    case 'tiled-tr':
      return { x: halfW, y: 0, width: width - halfW, height: halfH }
    case 'tiled-bl':
      return { x: 0, y: halfH, width: halfW, height: height - halfH }
    case 'tiled-br':
      return { x: halfW, y: halfH, width: width - halfW, height: height - halfH }
  }
}

export function detectTileZone(
  x: number,
  y: number,
  threshold = 20,
  canvas = getCanvasGeometry(),
): TileZone | null {
  const atLeft = x <= threshold
  const atRight = x >= canvas.width - threshold
  const atTop = y <= threshold
  const atBottom = y >= canvas.height - threshold

  if (atTop && atLeft) return 'tiled-tl'
  if (atTop && atRight) return 'tiled-tr'
  if (atBottom && atLeft) return 'tiled-bl'
  if (atBottom && atRight) return 'tiled-br'
  if (atLeft) return 'tiled-left'
  if (atRight) return 'tiled-right'
  if (atTop) return 'tiled-top'
  if (atBottom) return 'tiled-bottom'

  return null
}
