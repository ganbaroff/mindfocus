import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/brain_dump_provider.dart';
import 'providers/focus_provider.dart';
import 'providers/finance_provider.dart';
import 'pages/brain_dump_page.dart';
import 'pages/chat_page.dart';
import 'pages/feed_page.dart';
import 'pages/focus_page.dart';
import 'pages/finance_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final prefs = await SharedPreferences.getInstance();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => ThemeProvider(prefs)..loadTheme()),
        ChangeNotifierProvider(
            create: (_) => BrainDumpProvider(prefs)..loadThoughts()),
        ChangeNotifierProvider(create: (_) => FocusProvider()..loadData(prefs)),
        ChangeNotifierProvider(
            create: (_) => FinanceProvider(prefs)..loadFinanceData()),
      ],
      child: const MyApp(),
    ),
  );
}

// --- App Shell ---

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final tp = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: tp.themeMode,
      home: const MainContainer(),
    );
  }
}

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});
  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _idx = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: const [
        BrainDumpPage(),
        ChatPage(),
        FeedPage(),
        FocusPage(),
        FinancePage(),
      ]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.psychology), label: 'Dump'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.rss_feed), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'Focus'),
          BottomNavigationBarItem(icon: Icon(Icons.wallet), label: 'Finance'),
        ],
      ),
    );
  }
}
