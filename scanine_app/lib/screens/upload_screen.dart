import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/tokens.dart';
import 'analyzing_screen.dart';

const _tips = <String>[
  'Fill the frame with the affected area',
  'Use daylight or bright indoor lighting',
  'Hold steady — avoid motion blur',
];

/// Gallery upload path. Mirrors the PWA's upload mode: a tappable
/// dropzone, three quality tips, and a white primary action.
///
/// DEMO BUILD: the picked photo is passed straight to the analysing
/// screen; nothing is classified.
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _picker = ImagePicker();
  String? _path;
  String? _error;

  Future<void> _pick() async {
    setState(() => _error = null);
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
      );
      if (shot == null) return; // user cancelled
      if (!mounted) return;
      setState(() => _path = shot.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Couldn't open your gallery. $e");
    }
  }

  void _analyze() {
    if (_path == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AnalyzingScreen(imagePaths: [_path!]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _path != null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: T.cardGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(T.s6, T.s4, T.s6, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Upload photo',
                          style: TextStyle(
                            fontSize: T.tLg,
                            fontWeight: FontWeight.w700,
                            color: T.onDark,
                            letterSpacing: -0.22,
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.of(context).maybePop(),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0x29FFFFFF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: T.s2),
                    Text(
                      _error ??
                          'Pick a clear, well-lit photo from your gallery.',
                      style: TextStyle(
                        fontSize: T.tSm,
                        height: 1.5,
                        color: _error == null
                            ? T.onDark2
                            : const Color(0xFFFCA5A5),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Body ────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: T.s6),
                  child: hasPhoto
                      ? _Preview(path: _path!)
                      : _Dropzone(onTap: _pick),
                ),
              ),

              // ── Actions ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(T.s6, T.s4, T.s6, T.s8),
                child: Row(
                  children: [
                    Expanded(
                      child: hasPhoto
                          ? _GhostButton(label: 'Change photo', onTap: _pick)
                          : _PrimaryButton(label: 'Choose photo', onTap: _pick),
                    ),
                    if (hasPhoto) ...[
                      const SizedBox(width: T.s4),
                      Expanded(
                        child: _PrimaryButton(
                            label: 'Analyze photo', onTap: _analyze),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dropzone extends StatelessWidget {
  const _Dropzone({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(T.rLg),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                padding: const EdgeInsets.symmetric(
                    vertical: T.s8, horizontal: T.s6),
                decoration: BoxDecoration(
                  color: const Color(0x0AFFFFFF),
                  borderRadius: BorderRadius.circular(T.rLg),
                  border: Border.all(color: const Color(0x38FFFFFF), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Color(0x14FFFFFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.file_upload_outlined,
                          size: 26, color: T.onDark2),
                    ),
                    const SizedBox(height: T.s4),
                    const Text(
                      'Choose a photo of the affected area',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: T.tBase,
                        fontWeight: FontWeight.w600,
                        color: T.onDark,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: T.s3),
                    const Text(
                      'JPG or PNG · tap to browse',
                      style: TextStyle(
                        fontSize: T.tXs,
                        color: T.onDark3,
                        letterSpacing: 0.44,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: T.s6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _tips
                    .map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: T.s2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(Icons.check,
                                  size: 13, color: T.amber),
                            ),
                            const SizedBox(width: T.s2),
                            Expanded(
                              child: Text(
                                t,
                                style: const TextStyle(
                                  fontSize: T.tXs,
                                  color: T.onDark2,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: T.s4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(T.rLg),
        child: SizedBox(
          width: double.infinity,
          child: Image.file(File(path), fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: T.navy,
        padding: const EdgeInsets.symmetric(vertical: T.s4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(T.rFull),
        ),
        textStyle:
            const TextStyle(fontSize: T.tBase, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: T.onDarkLine, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: T.s4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(T.rFull),
        ),
        textStyle:
            const TextStyle(fontSize: T.tBase, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}
