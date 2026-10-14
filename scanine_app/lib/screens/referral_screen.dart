import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/clinic.dart';
import '../models/screening_result.dart';
import '../theme/tokens.dart';
import '../widgets/tacloban_map.dart';

/// Where "Refer to veterinarian" lands. Works with no connection: the map
/// is drawn locally and the clinic list is a bundled asset. Navigation and
/// calling are handed off to the phone's own apps.
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key, required this.result});

  final ScreeningResult result;

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  List<Clinic> _clinics = const [];
  int _selected = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Clinic.loadAll().then((list) {
      if (!mounted) return;
      setState(() {
        _clinics = list;
        _loading = false;
      });
    }).catchError((Object e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    });
  }

  Future<void> _openMaps(String query) async {
    final encoded = Uri.encodeComponent(query);
    for (final candidate in [
      Uri.parse('geo:0,0?q=$encoded'),
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded'),
    ]) {
      if (await canLaunchUrl(candidate)) {
        await launchUrl(candidate, mode: LaunchMode.externalApplication);
        return;
      }
    }
    _toast('No map app available on this device.');
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _toast('Could not open the dialer.');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openDetail(Clinic c, int index) {
    setState(() => _selected = index);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ClinicSheet(
        clinic: c,
        index: index,
        onCall: () => _call(c.phone!),
        onDirections: () => _openMaps(c.mapQuery),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(result: widget.result),
            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(T.s6),
                    child: Text(
                      "Couldn't load the clinic directory.\n$_error",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: T.tSm, color: T.ink2),
                    ),
                  ),
                ),
              )
            else
              // Map and list share one scroll view so the map can move out
              // of the way — it is close to square, and pinning it would
              // leave too little room for ten clinics.
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(T.s5, 0, T.s5, T.s6),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(T.rMd + 4),
                        border: Border.all(
                          color: T.line,
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x10193863),
                            blurRadius: 14,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(T.rMd + 3),
                        child: Stack(
                          children: [
                            TaclobanMap(
                              clinics: _clinics,
                              selected: _selected,
                              onPinTap: (i) => _openDetail(_clinics[i], i),
                            ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: GestureDetector(
                                onTap: () =>
                                    _openMaps('veterinary clinic Tacloban City'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 11, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xF7FFFFFF),
                                    borderRadius:
                                        BorderRadius.circular(T.rFull),
                                    border: Border.all(
                                      color: T.line,
                                      width: 1,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x18193863),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.map_outlined,
                                        size: 13,
                                        color: T.navy,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        'Open in Maps',
                                        style: TextStyle(
                                          fontSize: T.tXs,
                                          fontWeight: FontWeight.w600,
                                          color: T.navy,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: T.s3),
                    for (var i = 0; i < _clinics.length; i++) ...[
                      _ClinicCard(
                        clinic: _clinics[i],
                        number: i + 1,
                        selected: i == _selected,
                        onTap: () => _openDetail(_clinics[i], i),
                      ),
                      if (i != _clinics.length - 1)
                        const SizedBox(height: T.s2),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.result});

  final ScreeningResult result;

  @override
  Widget build(BuildContext context) {
    final urgent = result.urgency == Urgency.high;
    return Padding(
      padding: const EdgeInsets.fromLTRB(T.s5, T.s3, T.s5, T.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: back + title ─────────────────────────
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.of(context).maybePop(),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: T.surface,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.chevron_left, size: 20, color: T.ink),
                ),
              ),
              const SizedBox(width: T.s3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Veterinary clinics',
                    style: TextStyle(
                      fontSize: T.tLg,
                      fontWeight: FontWeight.w700,
                      color: T.ink,
                      letterSpacing: -0.22,
                    ),
                  ),
                  Text(
                    'Tacloban City, Leyte',
                    style: TextStyle(fontSize: T.tSm, color: T.ink3),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: T.s3),
          // ── Condition result (right-aligned) ──────────────
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  result.condition,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: T.tLg,
                    fontWeight: FontWeight.w700,
                    color: urgent ? T.maroon : T.navy,
                    letterSpacing: -0.3,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  urgent
                      ? 'Urgent referral recommended'
                      : 'Consultation advised',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: T.tSm,
                    color: T.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClinicCard extends StatelessWidget {
  const _ClinicCard({
    required this.clinic,
    required this.number,
    required this.selected,
    required this.onTap,
  });

  final Clinic clinic;
  final int number;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(15, 13, 12, 13),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF5F7FA) : T.surface,
          borderRadius: BorderRadius.circular(T.rMd),
          border: Border.all(
            color: selected ? T.navy : T.line,
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? const Color(0x10193863)
                  : const Color(0x06000000),
              blurRadius: selected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: selected ? T.navyDark : T.navySoft,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? const Color(0x30142E53)
                        : const Color(0x221F4273),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '$number',
                style: const TextStyle(
                  fontSize: T.tXs,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: T.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clinic.name,
                    style: const TextStyle(
                      fontSize: T.tSm + 1,
                      fontWeight: FontWeight.w600,
                      color: T.ink,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    clinic.address ?? 'Tacloban City',
                    style: const TextStyle(
                      fontSize: T.tXs + 0.5,
                      color: T.ink2,
                      height: 1.4,
                    ),
                  ),
                  if (!clinic.verified) ...[
                    const SizedBox(height: 5),
                    const _ToVerify(),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: T.ink3),
          ],
        ),
      ),
    );
  }
}

class _ToVerify extends StatelessWidget {
  const _ToVerify();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x10193863),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'details to verify',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: T.navy,
        ),
      ),
    );
  }
}

class _ClinicSheet extends StatelessWidget {
  const _ClinicSheet({
    required this.clinic,
    required this.index,
    required this.onCall,
    required this.onDirections,
  });

  final Clinic clinic;
  final int index;
  final VoidCallback onCall;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: T.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.rLg)),
      ),
      padding: const EdgeInsets.fromLTRB(T.s6, T.s3, T.s6, T.s6),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0x24101B34),
                  borderRadius: BorderRadius.circular(T.rFull),
                ),
              ),
            ),
            const SizedBox(height: T.s5),
            Text(
              clinic.name,
              style: const TextStyle(
                fontSize: T.tMd + 1,
                fontWeight: FontWeight.w700,
                color: T.ink,
                height: 1.25,
                letterSpacing: -0.15,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${clinic.services ?? "Veterinary clinic"} · Pin ${index + 1}',
              style: const TextStyle(fontSize: T.tXs + 0.5, color: T.ink3),
            ),
            const SizedBox(height: T.s4),
            _Row(label: 'Address', value: clinic.address),
            _Row(label: 'Phone', value: clinic.phone),
            _Row(label: 'Hours', value: clinic.hours),
            const SizedBox(height: T.s5),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: clinic.canCall ? onCall : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: T.navy,
                      disabledBackgroundColor: const Color(0x1A101B34),
                      disabledForegroundColor: T.ink3,
                      padding: const EdgeInsets.symmetric(vertical: T.s4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(T.rFull),
                      ),
                      textStyle: const TextStyle(
                        fontSize: T.tBase,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Call clinic'),
                  ),
                ),
                const SizedBox(width: T.s3),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDirections,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: T.ink,
                      side: const BorderSide(color: T.line, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: T.s4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(T.rFull),
                      ),
                      textStyle: const TextStyle(
                        fontSize: T.tBase,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Directions'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: T.s4),
            const Text(
              'Scanine is a triage aid. Confirm the diagnosis with the '
              'veterinarian.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: T.ink3, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final missing = value == null || value!.trim().isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: T.s3 - 2),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x12101B34))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: T.tXs,
                fontWeight: FontWeight.w600,
                color: T.ink3,
                letterSpacing: -0.2,
              ),
            ),
          ),
          Expanded(
            child: missing
                ? const _ToVerify()
                : Text(
                    value!,
                    style: const TextStyle(
                      fontSize: T.tSm,
                      color: T.ink,
                      height: 1.45,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
