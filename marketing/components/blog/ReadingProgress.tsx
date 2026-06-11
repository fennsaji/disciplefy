'use client'
// marketing/components/blog/ReadingProgress.tsx
import { useState, useEffect } from 'react'

export function ReadingProgress({ gradient }: { gradient: string }) {
  const [width, setWidth] = useState(0)

  useEffect(() => {
    let raf = 0
    const onScroll = () => {
      cancelAnimationFrame(raf)
      raf = requestAnimationFrame(() => {
        const d = document.documentElement
        const total = d.scrollHeight - d.clientHeight
        setWidth(total > 0 ? Math.min(100, (d.scrollTop / total) * 100) : 0)
      })
    }
    window.addEventListener('scroll', onScroll, { passive: true })
    onScroll()
    return () => {
      window.removeEventListener('scroll', onScroll)
      cancelAnimationFrame(raf)
    }
  }, [])

  return (
    <div
      role="progressbar"
      aria-label="Reading progress"
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={Math.round(width)}
      className="fixed top-0 left-0 right-0 z-50 h-[3px] bg-transparent"
    >
      <div
        className={`h-full bg-gradient-to-r ${gradient} transition-[width] duration-75 ease-out`}
        style={{ width: `${width}%` }}
      />
    </div>
  )
}
