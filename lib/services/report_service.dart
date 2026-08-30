import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/travel_models.dart';

/// Builds a polished, branded PDF trip report — a cover page (trip
/// snapshot), a preferences summary, a fully-styled card per destination
/// (rank badge, stat grid, activities table, transport/entry fees, and all
/// 3 hotel tiers with 3 hotels each), and a tips section — then hands it
/// to the OS share/save sheet. Uses the same Cormorant Garamond / Nunito
/// pairing and Ceylon Spice palette as the app so the export feels native
/// to the product instead of a generic data dump.
///
/// NOTE: image embedding (destination photos) was intentionally removed —
/// it was the source of a "value != double.infinity" crash in the pdf
/// package's number encoder (corrupt/undecodable asset bytes broke
/// BoxFit.cover's scale calculation). The report is now text/data only.
class ReportService {
  // ── Ceylon Spice palette (mirrors AppTheme) ───────────────────────────────
  static final _deepJungle = PdfColor.fromHex('#1B4332');
  static final _cinnamon = PdfColor.fromHex('#B5651D');
  static final _saffron = PdfColor.fromHex('#E9A825');
  static final _cream = PdfColor.fromHex('#F5F0E8');
  static final _muted = PdfColor.fromHex('#7A7268');
  static final _border = PdfColor.fromHex('#E4DED2');
  static final _silver = PdfColor.fromHex('#C0C0C0');
  static final _bronze = PdfColor.fromHex('#CD7F32');

  late pw.Font _regular;
  late pw.Font _bold;
  late pw.Font _italic;
  late pw.Font _headingBold;

  Future<void> _loadFonts() async {
    _regular = await PdfGoogleFonts.nunitoRegular();
    _bold = await PdfGoogleFonts.nunitoBold();
    _italic = await PdfGoogleFonts.nunitoItalic();
    _headingBold = await PdfGoogleFonts.cormorantGaramondBold();
  }

  Future<void> generateAndShareReport({
    required RecommendationResponse response,
    required TravelPreferences preferences,
  }) async {
    try {
      await _loadFonts();

      final doc = pw.Document(
        theme:
            pw.ThemeData.withFont(base: _regular, bold: _bold, italic: _italic),
      );

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) => _buildCoverPage(preferences, response),
        ),
      );

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(34, 26, 34, 26),
          header: _buildRunningHeader,
          footer: _buildRunningFooter,
          build: (context) => [
            _sectionTitle('Trip Preferences'),
            pw.SizedBox(height: 12),
            _preferencesCard(preferences),
            pw.SizedBox(height: 26),
            _sectionTitle('Recommended Destinations'),
            pw.SizedBox(height: 4),
            pw.Text(
              '${response.recommendations.length} AI-curated picks, ranked to fit your trip',
              style: pw.TextStyle(font: _italic, fontSize: 9.5, color: _muted),
            ),
            pw.SizedBox(height: 14),
            ...response.recommendations.map(_destinationSection),
            if (response.travelTips.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              _sectionTitle('Travel Tips'),
              pw.SizedBox(height: 12),
              _tipsCard(response.travelTips),
            ],
          ],
        ),
      );

      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'ceylon_trip_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('ReportService.generateAndShareReport failed: $e\n$st');
      rethrow;
    }
  }

  // ── Cover page ─────────────────────────────────────────────────────────────
  pw.Widget _buildCoverPage(
    TravelPreferences prefs,
    RecommendationResponse response,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          color: _deepJungle,
          padding: const pw.EdgeInsets.fromLTRB(40, 64, 40, 34),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'CeylonTourMate',
                style: pw.TextStyle(
                  font: _bold,
                  fontSize: 11,
                  color: _saffron,
                  letterSpacing: 3,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Your Sri Lanka',
                style: pw.TextStyle(
                  font: _headingBold,
                  fontSize: 38,
                  color: PdfColors.white,
                ),
              ),
              pw.Text(
                'Trip Report',
                style: pw.TextStyle(
                  font: _headingBold,
                  fontSize: 38,
                  color: _saffron,
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                '${response.recommendations.length} AI-curated destinations  •  '
                '${prefs.tripDays}-day journey  •  ${_titleCase(prefs.groupType)} trip',
                style: pw.TextStyle(
                  font: _regular,
                  fontSize: 11.5,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ),
        pw.Container(
          width: double.infinity,
          color: PdfColors.white,
          padding: const pw.EdgeInsets.fromLTRB(40, 36, 40, 30),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                'TRIP SNAPSHOT',
                style: pw.TextStyle(
                  font: _bold,
                  fontSize: 9.5,
                  color: _muted,
                  letterSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _snapshotChip(
                    'Group',
                    '${_titleCase(prefs.groupType)} • ${prefs.groupSize}',
                  ),
                  _snapshotChip(
                    'Budget',
                    '${_titleCase(prefs.budgetTier)} (~\$${_safeFixed(prefs.budgetUsd)})',
                  ),
                  _snapshotChip('Travel date', prefs.travelDate),
                  _snapshotChip('Duration', '${prefs.tripDays} day(s)'),
                ],
              ),
              pw.SizedBox(height: 28),
              pw.Divider(color: _border, thickness: 0.6),
              pw.SizedBox(height: 8),
              pw.Text(
                'Generated on ${_formatDate(DateTime.now())} by CeylonTourMate',
                style: pw.TextStyle(font: _italic, fontSize: 9, color: _muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _snapshotChip(String label, String value) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
          color: _cream,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: _border),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(
                font: _bold,
                fontSize: 7.5,
                color: _muted,
                letterSpacing: 1,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style:
                  pw.TextStyle(font: _bold, fontSize: 10.5, color: _deepJungle),
            ),
          ],
        ),
      );

  // ── Running header / footer for content pages ─────────────────────────────
  pw.Widget _buildRunningHeader(pw.Context context) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'CeylonTourMate',
              style: pw.TextStyle(
                font: _bold,
                fontSize: 8,
                color: _muted,
                letterSpacing: 1.5,
              ),
            ),
            pw.Text(
              'Trip Report',
              style: pw.TextStyle(font: _italic, fontSize: 8, color: _muted),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: _border, thickness: 0.6),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildRunningFooter(pw.Context context) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Divider(color: _border, thickness: 0.6),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'CeylonTourMate',
              style: pw.TextStyle(font: _regular, fontSize: 7.5, color: _muted),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(font: _regular, fontSize: 7.5, color: _muted),
            ),
          ],
        ),
      ],
    );
  }

  // ── Section title with accent bar ────────────────────────────────────────
  pw.Widget _sectionTitle(String text) => pw.Row(
        children: [
          pw.Container(width: 4, height: 18, color: _saffron),
          pw.SizedBox(width: 8),
          pw.Text(
            text,
            style: pw.TextStyle(
                font: _headingBold, fontSize: 18, color: _deepJungle),
          ),
        ],
      );

  pw.Widget _subheading(String text) => pw.Text(
        text,
        style: pw.TextStyle(font: _bold, fontSize: 10.5, color: _cinnamon),
      );

  // ── Preferences card ──────────────────────────────────────────────────────
  pw.Widget _preferencesCard(TravelPreferences p) {
    final rows = <List<String>>[
      [
        'Group',
        '${_titleCase(p.groupType)} • ${p.groupSize} traveller(s) • ${_titleCase(p.gender)}',
      ],
      ['Age range', p.ageRange],
      [
        'Budget',
        '${_titleCase(p.budgetTier)} (~USD ${_safeFixed(p.budgetUsd)})',
      ],
      ['Trip length', '${p.tripDays} day(s)'],
      ['Travel date', '${p.travelDate} (${p.travelMonth})'],
      if (p.activityPreferences.isNotEmpty)
        ['Interests', p.activityPreferences.join(', ')],
    ];

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _cream,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: rows
            .map(
              (r) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 7),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 92,
                      child: pw.Text(
                        r[0],
                        style: pw.TextStyle(
                          font: _bold,
                          fontSize: 9.5,
                          color: _deepJungle,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        r[1],
                        style: pw.TextStyle(
                          font: _regular,
                          fontSize: 9.5,
                          color: PdfColors.grey900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ── One destination's full package details ───────────────────────────────
  pw.Widget _destinationSection(TravelRecommendation rec) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _rankBadge(rec.rank),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            rec.destination,
                            style: pw.TextStyle(
                              font: _headingBold,
                              fontSize: 17,
                              color: _deepJungle,
                            ),
                          ),
                        ),
                        if (rec.rating != null && rec.rating!.isFinite)
                          pw.Text(
                            '${rec.rating!.toStringAsFixed(1)} / 5',
                            style: pw.TextStyle(
                              font: _bold,
                              fontSize: 9.5,
                              color: _saffron,
                            ),
                          ),
                      ],
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      rec.packageName,
                      style: pw.TextStyle(
                          font: _italic, fontSize: 10, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _statPair('Cost / person', 'USD ${rec.packageCostPerPerson}'),
              _statPair('Total / person', 'USD ${rec.totalCostPerPerson}'),
              _statPair('Weather fit', rec.weatherSuitability),
              _statPair('Accommodation', rec.accommodation),
            ],
          ),
          if (rec.whySuitable.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _subheading('Why this fits you'),
            pw.SizedBox(height: 3),
            pw.Text(
              rec.whySuitable,
              style: pw.TextStyle(
                  font: _regular, fontSize: 9.6, color: PdfColors.grey900),
            ),
          ],
          if (rec.activities.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _subheading('Activities'),
            pw.SizedBox(height: 5),
            _activitiesTable(rec.activities),
          ],
          if (rec.transportInfo.isNotEmpty || rec.entryFees.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (rec.transportInfo.isNotEmpty)
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _subheading('Transport'),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          rec.transportInfo,
                          style: pw.TextStyle(
                            font: _regular,
                            fontSize: 9.4,
                            color: PdfColors.grey900,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (rec.transportInfo.isNotEmpty && rec.entryFees.isNotEmpty)
                  pw.SizedBox(width: 16),
                if (rec.entryFees.isNotEmpty)
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _subheading('Entry Fees'),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          rec.entryFees,
                          style: pw.TextStyle(
                            font: _regular,
                            fontSize: 9.4,
                            color: PdfColors.grey900,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          if (rec.hotelOptions.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _subheading('Hotel Options'),
            pw.SizedBox(height: 6),
            _hotelTiersRow(rec.hotelOptions),
          ],
        ],
      ),
    );
  }

  pw.Widget _rankBadge(int rank) => pw.Container(
        width: 24,
        height: 24,
        decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle, color: _rankColor(rank)),
        alignment: pw.Alignment.center,
        child: pw.Text(
          '$rank',
          style:
              pw.TextStyle(font: _bold, fontSize: 11, color: PdfColors.white),
        ),
      );

  PdfColor _rankColor(int rank) {
    switch (rank) {
      case 1:
        return _saffron;
      case 2:
        return _silver;
      case 3:
        return _bronze;
      default:
        return _cinnamon;
    }
  }

  pw.Widget _statPair(String label, String value) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
                font: _bold, fontSize: 7.5, color: _muted, letterSpacing: 0.8),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value.isEmpty ? '—' : value,
            style: pw.TextStyle(
                font: _bold, fontSize: 10, color: PdfColors.grey900),
          ),
        ],
      );

  // ── Activities table ──────────────────────────────────────────────────────
  pw.Widget _activitiesTable(List<Activity> activities) {
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _cream),
          children: [
            _tableCell('Activity', bold: true),
            _tableCell('Price (USD)', bold: true, alignRight: true),
          ],
        ),
        ...activities.map(
          (a) => pw.TableRow(
            children: [
              _tableCell(a.name),
              _tableCell(a.priceUsd, alignRight: true),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _tableCell(String text,
          {bool bold = false, bool alignRight = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Text(
          text,
          textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            font: bold ? _bold : _regular,
            fontSize: 9,
            color: bold ? _deepJungle : PdfColors.grey900,
          ),
        ),
      );

  // ── Hotel tier cards (3 tiers × 3 hotels, side by side) ──────────────────
  pw.Widget _hotelTiersRow(List<HotelTierOption> tiers) {
    final children = <pw.Widget>[];
    for (var i = 0; i < tiers.length; i++) {
      if (i > 0) children.add(pw.SizedBox(width: 8));
      children.add(_hotelTierCard(tiers[i]));
    }
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: children,
    );
  }

  pw.Widget _hotelTierCard(HotelTierOption tier) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(9),
          decoration: pw.BoxDecoration(
            color: _cream,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: _border),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                tier.tier.toUpperCase(),
                style: pw.TextStyle(
                  font: _bold,
                  fontSize: 8.5,
                  color: _cinnamon,
                  letterSpacing: 0.6,
                ),
              ),
              pw.SizedBox(height: 5),
              ...tier.hotels.map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(
                        font: _regular,
                        fontSize: 8.3,
                        color: PdfColors.grey900),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  // ── Travel tips card ──────────────────────────────────────────────────────
  pw.Widget _tipsCard(List<String> tips) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: _cream,
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: _border),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: tips
              .map(
                (t) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 7),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        margin: const pw.EdgeInsets.only(top: 4, right: 8),
                        width: 5,
                        height: 5,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          color: _saffron,
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          t,
                          style: pw.TextStyle(
                            font: _regular,
                            fontSize: 9.8,
                            color: PdfColors.grey900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      );

  String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Safely formats a double that might be NaN/Infinity (bad upstream data)
  /// instead of feeding a non-finite value further downstream.
  String _safeFixed(double value, [int digits = 0]) =>
      value.isFinite ? value.toStringAsFixed(digits) : '—';
}
