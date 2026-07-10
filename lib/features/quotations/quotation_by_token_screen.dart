import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart';

/// Resolves a verification token to a quotation ID and navigates to it.
/// Shows a spinner while resolving; shows an error card on 403 or failure.
class QuotationByTokenScreen extends StatefulWidget {
  final String token;
  const QuotationByTokenScreen({super.key, required this.token});

  @override
  State<QuotationByTokenScreen> createState() => _QuotationByTokenScreenState();
}

class _QuotationByTokenScreenState extends State<QuotationByTokenScreen> {
  static const _green = Color(0xFF166534);
  static const _red = Color(0xFF991B1B);
  static const _gray = Color(0xFF374151);
  static const _grayMuted = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final data = await ApiClient.instance.get<Map<String, dynamic>>(
        ApiConstants.quotationByToken(widget.token),
        fromJson: (j) => j as Map<String, dynamic>,
      );
      final id = data['quotation_id'] as int? ?? data['id'] as int?;
      if (id == null) throw Exception('Missing quotation_id in response');
      if (mounted) context.replace('/quotations/$id');
    } on ForbiddenError {
      _showAccessDenied();
    } on AppError catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showAccessDenied() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: _red, size: 22),
            SizedBox(width: 8),
            Text('Access Denied',
                style: TextStyle(fontSize: 18, color: _red)),
          ],
        ),
        content: const Text(
          'You do not have permission to view this quotation.\n\nOnly the seller and the buyer can access the full quotation details.',
          style: TextStyle(fontSize: 14, color: _gray),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (mounted) context.pop();
            },
            child: const Text('OK', style: TextStyle(color: _green)),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Error', style: TextStyle(fontSize: 18)),
        content: Text(msg, style: const TextStyle(fontSize: 14, color: _gray)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (mounted) context.pop();
            },
            child: const Text('Back', style: TextStyle(color: _green)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _green),
            SizedBox(height: 16),
            Text('Loading quotation…',
                style: TextStyle(fontSize: 14, color: _grayMuted)),
          ],
        ),
      ),
    );
  }
}
