import type { AppId, Geometry, TileZone, WindowMode } from '@/types/app'

export interface WindowInstance extends Geometry {
  id: string
  appId: AppId
  title: string
  mode: WindowMode
  minWidth: number
  minHeight: number
  zIndex: number
  isActive: boolean
  prevGeometry: Geometry | null
}

export interface WindowManagerState {
  windows: Record<string, WindowInstance>
  focusOrder: number
  activeWindowId: string | null
  tilePreviewZone: TileZone | null

  openWindow: (appId: AppId, overrides?: Partial<WindowInstance>) => string
  closeWindow: (id: string) => void
  minimizeWindow: (id: string) => void
  maximizeWindow: (id: string) => void
  restoreWindow: (id: string) => void
  focusWindow: (id: string) => void
  moveWindow: (id: string, x: number, y: number) => void
  resizeWindow: (id: string, width: number, height: number, x?: number, y?: number) => void
  tileWindow: (id: string, zone: TileZone) => void
  snapToTile: (id: string, zone: TileZone) => void
  setTilePreviewZone: (zone: TileZone | null) => void
}
