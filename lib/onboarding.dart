import 'package:flutter/material.dart';

import 'mascot.dart';
import 'saku_channel.dart';
import 'store.dart';
import 'theme.dart';

class OnboardingGate extends StatefulWidget {
  final SakuStore store;
  final ValueChanged<List<String>> onDone;

  const OnboardingGate({super.key, required this.store, required this.onDone});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  int step = 0;
  bool folderOk = false;
  String folderName = '';
  bool notifOk = false;
  Set<String> picked = <String>{};
  List<Map<String, String>> apps = <Map<String, String>>[];
  bool loadingApps = true;

  @override
  void initState() {
    super.initState();
    _refreshFolder();
    _refreshNotif();
    _loadApps();
  }

  Future<void> _refreshFolder() async {
    final ok = await SakuChannel.folderReady();
    final name = await SakuChannel.folderName();
    if (!mounted) return;
    setState(() {
      folderOk = ok;
      folderName = name ?? '';
    });
  }

  Future<void> _refreshNotif() async {
    final ok = await SakuChannel.notifAccessGranted();
    if (!mounted) return;
    setState(() => notifOk = ok);
  }

  Future<void> _loadApps() async {
    final list = await SakuChannel.listInstalledApps();
    list.sort((a, b) => (a['label'] ?? '').toLowerCase().compareTo((b['label'] ?? '').toLowerCase()));
    if (!mounted) return;
    setState(() {
      apps = list;
      loadingApps = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Kenalan dulu dengan Saku'),
        actions: [
          if (step > 0)
            IconButton(
              onPressed: () => setState(() => step -= 1),
              icon: const Icon(Icons.arrow_back),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _progress(),
              Expanded(child: _stepBody()),
              Row(
                children: [
                  TextButton(
                    onPressed: () => widget.onDone(picked.toList()),
                    child: const Text('Lewati'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Text(step == 3 ? 'Mulai pakai Saku' : 'Lanjut'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progress() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: List.generate(4, (i) {
          final done = i < step;
          final active = i == step;
          return Expanded(
            child: Container(
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: done || active ? C.warmDeep : const Color(0xFFEAE4DA),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _stepBody() {
    switch (step) {
      case 0:
        return const _Intro();
      case 1:
        return _FolderStep(folderOk: folderOk, folderName: folderName, onPick: _pickFolder);
      case 2:
        return _NotifStep(
          notifOk: notifOk,
          onOpenSettings: () async {
            await SakuChannel.openNotifAccessSettings();
            await _refreshNotif();
          },
        );
      default:
        return _WhitelistStep(
          apps: apps,
          loading: loadingApps,
          picked: picked,
          onToggle: (pkg) => setState(() {
            if (picked.contains(pkg)) {
              picked.remove(pkg);
            } else {
              picked.add(pkg);
            }
          }),
        );
    }
  }

  Future<void> _pickFolder() async {
    final ok = await SakuChannel.pickFolder();
    if (ok) {
      await widget.store.bootstrapFromFolder();
    }
    await _refreshFolder();
  }

  void _next() {
    if (step == 3) {
      widget.onDone(picked.toList());
      return;
    }
    setState(() => step += 1);
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Mascot(size: 110, mood: Mood.happy),
        SizedBox(height: 16),
        Text(
          'Aku Saku, teman catat pengeluaranmu.',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.3),
        ),
        SizedBox(height: 10),
        Text(
          'Semua data cuma ada di HP kamu — offline, tanpa iklan, tanpa server. '
          'Selama 3 langkah berikutnya kita siapkan folder data, pembaca notifikasi, dan pilihan aplikasi yang mau aku pantau.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
      ],
    );
  }
}

class _FolderStep extends StatelessWidget {
  final bool folderOk;
  final String folderName;
  final Future<void> Function() onPick;

  const _FolderStep({required this.folderOk, required this.folderName, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.folder_copy_outlined, size: 44, color: C.warmDeep),
        const SizedBox(height: 12),
        const Text(
          'Langkah 1 — Kotak penyimpanan',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          'Pilih (atau buat) folder khusus, misalnya "Saku" di Download. '
          'Isi folder ini tetap ada walau aplikasinya dibongkar — begitu Saku dipasang lagi, datamu langsung balik.\n\n'
          'Mau datanya bisa dibuka dari laptop? Pilih folder di Google Drive lewat picker yang sama.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.folder_open),
          label: const Text('Pilih / buat folder'),
        ),
        if (folderOk)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: C.mintDeep, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Folder aktif: $folderName',
                    style: const TextStyle(fontSize: 12, color: C.mintDeep),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NotifStep extends StatelessWidget {
  final bool notifOk;
  final Future<void> Function() onOpenSettings;

  const _NotifStep({required this.notifOk, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notifications_active_outlined, size: 44, color: C.warmDeep),
          const SizedBox(height: 12),
          const Text(
            'Langkah 2 — Pembaca notifikasi',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Saku bisa menangkap nominal dari notifikasi GoPay/OVO/bank, lalu menunggu konfirmasimu.\n\n'
            'Catatan penting:\n'
            '1. Kalau tombol "Notification access" tidak bisa dinyalakan, buka Setelan → Aplikasi → Saku → menu titik tiga → "Izinkan setelan terbatas" dulu. Ini normal untuk aplikasi luar Play Store.\n'
            '2. Google Play Protect mungkin memperingatkan saat install APK — pilih "Tetap instal". Saku tidak meminta izin aneh-aneh.\n'
            '3. Untuk HP Xiaomi/MIUI/HyperOS: izinkan juga "Mulai otomatis" (Autostart) supaya Saku tetap aktif.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings),
            label: const Text('Buka "Notification access"'),
          ),
          if (notifOk)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: C.mintDeep, size: 18),
                  SizedBox(width: 6),
                  Text('Akses notifikasi aktif', style: TextStyle(fontSize: 12, color: C.mintDeep)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WhitelistStep extends StatelessWidget {
  final List<Map<String, String>> apps;
  final bool loading;
  final Set<String> picked;
  final ValueChanged<String> onToggle;

  const _WhitelistStep({
    required this.apps,
    required this.loading,
    required this.picked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.admin_panel_settings_outlined, size: 44, color: C.warmDeep),
        const SizedBox(height: 12),
        const Text(
          'Langkah 3 — Pilih app yang mau dipantau',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Saku hanya membaca notifikasi dari aplikasi yang kamu pilih. Kosongkan kalau mau aku pilih otomatis yang terlihat seperti notifikasi keuangan.',
          style: TextStyle(fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 8),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: apps.length,
              itemBuilder: (context, i) {
                final app = apps[i];
                final label = app['label'] ?? app['package'] ?? '';
                return CheckboxListTile(
                  dense: true,
                  value: picked.contains(app['package']),
                  onChanged: (_) => onToggle(app['package'] ?? ''),
                  title: Text(label, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(app['package'] ?? '', style: const TextStyle(fontSize: 10, color: C.inkSoft)),
                );
              },
            ),
          ),
      ],
    );
  }
}
