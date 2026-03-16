'use client'
// marketing/components/blog/ReadingProgress.tsx
import { useState, useEffect } from 'react'

export function ReadingProgress({ gradient }: { gradient: string }) {
  const [width, setWidth] = useState(0)

  useEffect(() => {
    const onScroll = () => {
      const d = document.documentElement
      const scrolled = d.scrollTop
      const total = d.scrollHeight - d.clientHeight
      setWidth(total > 0 ? Math.min(100, (scrolled / total) * 100) : 0)
    }
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  return (
    <div className="fixed top-0 left-0 right-0 z-50 h-[3px] bg-transparent">
      <div
        className={`h-full bg-gradient-to-r ${gradient} transition-[width] duration-75 ease-out`}
        style={{ width: `${width}%` }}
      />
    </div>
  )
}
