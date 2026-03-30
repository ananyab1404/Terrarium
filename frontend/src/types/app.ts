export type AppId =
  | 'live-feed'
  | 'cluster'
  | 'heatmap'
  | 'network'
  | 'jobs'
  | 'logs'
  | 'upload'
  | 'containers'
  | 'analytics'
  | 'settings'

export type WindowMode =
  | 'normal'
  | 'minimized'
  | 'maximized'
  | 'tiled-left'
  | 'tiled-right'
  | 'tiled-top'
  | 'tiled-bottom'
  | 'tiled-tl'
  | 'tiled-tr'
  | 'tiled-bl'
  | 'tiled-br'

export type TileZone = Extract<
  WindowMode,
  | 'tiled-left'
  | 'tiled-right'
  | 'tiled-top'
  | 'tiled-bottom'
  | 'tiled-tl'
  | 'tiled-tr'
  | 'tiled-bl'
  | 'tiled-br'
>

export interface Geometry {
  x: number
  y: number
  width: number
  height: number
}
