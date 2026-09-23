'use client'
// marketing/components/ui/FilterDropdown.tsx
// Themed dropdown used by the blog and learning-path filter bars.
import { useEffect, useRef, useState } from 'react'

export type DropdownOption = { value: string; label: string }

export function FilterDropdown({
  options,
  value,
  onChange,
  icon,
  placeholder,
}: {
  options: DropdownOption[]
  value: string
  onChange: (val: string) => void
  icon: React.ReactNode
  placeholder: string
}) {
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)

  // close on outside click
  useEffect(() => {
    if (!open) return
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [open])

  // close on Escape
  useEffect(() => {
    if (!open) return
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false)
    }
    document.addEventListener('keydown', handler)
    return () => document.removeEventListener('keydown', handler)
  }, [open])

  const active = value !== '' && value !== options[0]?.value
  const selectedLabel = options.find((o) => o.value === value)?.label ?? placeholder

  return (
    <div ref={ref} className="relative">
      {/* Trigger button */}
      <button
        type="button"
        aria-haspopup="listbox"
        aria-expanded={open}
        onClick={() => setOpen((v) => !v)}
        className={`inline-flex items-center gap-1.5 text-sm rounded-full px-3.5 py-1.5
          border transition-all duration-200 cursor-pointer select-none
          focus:outline-none focus-visible:ring-2 focus-visible:ring-primary/30 focus-visible:ring-offset-1
          ${active
            ? 'bg-primary/10 dark:bg-indigo-500/15 border-primary/25 dark:border-indigo-400/25 text-primary dark:text-indigo-300 shadow-sm shadow-primary/5'
            : 'bg-[var(--surface)] border-[var(--border)] text-[var(--muted)] hover:text-[var(--text)] hover:border-[var(--text)]/15 hover:shadow-sm'
          }`}
      >
        <span className={`transition-colors ${active ? 'text-primary dark:text-indigo-400' : 'opacity-60'}`}>
          {icon}
        </span>
        <span className={`max-w-[8rem] truncate ${active ? 'font-medium' : ''}`}>
          {selectedLabel}
        </span>
        <svg
          className={`w-3 h-3 flex-shrink-0 transition-transform duration-200 ${open ? 'rotate-180' : ''} ${active ? 'text-primary/50' : 'opacity-40'}`}
          fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}
        >
          <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {/* Dropdown menu */}
      {open && (
        <div
          role="listbox"
          className="absolute z-50 mt-1.5 left-0 min-w-[10rem] max-h-64 overflow-y-auto
          rounded-xl border border-[var(--border)] bg-[var(--surface)]
          shadow-lg shadow-black/8 dark:shadow-black/25
          py-1 animate-dropdown"
        >
          {options.map((opt) => (
            <button
              key={opt.value}
              type="button"
              role="option"
              aria-selected={opt.value === value}
              onClick={() => { onChange(opt.value); setOpen(false) }}
              className={`w-full text-left text-sm px-3.5 py-2 transition-colors duration-100
                ${opt.value === value
                  ? 'bg-primary/10 dark:bg-indigo-500/15 text-primary dark:text-indigo-300 font-medium'
                  : 'text-[var(--text)] hover:bg-[var(--border)]/60 dark:hover:bg-white/5'
                }`}
            >
              {opt.label}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
