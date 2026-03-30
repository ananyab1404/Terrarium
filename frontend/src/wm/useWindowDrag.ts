import type { PanInfo } from 'framer-motion'

import type { TileZone, WindowMode } from '@/types/app'
import { detectTileZone } from '@/wm/tileGeometry'

export function resolveSnapZone(info: PanInfo, mode: WindowMode): TileZone | null {
  if (mode === 'maximized') {
    return null
  }
  return detectTileZone(info.point.x, info.point.y)
}
