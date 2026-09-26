import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arriendos_app/config/environment_config.dart';
import 'package:arriendos_app/config/theme_config.dart';
import 'package:arriendos_app/models/building.dart';
import 'package:arriendos_app/services/supabase_service.dart';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io' as io;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    io.HttpOverrides.global = null;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });

  tearDownAll(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('1. Theme System Tests (Obsidian Dark & Clean Light)', () {
    test('Dark theme uses true obsidian black palette (#090A0C)', () {
      final darkTheme = AppTheme.darkTheme;
      expect(darkTheme.brightness, equals(Brightness.dark));
      expect(darkTheme.scaffoldBackgroundColor, equals(const Color(0xFF090A0C)));
      expect(darkTheme.cardTheme.color, equals(const Color(0xFF121316)));
      expect(darkTheme.inputDecorationTheme.fillColor, equals(const Color(0xFF181A1F)));
      expect(darkTheme.colorScheme.surface, equals(const Color(0xFF121316)));
    });

    test('Light theme uses clean SaaS palette (#F8FAFC)', () {
      final lightTheme = AppTheme.lightTheme;
      expect(lightTheme.brightness, equals(Brightness.light));
      expect(lightTheme.scaffoldBackgroundColor, equals(const Color(0xFFF8FAFC)));
      expect(lightTheme.cardTheme.color, equals(Colors.white));
      expect(lightTheme.inputDecorationTheme.fillColor, equals(const Color(0xFFF8FAFC)));
    });
  });

  group('2. Environment Configuration Tests', () {
    test('Environment URLs and keys match expected local and production endpoints', () {
      expect(EnvironmentConfig.localUrl, equals('http://127.0.0.1:54321'));
      expect(EnvironmentConfig.prodUrl, equals('https://npjpxjrrdxnplpxatxpb.supabase.co'));
      expect(EnvironmentConfig.localAnonKey, isNotEmpty);
      expect(EnvironmentConfig.prodAnonKey, isNotEmpty);
    });
  });

  group('3. Local Supabase Docker Integration & Sync Verification', () {
    late SupabaseClient client;
    const testBuildingId = '99999999-9999-9999-9999-999999999999';

    setUpAll(() async {
      await EnvironmentConfig.setEnvironment(AppEnvironment.local);
      SupabaseService.switchEnvironment();
      client = SupabaseClient(
        EnvironmentConfig.localUrl,
        EnvironmentConfig.localAnonKey,
      );
    });

    test('Can query seeded buildings from local Docker Supabase', () async {
      final response = await client
          .from('buildings')
          .select()
          .order('name', ascending: true);
      
      final list = response as List;
      expect(list.isNotEmpty, isTrue, reason: 'Local Supabase should contain seeded buildings');
      
      final names = list.map((b) => b['name'] as String).toList();
      expect(names.any((n) => n.contains('Santa Fe') || n.contains('Torres')), isTrue);
    });

    test('Can insert a new test building into local Supabase via upsert (simulating sync queue)', () async {
      final newBuilding = Building(
        id: testBuildingId,
        name: 'Edificio Automatizado E2E',
        address: 'Avenida 68 # 80-10',
      );

      final supabaseService = SupabaseService();
      await supabaseService.executeSyncAction(
        table: 'buildings',
        action: 'upsert',
        data: newBuilding.toMap(),
      );

      // Verificar que realmente se persistió en PostgreSQL local
      final fetched = await client
          .from('buildings')
          .select()
          .eq('id', testBuildingId)
          .maybeSingle();

      expect(fetched, isNotNull);
      expect(fetched!['name'], equals('Edificio Automatizado E2E'));
      expect(fetched['address'], equals('Avenida 68 # 80-10'));
    });

    test('Can update the test building in local Supabase via update action', () async {
      final supabaseService = SupabaseService();
      await supabaseService.executeSyncAction(
        table: 'buildings',
        action: 'update',
        data: {
          'id': testBuildingId,
          'name': 'Edificio Automatizado E2E (Modificado)',
          'address': 'Avenida 68 # 80-10 Bis',
        },
      );

      final fetched = await client
          .from('buildings')
          .select()
          .eq('id', testBuildingId)
          .maybeSingle();

      expect(fetched, isNotNull);
      expect(fetched!['name'], equals('Edificio Automatizado E2E (Modificado)'));
      expect(fetched['address'], equals('Avenida 68 # 80-10 Bis'));
    });

    test('Can delete the test building from local Supabase via delete action (clean up)', () async {
      final supabaseService = SupabaseService();
      await supabaseService.executeSyncAction(
        table: 'buildings',
        action: 'delete',
        data: {'id': testBuildingId},
      );

      final fetched = await client
          .from('buildings')
          .select()
          .eq('id', testBuildingId)
          .maybeSingle();

      expect(fetched, isNull, reason: 'Record must be deleted from local PostgreSQL');
    });
  });
}
