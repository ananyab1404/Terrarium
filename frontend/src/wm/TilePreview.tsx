import { AnimatePresence, motion } from 'framer-motion'

import type { TileZone } from '@/types/app'
import { getTileGeometry } from '@/wm/tileGeometry'

type TilePreviewProps = {
  zone: TileZone | null
}

export function TilePreview({ zone }: TilePreviewProps) {
  return (
    <AnimatePresence>
      {zone ? (
        <motion.div
          key={zone}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.08 }}
          className="pointer-events-none absolute z-10 rounded-lg border-2 border-dashed border-accent-blue/50 bg-accent-blue/10"
          style={getTileGeometry(zone)}
        />
      ) : null}
    </AnimatePresence>
  )
}
