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
  
  int _virtualBalance = 7500; 
  int _escrowBalance = 4250;    
  
  String _statusMessage = "مرحباً يا أحمد 👋 محفظة فكة جاهزة للمعاملات الفورية";
  String _escrowDetails = "المعاملات النشطة: شحن بضاعة إلى ولاية أخرى (معلقة بالضمان)";
  bool _hasActiveEscrow = true;
  final String _myAccountNumber = "FK-99241"; 

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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handleAiResponse(String userText) {
    String reply = "";
    String text = userText.toLowerCase();

    if (text.contains("ضمان") || text.contains("ولايات") || text.contains("حجز")) {
      reply = "🛡️ نظام الضمان يحمي قروش المعاملات بين الولايات. القروش الحالية المحجوزة (4,250 SDG) معلقة أماناً حتى يتأكد المستلم من وصول الشحنة.";
    } else if (text.contains("nfc") || text.contains("بث")) {
      reply = "⚡ ميزة الـ NFC تفاعلية بالكامل! اضغط على 'بث NFC' وقرب ظهر هاتف المرسل والمستلم لإتمام تبادل الفكة فورياً.";
    } else if (text.contains("رصيد") || text.contains("كم معي")) {
      reply = "💰 رصيدك الحالي المتاح هو $_virtualBalance SDG والأموال المحمية في الضمان هي $_escrowBalance SDG.";
    } else if (text.contains("سلام") || text.contains("مرحب")) {
      reply = "أهلاً بك يا أحمد! كيف يمكن لمساعد فكة الذكي أن يخدمك الآن؟";
    } else {
      reply = "🤖 أنا هنا لمساعدتك في إدارة حسابك 'فكة بلس'، تتبع شحنات الولايات، تفعيل كروت الـ NFC، والإجابة على أي استفسار مالي.";
    }

    setState(() {
      _aiMessages.add({"sender": "user", "text": userText});
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _aiMessages.add({"sender": "ai", "text": reply});
      });
    });
    _aiInputController.clear();
  }

  void _sendNfc(int amount) async {
    if (_virtualBalance < amount) {
      _showSnackBar("عفواً! الرصيد المتاح الحالي لا يكفي لبث هذا المبلغ.");
      return;
    }
    setState(() => _statusMessage = "جاري بث $amount SDG... قَرّب الهاتف من الجهاز الآخر الآن ⚡");
    
    try {
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
          setState(() {
            _virtualBalance -= amount;
            _statusMessage = "تم بث وتحويل $amount SDG بنجاح عبر الـ NFC! 🎉";
          });
          NfcManager.instance.stopSession();
        } catch (e) {
          setState(() => _statusMessage = "خطأ أثناء الكتابة: $e");
          NfcManager.instance.stopSession();
        }
      });
    } catch (e) {
      setState(() => _statusMessage = "خطأ في تشغيل جلسة NFC: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('محفظة فَكَّة الذكية - بلس'),
        backgroundColor: const Color(0xFF1B5E20),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // كارت المحفظة الرئيسي
              Card(
                color: const Color(0xFF1B5E20),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('الرصيد المتوفر الحالي', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 5),
                      Text('$_virtualBalance SDG', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),
                      Row(
                        justifyAxisAlignment: MainAxisAlignment.between,
                        children: [
                          Text('ضمان الولايات: $_escrowBalance SDG', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          Text('حساب: $_myAccountNumber', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // حالة الـ NFC أو النظام
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF1B5E20), size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_statusMessage, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              const Text('مساعد فكة الذكي 🤖', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              // شات الذكاء الاصطناعي
              Expanded(
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _aiMessages.length,
                    itemBuilder: (context, index) {
                      var msg = _aiMessages[index];
                      bool isAi = msg["sender"] == "ai";
                      return Align(
                        alignment: isAi ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isAi ? Colors.green[50] : Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(msg["text"] ?? "", style: const TextStyle(fontSize: 13)),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // إدخال الشات
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _aiInputController,
                      decoration: const InputDecoration(
                        hintText: 'اسأل المساعد (مثال: رصيد، ضمان)...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF1B5E20)),
                    onPressed: () {
                      if (_aiInputController.text.isNotEmpty) {
                        _handleAiResponse(_aiInputController.text);
                      }
                    },
                  )
                ],
              ),
              const SizedBox(height: 15),
              // زر بث الـ NFC الدائري والسريع
              Center(
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _sendNfc(500), // يبث 500 كمثال عند الضغط
                    icon: const Icon(Icons.wifi_protected_setup),
                    label: const Text('بث فكة عبر الـ NFC (500 SDG)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[700],
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
 
