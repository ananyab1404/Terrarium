import { beforeEach, describe, expect, it } from 'vitest'

import { useWindowStore } from '@/wm/windowStore'

describe('window store', () => {
  beforeEach(() => {
    useWindowStore.setState({
      windows: {},
      focusOrder: 0,
      activeWindowId: null,
      tilePreviewZone: null,
    })
  })

  it('reuses non-multi-instance app window', () => {
    const first = useWindowStore.getState().openWindow('cluster')
    const second = useWindowStore.getState().openWindow('cluster')

    expect(second).toBe(first)
    expect(Object.keys(useWindowStore.getState().windows)).toHaveLength(1)
  })

  it('tiles and restores a window', () => {
    const id = useWindowStore.getState().openWindow('jobs')

    useWindowStore.getState().tileWindow(id, 'tiled-left')
    expect(useWindowStore.getState().windows[id]?.mode).toBe('tiled-left')

    useWindowStore.getState().tileWindow(id, 'tiled-left')
    expect(useWindowStore.getState().windows[id]?.mode).toBe('normal')
  })
})
