import type { Geometry, TileZone } from '@/types/app'

export function getCanvasGeometry(): Geometry {
  const topInset = 0
  const taskbarHeight = 48
  const width = window.innerWidth
  const height = Math.max(window.innerHeight - topInset - taskbarHeight, 0)
  return { x: 0, y: topInset, width, height }
}

export function getTileGeometry(zone: TileZone, canvas = getCanvasGeometry()): Geometry {
  const { x, y, width, height } = canvas
  const halfW = Math.floor(width / 2)
  const halfH = Math.floor(height / 2)

  switch (zone) {
    case 'tiled-left':
      return { x, y, width: halfW, height }
    case 'tiled-right':
      return { x: x + halfW, y, width: width - halfW, height }
    case 'tiled-top':
      return { x, y, width, height: halfH }
    case 'tiled-bottom':
      return { x, y: y + halfH, width, height: height - halfH }
    case 'tiled-tl':
      return { x, y, width: halfW, height: halfH }
    case 'tiled-tr':
      return { x: x + halfW, y, width: width - halfW, height: halfH }
    case 'tiled-bl':
      return { x, y: y + halfH, width: halfW, height: height - halfH }
    case 'tiled-br':
      return { x: x + halfW, y: y + halfH, width: width - halfW, height: height - halfH }
  }
}

export function detectTileZone(
  x: number,
  y: number,
  threshold = 22,
  canvas = getCanvasGeometry(),
): TileZone | null {
  const minX = canvas.x
  const maxX = canvas.x + canvas.width
  const minY = canvas.y
  const maxY = canvas.y + canvas.height

  const atLeft = x <= minX + threshold
  const atRight = x >= maxX - threshold
  const atTop = y <= minY + threshold
  const atBottom = y >= maxY - threshold

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
