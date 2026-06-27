import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' hide Border;
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/presentation/providers/session_provider.dart';
import 'quotations.dart';

// ── Language support ───────────────────────────────────────────────────────────

enum _Lang {
  english('English', 'en'),
  hindi('हिंदी (Hindi)', 'hi'),
  tamil('தமிழ் (Tamil)', 'ta'),
  telugu('తెలుగు (Telugu)', 'te'),
  kannada('ಕನ್ನಡ (Kannada)', 'kn'),
  marathi('मराठी (Marathi)', 'mr');

  final String display;
  final String code;
  const _Lang(this.display, this.code);
}

class _Labels {
  final String quotation;
  final String generatedBy;
  final String nursery;
  final String address;
  final String phone;
  final String recipient;
  final String plant;
  final String description;
  final String qty;
  final String unitPrice;
  final String total;
  final String grandTotal;
  final String notes;
  final String date;
  final String status;
  final String priceDisclaimer;
  final String authorizedSignatory;
  final String digitallyAuthenticated;
  final String role;

  const _Labels({
    required this.quotation,
    required this.generatedBy,
    required this.nursery,
    required this.address,
    required this.phone,
    required this.recipient,
    required this.plant,
    required this.description,
    required this.qty,
    required this.unitPrice,
    required this.total,
    required this.grandTotal,
    required this.notes,
    required this.date,
    required this.status,
    required this.priceDisclaimer,
    required this.authorizedSignatory,
    required this.digitallyAuthenticated,
    required this.role,
  });
}

_Labels _labelsFor(_Lang lang) {
  switch (lang) {
    case _Lang.hindi:
      return const _Labels(
        quotation: 'कोटेशन',
        generatedBy: 'द्वारा जनरेट किया गया',
        nursery: 'नर्सरी',
        address: 'पता',
        phone: 'फोन',
        recipient: 'प्राप्तकर्ता',
        plant: 'पौधा',
        description: 'विवरण',
        qty: 'मात्रा',
        unitPrice: 'इकाई मूल्य',
        total: 'कुल',
        grandTotal: 'कुल योग',
        notes: 'नोट्स',
        date: 'तारीख',
        status: 'स्थिति',
        priceDisclaimer:
            'नोट: GreenRoot कीमतें तय नहीं करता। सभी मूल्य मालिक द्वारा प्रदान किए गए हैं।',
        authorizedSignatory: 'अधिकृत हस्ताक्षरकर्ता',
        digitallyAuthenticated: 'यह दस्तावेज़ GreenRoot प्लेटफ़ॉर्म द्वारा डिजिटल रूप से प्रमाणित है।',
        role: 'भूमिका',
      );
    case _Lang.tamil:
      return const _Labels(
        quotation: 'மேற்கோள்',
        generatedBy: 'உருவாக்கியவர்',
        nursery: 'நர்சரி',
        address: 'முகவரி',
        phone: 'தொலைபேசி',
        recipient: 'பெறுநர்',
        plant: 'தாவரம்',
        description: 'விவரம்',
        qty: 'அளவு',
        unitPrice: 'அலகு விலை',
        total: 'மொத்தம்',
        grandTotal: 'மொத்த தொகை',
        notes: 'குறிப்புகள்',
        date: 'தேதி',
        status: 'நிலை',
        priceDisclaimer:
            'குறிப்பு: GreenRoot விலைகளை நிர்ணயிக்கவில்லை. அனைத்து விலைகளும் உரிமையாளரால் வழங்கப்பட்டவை.',
        authorizedSignatory: 'அங்கீகரிக்கப்பட்ட கையொப்பமிடுபவர்',
        digitallyAuthenticated: 'இந்த ஆவணம் GreenRoot தளத்தால் டிஜிட்டல் முறையில் சான்றளிக்கப்பட்டது.',
        role: 'பதவி',
      );
    case _Lang.telugu:
      return const _Labels(
        quotation: 'కోటేషన్',
        generatedBy: 'సృష్టించిన వారు',
        nursery: 'నర్సరీ',
        address: 'చిరునామా',
        phone: 'ఫోన్',
        recipient: 'గ్రహీత',
        plant: 'మొక్క',
        description: 'వివరణ',
        qty: 'పరిమాణం',
        unitPrice: 'యూనిట్ ధర',
        total: 'మొత్తం',
        grandTotal: 'గ్రాండ్ టోటల్',
        notes: 'నోట్స్',
        date: 'తేది',
        status: 'స్థితి',
        priceDisclaimer:
            'గమనిక: GreenRoot ధరలను నిర్ణయించదు. అన్ని ధరలు యజమానిచే అందించబడ్డాయి.',
        authorizedSignatory: 'అధికారిక సంతకందారు',
        digitallyAuthenticated: 'ఈ పత్రం GreenRoot ప్లాట్‌ఫారమ్ ద్వారా డిజిటల్‌గా ధృవీకరించబడింది.',
        role: 'పాత్ర',
      );
    case _Lang.kannada:
      return const _Labels(
        quotation: 'ಉದ್ಧರಣ',
        generatedBy: 'ರಚಿಸಿದವರು',
        nursery: 'ನರ್ಸರಿ',
        address: 'ವಿಳಾಸ',
        phone: 'ಫೋನ್',
        recipient: 'ಸ್ವೀಕರಿಸುವವರು',
        plant: 'ಸಸ್ಯ',
        description: 'ವಿವರಣೆ',
        qty: 'ಪ್ರಮಾಣ',
        unitPrice: 'ಘಟಕ ಬೆಲೆ',
        total: 'ಒಟ್ಟು',
        grandTotal: 'ಗ್ರ್ಯಾಂಡ್ ಟೋಟಲ್',
        notes: 'ಟಿಪ್ಪಣಿಗಳು',
        date: 'ದಿನಾಂಕ',
        status: 'ಸ್ಥಿತಿ',
        priceDisclaimer:
            'ಗಮನಿಸಿ: GreenRoot ಬೆಲೆಗಳನ್ನು ನಿರ್ಧರಿಸುವುದಿಲ್ಲ. ಎಲ್ಲಾ ಬೆಲೆಗಳು ಮಾಲೀಕರಿಂದ ನೀಡಲ್ಪಟ್ಟಿವೆ.',
        authorizedSignatory: 'ಅಧಿಕೃತ ಸಹಿದಾರ',
        digitallyAuthenticated: 'ಈ ದಾಖಲೆಯನ್ನು GreenRoot ಪ್ಲಾಟ್‌ಫಾರ್ಮ್ ಡಿಜಿಟಲ್ ಆಗಿ ದೃಢೀಕರಿಸಿದೆ.',
        role: 'ಪಾತ್ರ',
      );
    case _Lang.marathi:
      return const _Labels(
        quotation: 'कोटेशन',
        generatedBy: 'तयार केले',
        nursery: 'नर्सरी',
        address: 'पत्ता',
        phone: 'फोन',
        recipient: 'प्राप्तकर्ता',
        plant: 'वनस्पती',
        description: 'वर्णन',
        qty: 'प्रमाण',
        unitPrice: 'एकक किंमत',
        total: 'एकूण',
        grandTotal: 'एकूण रक्कम',
        notes: 'नोट्स',
        date: 'तारीख',
        status: 'स्थिती',
        priceDisclaimer:
            'सूचना: GreenRoot किंमती ठरवत नाही. सर्व किंमती मालकाने दिलेल्या आहेत.',
        authorizedSignatory: 'अधिकृत स्वाक्षरीकर्ता',
        digitallyAuthenticated: 'हे दस्तावेज GreenRoot प्लॅटफॉर्मद्वारे डिजिटली प्रमाणित आहे.',
        role: 'भूमिका',
      );
    case _Lang.english:
      return const _Labels(
        quotation: 'Quotation',
        generatedBy: 'Generated By',
        nursery: 'Nursery',
        address: 'Address',
        phone: 'Phone',
        recipient: 'Recipient / Bill To',
        plant: 'Plant / Item',
        description: 'Description',
        qty: 'Qty',
        unitPrice: 'Unit Price',
        total: 'Total',
        grandTotal: 'Grand Total',
        notes: 'Notes',
        date: 'Date',
        status: 'Status',
        priceDisclaimer:
            'Note: GreenRoot does not set or verify price rates. All prices are as provided by the nursery owner.',
        authorizedSignatory: 'Authorized Signatory',
        digitallyAuthenticated:
            'This document is digitally authenticated by the GreenRoot Platform.',
        role: 'Role',
      );
  }
}

// ── Nursery address fetch ──────────────────────────────────────────────────────

Future<String?> _fetchNurseryAddress(int nurseryId) async {
  try {
    final addresses = await ApiClient.instance.get<List<dynamic>>(
      ApiConstants.nurseryAddresses(nurseryId),
      fromJson: (data) =>
          (data as Map<String, dynamic>)['addresses'] as List<dynamic>,
    );
    if (addresses.isEmpty) return null;
    final raw = addresses.firstWhere(
          (a) => (a as Map<String, dynamic>)['is_primary'] == true,
          orElse: () => addresses.first,
        ) as Map<String, dynamic>;
    final parts = <String>[
      if (raw['address_line1'] != null) raw['address_line1'] as String,
      if (raw['address_line2'] != null) raw['address_line2'] as String,
      if (raw['city'] != null) raw['city'] as String,
      if (raw['state'] != null) raw['state'] as String,
      if (raw['country'] != null) raw['country'] as String,
      if (raw['postal_code'] != null) raw['postal_code'] as String,
    ];
    return parts.isNotEmpty ? parts.join(', ') : null;
  } catch (_) {
    return null;
  }
}

/// Fetches plant names in the given language code from the API.
/// Returns a map of plantId → localName. Falls back to empty map on failure.
Future<Map<int, String>> _fetchPlantLocalNames(List<int> plantIds, String langCode) async {
  if (plantIds.isEmpty || langCode == 'en') return {};
  try {
    final ids = plantIds.toSet().join(',');
    final result = await ApiClient.instance.get<Map<int, String>>(
      ApiConstants.plantNamesByLang(ids: ids, lang: langCode),
      fromJson: (data) {
        final raw = (data as Map<String, dynamic>)['names'];
        if (raw == null) return <int, String>{};
        return (raw as Map<String, dynamic>)
            .map((k, v) => MapEntry(int.parse(k), v as String));
      },
    );
    return result;
  } catch (_) {
    return {};
  }
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class QuotationDetailScreen extends ConsumerStatefulWidget {
  final int quotationId;
  const QuotationDetailScreen({super.key, required this.quotationId});

  @override
  ConsumerState<QuotationDetailScreen> createState() =>
      _QuotationDetailScreenState();
}

class _QuotationDetailScreenState
    extends ConsumerState<QuotationDetailScreen> {
  bool _deleting = false;
  bool _exporting = false;
  bool _buyerActing = false;

  Future<void> _buyerAccept(Quotation q) async {
    setState(() => _buyerActing = true);
    try {
      await ref.read(quotationRepositoryProvider).acceptQuotation(q.id);
      if (mounted) {
        ref.invalidate(quotationDetailProvider(widget.quotationId));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Quotation accepted'),
          backgroundColor: AppColors.primaryMain,
        ));
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: AppColors.red600));
      }
    } finally {
      if (mounted) setState(() => _buyerActing = false);
    }
  }

  Future<void> _buyerReject(Quotation q) async {
    String? reason;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Reject Quotation'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'Reason (optional)'),
            onChanged: (v) => reason = v,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Reject', style: TextStyle(color: AppColors.red600)),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _buyerActing = true);
    try {
      await ref.read(quotationRepositoryProvider).rejectQuotation(q.id, reason: reason);
      if (mounted) {
        ref.invalidate(quotationDetailProvider(widget.quotationId));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Quotation rejected'),
          backgroundColor: AppColors.red600,
        ));
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: AppColors.red600));
      }
    } finally {
      if (mounted) setState(() => _buyerActing = false);
    }
  }

  Future<void> _confirmDelete(Quotation q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quotation'),
        content: Text(
            'Permanently delete ${q.quotationCode}?\nThis action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.red600)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(quotationRepositoryProvider).deleteQuotation(q.id);
      if (mounted) context.pop(true);
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: AppColors.red600));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _exportExcel(Quotation q) async {
    final lang = await _pickLanguage(context);
    if (lang == null || !mounted) return;

    setState(() => _exporting = true);
    try {
      final en = _labelsFor(_Lang.english);
      final lo = _labelsFor(lang);
      final isEn = lang == _Lang.english;
      String bi(String e, String l) => isEn ? e : '$e / $l';

      // Fetch local-language plant names from DB
      final plantIds = q.items.map((i) => i.plantId).toList();
      final localPlantNames = await _fetchPlantLocalNames(plantIds, lang.code);

      final excel = Excel.createExcel();
      excel.delete('Sheet1');
      final sheet = excel['Quotation'];

      // Title block
      sheet.appendRow([TextCellValue('GreenRoot — ${bi('Quotation', lo.quotation)}')]);
      sheet.appendRow([TextCellValue(q.quotationCode)]);
      sheet.appendRow([TextCellValue('${bi('Date', lo.date)}: ${_fmt(q.createdAt)}')]);
      if (q.nurseryName != null) {
        sheet.appendRow([TextCellValue('${bi('Nursery', lo.nursery)}: ${q.nurseryName}')]);
      }
      if (q.nurseryPhone != null) {
        sheet.appendRow([TextCellValue('${bi('Phone', lo.phone)}: ${q.nurseryPhone}')]);
      }
      if (q.recipientName != null) {
        sheet.appendRow([TextCellValue('${bi('Bill To', lo.recipient)}: ${q.recipientName}')]);
      }
      if (q.recipientMobile != null) {
        sheet.appendRow([TextCellValue('Mobile: ${q.recipientMobile}')]);
      }
      sheet.appendRow([TextCellValue('')]);

      // Column headers — bilingual when lang != English
      // 7 columns: # | Scientific Name | English Name | Local Name | Description | Qty | Unit Price | Total
      if (isEn) {
        sheet.appendRow([
          TextCellValue('#'),
          TextCellValue('Plant (Scientific)'),
          TextCellValue('Common Name (English)'),
          TextCellValue('Description'),
          TextCellValue('Qty'),
          TextCellValue('Unit Price (₹)'),
          TextCellValue('Total (₹)'),
        ]);
      } else {
        sheet.appendRow([
          TextCellValue('#'),
          TextCellValue('Plant (Scientific)'),
          TextCellValue('English Name'),
          TextCellValue('${lo.plant} (${lang.display.split(' ').first})'),
          TextCellValue(bi('Description', lo.description)),
          TextCellValue(bi('Qty', lo.qty)),
          TextCellValue(bi('Unit Price (₹)', lo.unitPrice)),
          TextCellValue(bi('Total (₹)', lo.total)),
        ]);
      }

      // Items
      for (int i = 0; i < q.items.length; i++) {
        final item = q.items[i];
        final localName = localPlantNames[item.plantId] ?? '';
        if (isEn) {
          sheet.appendRow([
            IntCellValue(i + 1),
            TextCellValue(item.scientificName),
            TextCellValue(item.commonName ?? ''),
            TextCellValue(item.description ?? ''),
            DoubleCellValue(item.quantity),
            DoubleCellValue(item.unitPrice),
            DoubleCellValue(item.totalPrice),
          ]);
        } else {
          sheet.appendRow([
            IntCellValue(i + 1),
            TextCellValue(item.scientificName),
            TextCellValue(item.commonName ?? ''),
            TextCellValue(localName),
            TextCellValue(item.description ?? ''),
            DoubleCellValue(item.quantity),
            DoubleCellValue(item.unitPrice),
            DoubleCellValue(item.totalPrice),
          ]);
        }
      }

      // Grand total
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([
        TextCellValue(''), TextCellValue(''), TextCellValue(''),
        TextCellValue(''), TextCellValue(''),
        TextCellValue(bi('Grand Total', lo.grandTotal)),
        DoubleCellValue(q.totalAmount),
      ]);

      if (q.notes != null) {
        sheet.appendRow([TextCellValue('')]);
        sheet.appendRow([
          TextCellValue(bi('Notes', lo.notes)),
          TextCellValue(q.notes!),
        ]);
      }

      // Disclaimer
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([TextCellValue(en.priceDisclaimer)]);
      if (!isEn) {
        sheet.appendRow([TextCellValue(lo.priceDisclaimer)]);
      }

      // Digital authentication line
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([TextCellValue(en.digitallyAuthenticated)]);
      if (!isEn) {
        sheet.appendRow([TextCellValue(lo.digitallyAuthenticated)]);
      }

      final bytes = excel.save();
      if (bytes == null) throw Exception('Failed to generate Excel file');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${q.quotationCode}.xlsx');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: 'Quotation ${q.quotationCode}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export failed: $e'),
              backgroundColor: AppColors.red600),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Shows "English only / Add another language?" dialog, then language picker.
  /// Returns null if cancelled, _Lang.english if user chose single language.
  Future<_Lang?> _pickLanguage(BuildContext context) async {
    final wantBilingual = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Language / भाषा'),
        content: const Text(
          'Do you want to add a second language to this document?\n\n'
          'क्या आप इस दस्तावेज़ में दूसरी भाषा जोड़ना चाहते हैं?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('English Only',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain),
            child: const Text('Yes, Choose Language',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (wantBilingual == null) return null; // cancelled
    if (!wantBilingual) return _Lang.english;

    if (!mounted) return null;
    return showModalBottomSheet<_Lang>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _LanguagePicker(),
    );
  }

  Future<void> _showPdfLangPicker(BuildContext context, Quotation q) async {
    final lang = await _pickLanguage(context);
    if (lang == null || !mounted) return;
    await _exportPdf(q, lang);
  }

  Future<void> _exportPdf(Quotation q, _Lang lang) async {
    setState(() => _exporting = true);
    try {
      // Fetch nursery address if available
      String? nurseryAddress;
      if (q.nurseryId != null) {
        nurseryAddress = await _fetchNurseryAddress(q.nurseryId!);
      }

      // Load appropriate font
      pw.Font? localFont;
      pw.Font? localFontBold;
      try {
        switch (lang) {
          case _Lang.hindi:
          case _Lang.marathi:
            localFont = await PdfGoogleFonts.notoSansDevanagariRegular();
            localFontBold = await PdfGoogleFonts.notoSansDevanagariBold();
            break;
          case _Lang.tamil:
            localFont = await PdfGoogleFonts.notoSansTamilRegular();
            localFontBold = await PdfGoogleFonts.notoSansTamilBold();
            break;
          case _Lang.telugu:
            localFont = await PdfGoogleFonts.notoSansTeluguRegular();
            localFontBold = await PdfGoogleFonts.notoSansTeluguBold();
            break;
          case _Lang.kannada:
            localFont = await PdfGoogleFonts.notoSansKannadaRegular();
            localFontBold = await PdfGoogleFonts.notoSansKannadaBold();
            break;
          case _Lang.english:
            break;
        }
      } catch (_) {
        // Font download failed — fall back to English-only
      }

      // Fetch local-language plant names from DB
      final plantIds = q.items.map((i) => i.plantId).toList();
      final localPlantNames = await _fetchPlantLocalNames(plantIds, lang.code);

      final doc = _buildProfessionalPdf(
        q: q,
        lang: lang,
        localFont: localFont,
        localFontBold: localFontBold,
        nurseryAddress: nurseryAddress,
        localPlantNames: localPlantNames,
      );

      await Printing.layoutPdf(
        onLayout: (_) => doc.save(),
        name: '${q.quotationCode}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('PDF export failed: $e'),
              backgroundColor: AppColors.red600),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(quotationDetailProvider(widget.quotationId));
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(
            title: const Text('Quotation'),
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0),
        body: const Center(
            child: CircularProgressIndicator(color: AppColors.primaryMain)),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
            title: const Text('Quotation'),
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Failed to load quotation',
                style: AppTypography.body.copyWith(color: AppColors.red600)),
            const SizedBox(height: 8),
            TextButton(
                onPressed: () => ref.invalidate(quotationDetailProvider(widget.quotationId)),
                child: const Text('Retry')),
          ]),
        ),
      ),
      data: (q) => _buildScaffold(q),
    );
  }

  Widget _buildScaffold(Quotation q) {
    final caps = ref.watch(sessionProvider).capabilities;
    final isBuyerView = !caps.canSell;
    final buyerCanAct = isBuyerView &&
        (q.status == 'CUSTOMER_SENT' ||
            q.status == 'APPROVED' ||
            q.status == 'SENT');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(q.quotationCode,
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (_deleting || _exporting || _buyerActing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primaryMain)),
            )
          else if (!isBuyerView) ...[
            // Edit
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () async {
                final edited = await context.push<bool>(
                    '/quotations/${q.id}/edit',
                    extra: q);
                if (edited == true && mounted) {
                  ref.invalidate(quotationDetailProvider(widget.quotationId));
                }
              },
            ),
            // More options
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) async {
                if (v == 'pdf') await _showPdfLangPicker(context, q);
                if (v == 'excel') await _exportExcel(q);
                if (v == 'delete') await _confirmDelete(q);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'pdf', child: _MenuOption(icon: Icons.picture_as_pdf_outlined, label: 'Export PDF')),
                const PopupMenuItem(value: 'excel', child: _MenuOption(icon: Icons.table_chart_outlined, label: 'Export Excel')),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: _MenuOption(icon: Icons.delete_outline, label: 'Delete', color: AppColors.red600),
                ),
              ],
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          // Caution note
          _CautionBanner(),
          const SizedBox(height: AppSpacing.md),

          // Header: code + date + status
          _InfoCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(q.quotationCode,
                        style: AppTypography.h3
                            .copyWith(color: AppColors.primaryMain))),
                _StatusBadge(status: q.status),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: q.isInternal ? AppColors.border : AppColors.forest100,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    q.isInternal ? 'Internal Quotation' : 'Customer Quotation',
                    style: AppTypography.caption.copyWith(
                      color: q.isInternal ? AppColors.textSecondary : AppColors.primaryMain,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Generated: ${_fmt(q.createdAt)}',
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
              ]),
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Nursery / Generated By
          _InfoCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Label('Generated By'),
              if (q.createdByName != null) ...[
                const SizedBox(height: 4),
                Text(q.createdByName!,
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
              ],
              if (q.nurseryName != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.storefront_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(q.nurseryName!,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ]),
              ],
              if (q.nurseryPhone != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.phone_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(q.nurseryPhone!,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textMuted)),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Recipient
          if (q.recipientName != null || q.recipientMobile != null) ...[
            _InfoCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('Bill To / Recipient'),
                    if (q.recipientName != null) ...[
                      const SizedBox(height: 4),
                      Text(q.recipientName!,
                          style: AppTypography.body
                              .copyWith(fontWeight: FontWeight.w600)),
                    ],
                    if (q.recipientMobile != null) ...[
                      const SizedBox(height: 2),
                      Text(q.recipientMobile!,
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.textMuted)),
                    ],
                  ]),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Items table
          _InfoCard(
            padding: EdgeInsets.zero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(children: [
                  _Label('Items'),
                  const Spacer(),
                  Text('${q.items.length} item${q.items.length == 1 ? '' : 's'}',
                      style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                ]),
              ),
              // Table header
              Container(
                color: AppColors.forest100,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(children: [
                  Expanded(flex: 5,
                      child: Text('Plant / Item',
                          style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryMain))),
                  SizedBox(
                      width: 40,
                      child: Text('Qty',
                          style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryMain),
                          textAlign: TextAlign.right)),
                  SizedBox(
                      width: 68,
                      child: Text('Unit ₹',
                          style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryMain),
                          textAlign: TextAlign.right)),
                  SizedBox(
                      width: 70,
                      child: Text('Total ₹',
                          style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryMain),
                          textAlign: TextAlign.right)),
                ]),
              ),
              // Item rows
              ...q.items.asMap().entries.map((e) {
                final item = e.value;
                final even = e.key % 2 == 0;
                return Container(
                  color: even ? Colors.white : AppColors.background,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.scientificName,
                                    style: AppTypography.bodySmall.copyWith(
                                        fontWeight: FontWeight.w600)),
                                if (item.commonName != null)
                                  Text(item.commonName!,
                                      style: AppTypography.caption.copyWith(
                                          color: AppColors.textMuted)),
                                if (item.description != null)
                                  Text(item.description!,
                                      style: AppTypography.caption.copyWith(
                                          color: AppColors.textMuted,
                                          fontStyle: FontStyle.italic)),
                              ]),
                        ),
                        SizedBox(
                            width: 40,
                            child: Text(_qty(item.quantity),
                                style: AppTypography.bodySmall,
                                textAlign: TextAlign.right)),
                        SizedBox(
                            width: 68,
                            child: Text('₹${item.unitPrice.toStringAsFixed(2)}',
                                style: AppTypography.bodySmall,
                                textAlign: TextAlign.right)),
                        SizedBox(
                            width: 70,
                            child: Text('₹${item.totalPrice.toStringAsFixed(2)}',
                                style: AppTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryMain),
                                textAlign: TextAlign.right)),
                      ]),
                );
              }),
              // Grand total
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.forest100,
                  borderRadius:
                      BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  const Expanded(
                      flex: 5,
                      child: Text('Grand Total',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryMain))),
                  SizedBox(width: 40 + 68),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '₹${q.totalAmount.toStringAsFixed(2)}',
                      style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryMain),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Notes
          if (q.notes != null) ...[
            _InfoCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('Notes'),
                    const SizedBox(height: 6),
                    Text(q.notes!, style: AppTypography.body),
                  ]),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Buyer action buttons (Accept / Reject)
          if (buyerCanAct) ...[
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _buyerActing ? null : () => _buyerReject(q),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red600,
                    side: const BorderSide(color: AppColors.red600),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _buyerActing ? null : () => _buyerAccept(q),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMain,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                    elevation: 0,
                  ),
                ),
              ),
            ]),
          ] else ...[
            // Seller export buttons
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exporting ? null : () => _showPdfLangPicker(context, q),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryMain,
                    side: const BorderSide(color: AppColors.primaryMain),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exporting ? null : () => _exportExcel(q),
                  icon: const Icon(Icons.table_chart_outlined, size: 18),
                  label: const Text('Excel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryMain,
                    side: const BorderSide(color: AppColors.primaryMain),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ),
            ]),
          ],
          const SizedBox(height: AppSpacing.x3l),
        ],
      ),
    );
  }
}

// ── Professional PDF builder ──────────────────────────────────────────────────

pw.Document _buildProfessionalPdf({
  required Quotation q,
  required _Lang lang,
  required pw.Font? localFont,
  required pw.Font? localFontBold,
  required String? nurseryAddress,
  required Map<int, String> localPlantNames,
}) {
  final en = _labelsFor(_Lang.english);
  final lo = _labelsFor(lang);
  final isEn = lang == _Lang.english;

  // Helper: bilingual text (English + Local)
  String bi(String enStr, String loStr) =>
      isEn ? enStr : '$enStr / $loStr';

  // Colors
  const greenDark = PdfColor.fromInt(0xFF1B4332);
  const greenMid = PdfColor.fromInt(0xFF2D6A4F);
  const greenLight = PdfColor.fromInt(0xFFD8F3DC);
  const greenXLight = PdfColor.fromInt(0xFFF0FFF4);
  const grey = PdfColor.fromInt(0xFF6B7280);
  const greyLight = PdfColor.fromInt(0xFFF3F4F6);
  const dark = PdfColor.fromInt(0xFF111827);
  const border = PdfColor.fromInt(0xFFD1D5DB);
  const amber = PdfColor.fromInt(0xFFD97706);
  const amberLight = PdfColor.fromInt(0xFFFEF3C7);

  pw.TextStyle _body({bool bold = false, PdfColor color = dark, double size = 10}) {
    if (localFont != null && !isEn) {
      return pw.TextStyle(
        font: bold ? localFontBold ?? localFont : localFont,
        fontSize: size,
        color: color,
      );
    }
    return pw.TextStyle(
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        fontSize: size,
        color: color);
  }

  pw.TextStyle _cap({bool bold = false, PdfColor color = grey}) =>
      _body(bold: bold, color: color, size: 8);

  pw.TextStyle _h({double size = 13}) =>
      _body(bold: true, color: PdfColors.white, size: size);

  final doc = pw.Document(
      title: q.quotationCode, author: 'GreenRoot', creator: 'GreenRoot Platform');

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
    header: (context) => _pdfHeader(q, en, lo, bi, greenDark, greenMid, _h),
    footer: (context) => _pdfFooter(context, en, lo, bi, grey, border, greenMid, _cap),
    build: (context) => [
      pw.SizedBox(height: 16),

      // From + To row
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // FROM (Nursery)
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: greenXLight,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: greenMid, width: 1.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(bi(en.generatedBy, lo.generatedBy).toUpperCase(),
                      style: _cap(bold: true, color: greenMid)),
                  pw.SizedBox(height: 5),
                  if (q.createdByName != null)
                    pw.Text(q.createdByName!, style: _body(bold: true, size: 11)),
                  if (q.nurseryName != null) ...[
                    pw.SizedBox(height: 2),
                    pw.Text('${bi(en.nursery, lo.nursery)}: ${q.nurseryName}',
                        style: _body(size: 10, color: grey)),
                  ],
                  if (nurseryAddress != null) ...[
                    pw.SizedBox(height: 2),
                    pw.Text('${bi(en.address, lo.address)}: $nurseryAddress',
                        style: _body(size: 9, color: grey)),
                  ],
                  if (q.nurseryPhone != null) ...[
                    pw.SizedBox(height: 2),
                    pw.Text('${bi(en.phone, lo.phone)}: ${q.nurseryPhone}',
                        style: _body(size: 9, color: grey)),
                  ],
                ],
              ),
            ),
          ),
          pw.SizedBox(width: 14),
          // TO (Recipient)
          pw.Expanded(
            child: q.recipientName != null || q.recipientMobile != null
                ? pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: greyLight,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(bi(en.recipient, lo.recipient).toUpperCase(),
                            style: _cap(bold: true, color: grey)),
                        pw.SizedBox(height: 5),
                        if (q.recipientName != null)
                          pw.Text(q.recipientName!,
                              style: _body(bold: true, size: 11)),
                        if (q.recipientMobile != null) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(q.recipientMobile!, style: _body(size: 9, color: grey)),
                        ],
                      ],
                    ),
                  )
                : pw.SizedBox(),
          ),
        ],
      ),
      pw.SizedBox(height: 18),

      // Items table
      pw.Container(
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: border),
        ),
        child: pw.Column(children: [
          // Table header
          pw.Container(
            decoration: const pw.BoxDecoration(
              color: greenDark,
              borderRadius: pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(6),
                  topRight: pw.Radius.circular(6)),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: pw.Row(children: [
              pw.SizedBox(
                  width: 22,
                  child: pw.Text('#', style: _cap(bold: true, color: PdfColors.white))),
              pw.Expanded(
                  flex: 5,
                  child: pw.Text(bi(en.plant, lo.plant),
                      style: _cap(bold: true, color: PdfColors.white))),
              pw.SizedBox(
                  width: 44,
                  child: pw.Text(bi(en.qty, lo.qty),
                      style: _cap(bold: true, color: PdfColors.white),
                      textAlign: pw.TextAlign.right)),
              pw.SizedBox(
                  width: 72,
                  child: pw.Text(bi(en.unitPrice, lo.unitPrice),
                      style: _cap(bold: true, color: PdfColors.white),
                      textAlign: pw.TextAlign.right)),
              pw.SizedBox(
                  width: 72,
                  child: pw.Text(bi(en.total, lo.total),
                      style: _cap(bold: true, color: PdfColors.white),
                      textAlign: pw.TextAlign.right)),
            ]),
          ),
          // Item rows
          ...q.items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            final localName = localPlantNames[item.plantId];
            return pw.Container(
              color: i.isEven ? PdfColors.white : const PdfColor.fromInt(0xFFF9FAFB),
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                      width: 22,
                      child: pw.Text('${i + 1}',
                          style: _cap(color: grey))),
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(item.scientificName,
                              style: _body(bold: true, size: 10)),
                          // English common name
                          if (item.commonName != null)
                            pw.Text(item.commonName!,
                                style: _cap(color: grey)),
                          // Local language name from DB (only in bilingual mode)
                          if (!isEn && localName != null && localName.isNotEmpty)
                            pw.Text(localName,
                                style: _body(size: 9, color: greenMid)),
                          if (item.description != null)
                            pw.Text(item.description!,
                                style: _cap(
                                    color: const PdfColor.fromInt(0xFF9CA3AF))),
                        ]),
                  ),
                  pw.SizedBox(
                      width: 44,
                      child: pw.Text(
                          item.quantity % 1 == 0
                              ? item.quantity.toInt().toString()
                              : item.quantity.toString(),
                          style: _body(size: 10),
                          textAlign: pw.TextAlign.right)),
                  pw.SizedBox(
                      width: 72,
                      child: pw.Text('₹${item.unitPrice.toStringAsFixed(2)}',
                          style: _body(size: 10),
                          textAlign: pw.TextAlign.right)),
                  pw.SizedBox(
                      width: 72,
                      child: pw.Text('₹${item.totalPrice.toStringAsFixed(2)}',
                          style: _body(bold: true, size: 10, color: greenMid),
                          textAlign: pw.TextAlign.right)),
                ],
              ),
            );
          }),
          // Grand total row
          pw.Container(
            decoration: const pw.BoxDecoration(
              color: greenLight,
              borderRadius: pw.BorderRadius.only(
                  bottomLeft: pw.Radius.circular(6),
                  bottomRight: pw.Radius.circular(6)),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: pw.Row(children: [
              pw.SizedBox(width: 22),
              pw.Expanded(
                  flex: 5,
                  child: pw.Text(bi(en.grandTotal, lo.grandTotal).toUpperCase(),
                      style: _body(bold: true, color: greenDark))),
              pw.SizedBox(width: 44),
              pw.SizedBox(width: 72),
              pw.SizedBox(
                  width: 72,
                  child: pw.Text('₹${q.totalAmount.toStringAsFixed(2)}',
                      style: _body(bold: true, size: 13, color: greenDark),
                      textAlign: pw.TextAlign.right)),
            ]),
          ),
        ]),
      ),

      // Notes
      if (q.notes != null) ...[
        pw.SizedBox(height: 14),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: greyLight,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(bi(en.notes, lo.notes).toUpperCase(),
                    style: _cap(bold: true, color: grey)),
                pw.SizedBox(height: 4),
                pw.Text(q.notes!, style: _body(size: 10)),
              ]),
        ),
      ],

      // Caution / Disclaimer
      pw.SizedBox(height: 14),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          color: amberLight,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: amber),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('⚠  ', style: _body(bold: true, color: amber, size: 9)),
            pw.Expanded(
                child: pw.Text(
                  isEn ? en.priceDisclaimer : '${en.priceDisclaimer}\n${lo.priceDisclaimer}',
                  style: _body(size: 8, color: amber),
                )),
          ],
        ),
      ),

      // Digital signature block
      pw.SizedBox(height: 22),
      _pdfSignatureBlock(q, en, lo, bi, isEn, greenDark, greenMid, greenLight, border, grey, _body, _cap),
    ],
  ));

  return doc;
}

pw.Widget _pdfHeader(
  Quotation q,
  _Labels en,
  _Labels lo,
  String Function(String, String) bi,
  PdfColor greenDark,
  PdfColor greenMid,
  pw.TextStyle Function({double size}) h,
) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: pw.BoxDecoration(
      gradient: pw.LinearGradient(
        colors: [greenDark, greenMid],
        begin: pw.Alignment.centerLeft,
        end: pw.Alignment.centerRight,
      ),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('🌿 GreenRoot', style: h(size: 20)),
          pw.SizedBox(height: 2),
          pw.Text(bi(en.quotation, lo.quotation),
              style: const pw.TextStyle(
                  fontSize: 11, color: PdfColor.fromInt(0xFFBBF7D0))),
          if (q.nurseryName != null)
            pw.Text(q.nurseryName!,
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColor.fromInt(0xFF86EFAC))),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text(q.quotationCode, style: h(size: 13)),
          pw.SizedBox(height: 3),
          pw.Text(
              '${bi(en.date, lo.date)}: ${_fmt(q.createdAt)}',
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColor.fromInt(0xFFBBF7D0))),
          pw.Text(
              '${bi(en.status, lo.status)}: ${q.status}',
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColor.fromInt(0xFFBBF7D0))),
        ]),
      ],
    ),
  );
}

pw.Widget _pdfFooter(
  pw.Context context,
  _Labels en,
  _Labels lo,
  String Function(String, String) bi,
  PdfColor grey,
  PdfColor border,
  PdfColor greenMid,
  pw.TextStyle Function({bool bold, PdfColor color}) cap,
) {
  return pw.Column(children: [
    pw.Divider(color: border),
    pw.SizedBox(height: 4),
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('GreenRoot Platform — greenroot.in',
            style: cap(color: grey)),
        pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: cap(color: grey)),
      ],
    ),
  ]);
}

pw.Widget _pdfSignatureBlock(
  Quotation q,
  _Labels en,
  _Labels lo,
  String Function(String, String) bi,
  bool isEn,
  PdfColor greenDark,
  PdfColor greenMid,
  PdfColor greenLight,
  PdfColor border,
  PdfColor grey,
  pw.TextStyle Function({bool bold, PdfColor color, double size}) body,
  pw.TextStyle Function({bool bold, PdfColor color}) cap,
) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: border),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(children: [
      // Header bar
      pw.Container(
        decoration: pw.BoxDecoration(
          color: greenLight,
          borderRadius: const pw.BorderRadius.only(
              topLeft: pw.Radius.circular(8), topRight: pw.Radius.circular(8)),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: pw.Row(children: [
          pw.Expanded(
              child: pw.Text('DIGITAL AUTHENTICATION / डिजिटल प्रमाणीकरण',
                  style: cap(bold: true, color: greenDark))),
        ]),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.all(14),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left: nursery sign block
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(bi(en.authorizedSignatory, lo.authorizedSignatory),
                      style: cap(bold: true, color: grey)),
                  pw.SizedBox(height: 24), // space for physical signature
                  pw.Container(
                    width: 120,
                    height: 1,
                    color: greenMid,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(q.nurseryName ?? 'Nursery',
                      style: body(bold: true, size: 10, color: greenDark)),
                  pw.Text('GreenRoot Platform',
                      style: cap(color: grey)),
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            // Right: verification info
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF9FAFB),
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: border),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('VERIFICATION ID',
                        style: cap(bold: true, color: grey)),
                    pw.SizedBox(height: 4),
                    pw.Text(q.quotationCode,
                        style: body(bold: true, size: 11, color: greenDark)),
                    pw.SizedBox(height: 6),
                    pw.Text('ISSUED',
                        style: cap(bold: true, color: grey)),
                    pw.SizedBox(height: 2),
                    pw.Text(_fmt(q.createdAt), style: body(size: 9)),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      en.digitallyAuthenticated,
                      style: body(size: 7, color: grey),
                    ),
                    if (!isEn) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(lo.digitallyAuthenticated,
                          style: body(size: 7, color: grey)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ]),
  );
}

// ── Language picker bottom sheet ───────────────────────────────────────────────

class _LanguagePicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            const Icon(Icons.language, color: AppColors.primaryMain, size: 18),
            const SizedBox(width: 8),
            Text('Select PDF Language',
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Bilingual PDF will include English + selected language labels.',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 10),
        const Divider(color: AppColors.border),
        ..._Lang.values.map((l) => ListTile(
              dense: true,
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: AppColors.forest100,
                    borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.translate,
                    color: AppColors.primaryMain, size: 16),
              ),
              title: Text(l.display, style: AppTypography.body),
              onTap: () => Navigator.pop(context, l),
            )),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _CautionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.amber50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.amber500),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, color: AppColors.amber600, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'GreenRoot does not set or verify any price rates. '
            'All prices shown in this quotation are as entered by the owner/nursery.',
            style: AppTypography.caption.copyWith(color: AppColors.amber700),
          ),
        ),
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _InfoCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AppTypography.caption.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5),
      );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    String label = status;
    switch (status) {
      case 'INTERNAL_DRAFT':
        bg = AppColors.border;
        fg = AppColors.textSecondary;
        label = 'Internal Draft';
        break;
      case 'CUSTOMER_DRAFT':
        bg = AppColors.amber100;
        fg = AppColors.amber600;
        label = 'Draft';
        break;
      case 'CUSTOMER_SENT':
        bg = AppColors.blue100;
        fg = AppColors.blue600;
        label = 'Sent to Customer';
        break;
      case 'CUSTOMER_ACCEPTED':
        bg = AppColors.forest100;
        fg = AppColors.primaryMain;
        label = 'Customer Accepted';
        break;
      case 'CUSTOMER_REJECTED':
        bg = AppColors.red100;
        fg = AppColors.red600;
        label = 'Customer Rejected';
        break;
      case 'CONVERTED':
        bg = AppColors.forest100;
        fg = AppColors.primaryMain;
        label = 'Converted to Order';
        break;
      // Legacy
      case 'DRAFT':
        bg = AppColors.amber100;
        fg = AppColors.amber600;
        label = 'Draft';
        break;
      case 'SENT':
      case 'APPROVED':
        bg = AppColors.blue100;
        fg = AppColors.blue600;
        label = 'Sent';
        break;
      case 'BUYER_ACCEPTED':
      case 'ACCEPTED':
        bg = AppColors.forest100;
        fg = AppColors.primaryMain;
        label = 'Accepted';
        break;
      default:
        bg = AppColors.red100;
        fg = AppColors.red600;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: AppTypography.caption
              .copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MenuOption({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return Row(children: [
      Icon(icon, size: 18, color: c),
      const SizedBox(width: 10),
      Text(label, style: AppTypography.body.copyWith(color: c)),
    ]);
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

String _fmt(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('d MMM yyyy, HH:mm').format(dt);
  } catch (_) {
    return iso;
  }
}

String _qty(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();
