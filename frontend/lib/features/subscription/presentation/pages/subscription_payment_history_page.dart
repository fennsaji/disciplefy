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

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/subscription/domain/entities/subscription.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_bloc.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_event.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_state.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';

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
    final palette = ReaderPalette.of(context);

    return Scaffold(
      backgroundColor: palette.page,
      appBar: LedgerTopBar(
        title: context.tr(TranslationKeys.ledgerInvoicesTitle),
        subtitle: context.tr(TranslationKeys.ledgerInvoicesSubtitle),
        onBack: () => Navigator.of(context).pop(),
        actions: [
          LedgerBarAction(
            icon: Icons.refresh_rounded,
            tooltip: context.tr(TranslationKeys.subscriptionRefresh),
            onPressed: _onRefresh,
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
              return const LedgerLoading();
            }

            if (state is SubscriptionError) {
              return _scrollable(LedgerMessage(
                icon: Icons.error_outline_rounded,
                isError: true,
                title: context.tr(TranslationKeys.ledgerInvoicesError),
                body: context.tr(TranslationKeys.commonErrorTryAgain),
                actionLabel: context.tr(TranslationKeys.commonRetry),
                onAction: _onRefresh,
              ));
            }

            if (state is SubscriptionLoaded) {
              final invoices = state.invoices;
              if (invoices == null || invoices.isEmpty) {
                return _scrollable(LedgerMessage(
                  icon: Icons.receipt_long_outlined,
                  title: context.tr(TranslationKeys.ledgerInvoicesEmpty),
                  body: context.tr(TranslationKeys.ledgerInvoicesEmptyBody),
                ));
              }
              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: invoices.length,
                itemBuilder: (context, index) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InvoiceCard(invoice: invoices[index]),
                    const LedgerHairline(),
                  ],
                ),
              );
            }

            return const LedgerLoading();
          },
        ),
      ),
    );
  }

  /// Keeps pull-to-refresh working on the empty and error states.
  Widget _scrollable(Widget child) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
      );
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
              // persist:false — since Flutter 3.44 a SnackBar with an action
              // defaults to persist:true, so it never times out AND blocks every
              // later snackbar behind it in the app-wide queue.
              persist: false,
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
            content: Text(context.tr(TranslationKeys.commonErrorTryAgain)),
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
    final palette = ReaderPalette.of(context);
    final invoice = widget.invoice;
    final paidAt = invoice.paidAt;

    final title = invoice.invoiceNumber != null
        ? '${DateFormat('MMM y').format(invoice.billingPeriodStart)} · ${context.tr(TranslationKeys.ledgerInvoiceNumber, {
                'number': invoice.invoiceNumber
              })}'
        : DateFormat('MMM y').format(invoice.billingPeriodStart);
    final paidLine = [
      if (paidAt != null)
        context.tr(TranslationKeys.ledgerPaidOn, {
          'date': DateFormat('MMM d · h:mm a').format(paidAt),
        }),
      if (invoice.paymentMethod != null)
        _formatPaymentMethod(invoice.paymentMethod!),
    ].join(' · ');
    final period =
        '${DateFormat('MMM d').format(invoice.billingPeriodStart)} – ${DateFormat('MMM d, y').format(invoice.billingPeriodEnd)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LedgerIconTile(icon: Icons.receipt_long_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      paidLine.isNotEmpty ? paidLine : period,
                      style: AppFonts.inter(
                        fontSize: 12.5,
                        color: palette.muted,
                        height: 1.35,
                      ),
                    ),
                    if (paidLine.isNotEmpty)
                      Text(
                        period,
                        style: AppFonts.inter(
                          fontSize: 12,
                          color: palette.dim,
                          height: 1.35,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${invoice.amountRupees.toStringAsFixed(0)}',
                    style: AppFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                      fontFeatures: kLedgerTabular,
                    ),
                  ),
                  if (!invoice.isPaid) ...[
                    const SizedBox(height: 4),
                    LedgerStatusPill(
                      label: _formatStatus(invoice.status),
                      tone: _statusTone(invoice.status),
                    ),
                  ],
                ],
              ),
            ],
          ),
          // Invoice PDF (only numbered invoices can be generated)
          if (invoice.invoiceNumber != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: LedgerLink(
                key: Key('invoice_download_${invoice.id}'),
                label: context.tr(_isDownloading
                    ? TranslationKeys.ledgerGeneratingPdf
                    : TranslationKeys.ledgerDownloadInvoice),
                leadingIcon: Icons.download_rounded,
                onTap: _isDownloading ? null : _downloadInvoicePDF,
              ),
            ),
          ],
        ],
      ),
    );
  }

  LedgerTone _statusTone(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return LedgerTone.success;
      case 'pending':
        return LedgerTone.warning;
      case 'failed':
        return LedgerTone.error;
      default:
        return LedgerTone.neutral;
    }
  }

  String _formatStatus(String status) {
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
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
