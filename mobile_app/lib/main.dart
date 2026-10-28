import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/api_service.dart';

const _teal = Color(0xff087e75);

void main() => runApp(
  ChangeNotifierProvider(
    create: (_) => AppState()..restoreSession(),
    child: const GlucoseCompanionApp(),
  ),
);

class AppState extends ChangeNotifier {
  final api = ApiService();
  bool restoring = true;
  bool get signedIn => api.token != null;

  Future<void> restoreSession() async {
    await api.restoreToken();
    if (api.token != null) {
      try {
        await api.get('/api/auth/me');
      } catch (_) {
        await api.logout();
      }
    }
    restoring = false;
    notifyListeners();
  }

  Future<void> login(String contact, String password) async {
    await api.login(contact, password);
    notifyListeners();
  }

  Future<void> logout() async {
    await api.logout();
    notifyListeners();
  }
}

class GlucoseCompanionApp extends StatelessWidget {
  const GlucoseCompanionApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Glucose Companion',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _teal),
      scaffoldBackgroundColor: const Color(0xfff6f8f7),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    ),
    home: const AppShell(),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int tab = 0;

  Future<void> openAuth({bool register = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AuthScreen(startWithRegister: register),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Consumer<AppState>(
    builder: (context, state, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Glucose Companion'),
        actions: [
          if (state.restoring)
            const Padding(
              padding: EdgeInsets.all(18),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (state.signedIn)
            IconButton(
              tooltip: 'Log out',
              onPressed: () async {
                await state.logout();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('You have been logged out.')),
                  );
                }
              },
              icon: const Icon(Icons.logout),
            )
          else ...[
            TextButton(onPressed: () => openAuth(), child: const Text('Login')),
            TextButton(
              onPressed: () => openAuth(register: true),
              child: const Text('Register'),
            ),
          ],
        ],
      ),
      body: IndexedStack(
        index: tab,
        children: [
          const HomePage(),
          IntakePage(onLogin: () => openAuth()),
          const FeedbackPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu),
            label: 'Intake Analysis',
          ),
          NavigationDestination(
            icon: Icon(Icons.feedback_outlined),
            label: 'Feedback',
          ),
        ],
      ),
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(colors: [_teal, Color(0xff48a99b)]),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.favorite, color: Colors.white, size: 36),
            SizedBox(height: 16),
            Text(
              'Understand your food',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Explore estimated nutrition for familiar foods and keep useful information close at hand.',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const _InfoCard(
        icon: Icons.search,
        title: 'Intake Analysis',
        text: 'Find a food, enter your portion and meal time, and view estimated nutrients.',
      ),
      const _InfoCard(
        icon: Icons.lock_outline,
        title: 'Your account',
        text: 'Browse the app freely. Sign in or register when you are ready to save and analyze an intake.',
      ),
      const _InfoCard(
        icon: Icons.health_and_safety_outlined,
        title: 'For information only',
        text: 'Nutrition values are estimates. This app does not diagnose or predict hypoglycemia and does not replace medical care.',
      ),
    ],
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: Icon(icon, color: _teal, size: 30),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text),
      ),
    ),
  );
}

class IntakePage extends StatefulWidget {
  const IntakePage({required this.onLogin, super.key});
  final VoidCallback onLogin;
  @override
  State<IntakePage> createState() => _IntakePageState();
}

class _IntakePageState extends State<IntakePage> {
  final name = TextEditingController();
  final grams = TextEditingController(text: '100');
  final time = TextEditingController();
  List<dynamic> foods = [];
  Map<String, dynamic>? result;
  bool searching = false, analyzing = false;
  String? error;

  Future<void> searchFoods(String query) async {
    if (query.trim().length < 2) {
      setState(() => foods = []);
      return;
    }
    setState(() {
      searching = true;
      error = null;
    });
    try {
      final found = await context.read<AppState>().api.foods(query.trim());
      if (mounted) setState(() => foods = found);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  Future<void> analyze() async {
    final app = context.read<AppState>();
    if (!app.signedIn) {
      final goLogin = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Login first'),
          content: const Text(
            'Sign in to analyze and save this intake. You can register if you do not have an account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Go to login'),
            ),
          ],
        ),
      );
      if (goLogin == true) widget.onLogin();
      return;
    }
    final portion = double.tryParse(grams.text.trim());
    final timePattern = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$');
    if (name.text.trim().isEmpty ||
        portion == null ||
        portion <= 0 ||
        !timePattern.hasMatch(time.text.trim())) {
      setState(
        () => error = 'Choose a food, enter a positive portion, and use 24-hour time (HH:MM).',
      );
      return;
    }
    setState(() {
      analyzing = true;
      error = null;
      result = null;
    });
    try {
      final analysis = await app.api.analyzeIntake(
        name: name.text.trim(),
        grams: portion,
        time: time.text.trim(),
      );
      if (mounted) setState(() => result = analysis);
    } on ApiException catch (e) {
      if (e.statusCode == 401 && mounted) {
        await app.logout();
        widget.onLogin();
      } else if (mounted) {
        setState(() => error = e.message);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => analyzing = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    grams.dispose();
    time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('Intake Analysis', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text(
        'Search the food list, select a result, and provide your portion and intake time.',
      ),
      const SizedBox(height: 18),
      TextField(
        controller: name,
        decoration: InputDecoration(
          labelText: 'Intake name',
          hintText: 'e.g. Poha',
          suffixIcon: searching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.search),
        ),
        onChanged: searchFoods,
      ),
      if (foods.isNotEmpty)
        Card(
          child: Column(
            children: foods
                .map(
                  (food) => ListTile(
                    dense: true,
                    title: Text(food['name'] as String? ?? ''),
                    subtitle: Text(
                      '${food['carbohydrates_per_100g']} g carbohydrates / 100 g',
                    ),
                    onTap: () {
                      name.text = food['name'] as String? ?? '';
                      setState(() {
                        foods = [];
                        result = null;
                      });
                    },
                  ),
                )
                .toList(),
          ),
        ),
      const SizedBox(height: 12),
      TextField(
        controller: grams,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Portion (grams)'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: time,
        keyboardType: TextInputType.datetime,
        decoration: const InputDecoration(
          labelText: 'Intake time (24-hour HH:MM)',
          hintText: '14:30',
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: analyzing ? null : analyze,
        icon: const Icon(Icons.analytics_outlined),
        label: Text(analyzing ? 'Analyzing…' : 'Analyze intake'),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(error!, style: const TextStyle(color: Colors.red)),
        ),
      if (result != null) _NutritionResult(result: result!),
    ],
  );
}

class _NutritionResult extends StatelessWidget {
  const _NutritionResult({required this.result});
  final Map<String, dynamic> result;
  @override
  Widget build(BuildContext context) {
    final nutrition = result['nutrition'] as Map<String, dynamic>? ?? {};
    return Card(
      margin: const EdgeInsets.only(top: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result['intake_name'] as String? ?? 'Nutrition estimate',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${result['portion_grams']} g · ${result['intake_time']} · Estimated values',
            ),
            const Divider(height: 24),
            ...nutrition.entries.map(
              (entry) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(entry.key),
                trailing: Text(
                  entry.value == null
                      ? 'Unavailable'
                      : '${entry.value} ${RegExp(r'\(([^)]+)\)').firstMatch(entry.key)?.group(1) ?? ''}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});
  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      contact = TextEditingController(),
      message = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    name.dispose();
    contact.dispose();
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('Feedback', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('Send a question or tell us about your experience.'),
      const SizedBox(height: 20),
      Form(
        key: form,
        child: Column(
          children: [
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter your name.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: contact,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Contact number'),
              validator: (v) =>
                  v == null || v.replaceAll(RegExp(r'\D'), '').length < 7
                  ? 'Enter a valid contact number.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: message,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Message'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter a message.' : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: sending ? null : submit,
                child: Text(sending ? 'Sending…' : 'Submit feedback'),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Future<void> submit() async {
    if (!(form.currentState?.validate() ?? false)) return;
    setState(() => sending = true);
    try {
      await context.read<AppState>().api.sendFeedback(
        name.text.trim(),
        contact.text.trim(),
        message.text.trim(),
      );
      name.clear();
      contact.clear();
      message.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks. Your feedback was sent.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({this.startWithRegister = false, super.key});
  final bool startWithRegister;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      contact = TextEditingController(),
      password = TextEditingController();
  late bool registering = widget.startWithRegister;
  bool busy = false;
  String? error, notice;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    contact.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(registering ? 'Register' : 'Login')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.monitor_heart_outlined,
                  color: _teal,
                  size: 56,
                ),
                const SizedBox(height: 12),
                Text(
                  registering ? 'Create your account' : 'Welcome back',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                if (registering) ...[
                  TextFormField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) =>
                        registering && (v == null || v.trim().isEmpty)
                        ? 'Enter your name.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) =>
                        registering && (v == null || !v.contains('@'))
                        ? 'Enter a valid email.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: contact,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact number',
                  ),
                  validator: (v) =>
                      v == null || v.replaceAll(RegExp(r'\D'), '').length < 7
                      ? 'Enter a valid contact number.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (v) =>
                      v == null || v.length < (registering ? 10 : 1)
                      ? registering
                            ? 'Use at least 10 characters.'
                            : 'Enter your password.'
                      : null,
                ),
                if (notice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(notice!, style: const TextStyle(color: _teal)),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(registering ? 'Create account' : 'Login'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          registering = !registering;
                          error = null;
                          notice = null;
                        }),
                  child: Text(
                    registering
                        ? 'Already registered? Login'
                        : 'New here? Register first',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> submit() async {
    if (!(form.currentState?.validate() ?? false)) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    final api = context.read<AppState>();
    try {
      if (registering) {
        await api.api.register(
          name.text.trim(),
          email.text.trim(),
          contact.text.trim(),
          password.text,
        );
        if (mounted) {
          setState(() {
            registering = false;
            password.clear();
            notice = 'Registration complete. Sign in with your contact number and password.';
          });
        }
      } else {
        await api.login(contact.text.trim(), password.text);
        if (mounted) Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (e.code == 'account_not_registered' && mounted) {
        final goRegister = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Register first'),
            content: const Text(
              'There is no account for this contact number. Create an account before logging in.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Register'),
              ),
            ],
          ),
        );
        if (goRegister == true && mounted) {
          setState(() {
            registering = true;
            error = null;
          });
        }
      } else if (mounted) {
        setState(
          () => error = e.code == 'invalid_credentials'
              ? 'The password is incorrect for this contact number.'
              : e.message,
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
