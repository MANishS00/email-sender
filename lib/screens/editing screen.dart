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
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null) {
        // Get app's documents directory
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String fileName = 'email_attachment_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final String newPath = path.join(appDir.path, fileName);

        // Save the file
        File savedFile;
        if (result.files.single.path != null) {
          savedFile = await File(result.files.single.path!).copy(newPath);
        } else {
          savedFile = await File(newPath).writeAsBytes(result.files.single.bytes!);
        }

        // Verify file saved successfully
        if (await savedFile.exists()) {
          setState(() {
            _attachmentFile = savedFile;
            _attachmentPath = newPath;
          });

          // Print debug info
          debugPrint('File saved at: $newPath');
          debugPrint('File size: ${savedFile.lengthSync()} bytes');

          // Save path to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('attachmentPath', newPath);
        }
      }
    } catch (e) {
      debugPrint('File save error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save file: ${e.toString()}')),
      );
    }
  }

  void _removeAttachment() {
    setState(() {
      _attachmentFile = null;
      _attachmentPath = null;
    });
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
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_attachmentFile != null)
                        Column(
                          children: [
                            Text(path.basename(_attachmentFile!.path)),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _removeAttachment,
                              child: const Text('Remove Attachment'),
                            ),
                          ],
                        ),
                      OutlinedButton(
                        onPressed: _selectFile,
                        child: const Text('Select PDF File'),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18.0),
                child: GestureDetector(
                  onTap: () {
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
                          offset: Offset(5, 5),
                          blurRadius: 10,
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          offset: Offset(-5, -5),
                          blurRadius: 10,
                        ),
                      ],
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.6),
                    ),
                    child: Center(
                        child: Text(
                          "Save",
                          style: TextStyle(fontSize: 25,fontWeight: FontWeight.bold),
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
