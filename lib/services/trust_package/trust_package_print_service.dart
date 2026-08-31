import '../../domain/trust_package/trust_package.dart';
import 'trust_package_pdf_renderer.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Print pipeline for Trust Package — consumes [TrustPackage] only.
abstract final class TrustPackagePrintService {
  static Future<void> printPackage(TrustPackage package) async {
    final bytes = await TrustPackagePdfRenderer.buildPdf(package);
    await Printing.layoutPdf(
      name: package.incidentSummary.incidentName,
      onLayout: (_) async => bytes,
      format: PdfPageFormat.a4,
    );
  }
}
