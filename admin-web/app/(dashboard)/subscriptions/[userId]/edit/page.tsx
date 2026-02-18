'use client'

import { useState, useEffect } from 'react'
import { toast } from 'sonner'
import { useParams, useRouter } from 'next/navigation'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { searchUsers, updateSubscription, createPaymentRecord } from '@/lib/api/admin'
import type { SubscriptionTier, SubscriptionStatus } from '@/types/admin'
import { LoadingState } from '@/components/ui/loading-spinner'
import { ErrorState } from '@/components/ui/empty-state'

const TIER_OPTIONS: { value: SubscriptionTier; label: string; icon: string; description: string }[] = [
  { value: 'free', label: 'Free', icon: '🆓', description: '8 tokens per day - Basic access' },
  { value: 'standard', label: 'Standard', icon: '⭐', description: '20 tokens per day - Standard features' },
  { value: 'plus', label: 'Plus', icon: '✨', description: '50 tokens per day - Enhanced features' },
  { value: 'premium', label: 'Premium', icon: '👑', description: 'Unlimited tokens - Full access' },
]

const STATUS_OPTIONS: { value: SubscriptionStatus | 'trial' | 'in_progress'; label: string; color: string; description: string }[] = [
  { value: 'trial', label: 'Trial', color: 'bg-blue-100 text-blue-800', description: 'Trial period subscription' },
  { value: 'created', label: 'Created', color: 'bg-slate-100 text-slate-800', description: 'Subscription created, awaiting payment' },
  { value: 'in_progress', label: 'In Progress', color: 'bg-purple-100 text-purple-800', description: 'Payment authorized but not captured yet' },
  { value: 'active', label: 'Active', color: 'bg-green-100 text-green-800', description: 'Active paid subscription' },
  { value: 'pending_cancellation', label: 'Pending Cancellation', color: 'bg-yellow-100 text-yellow-800', description: 'User cancelled but still has access until period end' },
  { value: 'paused', label: 'Paused', color: 'bg-orange-100 text-orange-800', description: 'Temporarily paused (not currently used)' },
  { value: 'cancelled', label: 'Cancelled', color: 'bg-red-100 text-red-800', description: 'Fully cancelled and inactive' },
  { value: 'completed', label: 'Completed', color: 'bg-teal-100 text-teal-800', description: 'Subscription period completed successfully' },
  { value: 'expired', label: 'Expired', color: 'bg-gray-100 text-gray-800', description: 'Subscription expired without renewal' },
]

const PROVIDER_OPTIONS = [
  { value: 'trial', label: 'Trial' },
  { value: 'system', label: 'System' },
  { value: 'razorpay', label: 'Razorpay' },
  { value: 'google_play', label: 'Google Play' },
  { value: 'apple_appstore', label: 'Apple App Store' },
]

const BILLING_CYCLE_OPTIONS = [
  { value: 'monthly', label: 'Monthly' },
  { value: 'yearly', label: 'Yearly' },
]

const PAYMENT_METHODS = [
  { value: 'bank_transfer', label: 'Bank Transfer' },
  { value: 'cash', label: 'Cash' },
  { value: 'cheque', label: 'Cheque' },
  { value: 'other', label: 'Other' },
]

export default function EditSubscriptionPage() {
  const params = useParams()
  const router = useRouter()
  const queryClient = useQueryClient()
  const userId = params.userId as string

  // Subscription fields
  const [selectedTier, setSelectedTier] = useState<SubscriptionTier>('free')
  const [selectedStatus, setSelectedStatus] = useState<SubscriptionStatus | 'trial'>('active')
  const [currentPeriodEnd, setCurrentPeriodEnd] = useState<string>('')
  const [nextPaymentDate, setNextPaymentDate] = useState<string>('')
  const [provider, setProvider] = useState<string>('razorpay')
  const [billingCycle, setBillingCycle] = useState<'monthly' | 'yearly'>('monthly')
  const [planName, setPlanName] = useState<string>('')
  const [amount, setAmount] = useState<string>('')
  const [currency, setCurrency] = useState<string>('INR')
  const [reason, setReason] = useState('')
  const [subscriptionId, setSubscriptionId] = useState<string>('')

  // Payment record fields
  const [showPaymentForm, setShowPaymentForm] = useState(false)
  const [paymentAmount, setPaymentAmount] = useState('')
  const [paymentMethod, setPaymentMethod] = useState<'bank_transfer' | 'cash' | 'cheque' | 'other'>('bank_transfer')
  const [paymentDate, setPaymentDate] = useState(new Date().toISOString().split('T')[0])
  const [paymentReference, setPaymentReference] = useState('')
  const [paymentNotes, setPaymentNotes] = useState('')

  // Fetch user details
  const { data: user, isLoading, error } = useQuery({
    queryKey: ['user-details', userId],
    queryFn: async () => {
      const result = await searchUsers({ query: userId })
      const foundUser = result.users.find(u => u.id === userId)
      if (!foundUser) throw new Error('User not found')
      return foundUser
    },
    refetchOnMount: 'always', // Always fetch fresh data when component mounts
  })

  // Update form fields when user data changes
  useEffect(() => {
    if (user?.subscriptions) {
      const activeSub = user.subscriptions.find(s =>
        ['active', 'trial', 'in_progress', 'pending_cancellation'].includes(s.status)
      )
      if (activeSub) {
        setSubscriptionId(activeSub.id)
        setSelectedTier(activeSub.tier)

        // Map database status to editable status options
        // Use status directly if it exists in STATUS_OPTIONS, otherwise default to 'active'
        const statusExists = STATUS_OPTIONS.find(opt => opt.value === activeSub.status)
        const mappedStatus = statusExists ? activeSub.status : 'active'
        setSelectedStatus(mappedStatus as any)

        setCurrentPeriodEnd(activeSub.current_period_end?.split('T')[0] || '')
        setNextPaymentDate(activeSub.next_billing_at?.split('T')[0] || '')
        setProvider(activeSub.provider || 'razorpay')
        setBillingCycle(activeSub.subscription_plans?.billing_cycle || 'monthly')
        setPlanName(activeSub.subscription_plans?.plan_name || '')
        setAmount(activeSub.subscription_plans?.price_inr?.toString() || '')
        setCurrency(activeSub.currency || 'INR')
      }
    }
  }, [user])

  // Update subscription mutation
  const updateMutation = useMutation({
    mutationFn: async (data: {
      newTier: SubscriptionTier
      newStatus?: SubscriptionStatus
      currentPeriodEnd?: string
      nextBillingAt?: string
      provider?: string
      billingCycle?: 'monthly' | 'yearly'
      planName?: string
      amount?: number
      reason?: string
    }) => {
      return updateSubscription({
        target_user_id: userId,
        new_tier: data.newTier,
        new_status: data.newStatus,
        current_period_end: data.currentPeriodEnd,
        next_billing_at: data.nextBillingAt,
        billing_cycle: data.billingCycle,
        plan_name: data.planName,
        reason: data.reason,
      })
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user-details', userId] })
      router.push(`/subscriptions/${userId}`)
    },
  })

  // Create payment record mutation
  const paymentMutation = useMutation({
    mutationFn: async () => {
      if (!subscriptionId) throw new Error('No subscription ID')
      return createPaymentRecord({
        user_id: userId,
        subscription_id: subscriptionId,
        amount: parseFloat(paymentAmount),
        currency: currency as 'INR' | 'USD',
        payment_method: paymentMethod,
        payment_date: paymentDate,
        reference_number: paymentReference || undefined,
        notes: paymentNotes || undefined,
      })
    },
    onSuccess: () => {
      // Reset payment form
      setShowPaymentForm(false)
      setPaymentAmount('')
      setPaymentReference('')
      setPaymentNotes('')
      toast.success('Payment record created successfully!')
    },
    onError: (error) => {
      toast.error(`Failed to create payment record: ${error instanceof Error ? error.message : 'Unknown error'}`)
    },
  })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    updateMutation.mutate({
      newTier: selectedTier,
      newStatus: selectedStatus,
      currentPeriodEnd: currentPeriodEnd || undefined,
      nextBillingAt: nextPaymentDate || undefined,
      provider: provider || undefined,
      billingCycle: billingCycle,
      planName: planName || undefined,
      amount: amount ? parseFloat(amount) : undefined,
      reason: reason || undefined,
    })
  }

  const handleCreatePayment = (e: React.FormEvent) => {
    e.preventDefault()
    if (!paymentAmount || parseFloat(paymentAmount) <= 0) {
      toast.error('Please enter a valid payment amount')
      return
    }
    paymentMutation.mutate()
  }

  if (isLoading) {
    return <LoadingState label="Loading subscriptions..." />
  }

  if (error || !user) {
    return (
      <ErrorState title="Error loading subscriptions" message={error instanceof Error ? error.message : 'User not found'} />
    )
  }

  return (
    <div className="space-y-6">
      {/* Back Button */}
      <button
        onClick={() => router.push(`/subscriptions/${userId}`)}
        className="mb-4 flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100"
      >
        <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
        </svg>
        Back to User Details
      </button>

      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">Edit Subscription</h1>
        <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
          Update subscription details for {user.full_name || user.email}
        </p>
      </div>

      {/* Subscription Edit Form */}
      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Plan & Status Section */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
          <h2 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">Plan & Status</h2>

          {/* Tier Selection */}
          <div className="mb-6">
            <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
              Subscription Tier
            </label>
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
              {TIER_OPTIONS.map((option) => (
                <button
                  key={option.value}
                  type="button"
                  onClick={() => setSelectedTier(option.value)}
                  className={`rounded-lg border-2 p-4 text-left transition-all ${
                    selectedTier === option.value
                      ? 'border-primary bg-primary-50 dark:bg-primary-900/20'
                      : 'border-gray-200 bg-white hover:border-gray-300 dark:border-gray-700 dark:bg-gray-800'
                  }`}
                >
                  <div className="flex items-center gap-2">
                    <span className="text-2xl">{option.icon}</span>
                    <span className="font-semibold text-gray-900 dark:text-gray-100">{option.label}</span>
                  </div>
                  <p className="mt-1 text-xs text-gray-600 dark:text-gray-400">{option.description}</p>
                </button>
              ))}
            </div>
          </div>

          {/* Status Selection */}
          <div className="mb-6">
            <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
              Subscription Status
            </label>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
              {STATUS_OPTIONS.map((option) => (
                <button
                  key={option.value}
                  type="button"
                  onClick={() => setSelectedStatus(option.value)}
                  title={option.description}
                  className={`rounded-lg border-2 p-3 text-center transition-all ${
                    selectedStatus === option.value
                      ? 'border-primary bg-primary-50 dark:bg-primary-900/20'
                      : 'border-gray-200 bg-white hover:border-gray-300 dark:border-gray-700 dark:bg-gray-800'
                  }`}
                >
                  <span className={`inline-block rounded-full px-3 py-1 text-xs font-medium ${option.color}`}>
                    {option.label}
                  </span>
                  <p className="mt-2 text-xs text-gray-500 dark:text-gray-400">
                    {option.description}
                  </p>
                </button>
              ))}
            </div>
          </div>

          {/* Provider Selection */}
          <div className="mb-6">
            <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
              Payment Provider
            </label>
            <select
              value={provider}
              onChange={(e) => setProvider(e.target.value)}
              className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
            >
              {PROVIDER_OPTIONS.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </div>
        </div>

        {/* Billing Details Section */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
          <h2 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">Billing Details</h2>

          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            {/* Plan Name */}
            <div>
              <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                Plan Name
              </label>
              <input
                type="text"
                value={planName}
                onChange={(e) => setPlanName(e.target.value)}
                placeholder="e.g., Premium Monthly"
                className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
              />
            </div>

            {/* Billing Cycle */}
            <div>
              <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                Billing Cycle
              </label>
              <select
                value={billingCycle}
                onChange={(e) => setBillingCycle(e.target.value as 'monthly' | 'yearly')}
                className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
              >
                {BILLING_CYCLE_OPTIONS.map((option) => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </div>

            {/* Amount */}
            <div>
              <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                Subscription Amount (₹)
              </label>
              <input
                type="number"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="e.g., 499"
                min="0"
                step="0.01"
                className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
              />
            </div>

            {/* Currency */}
            <div>
              <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                Currency
              </label>
              <select
                value={currency}
                onChange={(e) => setCurrency(e.target.value)}
                className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
              >
                <option value="INR">INR (₹)</option>
                <option value="USD">USD ($)</option>
              </select>
            </div>
          </div>
        </div>

        {/* Dates Section */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
          <h2 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">Subscription Dates</h2>

          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            {/* Current Period End */}
            <div>
              <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                Current Period End
              </label>
              <input
                type="date"
                value={currentPeriodEnd}
                onChange={(e) => setCurrentPeriodEnd(e.target.value)}
                className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
              />
              <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
                When current access expires (even if cancelled)
              </p>
            </div>

            {/* Next Payment Date */}
            <div>
              <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                Next Payment Date
              </label>
              <input
                type="date"
                value={nextPaymentDate}
                onChange={(e) => setNextPaymentDate(e.target.value)}
                className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
              />
              <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
                When payment will be charged (leave empty for cancelled/expired)
              </p>
            </div>
          </div>
        </div>

        {/* Admin Notes */}
        <div className="rounded-lg border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-800">
          <h2 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">Admin Notes</h2>
          <div>
            <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
              Reason for Change (Optional)
            </label>
            <textarea
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder="e.g., Customer support request, promotional upgrade, etc."
              rows={3}
              className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
            />
          </div>
        </div>

        {/* Action Buttons */}
        <div className="flex items-center justify-end gap-3">
          <button
            type="button"
            onClick={() => router.push(`/subscriptions/${userId}`)}
            className="rounded-lg border border-gray-300 bg-white px-6 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={updateMutation.isPending}
            className="rounded-lg bg-primary px-6 py-2 text-sm font-medium text-white hover:bg-primary-600 disabled:opacity-50"
          >
            {updateMutation.isPending ? 'Saving...' : 'Save Changes'}
          </button>
        </div>
      </form>

      {/* Manual Payment Record Section */}
      <div className="rounded-lg border border-blue-200 bg-blue-50 p-6 dark:border-blue-800 dark:bg-blue-900/20">
        <div className="mb-4 flex items-center justify-between">
          <div>
            <h2 className="text-lg font-semibold text-blue-900 dark:text-blue-100">Manual Payment Record</h2>
            <p className="mt-1 text-sm text-blue-700 dark:text-blue-300">
              Record manual payments (bank transfer, cash, etc.)
            </p>
          </div>
          <button
            type="button"
            onClick={() => setShowPaymentForm(!showPaymentForm)}
            className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
          >
            {showPaymentForm ? 'Hide Form' : 'Add Payment'}
          </button>
        </div>

        {showPaymentForm && (
          <form onSubmit={handleCreatePayment} className="mt-4 space-y-4 rounded-lg border border-blue-300 bg-white p-4 dark:border-blue-700 dark:bg-gray-800">
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
              {/* Payment Amount */}
              <div>
                <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                  Payment Amount (₹) *
                </label>
                <input
                  type="number"
                  value={paymentAmount}
                  onChange={(e) => setPaymentAmount(e.target.value)}
                  placeholder="e.g., 499"
                  min="0"
                  step="0.01"
                  required
                  className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
                />
              </div>

              {/* Payment Method */}
              <div>
                <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                  Payment Method *
                </label>
                <select
                  value={paymentMethod}
                  onChange={(e) => setPaymentMethod(e.target.value as any)}
                  required
                  className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
                >
                  {PAYMENT_METHODS.map((method) => (
                    <option key={method.value} value={method.value}>
                      {method.label}
                    </option>
                  ))}
                </select>
              </div>

              {/* Payment Date */}
              <div>
                <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                  Payment Date *
                </label>
                <input
                  type="date"
                  value={paymentDate}
                  onChange={(e) => setPaymentDate(e.target.value)}
                  required
                  className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
                />
              </div>

              {/* Reference Number */}
              <div>
                <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                  Reference Number (Optional)
                </label>
                <input
                  type="text"
                  value={paymentReference}
                  onChange={(e) => setPaymentReference(e.target.value)}
                  placeholder="e.g., TXN123456"
                  className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
                />
              </div>
            </div>

            {/* Payment Notes */}
            <div>
              <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                Notes (Optional)
              </label>
              <textarea
                value={paymentNotes}
                onChange={(e) => setPaymentNotes(e.target.value)}
                placeholder="Additional details about this payment..."
                rows={2}
                className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:border-primary focus:ring-2 focus:ring-primary dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100"
              />
            </div>

            {/* Payment Action Buttons */}
            <div className="flex items-center justify-end gap-3">
              <button
                type="button"
                onClick={() => setShowPaymentForm(false)}
                className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-300"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={paymentMutation.isPending}
                className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
              >
                {paymentMutation.isPending ? 'Creating...' : 'Create Payment Record'}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  )
}
