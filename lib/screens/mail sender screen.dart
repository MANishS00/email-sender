import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:async';
import '../auth/auth service.dart';
import 'editing screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

class EmailSenderScreen extends StatefulWidget {
  final String? email;

  const EmailSenderScreen({super.key, this.email});

  @override
  State<EmailSenderScreen> createState() => _EmailSenderScreenState();
}

class _EmailSenderScreenState extends State<EmailSenderScreen> {
  String? _recipientEmail;
  bool _isProcessing = false;
  String _statusMessage = '';
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  bool _hasOpenedEmailClient = false;

  String _subject = 'I am Subject';
  String _body = "I am Body";
  String? _attachmentPath;
  File? _attachmentFile;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _subject = prefs.getString('subject') ?? _subject;
      _body = prefs.getString('body') ?? _body;
      _attachmentPath = prefs.getString('attachmentPath');

      if (_attachmentPath != null) {
        _attachmentFile = File(_attachmentPath!);
        // Check if file exists
        if (!_attachmentFile!.existsSync()) {
          _attachmentPath = null;
          _attachmentFile = null;
          // Clean up invalid path
          prefs.remove('attachmentPath');
        }
      }
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subject', _subject);
    await prefs.setString('body', _body);
    if (_attachmentPath != null) {
      await prefs.setString('attachmentPath', _attachmentPath!);
    } else {
      await prefs.remove('attachmentPath');
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initAppLinks() async {
    _appLinks = AppLinks();

    final appLink = await _appLinks.getInitialLink();
    if (appLink != null) {
      _handleDeepLink(appLink);
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'mailto') {
      final recipient = uri.path;
      debugPrint('Received deep link with recipient: $recipient');

      setState(() {
        _recipientEmail = recipient;
      });

      // Auto-open email client when deep link is received
      if (!_hasOpenedEmailClient) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          _openEmailClientWithAttachment();
        });
      }
    }
  }

  Future<void> _openEmailClientWithAttachment() async {
    if (_recipientEmail == null || _recipientEmail!.isEmpty) {
      setState(() => _statusMessage = 'No recipient email found');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Opening email client with attachment...';
      _hasOpenedEmailClient = true;
    });

    try {
      // First, copy the file to a temporary location with a simpler name
      String? tempAttachmentPath;
      if (_attachmentFile != null && await _attachmentFile!.exists()) {
        // Create a temporary directory
        final tempDir = await getTemporaryDirectory();
        final originalFileName = path.basename(_attachmentFile!.path);
        final simpleFileName = originalFileName
            .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_') // Remove special chars
            .replaceAll(RegExp(r'_+'), '_'); // Replace multiple underscores

        tempAttachmentPath = path.join(tempDir.path, simpleFileName);

        debugPrint('Copying attachment to temporary location...');
        debugPrint('From: ${_attachmentFile!.path}');
        debugPrint('To: $tempAttachmentPath');

        // Copy file to temporary location
        await _attachmentFile!.copy(tempAttachmentPath);

        // Verify the copy worked
        final tempFile = File(tempAttachmentPath);
        if (await tempFile.exists()) {
          debugPrint(
              'File copied successfully. Size: ${await tempFile.length()} bytes');
        } else {
          debugPrint('ERROR: File copy failed!');
          tempAttachmentPath = null;
        }
      }

      // Prepare attachment list
      List<String> attachments = [];
      if (tempAttachmentPath != null) {
        attachments.add(tempAttachmentPath);
      } else if (_attachmentPath != null) {
        // Fallback to original path
        attachments.add(_attachmentPath!);
      }

      debugPrint('=== EMAIL DETAILS ===');
      debugPrint('Recipient: $_recipientEmail');
      debugPrint('Subject: $_subject');
      debugPrint('Body length: ${_body.length} chars');
      debugPrint('Attachment paths: $attachments');

      if (attachments.isNotEmpty) {
        for (String attachment in attachments) {
          final file = File(attachment);
          debugPrint('Attachment: ${path.basename(attachment)}');
          debugPrint('- Path: $attachment');
          debugPrint('- Exists: ${await file.exists()}');
          if (await file.exists()) {
            debugPrint('- Size: ${await file.length()} bytes');
          }
        }
      }
      debugPrint('=====================');

      // Create email with all data
      final Email email = Email(
        recipients: [_recipientEmail!],
        subject: _subject,
        body: _body,
        attachmentPaths: attachments,
        isHTML: false,
      );

      debugPrint('Attempting to open email client...');

      // This opens the native email client with everything pre-filled
      await FlutterEmailSender.send(email);
      debugPrint('Email client opened successfully');

      String message = '✅ Email client opened!\n'
          '✓ To: $_recipientEmail\n'
          '✓ Subject: $_subject\n';

      if (attachments.isNotEmpty) {
        message += '✓ Attachment: ${path.basename(attachments.first)}\n';

        // Show file size
        final file = File(attachments.first);
        if (await file.exists()) {
          final sizeKB = (await file.length()) / 1024;
          message += '✓ File size: ${sizeKB.toStringAsFixed(2)} KB\n';
        }
      } else {
        message += '✓ Attachment: None\n';
      }

      message += '\n📤 Please click "SEND" in your email app to send.';

      setState(() {
        _statusMessage = message;
      });
    } on PlatformException catch (e) {
      debugPrint('PlatformException: ${e.code} - ${e.message}');

      if (e.code == 'not_available') {
        // No email client found
        setState(() {
          _statusMessage = '❌ No email app found!\n'
              'Please install Gmail, Outlook, or any email app.';
        });

        // Fallback to mailto without attachment
        await _sendViaMailtoFallback();
      } else {
        setState(() => _statusMessage = 'Error: ${e.message}');
      }
    } catch (e) {
      debugPrint('Error opening email client: $e');
      setState(() => _statusMessage = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _sendViaMailtoFallback() async {
    try {
      String mailtoUri = 'mailto:${_recipientEmail!}?'
          'subject=${Uri.encodeComponent(_subject)}&'
          'body=${Uri.encodeComponent(_body)}';

      if (await canLaunchUrl(Uri.parse(mailtoUri))) {
        await launchUrl(Uri.parse(mailtoUri));
        setState(() {
          _statusMessage = 'Opened email client via mailto link!\n'
              'Note: Attachment cannot be included with this method.';
        });
      } else {
        setState(() {
          _statusMessage = 'Could not open email client.\n'
              'Please install an email app on your device.';
        });
      }
    } catch (e) {
      debugPrint('Mailto fallback error: $e');
    }
  }

  // Alternative method using direct platform channels
  Future<void> _openEmailClientDirectly() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Opening email client...';
    });

    try {
      String? attachmentUri;
      if (_attachmentFile != null && await _attachmentFile!.exists()) {
        // For Android, we need to create a content URI
        if (Platform.isAndroid) {
          // Android needs content:// URI
          final filePath = _attachmentFile!.path;
          attachmentUri =
              'content://${filePath.replaceFirst('/data/data/', '')}';
          debugPrint('Android attachment URI: $attachmentUri');
        } else if (Platform.isIOS) {
          // iOS uses file:// URI
          attachmentUri = 'file://${_attachmentFile!.path}';
          debugPrint('iOS attachment URI: $attachmentUri');
        }
      }

      // Create a mailto URI with attachment query parameter
      String mailtoUri = 'mailto:${_recipientEmail!}?'
          'subject=${Uri.encodeComponent(_subject)}&'
          'body=${Uri.encodeComponent(_body)}';

      if (attachmentUri != null) {
        mailtoUri += '&attachment=${Uri.encodeComponent(attachmentUri)}';
      }

      debugPrint('Opening URI: $mailtoUri');

      if (await canLaunchUrl(Uri.parse(mailtoUri))) {
        await launchUrl(Uri.parse(mailtoUri));
        setState(() {
          _statusMessage = 'Email client opened!\n'
              'Please check if attachment is included.';
        });
      } else {
        setState(() {
          _statusMessage = 'Could not open email client.';
        });
      }
    } catch (e) {
      debugPrint('Direct open error: $e');
      setState(() => _statusMessage = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _navigateToEditScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmailEditScreen(
          initialSubject: _subject,
          initialBody: _body,
          initialAttachmentPath: _attachmentPath,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _subject = result['subject'];
        _body = result['body'];
        _attachmentPath = result['attachmentPath'];
        if (_attachmentPath != null) {
          _attachmentFile = File(_attachmentPath!);
          // Verify file exists
          if (!_attachmentFile!.existsSync()) {
            _attachmentPath = null;
            _attachmentFile = null;
          }
        } else {
          _attachmentFile = null;
        }
      });

      await _saveData();
    }
  }

  Future<void> _testAttachment() async {
    if (_attachmentFile != null) {
      debugPrint('=== ATTACHMENT TEST ===');
      debugPrint('Path: ${_attachmentFile!.path}');
      debugPrint('Exists: ${await _attachmentFile!.exists()}');
      if (await _attachmentFile!.exists()) {
        debugPrint('Size: ${await _attachmentFile!.length()} bytes');
        try {
          await _attachmentFile!.readAsBytes();
          debugPrint('Readable: YES');

          // Try to get file info
          final stat = await _attachmentFile!.stat();
          debugPrint('File type: ${stat.type}');
          debugPrint('Last modified: ${stat.modified}');
        } catch (e) {
          debugPrint('Readable: NO - $e');
        }
      } else {
        debugPrint('ERROR: File does not exist!');
      }
      debugPrint('=======================');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attachment test complete. Check debug console.'),
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No attachment to test.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Email Template Bridge'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // User info
                if (widget.email != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          const Text(
                            "Logged in as:",
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          Text(
                            widget.email!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 30),

                // Recipient Info
                if (_recipientEmail != null)
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Icon(Icons.email, size: 40, color: Colors.blue),
                          const SizedBox(height: 10),
                          const Text(
                            'Ready to send email to:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _recipientEmail!,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _openEmailClientWithAttachment,
                            icon: const Icon(Icons.send),
                            label: const Text(
                                'Open Email Client with FlutterEmailSender'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(300, 50),
                              backgroundColor: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _openEmailClientDirectly,
                            icon: const Icon(Icons.alternate_email, size: 16),
                            label: const Text('Try Alternative Method'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _testAttachment,
                            icon: const Icon(Icons.bug_report, size: 16),
                            label: const Text('Test Attachment'),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 30),

                // Processing indicator
                if (_isProcessing) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  const Text('Opening email client with attachment...'),
                  const SizedBox(height: 20),
                ],

                // Status message
                if (_statusMessage.isNotEmpty)
                  Card(
                    color: _statusMessage.contains('❌') ||
                            _statusMessage.contains('Error')
                        ? Colors.red[50]
                        : _statusMessage.contains('Note')
                            ? Colors.orange[50]
                            : Colors.green[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _statusMessage.contains('❌') ||
                                  _statusMessage.contains('Error')
                              ? Colors.red[800]
                              : _statusMessage.contains('Note')
                                  ? Colors.orange[800]
                                  : Colors.green[800],
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                const SizedBox(height: 30),

                // Current Template Preview
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Current Template:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            if (_attachmentFile != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.attach_file, size: 12),
                                    SizedBox(width: 4),
                                    Text('With Attachment',
                                        style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Subject: $_subject',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Body: ${_body.length > 100 ? '${_body.substring(0, 100)}...' : _body}',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 10),
                        if (_attachmentFile != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              const Text(
                                'Attachment:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  const Icon(Icons.attach_file,
                                      size: 16, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      path.basename(_attachmentFile!.path),
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Size: ${(_attachmentFile!.lengthSync() / 1024).toStringAsFixed(2)} KB',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                'Path: ${_attachmentFile!.path}',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Clear recipient button
                if (_recipientEmail != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _recipientEmail = null;
                        _statusMessage = '';
                        _hasOpenedEmailClient = false;
                      });
                    },
                    child: const Text('Clear Current Recipient'),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: widget.email != null
          ? FloatingActionButton(
              onPressed: _navigateToEditScreen,
              tooltip: 'Edit Email Template',
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }
}
