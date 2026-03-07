import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class EmailEditScreen extends StatefulWidget {
  final String initialSubject;
  final String initialBody;
  final String? initialAttachmentPath;

  const EmailEditScreen({
    super.key,
    required this.initialSubject,
    required this.initialBody,
    required this.initialAttachmentPath,
  });

  @override
  State<EmailEditScreen> createState() => _EmailEditScreenState();
}

class _EmailEditScreenState extends State<EmailEditScreen> {
  late TextEditingController _subjectController;
  late TextEditingController _bodyController;
  File? _attachmentFile;
  String? _attachmentPath;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(text: widget.initialSubject);
    _bodyController = TextEditingController(text: widget.initialBody);
    _attachmentPath = widget.initialAttachmentPath;
    if (_attachmentPath != null) {
      _attachmentFile = File(_attachmentPath!);
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _selectFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result != null) {
        // Get external storage directory (more accessible)
        Directory appDir;
        try {
          // Try external storage first
          appDir = await getExternalStorageDirectory() ??
              await getApplicationDocumentsDirectory();
        } catch (e) {
          // Fallback to app documents directory
          appDir = await getApplicationDocumentsDirectory();
        }

        final String originalFileName = result.files.single.name;
        final String fileName =
            'email_attachment_${DateTime.now().millisecondsSinceEpoch}_$originalFileName';
        final String newPath = path.join(appDir.path, fileName);

        debugPrint('Saving file to: $newPath');
        debugPrint('Directory exists: ${await appDir.exists()}');

        // Save the file
        File savedFile;
        if (result.files.single.path != null) {
          savedFile = await File(result.files.single.path!).copy(newPath);
        } else {
          savedFile =
              await File(newPath).writeAsBytes(result.files.single.bytes!);
        }

        // Verify file saved successfully
        if (await savedFile.exists()) {
          final fileSize = await savedFile.length();
          debugPrint('File saved successfully');
          debugPrint('File size: $fileSize bytes');
          debugPrint('File path: $newPath');

          setState(() {
            _attachmentFile = savedFile;
            _attachmentPath = newPath;
          });

          // Save path to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('attachmentPath', newPath);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Attachment saved: $originalFileName')),
          );
        } else {
          throw Exception('File not saved properly');
        }
      }
    } catch (e) {
      debugPrint('File save error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save file: ${e.toString()}')),
      );
    }
  }

  void _removeAttachment() async {
    if (_attachmentFile != null && await _attachmentFile!.exists()) {
      try {
        await _attachmentFile!.delete();
        debugPrint('Attachment file deleted');
      } catch (e) {
        debugPrint('Error deleting file: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('attachmentPath');

    setState(() {
      _attachmentFile = null;
      _attachmentPath = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attachment removed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Edit Email Template'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _bodyController,
                maxLines: 17,
                decoration: const InputDecoration(
                  labelText: 'Body',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Attachment',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      if (_attachmentFile != null)
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.attach_file, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    path.basename(_attachmentFile!.path),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Size: ${(_attachmentFile!.lengthSync() / 5000).toStringAsFixed(2)} KB',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _removeAttachment,
                              child: const Text('Remove Attachment'),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _selectFile,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Select Attachment File'),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Supported: PDF, DOC, TXT, JPG, PNG',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18.0),
                child: GestureDetector(
                  onTap: () async {
                    // Verify attachment exists if path is not null
                    if (_attachmentPath != null) {
                      final file = File(_attachmentPath!);
                      if (!await file.exists()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Attachment file not found! Please reselect.')),
                        );
                        return;
                      }
                    }

                    Navigator.pop(context, {
                      'subject': _subjectController.text,
                      'body': _bodyController.text,
                      'attachmentPath': _attachmentPath,
                    });
                  },
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          offset: const Offset(5, 5),
                          blurRadius: 10,
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          offset: const Offset(-5, -5),
                          blurRadius: 10,
                        ),
                      ],
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.6),
                    ),
                    child: Center(
                        child: Text(
                      "Save",
                      style:
                          TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                    )),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
