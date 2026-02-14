'use client'

import { useEffect } from 'react'

export default function TestConsolePage() {
  useEffect(() => {
    console.log('🔴🔴🔴 TEST PAGE LOADED - CONSOLE LOGGING WORKS! 🔴🔴🔴')
    console.log('🔴 Current time:', new Date().toISOString())
    console.error('🔴 This is an ERROR log')
    console.warn('🔴 This is a WARNING log')
    console.info('🔴 This is an INFO log')
    console.debug('🔴 This is a DEBUG log')
  }, [])

  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      background: 'linear-gradient(to bottom right, #fef2f2, #ffffff)',
      padding: '2rem'
    }}>
      <div style={{
        maxWidth: '48rem',
        background: 'white',
        borderRadius: '1rem',
        padding: '2.5rem',
        boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.25)'
      }}>
        <h1 style={{ fontSize: '2rem', fontWeight: 'bold', marginBottom: '1.5rem', color: '#dc2626' }}>
          🔴 Console Test Page
        </h1>

        <div style={{ marginBottom: '2rem' }}>
          <p style={{ marginBottom: '1rem', fontSize: '1.125rem' }}>
            If console logging is working, you should see <strong>RED CIRCLE EMOJI (🔴)</strong> logs in your browser console.
          </p>
        </div>

        <div style={{
          background: '#fef2f2',
          border: '2px solid #dc2626',
          borderRadius: '0.5rem',
          padding: '1.5rem',
          marginBottom: '2rem'
        }}>
          <h2 style={{ fontSize: '1.25rem', fontWeight: 'bold', marginBottom: '1rem', color: '#dc2626' }}>
            How to Check Console:
          </h2>
          <ol style={{ paddingLeft: '1.5rem', lineHeight: '1.75' }}>
            <li>Press <strong>F12</strong> (or Cmd+Option+I on Mac)</li>
            <li>Click the <strong>"Console"</strong> tab</li>
            <li>Check the filter dropdown - make sure <strong>"All levels"</strong> is selected</li>
            <li>Look for logs starting with 🔴</li>
            <li>If you see nothing:
              <ul style={{ paddingLeft: '1.5rem', marginTop: '0.5rem' }}>
                <li>Try clicking "Clear console" button (🚫 icon)</li>
                <li>Refresh the page (Ctrl+R or Cmd+R)</li>
                <li>Make sure "Preserve log" is enabled (checkbox near top)</li>
              </ul>
            </li>
          </ol>
        </div>

        <div style={{
          background: '#eff6ff',
          border: '2px solid #3b82f6',
          borderRadius: '0.5rem',
          padding: '1.5rem'
        }}>
          <h2 style={{ fontSize: '1.25rem', fontWeight: 'bold', marginBottom: '1rem', color: '#1e40af' }}>
            Expected Console Output:
          </h2>
          <pre style={{
            background: '#1e293b',
            color: '#e2e8f0',
            padding: '1rem',
            borderRadius: '0.5rem',
            overflow: 'auto',
            fontSize: '0.875rem'
          }}>
{`🔴🔴🔴 TEST PAGE LOADED - CONSOLE LOGGING WORKS! 🔴🔴🔴
🔴 Current time: 2026-02-06T...
🔴 This is an ERROR log
🔴 This is a WARNING log
🔴 This is an INFO log
🔴 This is a DEBUG log`}
          </pre>
        </div>

        <div style={{ marginTop: '2rem', textAlign: 'center' }}>
          <a
            href="/login"
            style={{
              display: 'inline-block',
              padding: '1rem 2rem',
              background: '#dc2626',
              color: 'white',
              borderRadius: '0.5rem',
              textDecoration: 'none',
              fontWeight: 'bold'
            }}
          >
            Go to Login Page →
          </a>
        </div>
      </div>
    </div>
  )
}
