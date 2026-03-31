import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import '@fontsource/exo-2/500.css'
import '@fontsource/ibm-plex-sans/400.css'
import '@fontsource/ibm-plex-sans/500.css'
import '@fontsource/jetbrains-mono/400.css'
import './index.css'
import { Desktop } from './Desktop'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Desktop />
  </StrictMode>,
)
