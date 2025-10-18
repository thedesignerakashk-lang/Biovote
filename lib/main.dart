import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:open_file/open_file.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32-CAM Receiver',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _ipController = TextEditingController();
  String _statusMessage = 'Enter the IP address of your ESP32-CAM.';
  bool _isCapturing = false;
  String? _savedImagePath;

  @override
  void initState() {
    super.initState();
    _loadSavedIp();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    }
  }

  Future<void> _loadSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('esp32_ip');
    if (savedIp != null) {
      setState(() {
        _ipController.text = savedIp;
        _statusMessage = 'IP Address loaded. Ready to capture!';
      });
    }
  }

  Future<void> _saveIp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('esp32_ip', _ipController.text);
    setState(() {
      _statusMessage = 'IP Address Saved! Ready to capture.';
    });
  }

  Future<void> _capturePhoto() async {
    if (_ipController.text.isEmpty) {
      setState(() => _statusMessage = 'Please enter an IP address first.');
      return;
    }

    setState(() {
      _isCapturing = true;
      _statusMessage = 'Capturing photo...';
      _savedImagePath = null;
    });

    try {
      final response = await http.get(
        Uri.parse('http://${_ipController.text}/capture'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        Uint8List imageBytes = response.bodyBytes;
        String savedPath = await _saveImageToFile(imageBytes);
        setState(() {
          _statusMessage = 'Photo Saved Successfully!\n$savedPath';
          _savedImagePath = savedPath;
        });
      } else {
        setState(() => _statusMessage = 'Error: Failed to capture. Status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error: Could not connect. Check IP/WiFi.\n$e');
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  Future<String> _saveImageToFile(Uint8List imageBytes) async {
    final directory = await getExternalStorageDirectory();
    final String dateFolder = DateTime.now().toIso8601String().split('T')[0];
    final String fullPath = path.join(directory!.path, 'Pictures', 'ESP32Cam', dateFolder);

    await Directory(fullPath).create(recursive: true);

    final String fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final File imageFile = File(path.join(fullPath, fileName));
    await imageFile.writeAsBytes(imageBytes);

    return imageFile.path;
  }

  void _openGallery() async {
    final directory = await getExternalStorageDirectory();
    final galleryPath = path.join(directory!.path, 'Pictures', 'ESP32Cam');
    await OpenFile.open(galleryPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32-CAM Receiver'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ESP32-CAM IP Address', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ipController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(), hintText: 'e.g., 192.168.1.100', labelText: 'IP Address',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save), label: const Text('Save IP Address'), onPressed: _saveIp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: _isCapturing
                  ? const CircularProgressIndicator()
                  : FloatingActionButton.extended(
                      onPressed: _capturePhoto, icon: const Icon(Icons.camera_alt), label: const Text('Capture Photo'),
                    ),
            ),
            const SizedBox(height: 20),
            Card(
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_statusMessage, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              ),
            ),
            if (_savedImagePath != null) ...[
              const SizedBox(height: 20),
              const Text("Last Captured Photo:"),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.file(File(_savedImagePath!), height: 250, fit: BoxFit.cover),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Open Gallery Folder'),
                onPressed: _openGallery,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
