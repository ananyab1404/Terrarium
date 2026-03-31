import { useWindowStore } from '@/wm/windowStore'

export function useWindowManager() {
  const windows = useWindowStore((state) => state.windows)
  const activeWindowId = useWindowStore((state) => state.activeWindowId)
  const tilePreviewZone = useWindowStore((state) => state.tilePreviewZone)

  const openWindow = useWindowStore((state) => state.openWindow)
  const closeWindow = useWindowStore((state) => state.closeWindow)
  const minimizeWindow = useWindowStore((state) => state.minimizeWindow)
  const maximizeWindow = useWindowStore((state) => state.maximizeWindow)
  const restoreWindow = useWindowStore((state) => state.restoreWindow)
  const focusWindow = useWindowStore((state) => state.focusWindow)
  const moveWindow = useWindowStore((state) => state.moveWindow)
  const resizeWindow = useWindowStore((state) => state.resizeWindow)
  const tileWindow = useWindowStore((state) => state.tileWindow)
  const setTilePreviewZone = useWindowStore((state) => state.setTilePreviewZone)

  return {
    windows,
    activeWindowId,
    tilePreviewZone,
    openWindow,
    closeWindow,
    minimizeWindow,
    maximizeWindow,
    restoreWindow,
    focusWindow,
    moveWindow,
    resizeWindow,
    tileWindow,
    setTilePreviewZone,
  }
}
