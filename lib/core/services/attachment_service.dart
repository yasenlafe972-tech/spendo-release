import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class AttachmentItem {
  final String path;
  final String name;
  final bool isImage;
  final bool isPdf;

  const AttachmentItem({
    required this.path,
    required this.name,
    required this.isImage,
    required this.isPdf,
  });

  factory AttachmentItem.fromPath(String filePath) {
    final name = p.basename(filePath);
    final ext = p.extension(filePath).toLowerCase();
    final isImg = ['.jpg', '.jpeg', '.png', '.webp', '.heic'].contains(ext);
    final isPdfDoc = ext == '.pdf';

    return AttachmentItem(
      path: filePath,
      name: name,
      isImage: isImg,
      isPdf: isPdfDoc,
    );
  }
}

class AttachmentService {
  static final AttachmentService instance = AttachmentService._internal();
  AttachmentService._internal();

  final ImagePicker _picker = ImagePicker();

  Future<Directory> _getStorageDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(docsDir.path, 'spendo_attachments'));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir;
  }

  /// Copies an external file into the permanent app storage directory with a unique name.
  Future<String?> _copyToPermanentStorage(String sourcePath) async {
    try {
      final srcFile = File(sourcePath);
      if (!await srcFile.exists()) return null;

      final targetDir = await _getStorageDirectory();
      final ext = p.extension(sourcePath);
      final uniqueFileName = '${const Uuid().v4()}$ext';
      final destPath = p.join(targetDir.path, uniqueFileName);

      final copiedFile = await srcFile.copy(destPath);
      return copiedFile.path;
    } catch (e) {
      debugPrint('Error copying attachment to permanent storage: $e');
      return sourcePath;
    }
  }

  /// Takes a high-resolution photo using the device camera.
  Future<String?> capturePhoto() async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (xFile == null) return null;
      return await _copyToPermanentStorage(xFile.path);
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      return null;
    }
  }

  /// Picks images from the phone's gallery.
  Future<List<String>> pickImagesFromGallery() async {
    try {
      final List<XFile> xFiles = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (xFiles.isEmpty) return [];

      final List<String> permanentPaths = [];
      for (final xFile in xFiles) {
        final perm = await _copyToPermanentStorage(xFile.path);
        if (perm != null) permanentPaths.add(perm);
      }
      return permanentPaths;
    } catch (e) {
      debugPrint('Error picking images from gallery: $e');
      return [];
    }
  }

  /// Picks documents (PDF, Word, or images) via file picker.
  Future<List<String>> pickDocuments() async {
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );

      if (files.isEmpty) return [];

      final List<String> permanentPaths = [];
      for (final file in files) {
        if (file.path != null) {
          final perm = await _copyToPermanentStorage(file.path!);
          if (perm != null) permanentPaths.add(perm);
        }
      }
      return permanentPaths;
    } catch (e) {
      debugPrint('Error picking documents: $e');
      return [];
    }
  }

  /// Safely deletes an attachment file.
  Future<void> deleteAttachment(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting attachment: $e');
    }
  }
}
