import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert'; // Base64 çevrimi için
import 'dart:io';
import 'package:image_picker/image_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Akıllı Bitki Bakım',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const SplashScreen(), // İlk olarak Splash ekranı açılır
    );
  }
}

// ============================================================
// AÇILIŞ / KARŞILAMA EKRANI (SPLASH SCREEN)
// ============================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    // 2.5 saniye sonra ana sayfaya yumuşak geçiş yap
    Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => const HomePage(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade800,
              Colors.green.shade600,
              Colors.green.shade400,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),

            // Büyüyen ve belirginleşen logo/ikon alanı
            ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: 130,
                  height: 130,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/icons/app_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 25),

            // Başlık
            FadeTransition(
              opacity: _fadeAnimation,
              child: const Text(
                'Akıllı Bitki Bakım',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const SizedBox(height: 8),

            FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                'Otomatik Sulama & İzleme Sistemi',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
            ),

            const Spacer(),

            // Alt yükleme göstergesi
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sistem hazırlanıyor...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ANA SAYFA
// ============================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseReference systemRef = FirebaseDatabase.instance.ref(
    'plantSystem',
  );

  Map<String, dynamic> plants = {};

  double temperature = 0;
  double humidity = 0;
  double waterLevel = 0;

  StreamSubscription<DatabaseEvent>? _firebaseSubscription;

  @override
  void initState() {
    super.initState();

    listenToFirebase();
  }

  // ==========================================================
  // FIREBASE VERİLERİNİ DİNLE
  // ==========================================================

  void listenToFirebase() {
    _firebaseSubscription = systemRef.onValue.listen((event) {
      if (!mounted) return;

      final data = event.snapshot.value;

      if (data == null || data is! Map) {
        setState(() {
          plants = {};
          temperature = 0;
          humidity = 0;
          waterLevel = 0;
        });

        return;
      }

      final Map<String, dynamic> systemData = {};

      data.forEach((key, value) {
        systemData[key.toString()] = value;
      });

      // ======================================================
      // DHT11
      // ======================================================

      double newTemperature = 0;
      double newHumidity = 0;

      final dhtData = systemData['dht11'];

      if (dhtData is Map) {
        final temperatureValue = dhtData['temperature'];

        final humidityValue = dhtData['humidity'];

        newTemperature = double.tryParse('$temperatureValue') ?? 0;

        newHumidity = double.tryParse('$humidityValue') ?? 0;
      }

      // ======================================================
      // SU SEVİYESİ
      // ======================================================

      final newWaterLevel =
          double.tryParse('${systemData['waterLevel'] ?? 0}') ?? 0;

      // ======================================================
      // BİTKİLER
      // ======================================================

      final Map<String, dynamic> newPlants = {};

      final plantsData = systemData['plants'];

      if (plantsData is Map) {
        plantsData.forEach((key, value) {
          if (value is Map) {
            final Map<String, dynamic> plantData = {};

            value.forEach((plantKey, plantValue) {
              plantData[plantKey.toString()] = plantValue;
            });

            newPlants[key.toString()] = plantData;
          }
        });
      }

      // ======================================================
      // EKRANI GÜNCELLE
      // ======================================================

      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        setState(() {
          temperature = newTemperature;
          humidity = newHumidity;
          waterLevel = newWaterLevel;
          plants = newPlants;
        });
      });
    });
  }

  // ==========================================================
  // SAYFA KAPANIŞI
  // ==========================================================

  @override
  void dispose() {
    _firebaseSubscription?.cancel();

    super.dispose();
  }

  // ==========================================================
  // ÇİÇEK EKLE
  // ==========================================================

  Future<void> addPlant() async {
    final plantName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();

        return AlertDialog(
          title: const Text('Çiçek Ekle'),

          content: TextField(
            controller: controller,
            autofocus: true,

            decoration: const InputDecoration(
              labelText: 'Çiçek adı',
              hintText: 'Örn. Orkide',
              border: OutlineInputBorder(),
            ),

            onSubmitted: (value) {
              final name = value.trim();

              if (name.isNotEmpty) {
                Navigator.pop(dialogContext, name);
              }
            },
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },

              child: const Text('İptal'),
            ),

            FilledButton(
              onPressed: () {
                final name = controller.text.trim();

                if (name.isNotEmpty) {
                  Navigator.pop(dialogContext, name);
                }
              },

              child: const Text('Ekle'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (plantName == null || plantName.trim().isEmpty) {
      return;
    }

    final name = plantName.trim();

    try {
      final newPlantRef = systemRef.child('plants').push();

      final plantData = {
        'name': name,

        'pump': null,
        'pumpEnabled': false,
        'pumpState': 0,

        'soilSensor': null,
        'soilSensorEnabled': false,
        'soilMoisture': null,

        'lastWatered': null,
        'lastSoilChanged': null,

        'autoMode': false,
      };

      await newPlantRef.set(plantData);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$name eklendi.')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Çiçek eklenemedi: $e')));
    }
  }

  // ==========================================================
  // ÇİÇEK SİL
  // ==========================================================

  Future<void> deletePlant(String plantId, String plantName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Çiçeği Sil'),
          content: Text(
            '"$plantName" adlı çiçeği '
            'silmek istediğine emin misin?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      final db = FirebaseDatabase.instance;

      // 1. Silinecek bitkinin verisini oku (Hangi pompa ve sensör bağlı?)
      final plantSnapshot = await db.ref('plantSystem/plants/$plantId').get();
      final plantData = plantSnapshot.value;

      final Map<String, dynamic> updates = {};

      if (plantData is Map) {
        final assignedPump = plantData['pump'];
        final assignedSensor = plantData['soilSensor'];

        // Bağlı pompa varsa pompadaki assignedPlant kaydını sıfırla
        if (assignedPump != null) {
          updates['plantSystem/pumps/$assignedPump/assignedPlant'] = null;
        }

        // Bağlı sensör varsa sensördeki assignedPlant kaydını sıfırla
        if (assignedSensor != null) {
          updates['plantSystem/soilSensors/$assignedSensor/assignedPlant'] =
              null;
        }
      }

      // 2. Çiçeğin kendisini silinecekler listesine ekle
      updates['plantSystem/plants/$plantId'] = null;

      // 3. Tüm bu işlemleri Firebase'de atomik olarak tek seferde uygula
      await db.ref().update(updates);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$plantName adlı çiçek silindi.')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Çiçek silinemedi: $e')));
    }
  }

  // ==========================================================
  // ANA EKRAN
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Akıllı Bitki Bakım',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),

              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
      ),

      // ======================================================
      // DRAWER
      // ======================================================
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 30),

              // Logo
              Image.asset(
                'assets/icons/app_logo.png', // Logo dosya yolu
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 15),

              const Text(
                'Akıllı Bitki Bakım',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 30),

              const Divider(),
            ],
          ),
        ),
      ),

      // ======================================================
      // ÇİÇEK EKLE BUTONU
      // ======================================================
      floatingActionButton: FloatingActionButton(
        onPressed: addPlant,
        child: const Icon(Icons.add),
      ),

      // ======================================================
      // ANA İÇERİK
      // ======================================================
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 500));
        },

        child: ListView(
          padding: const EdgeInsets.all(16),

          children: [
            // ==================================================
            // ORTAM
            // ==================================================
            const Text(
              ' Ortam',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _infoCard(
                    iconWidget: Image.asset(
                      'assets/icons/temperature.png', // Sıcaklık ikonu dosya yolu
                      fit: BoxFit.contain,
                    ),
                    title: 'Sıcaklık',
                    value: '${temperature.toStringAsFixed(1)} °C',
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _infoCard(
                    iconWidget: Image.asset(
                      'assets/icons/humidity.png', // Nem ikonu dosya yolu
                      fit: BoxFit.contain,
                    ),
                    title: 'Hava Nemi',
                    value: '${humidity.toStringAsFixed(0)} %',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            // ==================================================
            // SU DEPOSU
            // ==================================================
            const Text(
              ' Su Deposu',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),

                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [
                        const Text(
                          'Su Seviyesi',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),

                        Text(
                          '${waterLevel.toStringAsFixed(0)}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    LinearProgressIndicator(
                      value: (waterLevel / 100).clamp(0.0, 1.0),

                      minHeight: 12,

                      borderRadius: BorderRadius.circular(10),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            // ==================================================
            // BİTKİLER
            // ==================================================
            const Text(
              ' Bitkiler',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            if (plants.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(30),

                  child: Column(
                    children: [
                      Icon(
                        Icons.local_florist,
                        size: 60,
                        color: Colors.grey.shade400,
                      ),

                      const SizedBox(height: 15),

                      const Text(
                        'Henüz çiçek eklenmedi.',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Yeni bir çiçek eklemek için '
                        'aşağıdaki + butonuna dokun.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...plants.entries.map((entry) {
                final plantId = entry.key;

                final plantData = _convertMap(entry.value);

                final plantName =
                    plantData['name']?.toString() ?? 'İsimsiz Çiçek';
                final pumpInfo = plantData['pump'];
                final sensorInfo = plantData['soilSensor'];
                final imageBase64 = plantData['imageBase64'];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.green.shade50,
                      backgroundImage: plantData['imageBase64'] != null
                          ? MemoryImage(
                              base64Decode(plantData['imageBase64'].toString()),
                            )
                          : null,
                      child: plantData['imageBase64'] == null
                          ? const Icon(
                              Icons.local_florist,
                              size: 30,
                              color: Colors.green,
                            )
                          : null,
                    ),
                    title: Text(
                      plantName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Pompa: ${pumpInfo != null ? 'Bağlı' : 'Yok'} | '
                      'Toprak Nem Sensörü: ${sensorInfo != null ? 'Bağlı' : 'Yok'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            deletePlant(plantId, plantName);
                          },
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PlantDetailPage(plantId: plantId),
                        ),
                      );
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // FIREBASE MAP DÖNÜŞTÜRME
  // ==========================================================

  Map<String, dynamic> _convertMap(dynamic value) {
    final Map<String, dynamic> result = {};

    if (value is Map) {
      value.forEach((key, value) {
        result[key.toString()] = value;
      });
    }

    return result;
  }

  // ==========================================================
  // BİLGİ KARTI
  // ==========================================================

  Widget _infoCard({
    required Widget iconWidget,
    required String title,
    required String value,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [
            // İkon veya PNG görselinin yerleştiği kutu
            SizedBox(height: 36, width: 36, child: Center(child: iconWidget)),

            const SizedBox(height: 8),

            Text(title, style: const TextStyle(fontSize: 14)),

            const SizedBox(height: 5),

            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ÇİÇEK DETAY SAYFASI
// ============================================================

class PlantDetailPage extends StatelessWidget {
  final String plantId;

  const PlantDetailPage({super.key, required this.plantId});

  // ------------------------------------------------------------
  // BİTKİ FOTOĞRAFI YÖNETİMİ (ÇEK / GALERİ / SİL)
  // ------------------------------------------------------------
  Future<void> pickAndUploadImage(
    BuildContext context,
    dynamic currentImageBase64,
  ) async {
    final picker = ImagePicker();

    // Kullanıcıya sunulacak menü
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('Fotoğraf Çek'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Galeriden Seç'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),

            // Sadece önceden bir fotoğraf yüklenmişse göster
            if (currentImageBase64 != null) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Fotoğrafı Kaldır',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            ],
          ],
        ),
      ),
    );

    if (action == null) return;

    // 1. Durum: Fotoğrafı Kaldır
    if (action == 'remove') {
      try {
        await FirebaseDatabase.instance
            .ref('plantSystem/plants/$plantId/imageBase64')
            .remove();

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Fotoğraf kaldırıldı.')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fotoğraf kaldırılamadı: $e')));
        }
      }
      return;
    }

    // 2. Durum: Fotoğraf Çek veya Galeriden Seç
    final source = action == 'camera'
        ? ImageSource.camera
        : ImageSource.gallery;

    // Avatar için optimize boyutlar (Firebase tasarrufu sağlar)
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 70,
    );

    if (pickedFile == null) return;

    try {
      final bytes = await File(pickedFile.path).readAsBytes();
      final base64String = base64Encode(bytes);

      await FirebaseDatabase.instance.ref('plantSystem/plants/$plantId').update(
        {'imageBase64': base64String},
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitki fotoğrafı güncellendi.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fotoğraf yüklenemedi: $e')));
      }
    }
  }

  // ------------------------------------------------------------
  // BİTKİ ADI DEĞİŞTİRME
  // ------------------------------------------------------------
  Future<void> changePlantName(BuildContext context, String currentName) async {
    final controller = TextEditingController(text: currentName);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Bitki Adını Düzenle'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Bitki adı'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = controller.text.trim();

                if (newName.isNotEmpty) {
                  await FirebaseDatabase.instance
                      .ref('plantSystem/plants/$plantId')
                      .update({'name': newName});
                }

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------
  // TARİH SEÇME
  // ------------------------------------------------------------
  Future<void> selectDate(BuildContext context, String field) async {
    // 1. Adım: Tarih Seçimi
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selectedDate == null)
      return; // Tarih seçilmeden çıkıldıysa işlemi durdur

    if (!context.mounted) return;

    // 2. Adım: Saat Seçimi
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        // İsteğe bağlı: Saat biçimini 24 saat (örn: 15:30) formatına getirmek için
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (selectedTime == null)
      return; // Saat seçilmeden çıkıldıysa işlemi durdur

    // 3. Adım: Tarih ve Saati Formatlama (GG.AA.YYYY SS:DD)
    final day = selectedDate.day.toString().padLeft(2, '0');
    final month = selectedDate.month.toString().padLeft(2, '0');
    final year = selectedDate.year;

    final hour = selectedTime.hour.toString().padLeft(2, '0');
    final minute = selectedTime.minute.toString().padLeft(2, '0');

    final formattedDateTime = '$day.$month.$year $hour:$minute';

    // 4. Adım: Firebase'e Kaydetme
    await FirebaseDatabase.instance.ref('plantSystem/plants/$plantId').update({
      field: formattedDateTime,
    });
  }

  // ------------------------------------------------------------
  // TARİH SİLME
  // ------------------------------------------------------------
  Future<void> clearDate(String field) async {
    await FirebaseDatabase.instance.ref('plantSystem/plants/$plantId').update({
      field: null,
    });
  }

  // ------------------------------------------------------------
  // POMPALARI GETİR
  // ------------------------------------------------------------
  Future<Map<String, dynamic>> getPumps() async {
    final snapshot = await FirebaseDatabase.instance
        .ref('plantSystem/pumps')
        .get();

    final data = snapshot.value;

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return {};
  }

  // ------------------------------------------------------------
  // POMPA SEÇME
  // ------------------------------------------------------------
  Future<String?> selectPump(BuildContext context, String? currentPump) async {
    final pumps = await getPumps();

    if (!context.mounted) return currentPump;

    return showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Pompa Seç'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext, null);
              },
              child: Row(
                children: [
                  const Expanded(child: Text('Pompa Yok')),
                  if (currentPump == null)
                    const Icon(Icons.check, color: Colors.green),
                ],
              ),
            ),
            for (int i = 1; i <= 4; i++)
              Builder(
                builder: (context) {
                  final pumpId = 'pump$i';
                  final pumpData = pumps[pumpId];

                  final assignedPlant = pumpData is Map
                      ? pumpData['assignedPlant']
                      : null;

                  final isUsed =
                      assignedPlant != null && assignedPlant != plantId;

                  final isCurrent = currentPump == pumpId;

                  return SimpleDialogOption(
                    onPressed: isUsed
                        ? null
                        : () {
                            Navigator.pop(dialogContext, pumpId);
                          },
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            isUsed ? 'Pompa $i  (Kullanımda)' : 'Pompa $i',
                          ),
                        ),
                        if (isCurrent)
                          const Icon(Icons.check, color: Colors.green),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------
  // POMPA ATAMA
  // ------------------------------------------------------------
  Future<void> assignPump(String? newPump, String? oldPump) async {
    final db = FirebaseDatabase.instance;

    final updates = <String, dynamic>{};

    if (oldPump != null) {
      updates['plantSystem/pumps/$oldPump/assignedPlant'] = null;
    }

    if (newPump != null) {
      updates['plantSystem/pumps/$newPump/assignedPlant'] = plantId;
    }

    updates['plantSystem/plants/$plantId/pump'] = newPump;
    updates['plantSystem/plants/$plantId/pumpEnabled'] = newPump != null;

    await db.ref().update(updates);
  }

  // ------------------------------------------------------------
  // TOPRAK NEM SENSÖRLERİNİ GETİR
  // ------------------------------------------------------------
  Future<Map<String, dynamic>> getSoilSensors() async {
    final snapshot = await FirebaseDatabase.instance
        .ref('plantSystem/soilSensors')
        .get();

    final data = snapshot.value;

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return {};
  }

  // ------------------------------------------------------------
  // TOPRAK NEM SENSÖRÜ SEÇME
  // ------------------------------------------------------------
  Future<String?> selectSoilSensor(
    BuildContext context,
    String? currentSensor,
  ) async {
    final sensors = await getSoilSensors();

    if (!context.mounted) return currentSensor;

    return showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Toprak Nem Sensörü Seç'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext, null);
              },
              child: Row(
                children: [
                  const Expanded(child: Text('Sensör Yok')),
                  if (currentSensor == null)
                    const Icon(Icons.check, color: Colors.green),
                ],
              ),
            ),
            for (int i = 1; i <= 4; i++)
              Builder(
                builder: (context) {
                  final sensorId = 'soilSensor$i';
                  final sensorData = sensors[sensorId];

                  final assignedPlant = sensorData is Map
                      ? sensorData['assignedPlant']
                      : null;

                  final sensorValue = sensorData is Map
                      ? sensorData['value']
                      : null;

                  final isUsed =
                      assignedPlant != null && assignedPlant != plantId;

                  final isCurrent = currentSensor == sensorId;

                  return SimpleDialogOption(
                    onPressed: isUsed
                        ? null
                        : () {
                            Navigator.pop(dialogContext, sensorId);
                          },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isUsed
                                    ? 'Sensör $i  (Kullanımda)'
                                    : 'Sensör $i',
                              ),
                            ),
                            if (isCurrent)
                              const Icon(Icons.check, color: Colors.green),
                          ],
                        ),
                        if (sensorValue != null)
                          Text(
                            'Mevcut nem: $sensorValue%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------
  // TOPRAK NEM SENSÖRÜ ATAMA
  // ------------------------------------------------------------
  Future<void> assignSoilSensor(String? newSensor, String? oldSensor) async {
    final db = FirebaseDatabase.instance;

    final updates = <String, dynamic>{};

    if (oldSensor != null) {
      updates['plantSystem/soilSensors/$oldSensor/assignedPlant'] = null;
    }

    if (newSensor != null) {
      updates['plantSystem/soilSensors/$newSensor/assignedPlant'] = plantId;

      final snapshot = await db
          .ref('plantSystem/soilSensors/$newSensor/value')
          .get();

      updates['plantSystem/plants/$plantId/soilMoisture'] = snapshot.value;
    } else {
      updates['plantSystem/plants/$plantId/soilMoisture'] = null;
    }

    updates['plantSystem/plants/$plantId/soilSensor'] = newSensor;

    updates['plantSystem/plants/$plantId/soilSensorEnabled'] =
        newSensor != null;

    await db.ref().update(updates);
  }

  // ------------------------------------------------------------
  // MANUEL SULAMA SÜRESİ SEÇME
  // ------------------------------------------------------------
  Future<void> showWateringDialog(BuildContext context, String pumpId) async {
    double selectedDuration = 10;

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.water_drop, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Sulama Süresi'),
                ],
              ),

              content: SizedBox(
                width: 300, // Sabit genişlik
                height: 180, // Sabit yükseklik
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.center, // Yatayda tam ortalama
                  children: [
                    const Text(
                      'Pompanın kaç saniye çalışmasını '
                      'istediğinizi seçin.',
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    Slider(
                      value: selectedDuration,
                      min: 1,
                      max: 30,
                      divisions: 29,
                      label: '${selectedDuration.round()} saniye',
                      onChanged: (value) {
                        setDialogState(() {
                          selectedDuration = value;
                        });
                      },
                    ),

                    Text(
                      '${selectedDuration.round()} saniye',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Vazgeç'),
                ),

                const SizedBox(width: 8), // İki buton arasındaki boşluk

                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext, selectedDuration.round());
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Başlat'),
                ),
              ],
            );
          },
        );
      },
    );

    // Kullanıcı Vazgeç dediyse hiçbir şey yapma
    if (result == null) return;

    // Sulamayı Firebase üzerinden başlat
    final pumpRef = FirebaseDatabase.instance.ref(
      'plantSystem/pumps/$pumpId/watering',
    );

    await pumpRef.update({
      'active': true,
      'duration': result,
      'remainingSeconds': result,
    });

    if (!context.mounted) return;

    // Sulama ilerleme ekranını aç
    await showWateringProgress(context, pumpId, result);
  }

  // ------------------------------------------------------------
  // SULAMA İLERLEME / DURDURMA EKRANI
  // ------------------------------------------------------------
  Future<void> showWateringProgress(
    BuildContext context,
    String pumpId,
    int duration,
  ) async {
    int remainingSeconds = duration;

    Timer? timer;

    bool stoppedByUser = false;

    final wateringRef = FirebaseDatabase.instance.ref(
      'plantSystem/pumps/$pumpId/watering',
    );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Timer sadece ilk oluşturulduğunda başlatılır
            timer ??= Timer.periodic(const Duration(seconds: 1), (timer) async {
              // ------------------------------------------------
              // SÜRE BİTTİ
              // ------------------------------------------------
              if (remainingSeconds <= 1) {
                timer.cancel();

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }

                return;
              }

              if (dialogContext.mounted) {
                setDialogState(() {
                  remainingSeconds--;
                });
              }
            });

            final progress = remainingSeconds / duration;

            return AlertDialog(
              title: Row(
                children: [
                  Image.asset(
                    'assets/icons/watering.png', // Sulanıyor ikonu için dosya yolu
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  const Text('Sulama Yapılıyor...'),
                ],
              ),

              content: SizedBox(
                width: 300, // İlk kutu ile aynı genişlik
                height: 180, // İlk kutu ile aynı yükseklik
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.center, // Yatayda tam ortalama
                  children: [
                    Text(
                      'Kalan süre',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade700,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      '$remainingSeconds saniye',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 14),

                    SizedBox(
                      width: 260, // İlerleme çubuğu için genişlik
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'Sulama devam ediyor...',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),

              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // ------------------------------------------
                      // TIMER DURDUR
                      // ------------------------------------------

                      timer?.cancel();
                      timer = null;

                      stoppedByUser = true;

                      // ------------------------------------------
                      // ESP32'YE DURDUR KOMUTU GÖNDER
                      // ------------------------------------------

                      await wateringRef.update({
                        'active': false,
                        'remainingSeconds': 0,
                      });

                      // ------------------------------------------
                      // DİYALOĞU KAPAT
                      // ------------------------------------------

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }

                      // ------------------------------------------
                      // BİLGİ MESAJI
                      // ------------------------------------------

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Sulama kullanıcı tarafından durduruldu.',
                            ),
                          ),
                        );
                      }
                    },

                    icon: const Icon(Icons.stop),

                    label: const Text('Sulamayı Durdur'),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    // Timer temizle
    timer?.cancel();
    timer = null;

    // ----------------------------------------------------------
    // NORMAL SULAMA TAMAMLANDI
    // ----------------------------------------------------------

    if (!stoppedByUser) {
      // Burada Firebase'deki active değerini Flutter tarafından kapatıyoruz.
      // ESP32 süreyi tamamladıktan sonra pompayı fiziksel olarak kapatmış oluyor.

      await wateringRef.update({
        'active': false,
        'remainingSeconds': 0,
        'duration': 0,
      });
    }
  }

  // ------------------------------------------------------------
  // TARİH KARTI
  // ------------------------------------------------------------
  Widget dateCard(
    BuildContext context, {
    required String title,
    required String? value,
    required String field,
    required Widget iconWidget, // IconData yerine Widget alacak
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(width: 28, height: 28, child: Center(child: iconWidget)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value ?? 'Belirtilmemiş',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                selectDate(context, field);
              },
            ),
            if (value != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  clearDate(field);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ANA EKRAN
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final plantRef = FirebaseDatabase.instance.ref(
      'plantSystem/plants/$plantId',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Bitki Detayı')),
      body: StreamBuilder<DatabaseEvent>(
        stream: plantRef.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.snapshot.value;

          if (data == null || data is! Map) {
            return const Center(child: Text('Bitki bulunamadı'));
          }

          final plant = Map<String, dynamic>.from(data);

          final name = plant['name'] ?? 'İsimsiz Bitki';

          final lastWatered = plant['lastWatered'];

          final lastSoilChanged = plant['lastSoilChanged'];

          final pump = plant['pump'];

          final pumpEnabled = plant['pumpEnabled'] == true;

          final soilSensor = plant['soilSensor'];

          final soilSensorEnabled = plant['soilSensorEnabled'] == true;

          final soilMoisture = plant['soilMoisture'];

          final imageBase64 = plant['imageBase64'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ------------------------------------------------
                // ÇİÇEK FOTOĞRAFI / AVATARI
                // ------------------------------------------------
                GestureDetector(
                  onTap: () => pickAndUploadImage(context, imageBase64),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: Colors.green.shade100,
                        backgroundImage: imageBase64 != null
                            ? MemoryImage(base64Decode(imageBase64.toString()))
                            : null,
                        child: imageBase64 == null
                            ? const Icon(
                                Icons.local_florist,
                                size: 50,
                                color: Colors.green,
                              )
                            : null,
                      ),

                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ------------------------------------------------
                // BİTKİ ADI
                // ------------------------------------------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name.toString(),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        changePlantName(context, name.toString());
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ------------------------------------------------
                // SON SULAMA
                // ------------------------------------------------
                dateCard(
                  context,
                  title: 'Son Sulama',
                  value: lastWatered?.toString(),
                  field: 'lastWatered',
                  iconWidget: Image.asset(
                    'assets/icons/last_watered.png', // Sulama ikonu dosya yolu
                    fit: BoxFit.contain,
                  ),
                ),

                // ------------------------------------------------
                // SON TOPRAK DEĞİŞİMİ
                // ------------------------------------------------
                dateCard(
                  context,
                  title: 'Son Toprak Değişimi',
                  value: lastSoilChanged?.toString(),
                  field: 'lastSoilChanged',
                  iconWidget: Image.asset(
                    'assets/icons/soil_change.png', // Toprak değişimi ikonu dosya yolu
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 10),

                // =================================================
                // POMPA KARTI
                // =================================================
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () async {
                      final selectedPump = await selectPump(context, pump);

                      if (selectedPump != pump) {
                        await assignPump(selectedPump, pump);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Su pompası ikonu
                              Image.asset(
                                'assets/icons/water_pump.png',
                                width: 28,
                                height: 28,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Pompa',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                pumpEnabled && pump != null
                                    ? pump.toString()
                                    : 'Pompa Yok',
                                style: TextStyle(
                                  color: pumpEnabled && pump != null
                                      ? Colors.green
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          // --------------------------------------
                          // POMPA ATANDIYSA SULAMA BÖLÜMÜ
                          // --------------------------------------
                          if (pumpEnabled && pump != null) ...[
                            const SizedBox(height: 14),
                            const Divider(),
                            const SizedBox(height: 10),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  showWateringDialog(context, pump.toString());
                                },
                                icon: const Icon(Icons.water_drop),
                                label: const Text(
                                  'Sulama Yap',
                                  style: TextStyle(fontSize: 16),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // =================================================
                // TOPRAK NEM SENSÖRÜ KARTI
                // =================================================
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () async {
                      final selectedSensor = await selectSoilSensor(
                        context,
                        soilSensor,
                      );

                      if (selectedSensor != soilSensor) {
                        await assignSoilSensor(selectedSensor, soilSensor);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Toprak nem sensörü ikonu
                              Image.asset(
                                'assets/icons/soil_sensor.png',
                                width: 28,
                                height: 28,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Toprak Nem Sensörü',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                soilSensorEnabled && soilSensor != null
                                    ? soilSensor.toString()
                                    : 'Sensör Yok',
                                style: TextStyle(
                                  color: soilSensorEnabled && soilSensor != null
                                      ? Colors.green
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          // --------------------------------------
                          // SENSÖR ATANDIYSA NEM DEĞERİ
                          // --------------------------------------
                          if (soilSensorEnabled && soilSensor != null) ...[
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 10),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.water_drop_outlined,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Toprak Nemi: '
                                  '${soilMoisture ?? '--'}%',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
