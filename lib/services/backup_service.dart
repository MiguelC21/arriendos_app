import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class BackupService {
  static Future<void> exportDatabase() async {
    try {
      final dbHelper = DatabaseHelper();
      // Cerramos para asegurar que no haya escrituras pendientes
      await dbHelper.closeDatabase();

      final dbPath = join(await getDatabasesPath(), 'arriendos_v2.db');
      final file = File(dbPath);

      if (await file.exists()) {
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final backupFile = File(
          join(tempDir.path, 'backup_arriendos_$timestamp.db'),
        );

        // Copiamos a un lugar temporal para compartir
        await file.copy(backupFile.path);

        await Share.shareXFiles(
          [XFile(backupFile.path)],
          subject: 'Copia de Seguridad Arriendos App',
          text: 'Archivo de base de datos generado el ${DateTime.now()}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<String?> saveDatabaseToFolder() async {
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.closeDatabase();

      final dbPath = join(await getDatabasesPath(), 'arriendos_v2.db');
      final file = File(dbPath);

      if (await file.exists()) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'backup_arriendos_$timestamp.db';

        // En Android/iOS se requieren los bytes para guardar
        final bytes = await file.readAsBytes();

        // Abrir selector de archivos para guardar
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Selecciona dónde guardar la copia de seguridad',
          fileName: fileName,
          type: FileType.any,
          bytes: bytes,
        );

        return outputFile;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> importDatabase() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type:
            FileType.any, // sqflite usa .db pero a veces el picker filtra raro
      );

      if (result != null) {
        File backupFile = File(result.files.single.path!);

        // Validación básica de extensión
        if (!backupFile.path.endsWith('.db')) {
          throw Exception(
            'El archivo seleccionado no es una base de datos válida (.db)',
          );
        }

        final dbHelper = DatabaseHelper();
        await dbHelper.closeDatabase();

        final dbPath = join(await getDatabasesPath(), 'arriendos_v2.db');

        // Reemplazar el archivo actual
        await backupFile.copy(dbPath);

        return true;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }
}
