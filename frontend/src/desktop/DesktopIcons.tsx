import { appDefinitions } from '@/apps/registry'
import { useWindowManager } from '@/wm/useWindowManager'

export function DesktopIcons() {
  const openWindow = useWindowManager().openWindow
  const rows = 6

  return (
    <div className="absolute left-4 top-4 z-10 max-w-[calc(100vw-1rem)] overflow-x-auto pb-2">
      <div
        className="grid w-max auto-cols-[112px] grid-flow-col gap-2"
        style={{
          gridTemplateRows: `repeat(${rows}, 88px)`,
        }}
      >
        {appDefinitions.map((app) => {
          const Icon = app.icon

          return (
            <button
              key={app.id}
              type="button"
              title={app.description}
              onClick={() => openWindow(app.id)}
              className="group flex h-full w-full flex-col items-center justify-center rounded px-2 text-center transition hover:bg-black/10"
            >
              <span className="mb-2 grid h-10 w-10 place-items-center rounded-lg border border-[#7b5a43]/50 bg-[#f5e8d7]/35 text-[#fff7ed] backdrop-blur-[2px]">
                <Icon className="h-5 w-5" />
              </span>
              <span className="line-clamp-2 text-xs font-medium leading-tight text-white [text-shadow:0_1px_3px_rgba(0,0,0,0.85)]">
                {app.title}
              </span>
            </button>
          )
        })}
      </div>
    </div>
  )
}
