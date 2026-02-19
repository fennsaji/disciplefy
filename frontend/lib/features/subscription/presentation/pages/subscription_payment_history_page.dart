import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Conditional imports for platform-specific PDF download
import 'pdf_download_stub.dart'
    if (dart.library.html) 'pdf_download_web.dart'
    if (dart.library.io) 'pdf_download_mobile.dart' as pdf_download;

import '../../domain/entities/subscription.dart';
import '../../../../core/theme/app_colors.dart';
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
              'Something went wrong. Please try again.',
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
class _InvoiceCard extends StatefulWidget {
  final SubscriptionInvoice invoice;

  const _InvoiceCard({required this.invoice});

  @override
  State<_InvoiceCard> createState() => _InvoiceCardState();
}

class _InvoiceCardState extends State<_InvoiceCard> {
  bool _isDownloading = false;

  /// Download invoice PDF
  Future<void> _downloadInvoicePDF() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      // Show loading snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Generating PDF...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Call Edge Function to generate PDF
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'generate-invoice-pdf',
        body: {'invoice_id': widget.invoice.id},
      );

      if (response.status != 200 || response.data == null) {
        throw Exception(
            'Failed to generate PDF: ${response.status} ${response.data}');
      }

      // Convert response data to Uint8List
      final bytes = response.data is Uint8List
          ? response.data as Uint8List
          : Uint8List.fromList(List<int>.from(response.data));

      // Generate filename
      final fileName = widget.invoice.invoiceNumber != null
          ? 'Invoice_${widget.invoice.invoiceNumber}.pdf'
          : 'Invoice_${widget.invoice.id.substring(0, 8)}.pdf';

      // Platform-specific download using conditional imports
      if (kIsWeb) {
        // Web: Trigger browser download
        await pdf_download.downloadPdfBytes(bytes, fileName);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invoice downloaded: $fileName'),
              backgroundColor: AppColors.successDark,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Mobile: Save to downloads folder, Web: Browser download
        final filePath = await pdf_download.downloadPdfBytes(bytes, fileName);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                kIsWeb
                    ? 'Invoice downloaded: $filePath'
                    : 'Invoice saved to:\n$filePath',
              ),
              backgroundColor: AppColors.successDark,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Something went wrong. Please try again.'),
            backgroundColor: AppColors.errorDark,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    // Status color and icon
    final statusColor = _getStatusColor(widget.invoice.status, isDark);
    final statusIcon = _getStatusIcon(widget.invoice.status);

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
                  '₹${widget.invoice.amountRupees.toStringAsFixed(0)}',
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
                        _formatStatus(widget.invoice.status),
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

            // Invoice number with download button
            if (widget.invoice.invoiceNumber != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.receipt_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Invoice: ${widget.invoice.invoiceNumber}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Download PDF button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isDownloading ? null : _downloadInvoicePDF,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isDownloading)
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    theme.colorScheme.primary,
                                  ),
                                ),
                              )
                            else
                              Icon(
                                Icons.download,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                            const SizedBox(width: 4),
                            Text(
                              _isDownloading ? 'Generating...' : 'PDF',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                  '${dateFormat.format(widget.invoice.billingPeriodStart)} - ${dateFormat.format(widget.invoice.billingPeriodEnd)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Payment date
            if (widget.invoice.paidAt != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Paid on ${dateFormat.format(widget.invoice.paidAt!)} at ${timeFormat.format(widget.invoice.paidAt!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Payment method
            if (widget.invoice.paymentMethod != null) ...[
              Row(
                children: [
                  Icon(
                    _getPaymentMethodIcon(widget.invoice.paymentMethod!),
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatPaymentMethod(widget.invoice.paymentMethod!),
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
        return isDark ? AppColors.success : AppColors.successDark;
      case 'pending':
        return isDark ? AppColors.warning : AppColors.warningDark;
      case 'failed':
        return isDark ? AppColors.error : AppColors.errorDark;
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
