import { useState, type FormEvent } from 'react'

export default function UploadApp() {
  const [filename, setFilename] = useState('')
  const [language, setLanguage] = useState('typescript')
  const [submitted, setSubmitted] = useState<string | null>(null)

  const onSubmit = (event: FormEvent) => {
    event.preventDefault()
    if (!filename.trim()) {
      return
    }
    setSubmitted(`${filename} (${language})`)
    setFilename('')
  }

  return (
    <form onSubmit={onSubmit} className="grid h-full grid-rows-[1fr_auto] gap-3 text-sm">
      <div className="rounded-lg border border-dashed border-surface-3 bg-surface-1 p-4">
        <div className="mb-4 text-xs uppercase tracking-wide text-text-secondary">Upload Function Artifact</div>
        <div className="space-y-3">
          <input
            value={filename}
            onChange={(event) => setFilename(event.target.value)}
            placeholder="function.tar.gz"
            className="w-full rounded border border-surface-3 bg-surface-0 px-3 py-2"
          />
          <select
            value={language}
            onChange={(event) => setLanguage(event.target.value)}
            className="w-full rounded border border-surface-3 bg-surface-0 px-3 py-2"
          >
            <option value="typescript">TypeScript</option>
            <option value="python">Python</option>
            <option value="rust">Rust</option>
            <option value="go">Go</option>
          </select>
          <button type="submit" className="rounded bg-accent-cyan px-4 py-2 font-semibold text-slate-950">
            Queue Upload
          </button>
        </div>
      </div>
      <div className="text-xs text-text-secondary">{submitted ? `Queued: ${submitted}` : 'No pending uploads'}</div>
    </form>
  )
}
