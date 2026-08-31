import 'package:flutter/material.dart';

import '../../services/storage/file_attach_flow.dart';

/// Live [PopEntry] so SAF/system [Navigator.maybePop] is blocked as soon as
/// [FileAttachFlow.blocksWorkspacePop] becomes true — without waiting a frame.
class FileAttachPopBarrier extends StatefulWidget {
  const FileAttachPopBarrier({super.key, required this.child});

  final Widget child;

  @override
  State<FileAttachPopBarrier> createState() => _FileAttachPopBarrierState();
}

class _FileAttachPopBarrierState extends State<FileAttachPopBarrier>
    implements PopEntry<void> {
  ModalRoute<dynamic>? _route;

  @override
  final ValueNotifier<bool> canPopNotifier = ValueNotifier<bool>(
    !FileAttachFlow.blocksWorkspacePop,
  );

  @override
  void initState() {
    super.initState();
    FileAttachFlow.attachLock.addListener(_syncCanPop);
    _syncCanPop();
  }

  void _syncCanPop() {
    final next = !FileAttachFlow.blocksWorkspacePop;
    if (canPopNotifier.value != next) {
      canPopNotifier.value = next;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      _route?.unregisterPopEntry(this);
      _route = route;
      _route?.registerPopEntry(this);
    }
  }

  @override
  void dispose() {
    FileAttachFlow.attachLock.removeListener(_syncCanPop);
    _route?.unregisterPopEntry(this);
    canPopNotifier.dispose();
    super.dispose();
  }

  @override
  void onPopInvoked(bool didPop) {}

  @override
  void onPopInvokedWithResult(bool didPop, void result) {}

  @override
  Widget build(BuildContext context) => widget.child;
}
