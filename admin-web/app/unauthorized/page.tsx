'use client'

import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

export default function UnauthorizedPage() {
  const router = useRouter()
  const supabase = createClient()

  const handleSignOut = async () => {
    await supabase.auth.signOut()
    router.push('/login')
  }

  return (
    <div style={{
      display: 'flex',
      minHeight: '100vh',
      alignItems: 'center',
      justifyContent: 'center',
      background: 'linear-gradient(to bottom right, #fef2f2, #ffffff, #fee2e2)'
    }}>
      <div style={{
        width: '100%',
        maxWidth: '28rem',
        padding: '2.5rem',
        background: 'white',
        borderRadius: '1rem',
        boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.25)',
        textAlign: 'center'
      }}>
        <div style={{
          width: '64px',
          height: '64px',
          margin: '0 auto 1.5rem',
          background: 'linear-gradient(to bottom right, #dc2626, #ef4444)',
          borderRadius: '50%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          boxShadow: '0 10px 15px -3px rgba(220, 38, 38, 0.3)'
        }}>
          <svg style={{ width: '40px', height: '40px', color: 'white' }} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
          </svg>
        </div>
        <h1 style={{ fontSize: '1.875rem', fontWeight: 'bold', color: '#111827', marginBottom: '0.5rem' }}>Access Denied</h1>
        <p style={{ color: '#6b7280', fontSize: '1rem', marginBottom: '1.5rem', lineHeight: '1.5' }}>
          You don't have permission to access the admin dashboard.
        </p>
        <button onClick={handleSignOut} style={{
          width: '100%', padding: '0.75rem 1.5rem', background: 'linear-gradient(to right, #dc2626, #ef4444)',
          color: 'white', border: 'none', borderRadius: '0.5rem', fontSize: '1rem', fontWeight: 500,
          cursor: 'pointer', boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)'
        }}>Sign Out</button>
      </div>
    </div>
  )
}
