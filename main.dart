import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(const PhoneHealthApp());

// ───────────────────────── الألوان ─────────────────────────
class Palette {
  static const bg = Color(0xFFF2F5F4);
  static const ink = Color(0xFF13262B);
  static const muted = Color(0xFF5F7378);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFDDE5E3);
  static const good = Color(0xFF138A5B);
  static const warn = Color(0xFFC98A0B);
  static const bad = Color(0xFFC2432F);
}

class PhoneHealthApp extends StatelessWidget {
  const PhoneHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'صحة الهاتف',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Palette.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: Palette.good),
      ),
      // واجهة عربية من اليمين إلى اليسار
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const DiagnosisScreen(),
    );
  }
}

// ───────────────────────── النماذج ─────────────────────────
enum Severity { high, medium, low }

enum FixKind {
  autoSafe, // آمن تلقائياً بعد موافقة واحدة
  review, // يحتاج مراجعة من المستخدم
  guidance, // توجيه فقط، التطبيق لا يحذف
}

class Issue {
  final String id;
  final String title;
  final String detail;
  final int impact; // عدد النقاط المخصومة من درجة الصحة
  final int savingMB;
  final Severity severity;
  final FixKind kind;
  final List<String> actions; // ما سيحدث بالتحديد عند العلاج

  const Issue({
    required this.id,
    required this.title,
    required this.detail,
    required this.impact,
    required this.savingMB,
    required this.severity,
    required this.kind,
    required this.actions,
  });
}

// بيانات تجريبية. في النسخة الحقيقية تأتي من خدمات المسح (انظر الملاحظات أسفل الملف).
const List<Issue> demoIssues = [
  Issue(
    id: 'storage',
    title: 'التخزين شبه ممتلئ',
    detail: 'المتبقي 7% فقط من مساحة الهاتف، وهذا سبب شائع للبطء.',
    impact: 22,
    savingMB: 0,
    severity: Severity.high,
    kind: FixKind.guidance,
    actions: ['يُحل بمعالجة المشاكل الأخرى في هذه القائمة'],
  ),
  Issue(
    id: 'dupes',
    title: '312 صورة مكررة تماماً',
    detail: 'نفس الملف بالضبط محفوظ أكثر من مرة.',
    impact: 14,
    savingMB: 1480,
    severity: Severity.high,
    kind: FixKind.autoSafe,
    actions: [
      'يُبقي نسخة واحدة من كل صورة',
      'تنتقل النسخ الزائدة إلى السلة الداخلية 30 يوماً',
    ],
  ),
  Issue(
    id: 'whatsapp',
    title: 'وسائط واتساب قديمة ومكررة',
    detail: 'ملفات أقدم من 6 أشهر ومحفوظة في أكثر من مكان.',
    impact: 12,
    savingMB: 2310,
    severity: Severity.high,
    kind: FixKind.review,
    actions: [
      'تعرض لك الملفات لتختار منها',
      'المحذوف ينتقل إلى السلة 30 يوماً',
      'لا يُمس أي ملف داخل محادثة مفضلة',
    ],
  ),
  Issue(
    id: 'large',
    title: '9 فيديوهات كبيرة',
    detail: 'كل فيديو يزيد عن 300 ميغابايت.',
    impact: 8,
    savingMB: 3920,
    severity: Severity.medium,
    kind: FixKind.review,
    actions: [
      'تعرض لك الفيديوهات مع أحجامها',
      'يمكنك ضغطها بدل حذفها',
    ],
  ),
  Issue(
    id: 'similar',
    title: '86 صورة متشابهة',
    detail: 'لقطات متتالية متقاربة جداً، يكفي الاحتفاظ بأفضلها.',
    impact: 5,
    savingMB: 540,
    severity: Severity.low,
    kind: FixKind.review,
    actions: [
      'نقترح الأفضل في كل مجموعة وأنت تقرر',
      'لا يُحذف شيء دون تأكيدك',
    ],
  ),
  Issue(
    id: 'apps',
    title: '14 تطبيقاً لم تفتحها منذ 90 يوماً',
    detail: 'تشغل مساحة وقد تعمل في الخلفية.',
    impact: 6,
    savingMB: 2100,
    severity: Severity.medium,
    kind: FixKind.guidance,
    actions: [
      'نفتح لك شاشة التطبيقات في إعدادات الهاتف',
      'الحذف يتم بيدك، التطبيق لا يحذف تطبيقات',
    ],
  ),
];

// ───────────────────────── الشاشة الرئيسية ─────────────────────────
enum ScanState { idle, scanning, done }

class DiagnosisScreen extends StatefulWidget {
  const DiagnosisScreen({super.key});

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  ScanState _state = ScanState.idle;
  String _stage = '';
  double _progress = 0;
  final List<Issue> _issues = [];
  int _freedMB = 0;

  static const _stages = [
    'فحص مساحة التخزين',
    'البحث عن الصور المكررة',
    'فحص وسائط واتساب',
    'البحث عن الملفات الكبيرة',
    'فحص التطبيقات',
  ];

  int get _score {
    final total = _issues.fold<int>(0, (s, i) => s + i.impact);
    return (100 - total).clamp(0, 100);
  }

  int get _potentialMB => _issues.fold<int>(0, (s, i) => s + i.savingMB);

  Future<void> _runScan() async {
    setState(() {
      _state = ScanState.scanning;
      _progress = 0;
      _issues.clear();
      _freedMB = 0;
    });
    for (var i = 0; i < _stages.length; i++) {
      if (!mounted) return;
      setState(() {
        _stage = _stages[i];
        _progress = (i + 1) / _stages.length;
      });
      await Future.delayed(const Duration(milliseconds: 700));
    }
    if (!mounted) return;
    setState(() {
      _issues.addAll(demoIssues);
      _state = ScanState.done;
    });
  }

  Future<void> _openIssue(Issue issue) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Palette.surface,
      builder: (_) => IssueSheet(issue: issue),
    );
    if (confirmed != true || !mounted) return;

    final index = _issues.indexWhere((i) => i.id == issue.id);
    setState(() {
      _issues.removeWhere((i) => i.id == issue.id);
      _freedMB += issue.savingMB;
    });

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(issue.kind == FixKind.guidance
            ? 'تم فتح الشاشة المناسبة'
            : 'تم النقل إلى السلة، يمكنك التراجع خلال 30 يوماً'),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () {
            setState(() {
              _issues.insert(index.clamp(0, _issues.length), issue);
              _freedMB -= issue.savingMB;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            const Text(
              'صحة هاتفك',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Palette.ink),
            ),
            const SizedBox(height: 4),
            const Text(
              'نفحص ما يبطّئ الهاتف، ونعالجه دون حذف شيء بدون موافقتك.',
              style: TextStyle(fontSize: 14, color: Palette.muted, height: 1.5),
            ),
            const SizedBox(height: 28),
            _buildHero(),
            const SizedBox(height: 24),
            if (_state == ScanState.done) ..._buildResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    switch (_state) {
      case ScanState.idle:
        return Column(
          children: [
            const SizedBox(height: 12),
            const HealthRing(score: 0, showScore: false),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _runScan,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: Palette.ink,
              ),
              child: const Text('افحص الهاتف الآن',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      case ScanState.scanning:
        return Column(
          children: [
            const SizedBox(height: 12),
            const HealthRing(score: 0, showScore: false),
            const SizedBox(height: 28),
            Text(_stage,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Palette.ink)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                backgroundColor: Palette.line,
                color: Palette.good,
              ),
            ),
          ],
        );
      case ScanState.done:
        return Column(
          children: [
            const SizedBox(height: 12),
            HealthRing(score: _score),
            const SizedBox(height: 20),
            Text(
              _verdict(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Palette.ink),
            ),
            const SizedBox(height: 6),
            Text(
              _freedMB > 0
                  ? 'تم تحرير ${_fmt(_freedMB)} حتى الآن'
                  : 'يمكن تحرير ${_fmt(_potentialMB)} بعد مراجعتك',
              style: const TextStyle(fontSize: 14, color: Palette.muted),
            ),
          ],
        );
    }
  }

  String _verdict() {
    if (_issues.isEmpty) return 'هاتفك بأفضل حال';
    if (_score >= 80) return 'حالة جيدة مع ملاحظات بسيطة';
    if (_score >= 60) return 'يحتاج بعض التنظيف';
    return 'الهاتف مثقل، والعلاج متاح';
  }

  List<Widget> _buildResults() {
    if (_issues.isEmpty) {
      return [
        OutlinedButton(
          onPressed: _runScan,
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50)),
          child: const Text('أعد الفحص'),
        ),
      ];
    }
    final sorted = [..._issues]..sort((a, b) => b.impact.compareTo(a.impact));
    return [
      Text('المشاكل مرتبة حسب تأثيرها (${sorted.length})',
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: Palette.ink)),
      const SizedBox(height: 12),
      for (final issue in sorted) ...[
        IssueTile(issue: issue, onTap: () => _openIssue(issue)),
        const SizedBox(height: 10),
      ],
    ];
  }
}

String _fmt(int mb) =>
    mb >= 1024 ? '${(mb / 1024).toStringAsFixed(1)} غيغابايت' : '$mb ميغابايت';

Color _severityColor(Severity s) {
  switch (s) {
    case Severity.high:
      return Palette.bad;
    case Severity.medium:
      return Palette.warn;
    case Severity.low:
      return Palette.good;
  }
}

String _kindLabel(FixKind k) {
  switch (k) {
    case FixKind.autoSafe:
      return 'آمن، علاج بضغطة';
    case FixKind.review:
      return 'يحتاج مراجعتك';
    case FixKind.guidance:
      return 'توجيه فقط';
  }
}

// ───────────────────────── حلقة الصحة ─────────────────────────
class HealthRing extends StatelessWidget {
  final int score;
  final bool showScore;
  const HealthRing({super.key, required this.score, this.showScore = true});

  Color get _color {
    if (!showScore) return Palette.line;
    if (score >= 80) return Palette.good;
    if (score >= 60) return Palette.warn;
    return Palette.bad;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score / 100),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: 190,
          height: 190,
          child: CustomPaint(
            painter: _RingPainter(value: value, color: _color),
            child: Center(
              child: showScore
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${(value * 100).round()}',
                            style: TextStyle(
                                fontSize: 58,
                                fontWeight: FontWeight.w800,
                                color: _color,
                                height: 1)),
                        const SizedBox(height: 4),
                        const Text('من 100',
                            style: TextStyle(
                                fontSize: 13, color: Palette.muted)),
                      ],
                    )
                  : const Icon(Icons.phone_android,
                      size: 52, color: Palette.muted),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  _RingPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Palette.line;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = color;
    // يبدأ من الأعلى ويدور باتجاه عقارب الساعة
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * value, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}

// ───────────────────────── بطاقة المشكلة ─────────────────────────
class IssueTile extends StatelessWidget {
  final Issue issue;
  final VoidCallback onTap;
  const IssueTile({super.key, required this.issue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(issue.severity);
    return Material(
      color: Palette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Palette.line),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 52,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(issue.title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Palette.ink)),
                    const SizedBox(height: 4),
                    Text(issue.detail,
                        style: const TextStyle(
                            fontSize: 13, color: Palette.muted, height: 1.4)),
                    const SizedBox(height: 8),
                    Text(
                      issue.savingMB > 0
                          ? '${_kindLabel(issue.kind)}  •  توفير ${_fmt(issue.savingMB)}'
                          : _kindLabel(issue.kind),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: Palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── نافذة المعاينة والموافقة ─────────────────────────
class IssueSheet extends StatelessWidget {
  final Issue issue;
  const IssueSheet({super.key, required this.issue});

  @override
  Widget build(BuildContext context) {
    final guidance = issue.kind == FixKind.guidance;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 4, 20, 20 + MediaQuery.of(context).viewPadding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(issue.title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Palette.ink)),
          const SizedBox(height: 6),
          Text(issue.detail,
              style: const TextStyle(
                  fontSize: 14, color: Palette.muted, height: 1.5)),
          const SizedBox(height: 18),
          const Text('ما الذي سيحدث',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Palette.ink)),
          const SizedBox(height: 8),
          for (final a in issue.actions)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle,
                        size: 16, color: Palette.good),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(a,
                        style: const TextStyle(
                            fontSize: 14, color: Palette.ink, height: 1.4)),
                  ),
                ],
              ),
            ),
          if (issue.savingMB > 0) ...[
            const SizedBox(height: 8),
            Text('المساحة التي ستتحرر: ${_fmt(issue.savingMB)}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Palette.good)),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                  child: const Text('إلغاء'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: Palette.ink,
                  ),
                  child: Text(
                    guidance
                        ? 'افتح الشاشة'
                        : issue.kind == FixKind.review
                            ? 'راجع الملفات'
                            : 'عالج الآن',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ───────────────────────── ملاحظات للمرحلة التالية ─────────────────────────
 * استبدل demoIssues بخدمات مسح حقيقية (أندرويد):
 *  - التخزين:      package disk_space_2 أو MethodChannel إلى StatFs
 *  - الصور:        photo_manager (قراءة المعرض) + حساب hash للمكررات
 *  - المتشابهة:    perceptual hash (dHash) على صور مصغّرة
 *  - واتساب:       مجلد Android/media/com.whatsapp عبر SAF (اختيار المستخدم للمجلد)
 *  - التطبيقات:    UsageStatsManager (صلاحية Usage Access يمنحها المستخدم)
 *  - البطارية:     battery_plus
 *
 * السلة الداخلية: انقل الملفات إلى مجلد خاص بالتطبيق مع سجل (SQLite)
 * بتاريخ الحذف، واحذف نهائياً بعد 30 يوماً عبر WorkManager.
 *
 * pubspec.yaml (لاحقاً): photo_manager, battery_plus, sqflite, path_provider
 */
