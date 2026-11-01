import 'dart:io';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sanad_app/core/services/attachment_service.dart';
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';

class AttachmentViewerModal extends StatefulWidget {
  final String filePath;
  final VoidCallback? onDelete;

  const AttachmentViewerModal({
    super.key,
    required this.filePath,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required String filePath,
    VoidCallback? onDelete,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (_) => AttachmentViewerModal(
        filePath: filePath,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<AttachmentViewerModal> createState() => _AttachmentViewerModalState();
}

class _AttachmentViewerModalState extends State<AttachmentViewerModal> {
  bool _isLoading = true;
  bool _exists = false;
  int _fileLength = 0;
  late final File _file;
  late final AttachmentItem _item;

  @override
  void initState() {
    super.initState();
    _file = File(widget.filePath);
    _item = AttachmentItem.fromPath(widget.filePath);
    _checkFile();
  }

  Future<void> _checkFile() async {
    final exists = await _file.exists();
    int length = 0;
    if (exists) {
      try {
        length = await _file.length();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _exists = exists;
        _fileLength = length;
        _isLoading = false;
      });
    }
  }

  void _shareAttachment(BuildContext context) {
    SpendoHaptics.light();
    SharePlus.instance.share(
      ShareParams(
        files: [XFile(widget.filePath)],
        subject: 'مرفق توثيق العمل - Spendo',
      ),
    );
  }

  void _openFileExternally() async {
    SpendoHaptics.light();
    final uri = Uri.file(widget.filePath);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: const Color(0xFF121413).withValues(alpha: 0.95),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Remix.close_line, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _item.name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: const Icon(Remix.share_forward_line, color: Color(0xFFEAB308)),
              tooltip: 'مشاركة',
              onPressed: () => _shareAttachment(context),
            ),
            if (widget.onDelete != null)
              IconButton(
                icon: const Icon(Remix.delete_bin_6_line, color: Color(0xFFEF4444)),
                tooltip: 'حذف المرفق',
                onPressed: () {
                  SpendoHaptics.light();
                  Navigator.pop(context);
                  widget.onDelete!();
                },
              ),
          ],
        ),
        body: Center(
          child: _isLoading
              ? const CircularProgressIndicator(color: Color(0xFF00A86B))
              : !_exists
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Remix.file_damage_line, size: 48, color: Color(0xFF71717A)),
                        SizedBox(height: 12),
                        Text(
                          'الملف غير متوفر في الذاكرة المحلية',
                          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                        ),
                      ],
                    )
                  : _item.isImage
                      ? InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 4.0,
                          child: Image.file(
                            _file,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Container(
                          margin: const EdgeInsets.all(24),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF171A19),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF242927)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _item.isPdf ? Remix.file_pdf_2_fill : Remix.file_text_fill,
                                size: 64,
                                color: _item.isPdf ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _item.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'الحجم: ${(_fileLength / 1024).toStringAsFixed(1)} كيلوبايت',
                                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF00A86B),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      icon: const Icon(Remix.external_link_line, size: 16),
                                      label: const Text('فتح الملف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      onPressed: _openFileExternally,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFF242927)),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      icon: const Icon(Remix.share_line, size: 16),
                                      label: const Text('مشاركة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      onPressed: () => _shareAttachment(context),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
        ),
      ),
    );
  }
}
