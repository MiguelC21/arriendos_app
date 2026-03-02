import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tenant_provider.dart';
import 'unit_detail_screen.dart';
import '../services/database_helper.dart';
import '../models/unit.dart';

class TenantListScreen extends ConsumerWidget {
  const TenantListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(activeTenantsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Inquilinos'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(activeTenantsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: tenantsAsync.when(
        data: (tenants) {
          if (tenants.isEmpty) {
            return const Center(
              child: Text(
                'No hay inquilinos con contrato activo.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: tenants.length,
            itemBuilder: (context, index) {
              final tenant = tenants[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      tenant.name[0].toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  title: Text(
                    tenant.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        '🏢 ${tenant.buildingName} - Apartamento ${tenant.unitNumber}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '📞 ${tenant.phone}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white24,
                  ),
                  onTap: () async {
                    // Obtener el objeto Unit real para ir al detalle
                    final dbHelper = DatabaseHelper();
                    final db = await dbHelper.database;
                    final List<Map<String, dynamic>> maps = await db.query(
                      'units',
                      where: 'id = ?',
                      whereArgs: [tenant.unitId],
                      limit: 1,
                    );
                    if (maps.isNotEmpty && context.mounted) {
                      final unit = Unit.fromMap(maps.first);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UnitDetailScreen(unit: unit),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
