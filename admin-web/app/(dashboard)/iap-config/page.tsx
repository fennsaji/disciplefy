'use client'

import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tantml:query'
import { toast } from 'sonner'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Textarea } from '@/components/ui/textarea'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Switch } from '@/components/ui/switch'
import { Badge } from '@/components/ui/badge'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import {
  CheckCircle2,
  XCircle,
  Loader2,
  Key,
  Package,
  ShieldCheck,
} from 'lucide-react'

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

export default function IAPConfigPage() {
  const [activeProvider, setActiveProvider] = useState<Provider>('google_play')
  const [activeEnvironment, setActiveEnvironment] =
    useState<Environment>('production')
  const queryClient = useQueryClient()

  // Fetch IAP Configuration
  const { data: iapConfigData, isLoading: configLoading } = useQuery({
    queryKey: ['iap-config', activeProvider, activeEnvironment],
    queryFn: async () => {
      const res = await fetch(
        `/api/admin/iap/config?provider=${activeProvider}&environment=${activeEnvironment}`,
        {
          credentials: 'include',
        }
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
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">
            In-App Purchase Configuration
          </h1>
          <p className="text-muted-foreground mt-2">
            Manage Google Play and Apple App Store credentials and product IDs
          </p>
        </div>
      </div>

      <Tabs defaultValue="credentials" className="space-y-6">
        <TabsList>
          <TabsTrigger value="credentials" className="gap-2">
            <Key className="h-4 w-4" />
            Provider Credentials
          </TabsTrigger>
          <TabsTrigger value="products" className="gap-2">
            <Package className="h-4 w-4" />
            Product IDs
          </TabsTrigger>
          <TabsTrigger value="verification" className="gap-2">
            <ShieldCheck className="h-4 w-4" />
            Receipt Verification
          </TabsTrigger>
        </TabsList>

        {/* Credentials Tab */}
        <TabsContent value="credentials" className="space-y-6">
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
        </TabsContent>

        {/* Product IDs Tab */}
        <TabsContent value="products">
          <ProductIDManagement
            products={products}
            isLoading={productsLoading}
            onUpdate={(data) => updateProductId.mutate(data)}
            isUpdating={updateProductId.isPending}
          />
        </TabsContent>

        {/* Receipt Verification Tab */}
        <TabsContent value="verification">
          <ReceiptVerificationTool />
        </TabsContent>
      </Tabs>
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

  // Initialize form data from configs
  useState(() => {
    const data: Record<string, string> = {}
    configs.forEach((config) => {
      data[config.config_key] = config.config_value
      if (config.is_active) setIsActive(true)
    })
    setFormData(data)
  })

  const handleSave = () => {
    onUpdate({ configs: formData, is_active: isActive })
  }

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <div>
            <CardTitle className="flex items-center gap-2">
              {icon}
              {title}
              <Badge variant={isActive ? 'default' : 'secondary'}>
                {isActive ? 'Active' : 'Inactive'}
              </Badge>
            </CardTitle>
            <CardDescription>{description}</CardDescription>
          </div>
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2">
              <Label htmlFor={`${provider}-active`}>Active</Label>
              <Switch
                id={`${provider}-active`}
                checked={isActive}
                onCheckedChange={setIsActive}
              />
            </div>
            <Select
              value={environment}
              onValueChange={(val) =>
                onEnvironmentChange(val as Environment)
              }
            >
              <SelectTrigger className="w-40">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="production">Production</SelectItem>
                <SelectItem value="sandbox">Sandbox</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        {isLoading ? (
          <div className="flex items-center justify-center py-8">
            <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
          </div>
        ) : (
          <>
            {fields.map((field) => (
              <div key={field.key} className="space-y-2">
                <Label htmlFor={`${provider}-${field.key}`}>
                  {field.label}
                </Label>
                {field.type === 'textarea' ? (
                  <Textarea
                    id={`${provider}-${field.key}`}
                    placeholder={field.placeholder}
                    value={formData[field.key] || ''}
                    onChange={(e) =>
                      setFormData({
                        ...formData,
                        [field.key]: e.target.value,
                      })
                    }
                    rows={field.rows || 4}
                    className="font-mono text-xs"
                  />
                ) : (
                  <Input
                    id={`${provider}-${field.key}`}
                    placeholder={field.placeholder}
                    value={formData[field.key] || ''}
                    onChange={(e) =>
                      setFormData({
                        ...formData,
                        [field.key]: e.target.value,
                      })
                    }
                    type={field.type || 'text'}
                  />
                )}
                <p className="text-sm text-muted-foreground">
                  {field.description}
                </p>
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
                      Store the shared secret securely. Apple recommends using
                      an app-specific shared secret instead of your master
                      shared secret.
                    </p>
                  </div>
                </div>
              </div>
            )}

            <div className="flex justify-end pt-4">
              <Button
                onClick={handleSave}
                disabled={isUpdating}
                className="gap-2"
              >
                {isUpdating && (
                  <Loader2 className="h-4 w-4 animate-spin" />
                )}
                Save {title}
              </Button>
            </div>
          </>
        )}
      </CardContent>
    </Card>
  )
}

// Google Play wrapper
function GooglePlayCredentials(props: Omit<React.ComponentProps<typeof IAPCredentialsCard>, 'provider' | 'title' | 'icon' | 'description' | 'fields'>) {
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
function AppleAppStoreCredentials(props: Omit<React.ComponentProps<typeof IAPCredentialsCard>, 'provider' | 'title' | 'icon' | 'description' | 'fields'>) {
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

  const handleSave = (
    plan_id: string,
    provider: Provider,
    product_id: string
  ) => {
    onUpdate({ plan_id, provider, product_id })
    setEditingProduct(null)
    setEditValue('')
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Product ID Mappings</CardTitle>
        <CardDescription>
          Map subscription plans to store product IDs for Google Play and Apple
          App Store
        </CardDescription>
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <div className="flex items-center justify-center py-8">
            <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
          </div>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Plan</TableHead>
                <TableHead>Provider</TableHead>
                <TableHead>Product ID</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {products.map((product) => {
                const key = `${product.id}-${product.provider}`
                const isEditing = editingProduct === key

                return (
                  <TableRow key={key}>
                    <TableCell className="font-medium">
                      {product.plan_name}
                      <div className="text-sm text-muted-foreground">
                        {product.plan_code}
                      </div>
                    </TableCell>
                    <TableCell>
                      <Badge variant="outline">
                        {product.provider === 'google_play'
                          ? 'Google Play'
                          : 'App Store'}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      {isEditing ? (
                        <Input
                          value={editValue}
                          onChange={(e) => setEditValue(e.target.value)}
                          placeholder="com.disciplefy.standard_monthly"
                          className="font-mono text-xs"
                        />
                      ) : (
                        <code className="text-xs">
                          {product.product_id || 'Not configured'}
                        </code>
                      )}
                    </TableCell>
                    <TableCell>
                      {product.product_id ? (
                        <div className="flex items-center gap-1 text-green-600">
                          <CheckCircle2 className="h-4 w-4" />
                          <span className="text-sm">Configured</span>
                        </div>
                      ) : (
                        <div className="flex items-center gap-1 text-yellow-600">
                          <XCircle className="h-4 w-4" />
                          <span className="text-sm">Missing</span>
                        </div>
                      )}
                    </TableCell>
                    <TableCell className="text-right">
                      {isEditing ? (
                        <div className="flex justify-end gap-2">
                          <Button
                            size="sm"
                            onClick={() =>
                              handleSave(
                                product.id,
                                product.provider,
                                editValue
                              )
                            }
                            disabled={isUpdating}
                          >
                            Save
                          </Button>
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() => {
                              setEditingProduct(null)
                              setEditValue('')
                            }}
                          >
                            Cancel
                          </Button>
                        </div>
                      ) : (
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() =>
                            handleEdit(key, product.product_id || '')
                          }
                        >
                          Edit
                        </Button>
                      )}
                    </TableCell>
                  </TableRow>
                )
              })}
            </TableBody>
          </Table>
        )}
      </CardContent>
    </Card>
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
    <Card>
      <CardHeader>
        <CardTitle>Receipt Verification Tool</CardTitle>
        <CardDescription>
          Test receipt validation with Google Play or Apple App Store
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="verify-provider">Provider</Label>
          <Select
            value={provider}
            onValueChange={(val) => setProvider(val as Provider)}
          >
            <SelectTrigger id="verify-provider">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="google_play">Google Play</SelectItem>
              <SelectItem value="apple_appstore">Apple App Store</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <Label htmlFor="receipt-data">Receipt Data</Label>
          <Textarea
            id="receipt-data"
            placeholder={
              provider === 'google_play'
                ? 'Paste Google Play receipt JSON here...'
                : 'Paste Apple App Store receipt (base64) here...'
            }
            value={receiptData}
            onChange={(e) => setReceiptData(e.target.value)}
            rows={10}
            className="font-mono text-xs"
          />
        </div>

        <Button
          onClick={handleVerify}
          disabled={isVerifying || !receiptData}
          className="gap-2"
        >
          {isVerifying && <Loader2 className="h-4 w-4 animate-spin" />}
          Verify Receipt
        </Button>

        {verificationResult && (
          <div className="mt-6 rounded-lg border p-4">
            <div className="flex items-center gap-2 mb-4">
              {verificationResult.success ? (
                <CheckCircle2 className="h-5 w-5 text-green-600" />
              ) : (
                <XCircle className="h-5 w-5 text-red-600" />
              )}
              <h3 className="font-semibold">
                {verificationResult.success
                  ? 'Verification Successful'
                  : 'Verification Failed'}
              </h3>
            </div>
            <pre className="rounded bg-muted p-4 text-xs overflow-auto max-h-96">
              {JSON.stringify(verificationResult, null, 2)}
            </pre>
          </div>
        )}
      </CardContent>
    </Card>
  )
}
