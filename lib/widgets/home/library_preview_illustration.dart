import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/library_incident_summary.dart';
import 'library_incident_summary_tile.dart';

/// Visual-only preview of a future Library — never real user data.
class LibraryPreviewIllustration extends StatelessWidget {
  const LibraryPreviewIllustration({super.key});

  /// Frozen informational examples. The first two cards are canonical and
  /// must keep their existing identity, metadata, and order.
  static const previewIncidents = [
    LibraryIncidentSummary(
      id: 'preview-workplace-harassment',
      title: 'Workplace Harassment',
      evidenceCount: 12,
      contextEnrichedCount: 5,
      integrityVerified: true,
      lastPreserved: 'Yesterday • 18:42',
    ),
    LibraryIncidentSummary(
      id: 'preview-traffic-collision',
      title: 'Traffic Collision',
      evidenceCount: 27,
      contextEnrichedCount: 8,
      integrityVerified: true,
      lastPreserved: '2 days ago • 09:13',
    ),
    LibraryIncidentSummary(
      id: 'preview-wrong-item-delivered',
      title: 'Wrong Item Delivered',
      evidenceCount: 8,
      contextEnrichedCount: 5,
      integrityVerified: true,
      lastPreserved: '3 days ago • 16:08',
    ),
    LibraryIncidentSummary(
      id: 'preview-upi-payment-disputed',
      title: 'UPI Payment Disputed',
      evidenceCount: 7,
      contextEnrichedCount: 6,
      integrityVerified: true,
      lastPreserved: '5 days ago • 11:27',
    ),
    LibraryIncidentSummary(
      id: 'preview-ride-dispute',
      title: 'Ride Dispute',
      evidenceCount: 11,
      contextEnrichedCount: 7,
      integrityVerified: true,
      lastPreserved: '6 days ago • 21:14',
    ),
    LibraryIncidentSummary(
      id: 'preview-security-deposit-dispute',
      title: 'Security Deposit Dispute',
      evidenceCount: 13,
      contextEnrichedCount: 8,
      integrityVerified: true,
      lastPreserved: '8 days ago • 10:03',
    ),
    LibraryIncidentSummary(
      id: 'preview-builder-promise-vs-reality',
      title: 'Builder Promise vs Reality',
      evidenceCount: 15,
      contextEnrichedCount: 9,
      integrityVerified: true,
      lastPreserved: '12 days ago • 14:55',
    ),
    LibraryIncidentSummary(
      id: 'preview-service-complaint-unresolved',
      title: 'Service Complaint Unresolved',
      evidenceCount: 14,
      contextEnrichedCount: 11,
      integrityVerified: true,
      lastPreserved: '18 days ago • 09:40',
    ),
    LibraryIncidentSummary(
      id: 'preview-service-vs-what-was-promised',
      title: 'Service vs What Was Promised',
      evidenceCount: 10,
      contextEnrichedCount: 6,
      integrityVerified: true,
      lastPreserved: '3 weeks ago • 15:22',
    ),
    LibraryIncidentSummary(
      id: 'preview-repeated-unwanted-contact',
      title: 'Repeated Unwanted Contact',
      evidenceCount: 21,
      contextEnrichedCount: 12,
      integrityVerified: true,
      lastPreserved: '4 days ago • 22:19',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.45,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < previewIncidents.length; index++) ...[
              if (index > 0) const SizedBox(height: AppSpacing.xs),
              LibraryIncidentSummaryTile(incident: previewIncidents[index]),
            ],
          ],
        ),
      ),
    );
  }
}
