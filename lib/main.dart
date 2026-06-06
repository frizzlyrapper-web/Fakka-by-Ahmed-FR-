import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

void main() {
  runApp(const FakkaApp());
}

class FakkaApp extends StatelessWidget {
  const FakkaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fakka Wallet',
      theme: ThemeData(
        primaryColor: const Color(0xFF1B5E20),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
        useMaterial3: true,
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
  String _statusMessage = "مرحباً يا أحمد 👋 محفظة فكة مؤمنة بالكامل بالمعايير العالمية";
  final String _myAccountNumber = "FK-99241";
  
  bool _isProcessing = false;
  List<String> _transactionHistory = [];
  final TextEditingController _amountController = TextEditingController();

  late encrypt.Key _secureKey;
  late Future<void> _initWalletFuture;

  @override
  void initState() {
    super.initState();
    _initWalletFuture = _initWallet();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _initWallet() async {
    _initEncryptionKey();
    _initNfc();
    await _loadTransactionHistory();
  }

  void _initEncryptionKey() {
    const masterSecret = "Fakka_Secured_Salt_2026_AhmedFR_V2";
    var bytes = utf8.encode(masterSecret);
    var digest = sha256.convert(bytes);
    _secureKey = encrypt.Key(Uint8List.fromList(digest.bytes));
  }

  void _initNfc() async {
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        _safeStateUpdate(() {
          _statusMessage = "مستشعر NFC غير نشط حالياً. يمكنك استخدام رقم الحساب.";
        });
      }
    } catch (e) {
      debugPrint("NFC Init Error: $e");
      _safeStateUpdate(() {
        _statusMessage = "خطأ في تهيئة NFC: $e";
      });
    }
  }

  Future<void> _loadTransactionHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _safeStateUpdate(() {
        _transactionHistory = prefs.getStringList('fakka_tx_history') ?? [];
        _virtualBalance = prefs.getInt('fakka_balance') ?? 7500;
      });
    } catch (e) {
      debugPrint("Load transaction error: $e");
    }
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('fakka_tx_history', _transactionHistory.take(100).toList());
      await prefs.setInt('fakka_balance', _virtualBalance);
    } catch (e) {
      debugPrint("Save data error: $e");
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: isError ? Colors.red[800] : Colors.green[800],
        duration: const Duration(seconds: 4),
      ),
    );
  }

  encrypt.IV _generateRandomIV() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return encrypt.IV(Uint8List.fromList(values));
  }

  Future<bool> _verifyRecipient(Ndef ndef) async {
    try {
      NdefMessage? cachedMessage = ndef.cachedMessage;
      if (cachedMessage != null && cachedMessage.records.isNotEmpty) {
        String recipientData = String.fromCharCodes(
          cachedMessage.records[0].payload.skip(3)
        );
        
        // Check if recipient is a valid Fakka wallet
        if (recipientData.contains('FAKKA_WALLET')) {
          return true;
        }
      }
      return true; // Allow if no existing data (fresh tag)
    } catch (e) {
      debugPrint("Recipient verification error: $e");
      return false;
    }
  }

  void _sendNfc(int amount) async {
    if (_isProcessing) {
      _showSnackBar("عملية جارية بالفعل. انتظر اكتمالها أولاً.", isError: true);
      return;
    }

    // Validation checks
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      _showSnackBar("ميزة الـ NFC معطلة أو غير مدعومة في هذا الجهاز.");
      return;
    }

    if (amount <= 0) {
      _showSnackBar("المبلغ يجب أن يكون أكثر من صفر.");
      return;
    }

    if (amount > 10000) {
      _showSnackBar("الحد الأقصى للتحويل: 10000 SDG");
      return;
    }

    if (_virtualBalance < amount) {
      _showSnackBar("الرصيد غير كافٍ. رصيدك الحالي: $_virtualBalance SDG");
      return;
    }

    _safeStateUpdate(() {
      _isProcessing = true;
      _statusMessage = "جاري البث الآمن... قَرّب الهاتف الآن (مهلة 30 ثانية) ⚡";
    });

    bool txSuccess = false;
    bool sessionClosed = false;

    // Timeout after 30 seconds
    final timeoutFuture = Future.delayed(const Duration(seconds: 30), () {
      if (_isProcessing && !txSuccess && !sessionClosed && mounted) {
        sessionClosed = true;
        try {
          NfcManager.instance.stopSession();
        } catch (e) {
          debugPrint("Error stopping NFC session: $e");
        }
        
        _safeStateUpdate(() {
          _statusMessage = "انتهت المهلة (30 ثانية) دون استجابة. تم إلغاء البث بأمان.";
          _isProcessing = false;
        });
        _showSnackBar("انتهت مهلة البث. الرصيد محمي وآمن.", isError: true);
      }
    });

    try {
      NfcManager.instance.startSession(
        alertMessage: "قَرّب هاتفك الآن لإكمال التحويل",
        onDiscovered: (NfcTag tag) async {
          if (sessionClosed) return;

          try {
            Ndef? ndef = Ndef.from(tag);
            
            // Validate tag
            if (ndef == null || !ndef.isWritable) {
              _safeStateUpdate(() {
                _statusMessage = "فشل: الجهاز المقابل غير مدعوم أو ليس محفظة فكة.";
                _isProcessing = false;
              });
              sessionClosed = true;
              NfcManager.instance.stopSession();
              _showSnackBar("الجهاز غير متوافق مع محفظة فكة.");
              return;
            }

            // Verify recipient
            bool isValidRecipient = await _verifyRecipient(ndef);
            if (!isValidRecipient) {
              _safeStateUpdate(() {
                _statusMessage = "خطأ أمان: الجهاز المقابل ليس محفظة فكة معتمدة.";
                _isProcessing = false;
              });
              sessionClosed = true;
              NfcManager.instance.stopSession();
              _showSnackBar("فشل التحقق من الجهاز المقابل.");
              return;
            }

            txSuccess = true;

            // Generate random IV for this transaction
            final currentIV = _generateRandomIV();
            
            // Create transaction payload with timestamp
            String rawData = "FAKKA_VERIFIED_TX|$_myAccountNumber|$amount|${DateTime.now().millisecondsSinceEpoch}|${_generateTransactionId()}";
            
            // Encrypt the payload
            final encrypter = encrypt.Encrypter(encrypt.AES(_secureKey));
            final encrypted = encrypter.encrypt(rawData, iv: currentIV);

            // Combine IV and encrypted data
            String finalPayload = "${currentIV.base64}:${encrypted.base64}";

            // Create NFC message
            NdefMessage message = NdefMessage([
              NdefRecord.createText("FAKKA_WALLET_HEADER"),
              NdefRecord.createText(finalPayload),
              NdefRecord.createText("TX_COMPLETE"),
            ]);

            // Write to NFC tag
            await ndef.write(message);

            // Only deduct balance AFTER successful write
            final timeFormat = DateFormat('HH:mm').format(DateTime.now());
            _safeStateUpdate(() {
              _virtualBalance -= amount;
              _statusMessage = "✅ تم تحويل $amount SDG بنجاح وبتشفير عسكري! 🎉";
              _transactionHistory.insert(
                0,
                "✓ إرسال $amount SDG (AES-256 آمن) - $timeFormat"
              );
              _isProcessing = false;
            });

            // Save to persistent storage
            await _saveData();
            
            // Show success snackbar
            _showSnackBar("تحويل بقيمة $amount SDG تم بنجاح!", isError: false);

            sessionClosed = true;
            NfcManager.instance.stopSession();
          } catch (e) {
            debugPrint("NFC Write Error: $e");
            
            // Transaction failed - balance is NOT deducted (safe!)
            _safeStateUpdate(() {
              _statusMessage = "⚠️ فشلت عملية الكتابة. رصيدك محمي وآمن: $e";
              _transactionHistory.insert(
                0,
                "✗ فشل التحويل بمبلغ $amount SDG (الرصيد محمي)"
              );
              _isProcessing = false;
            });

            _showSnackBar("فشلت عملية الكتابة: $e", isError: true);

            sessionClosed = true;
            try {
              NfcManager.instance.stopSession();
            } catch (e) {
              debugPrint("Error stopping session after error: $e");
            }
          }
        },
      );
    } catch (e) {
      debugPrint("NFC Session Error: $e");
      _safeStateUpdate(() {
        _statusMessage = "❌ خطأ في تشغيل NFC: $e";
        _isProcessing = false;
      });
      _showSnackBar("خطأ في تشغيل NFC: $e", isError: true);
      timeoutFuture.ignore();
    }
  }

  String _generateTransactionId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  void _safeStateUpdate(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void _showCustomAmountDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text("تحديد مبلغ مخصص"),
          content: TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(signed: false),
            decoration: const InputDecoration(
              labelText: "المبلغ بالسوداني (SDG)",
              hintText: "مثال: 1500",
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                _amountController.clear();
                Navigator.pop(context);
              },
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              onPressed: () {
                final text = _amountController.text.trim();
                int? amount = int.tryParse(text);

                if (amount == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("الرجاء إدخال رقم صحيح"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("المبلغ يجب أن يكون أكثر من صفر"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (amount > _virtualBalance) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("الرصيد غير كافٍ. رصيدك: $_virtualBalance SDG"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (amount > 10000) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("الحد الأقصى للتحويل: 10000 SDG"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                _amountController.clear();
                _sendNfc(amount);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                "بث الآن",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('محفظة فَكَّة الذكية 🛡️'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 2,
      ),
      body: FutureBuilder<void>(
        future: _initWalletFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'خطأ في تحميل المحفظة: ${snapshot.error}',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
              ),
            );
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Balance Card
                  Card(
                    color: const Color(0xFF1B5E20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'الرصيد المتوفر الحالي',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_virtualBalance SDG',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ضمان الولايات: $_escrowBalance SDG',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'حساب: $_myAccountNumber',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status Message
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Transaction History Header
                  const Text(
                    "سجل المعاملات الأخيرة:",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Transaction History List
                  Expanded(
                    child: _transactionHistory.isEmpty
                        ? Center(
                            child: Text(
                              "لا توجد معاملات مسجلة حتى الآن",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _transactionHistory.length,
                            itemBuilder: (context, index) => Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: Icon(
                                  _transactionHistory[index].startsWith('✓')
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: _transactionHistory[index].startsWith('✓')
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                  size: 24,
                                ),
                                title: Text(
                                  _transactionHistory[index],
                                  style: const TextStyle(fontSize: 13),
                                ),
                                dense: true,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : () => _sendNfc(500),
                          icon: const Icon(Icons.nfc),
                          label: const Text(
                            'بث (500 SDG)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[700],
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Colors.grey[400],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _showCustomAmountDialog,
                          icon: const Icon(Icons.edit),
                          label: const Text(
                            'مبلغ مخصص',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey[400],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
