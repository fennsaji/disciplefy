import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/error_widget.dart' as custom;
import '../../domain/entities/saved_payment_method.dart';
import '../bloc/payment_method_bloc.dart';
import '../widgets/payment_method_card.dart';
import '../widgets/add_payment_method_dialog.dart';

class SavedPaymentMethodsScreen extends StatefulWidget {
  static const String routeName = '/saved-payment-methods';

  const SavedPaymentMethodsScreen({super.key});

  @override
  State<SavedPaymentMethodsScreen> createState() =>
      _SavedPaymentMethodsScreenState();
}

class _SavedPaymentMethodsScreenState extends State<SavedPaymentMethodsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PaymentMethodBloc>().add(LoadPaymentMethods());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceColor,
      appBar: CustomAppBar(
        title: 'Saved Payment Methods',
        backgroundColor: AppColors.surfaceColor,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: BlocConsumer<PaymentMethodBloc, PaymentMethodState>(
        listener: (context, state) {
          if (state is PaymentMethodError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.errorColor,
              ),
            );
          } else if (state is PaymentMethodSaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment method saved successfully'),
                backgroundColor: AppColors.successColor,
              ),
            );
          } else if (state is PaymentMethodDefaultSet) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Default payment method updated'),
                backgroundColor: AppColors.successColor,
              ),
            );
          } else if (state is PaymentMethodDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment method deleted successfully'),
                backgroundColor: AppColors.successColor,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is PaymentMethodLoading) {
            return const LoadingWidget();
          } else if (state is PaymentMethodError) {
            return custom.AppErrorWidget(
              message: state.message,
              onRetry: () {
                context.read<PaymentMethodBloc>().add(LoadPaymentMethods());
              },
            );
          } else if (state is PaymentMethodsLoaded) {
            return _buildPaymentMethodsList(state.paymentMethods);
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPaymentMethodDialog,
        backgroundColor: AppColors.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPaymentMethodsList(List<SavedPaymentMethod> paymentMethods) {
    if (paymentMethods.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<PaymentMethodBloc>().add(LoadPaymentMethods());
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: paymentMethods.length,
        itemBuilder: (context, index) {
          final paymentMethod = paymentMethods[index];
          return PaymentMethodCard(
            paymentMethod: paymentMethod,
            onSetDefault: paymentMethod.isDefault
                ? null
                : () => _setDefaultPaymentMethod(paymentMethod.id),
            onDelete: () => _deletePaymentMethod(paymentMethod),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.credit_card_outlined,
            size: 80,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 24),
          Text(
            'No Saved Payment Methods',
            style: AppTextStyles.headingMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Add your payment methods for quick\nand easy token purchases',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showAddPaymentMethodDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Payment Method'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPaymentMethodDialog() {
    showDialog(
      context: context,
      builder: (context) => AddPaymentMethodDialog(
        onSave: (methodType, provider, token, lastFour, brand, displayName,
            isDefault, expiryMonth, expiryYear) {
          context.read<PaymentMethodBloc>().add(SavePaymentMethodEvent(
                methodType: methodType,
                provider: provider,
                token: token,
                lastFour: lastFour,
                brand: brand,
                displayName: displayName,
                isDefault: isDefault,
                expiryMonth: expiryMonth,
                expiryYear: expiryYear,
              ));
        },
      ),
    );
  }

  void _setDefaultPaymentMethod(String paymentMethodId) {
    context.read<PaymentMethodBloc>().add(
          SetDefaultPaymentMethodEvent(paymentMethodId: paymentMethodId),
        );
  }

  void _deletePaymentMethod(SavedPaymentMethod paymentMethod) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment Method'),
        content: Text(
          'Are you sure you want to delete ${paymentMethod.displayName ?? paymentMethod.methodTypeLabel}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<PaymentMethodBloc>().add(
                    DeletePaymentMethodEvent(paymentMethodId: paymentMethod.id),
                  );
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
