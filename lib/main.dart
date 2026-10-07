import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'store.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  final store = SakuStore();
  final repo = SakuRepo(store);
  runApp(SakuApp(store: store, repo: repo));
}

class SakuApp extends StatelessWidget {
  final SakuStore store;
  final SakuRepo repo;

  const SakuApp({super.key, required this.store, required this.repo});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saku',
      debugShowCheckedModeBanner: false,
      theme: sakuTheme(),
      home: SakuRoot(store: store, repo: repo),
    );
  }
}
