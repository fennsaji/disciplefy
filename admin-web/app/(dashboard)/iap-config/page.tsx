'use client'

import { useState, useEffect } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { PageHeader } from '@/components/ui/page-header'
import { TabNav } from '@/components/ui/tab-nav'
import { LoadingState } from '@/components/ui/loading-spinner'

type Provider = 'google_play' | 'apple_appstore'
type Environment = 'production' | 'sandbox'

interface IAPConfig {
  id: string
  provider: Provider
  environment: Environment
  is_active: boolean
  config_key: string
  config_value: string
}

interface ProductMapping {
  id: string
  plan_code: string
  plan_name: string
  provider: Provider
  product_id: string | null
}

const IAP_TABS = [
  { value: 'credentials', label: 'Provider Credentials', icon: '🔑' },
  { value: 'products', label: 'Product IDs', icon: '📦' },
  { value: 'verification', label: 'Receipt Verification', icon: '🛡️' },
]

export default function IAPConfigPage() {
  const [activeTab, setActiveTab] = useState<'credentials' | 'products' | 'verification'>('credentials')
  const [activeEnvironment, setActiveEnvironment] = useState<Environment>('production')
  const queryClient = useQueryClient()

  // Fetch IAP Configuration
  const { data: iapConfigData, isLoading: configLoading } = useQuery({
    queryKey: ['iap-config', activeEnvironment],
    queryFn: async () => {
      const res = await fetch(
        `/api/admin/iap/config?environment=${activeEnvironment}`,
        { credentials: 'include' }
      )
      if (!res.ok) throw new Error('Failed to fetch IAP config')
      return res.json()
    },
  })

  // Fetch Product Mappings
  const { data: productsData, isLoading: productsLoading } = useQuery({
    queryKey: ['iap-products'],
    queryFn: async () => {
      const res = await fetch('/api/admin/iap/products', {
        credentials: 'include',
      })
      if (!res.ok) throw new Error('Failed to fetch product mappings')
      return res.json()
    },
  })

  // Update IAP Configuration
  const updateConfig = useMutation({
    mutationFn: async (data: {
      provider: Provider
      environment: Environment
      configs: Record<string, string>
      is_active: boolean
    }) => {
      const res = await fetch('/api/admin/iap/config', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(data),
      })
      if (!res.ok) throw new Error('Failed to update IAP config')
      return res.json()
    },
    onSuccess: () => {
      toast.success('IAP configuration updated successfully')
      queryClient.invalidateQueries({ queryKey: ['iap-config'] })
    },
    onError: (error) => {
      console.error('Update error:', error)
      toast.error('Failed to update IAP configuration')
    },
  })

  // Update Product ID
  const updateProductId = useMutation({
    mutationFn: async (data: {
      plan_id: string
      provider: Provider
      product_id: string
    }) => {
      const res = await fetch('/api/admin/iap/products', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(data),
      })
      if (!res.ok) throw new Error('Failed to update product ID')
      return res.json()
    },
    onSuccess: () => {
      toast.success('Product ID updated successfully')
      queryClient.invalidateQueries({ queryKey: ['iap-products'] })
    },
    onError: (error) => {
      console.error('Update error:', error)
      toast.error('Failed to update product ID')
    },
  })

  const configs = iapConfigData?.configs || []
  const products = productsData?.products || []

  return (
    <div className="space-y-6">
      <PageHeader
        title="In-App Purchase Configuration"
        description="Manage Google Play and Apple App Store credentials and product IDs"
      />

      <TabNav
        tabs={IAP_TABS}
        activeTab={activeTab}
        onChange={(val) => setActiveTab(val as typeof activeTab)}
      />

      {/* Credentials Tab */}
      {activeTab === 'credentials' && (
        <div className="space-y-6">
          <GooglePlayCredentials
            environment={activeEnvironment}
            onEnvironmentChange={setActiveEnvironment}
            configs={configs.filter(
              (c: IAPConfig) =>
                c.provider === 'google_play' &&
                c.environment === activeEnvironment
            )}
            isLoading={configLoading}
            onUpdate={(data) =>
              updateConfig.mutate({
                provider: 'google_play',
                environment: activeEnvironment,
                ...data,
              })
            }
            isUpdating={updateConfig.isPending}
          />

          <AppleAppStoreCredentials
            environment={activeEnvironment}
            onEnvironmentChange={setActiveEnvironment}
            configs={configs.filter(
              (c: IAPConfig) =>
                c.provider === 'apple_appstore' &&
                c.environment === activeEnvironment
            )}
            isLoading={configLoading}
            onUpdate={(data) =>
              updateConfig.mutate({
                provider: 'apple_appstore',
                environment: activeEnvironment,
                ...data,
              })
            }
            isUpdating={updateConfig.isPending}
          />
        </div>
      )}

      {/* Product IDs Tab */}
      {activeTab === 'products' && (
        <ProductIDManagement
          products={products}
          isLoading={productsLoading}
          onUpdate={(data) => updateProductId.mutate(data)}
          isUpdating={updateProductId.isPending}
        />
      )}

      {/* Receipt Verification Tab */}
      {activeTab === 'verification' && <ReceiptVerificationTool />}
    </div>
  )
}

// Generic IAP Credentials Component
function IAPCredentialsCard({
  provider,
  environment,
  onEnvironmentChange,
  configs,
  isLoading,
  onUpdate,
  isUpdating,
  title,
  icon,
  description,
  fields,
}: {
  provider: Provider
  environment: Environment
  onEnvironmentChange: (env: Environment) => void
  configs: IAPConfig[]
  isLoading: boolean
  onUpdate: (data: {
    configs: Record<string, string>
    is_active: boolean
  }) => void
  isUpdating: boolean
  title: string
  icon: React.ReactNode
  description: string
  fields: Array<{
    key: string
    label: string
    placeholder: string
    description: string
    type?: 'text' | 'password' | 'textarea'
    rows?: number
  }>
}) {
  const [formData, setFormData] = useState<Record<string, string>>({})
  const [isActive, setIsActive] = useState(false)

  // Initialize form data from configs whenever configs changes
  useEffect(() => {
    const data: Record<string, string> = {}
    let active = false
    configs.forEach((config) => {
      data[config.config_key] = config.config_value
      if (config.is_active) active = true
    })
    setFormData(data)
    setIsActive(active)
  }, [configs])

  const handleSave = () => {
    onUpdate({ configs: formData, is_active: isActive })
  }

  return (
    <div className="rounded-lg bg-white p-6 shadow-sm border border-gray-200 dark:bg-gray-800 dark:border-gray-700">
      {/* Card Header */}
      <div className="flex items-start justify-between gap-4 mb-6">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-100 flex items-center gap-2">
              {icon}
              {title}
            </h2>
            <span
              className={
                isActive
                  ? 'inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900/30 dark:text-green-300'
                  : 'inline-flex items-center rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-medium text-gray-600 dark:bg-gray-700 dark:text-gray-400'
              }
            >
              {isActive ? 'Active' : 'Inactive'}
            </span>
          </div>
          <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">{description}</p>
        </div>

        <div className="flex items-center gap-4 shrink-0">
          {/* Active toggle */}
          <div className="flex items-center gap-2">
            <label
              htmlFor={`${provider}-active`}
              className="block text-sm font-medium text-gray-700 dark:text-gray-300 cursor-pointer"
            >
              Active
            </label>
            <button
              id={`${provider}-active`}
              type="button"
              role="switch"
              aria-checked={isActive}
              onClick={() => setIsActive(!isActive)}
              className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 ${
                isActive ? 'bg-primary' : 'bg-gray-200 dark:bg-gray-600'
              }`}
            >
              <span
                className={`inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform ${
                  isActive ? 'translate-x-6' : 'translate-x-1'
                }`}
              />
            </button>
          </div>

          {/* Environment selector */}
          <select
            value={environment}
            onChange={(e) => onEnvironmentChange(e.target.value as Environment)}
            className="w-40 rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
          >
            <option value="production">Production</option>
            <option value="sandbox">Sandbox</option>
          </select>
        </div>
      </div>

      {/* Card Content */}
      {isLoading ? (
        <LoadingState label="Loading configuration..." />
      ) : (
        <div className="space-y-4">
          {fields.map((field) => (
            <div key={field.key} className="space-y-1">
              <label
                htmlFor={`${provider}-${field.key}`}
                className="block text-sm font-medium text-gray-700 dark:text-gray-300"
              >
                {field.label}
              </label>
              {field.type === 'textarea' ? (
                <textarea
                  id={`${provider}-${field.key}`}
                  placeholder={field.placeholder}
                  value={formData[field.key] || ''}
                  onChange={(e) =>
                    setFormData({ ...formData, [field.key]: e.target.value })
                  }
                  rows={field.rows || 4}
                  className="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder-gray-400 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-500 font-mono"
                />
              ) : (
                <input
                  id={`${provider}-${field.key}`}
                  type={field.type || 'text'}
                  placeholder={field.placeholder}
                  value={formData[field.key] || ''}
                  onChange={(e) =>
                    setFormData({ ...formData, [field.key]: e.target.value })
                  }
                  className="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder-gray-400 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-500"
                />
              )}
              <p className="text-sm text-gray-500 dark:text-gray-400">{field.description}</p>
            </div>
          ))}

          {provider === 'apple_appstore' && (
            <div className="rounded-lg border border-yellow-200 bg-yellow-50 p-4 dark:border-yellow-900 dark:bg-yellow-950">
              <div className="flex gap-3">
                <svg
                  className="h-5 w-5 flex-shrink-0 text-yellow-600 dark:text-yellow-500"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                >
                  <path
                    fillRule="evenodd"
                    d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495zM10 5a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 5zm0 9a1 1 0 100-2 1 1 0 000 2z"
                    clipRule="evenodd"
                  />
                </svg>
                <div className="text-sm text-yellow-800 dark:text-yellow-200">
                  <p className="font-medium">Important Security Note</p>
                  <p className="mt-1">
                    Store the shared secret securely. Apple recommends using an
                    app-specific shared secret instead of your master shared secret.
                  </p>
                </div>
              </div>
            </div>
          )}

          <div className="flex justify-end pt-4">
            <button
              type="button"
              onClick={handleSave}
              disabled={isUpdating}
              className="inline-flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isUpdating && (
                <span className="inline-block h-4 w-4 animate-spin rounded-full border-2 border-solid border-white border-r-transparent" />
              )}
              Save {title}
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

// Google Play wrapper
function GooglePlayCredentials(
  props: Omit<
    React.ComponentProps<typeof IAPCredentialsCard>,
    'provider' | 'title' | 'icon' | 'description' | 'fields'
  >
) {
  return (
    <IAPCredentialsCard
      {...props}
      provider="google_play"
      title="Google Play Configuration"
      icon={
        <svg className="h-6 w-6" viewBox="0 0 24 24">
          <path
            fill="currentColor"
            d="M3,20.5V3.5C3,2.91 3.34,2.39 3.84,2.15L13.69,12L3.84,21.85C3.34,21.6 3,21.09 3,20.5M16.81,15.12L6.05,21.34L14.54,12.85L16.81,15.12M20.16,10.81C20.5,11.08 20.75,11.5 20.75,12C20.75,12.5 20.5,12.92 20.16,13.19L17.89,14.5L15.39,12L17.89,9.5L20.16,10.81M6.05,2.66L16.81,8.88L14.54,11.15L6.05,2.66Z"
          />
        </svg>
      }
      description="Configure Google Play Developer API credentials for receipt validation"
      fields={[
        {
          key: 'service_account_email',
          label: 'Service Account Email',
          placeholder: 'service-account@project-id.iam.gserviceaccount.com',
          description:
            'Email address of the Google Cloud service account with access to Play Developer API',
        },
        {
          key: 'service_account_key',
          label: 'Service Account Private Key (JSON)',
          placeholder:
            '{"type": "service_account", "private_key": "-----BEGIN PRIVATE KEY-----\\n...", ...}',
          description: 'Full JSON key file downloaded from Google Cloud Console',
          type: 'textarea',
          rows: 6,
        },
        {
          key: 'package_name',
          label: 'Package Name',
          placeholder: 'com.disciplefy.app',
          description:
            'Android application package name registered in Google Play Console',
        },
      ]}
    />
  )
}

// Apple App Store wrapper
function AppleAppStoreCredentials(
  props: Omit<
    React.ComponentProps<typeof IAPCredentialsCard>,
    'provider' | 'title' | 'icon' | 'description' | 'fields'
  >
) {
  return (
    <IAPCredentialsCard
      {...props}
      provider="apple_appstore"
      title="Apple App Store Configuration"
      icon={
        <svg className="h-6 w-6" viewBox="0 0 24 24">
          <path
            fill="currentColor"
            d="M17.05 20.28c-.98.95-2.05.88-3.08.4-1.09-.5-2.08-.48-3.24 0-1.44.62-2.2.44-3.06-.4C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09l.01-.01M12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z"
          />
        </svg>
      }
      description="Configure Apple App Store credentials for receipt validation"
      fields={[
        {
          key: 'shared_secret',
          label: 'App-Specific Shared Secret',
          placeholder: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
          description:
            'Shared secret from App Store Connect → Your App → General → App-Specific Shared Secret',
          type: 'password',
        },
        {
          key: 'bundle_id',
          label: 'Bundle ID',
          placeholder: 'com.disciplefy.app',
          description: 'iOS application bundle identifier from Xcode',
        },
      ]}
    />
  )
}

// Product ID Management Component
function ProductIDManagement({
  products,
  isLoading,
  onUpdate,
  isUpdating,
}: {
  products: ProductMapping[]
  isLoading: boolean
  onUpdate: (data: {
    plan_id: string
    provider: Provider
    product_id: string
  }) => void
  isUpdating: boolean
}) {
  const [editingProduct, setEditingProduct] = useState<string | null>(null)
  const [editValue, setEditValue] = useState('')

  const handleEdit = (productId: string, currentValue: string) => {
    setEditingProduct(productId)
    setEditValue(currentValue || '')
  }

  const handleSave = (plan_id: string, provider: Provider, product_id: string) => {
    onUpdate({ plan_id, provider, product_id })
    setEditingProduct(null)
    setEditValue('')
  }

  return (
    <div className="rounded-lg bg-white p-6 shadow-sm border border-gray-200 dark:bg-gray-800 dark:border-gray-700">
      {/* Card Header */}
      <div className="mb-6">
        <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
          Product ID Mappings
        </h2>
        <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
          Map subscription plans to store product IDs for Google Play and Apple App Store
        </p>
      </div>

      {/* Card Content */}
      {isLoading ? (
        <LoadingState label="Loading product mappings..." />
      ) : (
        <div className="overflow-hidden rounded-lg border border-gray-200 dark:border-gray-700">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 dark:bg-gray-700/50">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                  Plan
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                  Provider
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                  Product ID
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                  Status
                </th>
                <th className="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
              {products.map((product) => {
                const key = `${product.id}-${product.provider}`
                const isEditing = editingProduct === key

                return (
                  <tr key={key} className="bg-white dark:bg-gray-800">
                    <td className="px-4 py-3 text-sm text-gray-900 dark:text-gray-100 font-medium">
                      {product.plan_name}
                      <div className="text-xs text-gray-500 dark:text-gray-400 font-normal">
                        {product.plan_code}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">
                      <span className="inline-flex items-center rounded-full border border-gray-300 dark:border-gray-600 px-2.5 py-0.5 text-xs font-medium text-gray-700 dark:text-gray-300">
                        {product.provider === 'google_play' ? 'Google Play' : 'App Store'}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">
                      {isEditing ? (
                        <input
                          type="text"
                          value={editValue}
                          onChange={(e) => setEditValue(e.target.value)}
                          placeholder="com.disciplefy.standard_monthly"
                          className="w-full rounded-lg border border-gray-300 bg-white px-3 py-1.5 text-xs text-gray-900 placeholder-gray-400 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-500 font-mono"
                        />
                      ) : (
                        <code className="text-xs text-gray-700 dark:text-gray-300">
                          {product.product_id || 'Not configured'}
                        </code>
                      )}
                    </td>
                    <td className="px-4 py-3 text-sm">
                      {product.product_id ? (
                        <div className="flex items-center gap-1 text-green-600 dark:text-green-400">
                          <svg
                            className="h-4 w-4"
                            fill="none"
                            viewBox="0 0 24 24"
                            stroke="currentColor"
                          >
                            <path
                              strokeLinecap="round"
                              strokeLinejoin="round"
                              strokeWidth={2}
                              d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                            />
                          </svg>
                          <span className="text-sm">Configured</span>
                        </div>
                      ) : (
                        <div className="flex items-center gap-1 text-yellow-600 dark:text-yellow-400">
                          <svg
                            className="h-4 w-4"
                            fill="none"
                            viewBox="0 0 24 24"
                            stroke="currentColor"
                          >
                            <path
                              strokeLinecap="round"
                              strokeLinejoin="round"
                              strokeWidth={2}
                              d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                            />
                          </svg>
                          <span className="text-sm">Missing</span>
                        </div>
                      )}
                    </td>
                    <td className="px-4 py-3 text-sm text-right">
                      {isEditing ? (
                        <div className="flex justify-end gap-2">
                          <button
                            type="button"
                            onClick={() => handleSave(product.id, product.provider, editValue)}
                            disabled={isUpdating}
                            className="inline-flex items-center gap-1 rounded-lg bg-primary px-3 py-1.5 text-xs font-medium text-white hover:bg-primary-600 disabled:opacity-50 disabled:cursor-not-allowed"
                          >
                            {isUpdating && (
                              <span className="inline-block h-3 w-3 animate-spin rounded-full border-2 border-solid border-white border-r-transparent" />
                            )}
                            Save
                          </button>
                          <button
                            type="button"
                            onClick={() => {
                              setEditingProduct(null)
                              setEditValue('')
                            }}
                            className="inline-flex items-center rounded-lg border border-gray-300 bg-white px-3 py-1.5 text-xs font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-200 dark:hover:bg-gray-700"
                          >
                            Cancel
                          </button>
                        </div>
                      ) : (
                        <button
                          type="button"
                          onClick={() => handleEdit(key, product.product_id || '')}
                          className="inline-flex items-center rounded-lg border border-gray-300 bg-white px-3 py-1.5 text-xs font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-200 dark:hover:bg-gray-700"
                        >
                          Edit
                        </button>
                      )}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

// Receipt Verification Tool Component
function ReceiptVerificationTool() {
  const [provider, setProvider] = useState<Provider>('google_play')
  const [receiptData, setReceiptData] = useState('')
  const [verificationResult, setVerificationResult] = useState<any>(null)
  const [isVerifying, setIsVerifying] = useState(false)

  const handleVerify = async () => {
    setIsVerifying(true)
    setVerificationResult(null)

    try {
      const res = await fetch('/api/admin/iap/verify-receipt', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          provider,
          receipt_data: receiptData,
        }),
      })

      const result = await res.json()
      setVerificationResult(result)

      if (result.success) {
        toast.success('Receipt verified successfully')
      } else {
        toast.error('Receipt verification failed')
      }
    } catch (error) {
      console.error('Verification error:', error)
      toast.error('Failed to verify receipt')
      setVerificationResult({ success: false, error: String(error) })
    } finally {
      setIsVerifying(false)
    }
  }

  return (
    <div className="rounded-lg bg-white p-6 shadow-sm border border-gray-200 dark:bg-gray-800 dark:border-gray-700">
      {/* Card Header */}
      <div className="mb-6">
        <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
          Receipt Verification Tool
        </h2>
        <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
          Test receipt validation with Google Play or Apple App Store
        </p>
      </div>

      {/* Card Content */}
      <div className="space-y-4">
        <div className="space-y-1">
          <label
            htmlFor="verify-provider"
            className="block text-sm font-medium text-gray-700 dark:text-gray-300"
          >
            Provider
          </label>
          <select
            id="verify-provider"
            value={provider}
            onChange={(e) => setProvider(e.target.value as Provider)}
            className="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
          >
            <option value="google_play">Google Play</option>
            <option value="apple_appstore">Apple App Store</option>
          </select>
        </div>

        <div className="space-y-1">
          <label
            htmlFor="receipt-data"
            className="block text-sm font-medium text-gray-700 dark:text-gray-300"
          >
            Receipt Data
          </label>
          <textarea
            id="receipt-data"
            placeholder={
              provider === 'google_play'
                ? 'Paste Google Play receipt JSON here...'
                : 'Paste Apple App Store receipt (base64) here...'
            }
            value={receiptData}
            onChange={(e) => setReceiptData(e.target.value)}
            rows={10}
            className="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder-gray-400 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 dark:placeholder-gray-500 font-mono"
          />
        </div>

        <button
          type="button"
          onClick={handleVerify}
          disabled={isVerifying || !receiptData}
          className="inline-flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-600 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isVerifying && (
            <span className="inline-block h-4 w-4 animate-spin rounded-full border-2 border-solid border-white border-r-transparent" />
          )}
          Verify Receipt
        </button>

        {verificationResult && (
          <div className="mt-6 rounded-lg border border-gray-200 dark:border-gray-700 p-4">
            <div className="flex items-center gap-2 mb-4">
              {verificationResult.success ? (
                <svg
                  className="h-5 w-5 text-green-600"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
              ) : (
                <svg
                  className="h-5 w-5 text-yellow-600"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
              )}
              <h3 className="font-semibold text-gray-900 dark:text-gray-100">
                {verificationResult.success
                  ? 'Verification Successful'
                  : 'Verification Failed'}
              </h3>
            </div>
            <pre className="rounded bg-gray-100 dark:bg-gray-800 p-4 text-xs overflow-auto max-h-96 text-gray-900 dark:text-gray-100">
              {JSON.stringify(verificationResult, null, 2)}
            </pre>
          </div>
        )}
      </div>
    </div>
  )
}
