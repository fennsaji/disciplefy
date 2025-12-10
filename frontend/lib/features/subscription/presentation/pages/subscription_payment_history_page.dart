import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/subscription.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';

/// Page displaying subscription payment history (invoices)
class SubscriptionPaymentHistoryPage extends StatefulWidget {
  const SubscriptionPaymentHistoryPage({super.key});

  @override
  State<SubscriptionPaymentHistoryPage> createState() =>
      _SubscriptionPaymentHistoryPageState();
}

class _SubscriptionPaymentHistoryPageState
    extends State<SubscriptionPaymentHistoryPage> {
  @override
  void initState() {
    super.initState();
    // Load invoices when page opens
    context.read<SubscriptionBloc>().add(const GetSubscriptionInvoices());
  }

  void _onRefresh() {
    context.read<SubscriptionBloc>().add(const RefreshSubscriptionInvoices());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Payment History'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _onRefresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _onRefresh();
          // Wait for bloc to complete
          await context
              .read<SubscriptionBloc>()
              .stream
              .where((state) =>
                  state is SubscriptionLoaded || state is SubscriptionError)
              .first
              .timeout(const Duration(seconds: 10))
              .catchError((_) => const SubscriptionInitial());
        },
        child: BlocBuilder<SubscriptionBloc, SubscriptionState>(
          buildWhen: (previous, current) =>
              current is SubscriptionLoading ||
              current is SubscriptionLoaded ||
              current is SubscriptionError,
          builder: (context, state) {
            if (state is SubscriptionLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (state is SubscriptionError) {
              return _buildErrorView(context, state);
            }

            if (state is SubscriptionLoaded) {
              final invoices = state.invoices;
              if (invoices == null || invoices.isEmpty) {
                return _buildEmptyView(context);
              }
              return _buildInvoiceList(context, invoices);
            }

            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Payment History',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your subscription payments will appear here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, SubscriptionError state) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.errorMessage,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _onRefresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceList(
      BuildContext context, List<SubscriptionInvoice> invoices) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        return _InvoiceCard(invoice: invoice);
      },
    );
  }
}

/// Card widget displaying a single invoice
class _InvoiceCard extends StatelessWidget {
  final SubscriptionInvoice invoice;

  const _InvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    // Status color and icon
    final statusColor = _getStatusColor(invoice.status, isDark);
    final statusIcon = _getStatusIcon(invoice.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: Amount and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₹${invoice.amountRupees.toStringAsFixed(0)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        _formatStatus(invoice.status),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Invoice number
            if (invoice.invoiceNumber != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.receipt_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Invoice: ${invoice.invoiceNumber}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Billing period
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 8),
                Text(
                  '${dateFormat.format(invoice.billingPeriodStart)} - ${dateFormat.format(invoice.billingPeriodEnd)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Payment date
            if (invoice.paidAt != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Paid on ${dateFormat.format(invoice.paidAt!)} at ${timeFormat.format(invoice.paidAt!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Payment method
            if (invoice.paymentMethod != null) ...[
              Row(
                children: [
                  Icon(
                    _getPaymentMethodIcon(invoice.paymentMethod!),
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatPaymentMethod(invoice.paymentMethod!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status, bool isDark) {
    switch (status.toLowerCase()) {
      case 'paid':
        return isDark ? Colors.green[300]! : Colors.green[700]!;
      case 'pending':
        return isDark ? Colors.orange[300]! : Colors.orange[700]!;
      case 'failed':
        return isDark ? Colors.red[300]! : Colors.red[700]!;
      default:
        return isDark ? Colors.grey[300]! : Colors.grey[700]!;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'failed':
        return Icons.error;
      default:
        return Icons.info;
    }
  }

  String _formatStatus(String status) {
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  IconData _getPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'upi':
        return Icons.qr_code;
      case 'card':
        return Icons.credit_card;
      case 'netbanking':
        return Icons.account_balance;
      case 'wallet':
        return Icons.account_balance_wallet;
      default:
        return Icons.payment;
    }
  }

  String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'upi':
        return 'UPI';
      case 'card':
        return 'Card';
      case 'netbanking':
        return 'Net Banking';
      case 'wallet':
        return 'Wallet';
      default:
        return method;
    }
  }
}
