import { describe, expect, it } from 'vitest'

import { detectTileZone, getTileGeometry } from '@/wm/tileGeometry'

describe('tile geometry', () => {
  it('returns equal split for left and right zones', () => {
    const canvas = { x: 0, y: 0, width: 1200, height: 800 }

    expect(getTileGeometry('tiled-left', canvas)).toEqual({ x: 0, y: 0, width: 600, height: 800 })
    expect(getTileGeometry('tiled-right', canvas)).toEqual({ x: 600, y: 0, width: 600, height: 800 })
  })

  it('detects top-left corner snap zone', () => {
    const canvas = { x: 0, y: 0, width: 1000, height: 700 }
    expect(detectTileZone(8, 8, 20, canvas)).toBe('tiled-tl')
  })
})
