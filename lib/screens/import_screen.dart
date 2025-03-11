import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../services/contacts_service.dart';

// İçe aktarma işlem durumları
enum ImportState { initial, loading, success, error }

// İçe aktarma durumu sağlayıcısı
final importStateProvider =
    StateProvider<ImportState>((ref) => ImportState.initial);

// İçe aktarılan kişi sayısı sağlayıcısı
final importedCountProvider = StateProvider<int>((ref) => 0);

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _contactsManager = ContactsManager();
  String? _selectedFilePath;
  String? _selectedFileName;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final importState = ref.watch(importStateProvider);
    final importedCount = ref.watch(importedCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yedeği Geri Yükle'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFileSelector(importState),
            const SizedBox(height: 24),
            if (_selectedFilePath != null && importState == ImportState.initial)
              _buildImportButton(),
            if (importState == ImportState.loading)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Kişiler içe aktarılıyor...'),
                  ],
                ),
              ),
            if (importState == ImportState.success)
              _buildSuccessMessage(importedCount),
            if (importState == ImportState.error && _errorMessage != null)
              _buildErrorMessage(),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelector(ImportState importState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yedek Dosyası Seçimi',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const Text(
              'İçe aktarmak için bir vCard (.vcf) dosyası seçin. '
              'Bu dosya, önceden oluşturduğunuz bir rehber yedeği olabilir.',
            ),
            const SizedBox(height: 16),
            if (_selectedFilePath == null)
              OutlinedButton.icon(
                onPressed:
                    importState != ImportState.loading ? _pickFile : null,
                icon: const Icon(Icons.file_open),
                label: const Text('Dosya Seç'),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.description, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedFileName ?? 'Seçili Dosya',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_selectedFilePath != null)
                                  Text(
                                    _selectedFilePath!,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: importState != ImportState.loading
                        ? () {
                            setState(() {
                              _selectedFilePath = null;
                              _selectedFileName = null;
                            });
                          }
                        : null,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportButton() {
    return ElevatedButton.icon(
      onPressed: _importContacts,
      icon: const Icon(Icons.restore),
      label: const Text('Rehbere Geri Yükle'),
    );
  }

  Widget _buildSuccessMessage(int importedCount) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'İçe Aktarma Başarılı!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('$importedCount kişi rehberinize eklendi.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(importStateProvider.notifier).state =
                    ImportState.initial;
                setState(() {
                  _selectedFilePath = null;
                  _selectedFileName = null;
                });
              },
              child: const Text('Yeni Dosya Seç'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(
              Icons.error,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'İçe Aktarma Hatası!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(_errorMessage ?? 'Bilinmeyen hata'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(importStateProvider.notifier).state =
                    ImportState.initial;
              },
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['vcf'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFilePath = result.files.first.path;
          _selectedFileName = result.files.first.name;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dosya seçme hatası: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importContacts() async {
    if (_selectedFilePath == null) {
      return;
    }

    _errorMessage = null;
    ref.read(importStateProvider.notifier).state = ImportState.loading;

    try {
      final importedCount =
          await _contactsManager.importContactsFromVCard(_selectedFilePath!);

      ref.read(importedCountProvider.notifier).state = importedCount;
      ref.read(importStateProvider.notifier).state = ImportState.success;
    } catch (e) {
      _errorMessage = e.toString();
      ref.read(importStateProvider.notifier).state = ImportState.error;
    }
  }
}
