import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

final dashboardProvider = FutureProvider<Map<String, int>>((ref) async {
  final client = supabase;
  Future<int> count(String table) async {
    final result = await client.from(table).select('id').count(CountOption.exact);
    return result.count;
  }
  final results = await Future.wait([
    count('profiles'), count('deposit_requests'), count('withdraw_requests'),
    count('market_signals'),
  ]);
  return {'users': results[0], 'deposits': results[1],
    'withdraws': results[2], 'signals': results[3]};
});

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false, obscure = true;
  String? error;
  Future<void> login() async {
    setState(() { busy = true; error = null; });
    try {
      await supabase.auth.signInWithPassword(
        email: email.text.trim(), password: password.text,
      );
      if (!mounted) return;
      // Role is verified server-side by RLS; do not trust a client-side role flag.
      context.go('/');
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = 'تعذّر تسجيل الدخول. تحقق من الاتصال والإعدادات.');
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override void dispose() { email.dispose(); password.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    body: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24), child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440), child: Card(
          child: Padding(padding: const EdgeInsets.all(24), child: Column(
            mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.admin_panel_settings, size: 58, color: adminRed),
              const SizedBox(height: 12),
              const Text('Sahmi Admin', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Text('لوحة الإدارة الآمنة', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              TextField(controller: email, keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email))),
              const SizedBox(height: 12),
              TextField(controller: password, obscureText: obscure,
                decoration: InputDecoration(labelText: 'كلمة المرور', prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => obscure = !obscure)))),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 12),
                child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
              const SizedBox(height: 18),
              SizedBox(width: double.infinity, child: FilledButton(
                onPressed: busy ? null : login,
                child: busy ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)) : const Text('تسجيل الدخول'))),
              const SizedBox(height: 8),
              const Text('فعّل MFA من إعدادات حساب Supabase للمشرفين.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white60)),
            ],
          )),
        ),
      ),
    )),
  );
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override State<AdminShell> createState() => _AdminShellState();
}
class _AdminShellState extends State<AdminShell> {
  int selected = 0;
  final titles = const ['لوحة التحكم', 'المستخدمون', 'طلبات الشحن', 'طلبات السحب',
    'الإشارات', 'الفريق', 'الإشعارات', 'التقارير', 'سجل النشاط', 'الإعدادات'];
  final icons = const [Icons.dashboard, Icons.people, Icons.add_card, Icons.payments,
    Icons.show_chart, Icons.groups, Icons.notifications, Icons.bar_chart,
    Icons.history, Icons.settings];
  @override Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardScreen(), const DataListScreen(table: 'profiles', title: 'المستخدمون'),
      const DataListScreen(table: 'deposit_requests', title: 'طلبات الشحن'),
      const DataListScreen(table: 'withdraw_requests', title: 'طلبات السحب'),
      const DataListScreen(table: 'market_signals', title: 'إشارات السوق'),
      const DataListScreen(table: 'admin_members', title: 'فريق الإدارة'),
      const BroadcastScreen(), const DataListScreen(table: 'admin_audit_log', title: 'سجل النشاط'),
      const DataListScreen(table: 'admin_audit_log', title: 'سجل النشاط'),
      const SettingsScreen(),
    ];
    return Directionality(textDirection: ui.TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: Text(titles[selected]),
        actions: [IconButton(tooltip: 'تسجيل الخروج', icon: const Icon(Icons.logout),
          onPressed: () async { await supabase.auth.signOut(); if (mounted) context.go('/login'); })]),
      drawer: Drawer(child: SafeArea(child: Column(children: [
        const ListTile(leading: Icon(Icons.admin_panel_settings, color: adminRed, size: 34),
          title: Text('Sahmi Admin', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('إدارة التطبيق')),
        const Divider(),
        Expanded(child: ListView.builder(itemCount: titles.length, itemBuilder: (_, i) =>
          ListTile(selected: selected == i, leading: Icon(icons[i]),
            title: Text(titles[i]), onTap: () { setState(() => selected = i); Navigator.pop(context); }))),
        const Padding(padding: EdgeInsets.all(12), child: Text('Admin Console • RTL',
          style: TextStyle(color: Colors.white54, fontSize: 12))),
      ]))),
      body: pages[selected],
    ));
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardProvider);
    return RefreshIndicator(onRefresh: () async => ref.invalidate(dashboardProvider),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('نظرة عامة مباشرة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        stats.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Card(child: Padding(padding: const EdgeInsets.all(16),
            child: Text('تعذر تحميل الإحصائيات: $e\nتحقق من الجداول وصلاحيات RLS.'))),
          data: (d) => GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
            crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.35,
            children: [
              _StatCard('المستخدمون', d['users']!, Icons.people, adminRed),
              _StatCard('طلبات الشحن', d['deposits']!, Icons.add_card, success),
              _StatCard('طلبات السحب', d['withdraws']!, Icons.payments, gold),
              _StatCard('إشارات السوق', d['signals']!, Icons.show_chart, Colors.lightBlueAccent),
            ]),
        ),
        const SizedBox(height: 20),
        const Card(child: Padding(padding: EdgeInsets.all(18), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('مركز المتابعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('تُحمّل الإحصائيات من Supabase. ستظهر البيانات حسب الجداول والصلاحيات المفعّلة في مشروعك.'),
            SizedBox(height: 8),
            Text('تنبيه: لا تعتمد على أرقام مالية قبل ربط إجراءات الشحن والسحب بدوال قاعدة بيانات ذرّية ومراجعتها.',
              style: TextStyle(color: Colors.amber)),
          ]))),
      ]),
    );
  }
}
class _StatCard extends StatelessWidget {
  final String title; final int value; final IconData icon; final Color color;
  const _StatCard(this.title, this.value, this.icon, this.color);
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: color), const SizedBox(height: 8),
      Text('$value', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
      Text(title, style: const TextStyle(color: Colors.white70)),
    ])));
}

class DataListScreen extends StatefulWidget {
  final String table, title;
  const DataListScreen({super.key, required this.table, required this.title});
  @override State<DataListScreen> createState() => _DataListScreenState();
}
class _DataListScreenState extends State<DataListScreen> {
  late Future<List<Map<String, dynamic>>> future;
  final search = TextEditingController();
  @override void initState() { super.initState(); future = load(); }
  Future<List<Map<String, dynamic>>> load() async {
    // Load only a bounded page; adapt selected columns to the real schema.
    final rows = await supabase.from(widget.table).select().limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }
  void refresh() => setState(() => future = load());
  @override void dispose() { search.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.all(12), child: Row(children: [
      Expanded(child: TextField(controller: search, onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث في النتائج المحمّلة...'))),
      IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)),
    ])),
    Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: future, builder: (_, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return _MessageState(icon: Icons.error_outline,
        text: 'تعذر تحميل ${widget.title}.\nقد يكون الجدول غير موجود أو لا تملك صلاحية القراءة.\n${snap.error}',
        action: refresh);
      final rows = (snap.data ?? []).where((r) =>
        r.values.any((v) => '$v'.toLowerCase().contains(search.text.toLowerCase()))).toList();
      if (rows.isEmpty) return _MessageState(icon: Icons.inbox, text: 'لا توجد بيانات مطابقة حالياً.', action: refresh);
      return RefreshIndicator(onRefresh: () async => refresh(), child: ListView.separated(
        itemCount: rows.length, separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final row = rows[i];
          final title = row['name'] ?? row['name_ar'] ?? row['email'] ?? row['symbol'] ?? row['id'] ?? 'عنصر ${i+1}';
          final subtitle = row.entries.where((e) => e.key != 'id').take(3)
            .map((e) => '${e.key}: ${e.value}').join(' • ');
          return ListTile(title: Text('$title', maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_left));
        },
      ));
    })),
  ]);
}

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});
  @override State<BroadcastScreen> createState() => _BroadcastScreenState();
}
class _BroadcastScreenState extends State<BroadcastScreen> {
  final title = TextEditingController(), body = TextEditingController();
  bool sending = false;
  String? message;
  @override void dispose() { title.dispose(); body.dispose(); super.dispose(); }
  Future<void> submit() async {
    if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
      setState(() => message = 'اكتب العنوان ونص الإشعار أولاً.'); return;
    }
    setState(() { sending = true; message = null; });
    try {
      // Queue only. A trusted server/Edge Function must deliver push notifications.
      await supabase.from('admin_notification_queue').insert({
        'title': title.text.trim(), 'body': body.text.trim(), 'audience': 'all',
        'created_by': supabase.auth.currentUser?.id,
      });
      setState(() => message = 'تمت إضافة الإشعار إلى قائمة الإرسال.');
      title.clear(); body.clear();
    } catch (e) { setState(() => message = 'فشل الحفظ: $e'); }
    finally { if (mounted) setState(() => sending = false); }
  }
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('بث إشعار', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    const SizedBox(height: 16),
    TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان الإشعار')),
    const SizedBox(height: 12),
    TextField(controller: body, minLines: 4, maxLines: 7,
      decoration: const InputDecoration(labelText: 'نص الإشعار')),
    const SizedBox(height: 14),
    FilledButton.icon(onPressed: sending ? null : submit,
      icon: const Icon(Icons.send), label: Text(sending ? 'جارٍ الحفظ...' : 'إضافة إلى قائمة الإرسال')),
    if (message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(message!)),
    const SizedBox(height: 12),
    const Text('الإرسال الفعلي يحتاج Edge Function أو خادماً موثوقاً متصلاً بـ FCM؛ لا تضع مفاتيح الخدمة في تطبيق الإدارة.',
      style: TextStyle(color: Colors.amber)),
  ]);
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen> {
  final appName = TextEditingController(text: 'Sahmi');
  final telegram = TextEditingController(text: '@CG_CG9');
  bool maintenance = false;
  @override void dispose() { appName.dispose(); telegram.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('إعدادات التطبيق', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    const SizedBox(height: 16),
    TextField(controller: appName, decoration: const InputDecoration(labelText: 'اسم التطبيق')),
    const SizedBox(height: 12),
    TextField(controller: telegram, decoration: const InputDecoration(labelText: 'حساب تلغرام للدعم')),
    SwitchListTile(title: const Text('وضع الصيانة'), value: maintenance,
      onChanged: (v) => setState(() => maintenance = v)),
    const SizedBox(height: 8),
    const Text('هذه حقول واجهة محلية. لا تُحفظ في قاعدة البيانات إلا بعد إضافة جدول إعدادات وسياسات وصول مناسبة.',
      style: TextStyle(color: Colors.amber)),
  ]);
}

class _MessageState extends StatelessWidget {
  final IconData icon; final String text; final VoidCallback action;
  const _MessageState({required this.icon, required this.text, required this.action});
  @override Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 44, color: Colors.white54), const SizedBox(height: 12),
      Text(text, textAlign: TextAlign.center), const SizedBox(height: 12),
      OutlinedButton(onPressed: action, child: const Text('إعادة المحاولة')),
    ]),
  ));
}
