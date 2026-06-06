
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
  int _virtualBalance = 7500; 
  int _escrowBalance = 4250;    
  
  String _statusMessage = "مرحباً يا أحمد 👋 محفظة فكة جاهزة للمعاملات الفورية";
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
          _statusMessage = "مستشعر NFC غير نشط. يمكنك استخدام رقم الحساب للتحويل.";
        });
      }
    } catch (e) {
      debugPrint("NFC Init Error: $e");
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: isError ? Colors.red[800] : Colors.green[800],
      ),
    );
  }

  void _handleAiResponse(String userText) {
    if (userText.trim().isEmpty) return;
    String reply = "";
    String text = userText.toLowerCase();

    if (text.contains("ضمان") || text.contains("ولايات")) {
      reply = "🛡️ نظام الضمان يحمي المعاملات التجارية بين الولايات. المبالغ الحالية (4,250 SDG) معلقة بأمان لحين استلام الشحنة.";
    } else if (text.contains("nfc") || text.contains("بث")) {
      reply = "⚡ اضغط على زر البث في الأسفل وقرّب ظهر هاتفك من هاتف الطرف الآخر لإتمام تبادل الفكة فورياً عبر الـ NFC.";
    } else if (text.contains("رصيد") || text.contains("كم معي")) {
      reply = "💰 رصيدك المتاح الحالي هو $_virtualBalance SDG والأموال في الضمان هي $_escrowBalance SDG.";
    } else {
      reply = "🤖 أنا هنا لمساعدتك في إدارة محفظة فكة، تتبع أموال الضمان، وتسهيل الدفع اللاتلامسي.";
    }

    setState(() {
      _aiMessages.add({"sender": "user", "text": userText});
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      setState(() {
        _aiMessages.add({"sender": "ai", "text": reply});
      });
    });
    _aiInputController.clear();
  }

  void _sendNfc(int amount) async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      _showSnackBar("عذراً، ميزة الـ NFC معطلة أو غير مدعومة في هذا الجهاز.");
      return;
    }
    if (_virtualBalance < amount) {
      _showSnackBar("عفواً! الرصيد المتاح الحالي لا يكفي لبث هذا المبلغ.");
      return;
    }
    setState(() => _statusMessage = "جاري بث $amount SDG... قَرّب الهاتف الآن ⚡");
    try {
      NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
        try {
          Ndef? ndef = Ndef.from(tag);
          if (ndef == null || !ndef.isWritable) {
            setState(() => _statusMessage = "فشل: جهاز الطرف الآخر غير مدعوم.");
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
      setState(() => _statusMessage = "خطأ في تشغيل الـ NFC: $e");
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
              Card(
                color: const Color(0xFF1B5E20),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ضمان الولايات: $_escrowBalance SDG', style: const TextStyle(color: Colors.white70)),
                          Text('حساب: $_myAccountNumber', style: const TextStyle(color: Colors.white70)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                child: Text(_statusMessage, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 15),
              const Text('مساعد فكة الذكي 🤖', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
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
                          child: Text(msg["text"] ?? ""),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _aiInputController,
                      decoration: const InputDecoration(
                        hintText: 'اسأل المساعد...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF1B5E20)),
                    onPressed: () => _handleAiResponse(_aiInputController.text),
                  )
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _sendNfc(500), 
                  icon: const Icon(Icons.nfc),
                  label: const Text('بث فكة عبر الـ NFC (500 SDG)'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700], foregroundColor: Colors.black),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
