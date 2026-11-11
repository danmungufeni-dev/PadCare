import 'package:flutter/material.dart';

const Color _dialogDeepTeal = Color(0xFF116B78);
const Color _dialogMuted = Color(0xFF6B8487);
const Color _dialogInk = Color(0xFF172B36);

/// Modal dialog prompting confirmation prior to executing atomic pad kit dispensation.
class DispenseConfirmationDialog extends StatelessWidget {
  const DispenseConfirmationDialog({
    super.key,
    required this.requestId,
    required this.pickupPin,
    required this.reference,
    required this.product,
    required this.quantity,
    required this.status,
    required this.availableStock,
    required this.stockUnit,
    required this.school,
    this.batchNumber = 'BATCH-2025-08X',
    this.shelfLifeStatus = 'Good (Expires June 2028)',
  });

  final String requestId;
  final String pickupPin;
  final String reference;
  final String product;
  final int quantity;
  final String status;
  final int availableStock;
  final String stockUnit;
  final String school;
  final String batchNumber;
  final String shelfLifeStatus;

  @override
  Widget build(BuildContext context) {
    final remaining = availableStock - quantity;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.verified_user_rounded, color: _dialogDeepTeal, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Confirm Dispense & Handout',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF99F6E4)),
              ),
              child: Row(
                children: [
                  const Text('Verified PIN:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _dialogMuted)),
                  const Spacer(),
                  Text(
                    '#$pickupPin',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _dialogDeepTeal, letterSpacing: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _infoRow('Request ID', reference.isNotEmpty ? reference : requestId),
            _infoRow('School Facility', school),
            _infoRow('Product Requested', product),
            _infoRow('Quantity Requested', '$quantity $stockUnit'),
            _infoRow('Current Request Status', status),
            _infoRow('Batch Lot (FIFO)', batchNumber, isBold: true),
            _infoRow('Shelf Life Status', shelfLifeStatus, valueColor: const Color(0xFF16A34A)),
            const Divider(height: 24),
            _infoRow('Stock Available', '$availableStock $stockUnit', valueColor: _dialogDeepTeal, isBold: true),
            _infoRow('Stock Remaining After Dispense', '$remaining $stockUnit', valueColor: remaining < 10 ? const Color(0xFFD97706) : _dialogInk, isBold: true),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_clock_outlined, size: 16, color: _dialogMuted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This transaction will atomically mark the request as Collected, deduct school inventory, and write an immutable audit log.',
                      style: TextStyle(fontSize: 11, color: _dialogMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          key: const ValueKey('cancel-dispense-dialog-btn'),
          onPressed: () => Navigator.pop(context, false),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const ValueKey('confirm-dispense-dialog-btn'),
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Confirm & Dispense'),
          style: FilledButton.styleFrom(
            backgroundColor: _dialogDeepTeal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: const TextStyle(fontSize: 12, color: _dialogMuted)),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                color: valueColor ?? _dialogInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
