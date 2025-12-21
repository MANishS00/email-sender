
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

      if (_attachmentPath != null && File(_attachmentPath!).existsSync()) {
        _attachmentFile = File(_attachmentPath!);
      } else {
        _attachmentPath = null;
        _attachmentFile = null;
      }
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subject', _subject);
    await prefs.setString('body', _body);
    if (_attachmentPath != null) {
      await prefs.setString('attachmentPath', _attachmentPath!);
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
      setState(() {
        _recipientEmail = uri.path;
      });
      _openDefaultEmailClient();
    }
  }

  Future<void> _openDefaultEmailClient() async {
    if (_recipientEmail == null || _recipientEmail!.isEmpty) {
      setState(() => _statusMessage = 'No recipient email found');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Preparing email...';
    });

    try {
      List<String> attachments = [];
      if (_attachmentFile != null && await _attachmentFile!.exists()) {
        attachments.add(_attachmentFile!.path);
      }

      final Email email = Email(
        recipients: [_recipientEmail!],
        subject: _subject,
        body: _body,
        attachmentPaths: attachments,
      );

      // First try to send directly
      await FlutterEmailSender.send(email);
      setState(() => _statusMessage = 'Email sent successfully!');
    } on PlatformException catch (e) {
      if (e.code == 'not_available') {
        // Fallback to mailto: URI if no email client found
        await _sendEmail();
      } else {
        setState(() => _statusMessage = 'Error: ${e.message}');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }
  Future<void> _sendEmail() async {
    try {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Preparing email...';
      });

      // Verify attachment exists
      List<String> attachments = [];
      if (_attachmentPath != null) {
        final file = File(_attachmentPath!);

        // Add debug prints
        debugPrint('Checking attachment at: ${file.path}');
        debugPrint('File exists: ${await file.exists()}');
        if (await file.exists()) {
          debugPrint('File size: ${await file.length()} bytes');
          attachments.add(file.path);
        } else {
          debugPrint('Attachment file missing');
          setState(() => _statusMessage = 'Attachment file not found');
          return;
        }
      }

      final Email email = Email(
        recipients: [_recipientEmail!],
        subject: _subject,
        body: _body,
        attachmentPaths: attachments,
        isHTML: false,
      );

      // Print final email details before sending
      debugPrint('Sending email with attachment: ${attachments.isNotEmpty ? attachments.first : "none"}');

      await FlutterEmailSender.send(email);

      setState(() {
        _statusMessage = 'Email sent with attachment!';
      });
    } catch (e) {
      debugPrint('Email send error: $e');
      setState(() => _statusMessage = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }


  Future<void> _sendViaMailto() async {
    try {
      String mailtoUri = 'mailto:${_recipientEmail!}?'
          'subject=${Uri.encodeComponent(_subject)}&'
          'body=${Uri.encodeComponent(_body)}';

      if (await canLaunch(mailtoUri)) {
        await launch(mailtoUri);
        setState(() {
          _statusMessage = 'Opened email client! Note: Attachments cannot be included with mailto links';
        });
      } else {
        setState(() {
          _statusMessage = 'Could not launch email client';
        });
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error: ${e.toString()}');
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
        }
      });

      await _saveData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('E Template Sender'),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.email != null)
                Text.rich(TextSpan(children: [
                  TextSpan(
                    text: "This is:\n",
                    style: TextStyle(fontSize: 15),
                  ),
                  TextSpan(
                    text: widget.email,
                    style: TextStyle(fontSize: 20),
                  ),
                ])),
              const SizedBox(height: 30),
              if (_recipientEmail != null)
                Text(
                  'To \nRecipient: \n$_recipientEmail',
                  style: const TextStyle(fontSize: 20),
                ),
              const SizedBox(height: 30),
              if (_isProcessing) const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                _statusMessage,
                style: TextStyle(
                  color: _statusMessage.contains('Error')
                      ? Colors.red
                      : Colors.green,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              if (_attachmentFile != null)
                Column(
                  children: [
                    const Text('Current Attachment:'),
                    Text(
                      path.basename(_attachmentFile!.path),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: widget.email != null
          ? FloatingActionButton(
        onPressed: _navigateToEditScreen,
        tooltip: 'Edit Template',
        child: const Icon(Icons.edit),
      )
          : null,
    );
  }
}

