import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';

void main() {
  runApp(const FakkaApp());
}

class FakkaApp extends StatelessWidget {
  const FakkaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fakka - Ahmed FR',
      theme: ThemeData(
        primaryColor: const Color(0xFF1B5E20),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
      ),
      home: const MainLayout(),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  _MainLayoutState createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  
  // تحديث المبالغ لتطابق تماماً التصميم الظاهر في FlutterFlow لديك
  int _virtualBalance = 7500; 
  int _escrowBalance = 4250;    
  
  String _statusMessage = "مرحباً يا أحمد 👋 محفظة فكة جاهزة للمعاملات الفورية";
  String _escrowDetails = "المعاملات النشطة: شحن بضاعة إلى ولاية أخرى (معلقة بالضمان)";
  bool _hasActiveEscrow = true;
  final String _myAccountNumber = "FK-99241"; 

  // قائمة رسائل مساعد الذكاء الاصطناعي
  final List<Map<String, String>> _aiMessages = [
    {"sender": "ai", "text": "مرحباً يا أحمد! أنا مساعد فكة الذكي 🤖 كيف يمكنني مساعدتك في عمليات التحويل أو الـ NFC أو خدمات الولايات اليوم؟"},
    {"sender": "user", "text": "أريد معرفة رصيدي المتاح في محفظتي"},
    {"sender": "ai", "text": "رصيدك الحالي المتوفر للاستخدام المباشر هو 7,500 SDG، ولديك مبالغ محجوزة بأمان في نظام الضمان للولايات بقيمة 4,250 SDG 🛡️"}
  ];
  
  final TextEditingController _aiInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initNfc();
  }

  void _initNfc() async {
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        setState(() {
          _statusMessage = "مستشعر NFC غير نشط. يمكنك استخدام رقم الحساب أو الـ QR للتحويل.";
        });
      }
    } catch (e) {
      debugPrint("NFC Init Error: $e");
    }
  }

  void _handleAiResponse(String userText) {
    String reply = "";
    String text = userText.toLowerCase();

    if (text.contains("ضمان") || text.contains("ولايات") || text.contains("حجز")) {
      reply = "🛡️ نظام الضمان يحمي قروش المعاملات بين الولايات. القروش الحالية المحجوزة (4,250 SDG) معلقة أماناً حتى يتأكد المستلم من وصول الشحنة.";
    } else if (text.contains("nfc") || text.contains("بث")) {
      reply = "⚡ ميزة الـ NFC تفاعلية بالكامل! اضغط على 'بث NFC' أو 'استقبال' وقرب ظهر هاتف المرسل والمستلم لإتمام تبادل الفكة فورياً.";
    } else if (text.contains("رصيد") || text.contains("كم معي")) {
      reply = "💰 رصيدك الحالي المتاح هو $_virtualBalance SDG والأموال المحمية في الضمان هي $_escrowBalance SDG.";
    } else if (text.contains("سلام") || text.contains("مرحب")) {
      reply = "أهلاً بك يا أحمد! كيف يمكن لمساعد فكة الذكي أن يخدمك الآن؟";
    } else {
      reply = "🤖 أنا هنا لمساعدتك في إدارة حسابك 'فكة بلس'، تتبع شحنات الولايات، تفعيل كروت الـ NFC، والإجابة على أي استفسار مالي.";
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _aiMessages.add({"sender": "ai", "text": reply});
      });
    });
  }

  // دالة بث وتبادل الأموال عبر الـ NFC
  void _sendNfc(int amount) async {
    if (_virtualBalance < amount) {
      _showSnackBar("عفواً! الرصيد المتاح الحالي لا يكفي لبث هذا المبلغ.");
      return;
    }
    setState(() => _statusMessage = "جاري بث $amount SDG... قَرّب الهاتف من الجهاز الآخر الآن ⚡");
    
    NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
      try {
        Ndef? ndef = Ndef.from(tag);
        if (ndef == null || !ndef.isWritable) {
          setState(() => _statusMessage = "فشل: جهاز الطرف الآخر غير مدعوم أو مغلق.");
          NfcManager.instance.stopSession();
          return;
        }
        NdefMessage message = NdefMessage([NdefRecord.createText('FAKKA_TX:$amount')]);
        await ndef.write(message);
