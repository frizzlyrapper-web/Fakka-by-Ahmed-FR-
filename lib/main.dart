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
          _statusMessage = "مستشعر NFC غير نشط حالياً. يمكنك استخدام رقم الحساب.";
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

  void _sendNfc(int amount) async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      _showSnackBar("ميزة الـ NFC معطلة أو غير مدعومة في هذا الجهاز.");
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
        title: const Text('محفظة فَكَّة الذكية'),
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
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                child: Text(
                  _statusMessage, 
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () => _sendNfc(500), 
                  icon: const Icon(Icons.nfc, size: 28),
                  label: const Text('بث فكة عبر الـ NFC (500 SDG)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700], 
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
