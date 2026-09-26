import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/tenant_provider.dart';
import '../providers/building_stats_provider.dart';
import '../providers/repository_provider.dart';
import 'unit_detail_screen.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/status_badge.dart';

class TenantListScreen extends ConsumerStatefulWidget {
  const TenantListScreen({super.key});

  @override
  ConsumerState<TenantListScreen> createState() => _TenantListScreenState();
}

class _TenantListScreenState extends ConsumerState<TenantListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final tenantsAsync = ref.watch(activeTenantsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = ResponsiveLayout.isDesktop(context);

    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    final content = tenantsAsync.when(
      data: (tenants) {
        if (tenants.isEmpty) {
          return const EmptyStateView(
            icon: Icons.people_outline_rounded,
            title: 'No hay inquilinos activos',
            description:
                'Cuando agregues contratos a tus apartamentos u oficinas, verás el directorio de inquilinos aquí.',
          );
        }

        final filtered = tenants.where((t) {
          final query = _searchQuery.toLowerCase();
          final matches = t.name.toLowerCase().contains(query) ||
              t.phone.toLowerCase().contains(query) ||
              t.buildingName.toLowerCase().contains(query) ||
              t.unitNumber.toLowerCase().contains(query);
          return matches;
        }).toList();

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 36 : 20,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado y Buscador
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Directorio de Inquilinos',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.4,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${tenants.length} inquilinos con contrato activo',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isDesktop)
                    SizedBox(
                      width: 280,
                      height: 44,
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre, tel, apto...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                          fillColor: isDark ? const Color(0xFF181A1F) : Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              if (!isDesktop) ...[
                const SizedBox(height: 14),
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Buscar inquilino...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    fillColor: isDark ? const Color(0xFF181A1F) : Colors.white,
                  ),
                ),
              ],
              const SizedBox(height: 20),

              if (filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No hay inquilinos que coincidan con "$_searchQuery"',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              else if (isDesktop)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 520,
                    mainAxisExtent: 155,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _TenantCard(
                      tenant: filtered[index],
                      currencyFormat: currencyFormat,
                    );
                  },
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _TenantCard(
                      tenant: filtered[index],
                      currencyFormat: currencyFormat,
                    );
                  },
                ),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 50),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, s) => Center(
        child: Text('Error al cargar inquilinos: $e'),
      ),
    );

    return ResponsiveLayout(
      title: 'Inquilinos',
      selectedIndex: 1,
      actions: [
        IconButton(
          tooltip: 'Recargar',
          onPressed: () => ref.invalidate(activeTenantsProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      mobileBody: content,
    );
  }
}

class _TenantCard extends ConsumerWidget {
  final TenantInfo tenant;
  final NumberFormat currencyFormat;

  const _TenantCard({
    required this.tenant,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final repository = ref.read(appRepositoryProvider);
          final unit = await repository.getUnitById(tenant.unitId);
          if (unit != null && context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UnitDetailScreen(unit: unit),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        hoverColor: theme.colorScheme.primary.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.1),
                child: Text(
                  tenant.name.isNotEmpty ? tenant.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tenant.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.apartment_rounded,
                          size: 13,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${tenant.buildingName} • ${tenant.unitNumber}',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              fontSize: 12.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          tenant.phone.isNotEmpty ? tenant.phone : 'Sin teléfono',
                          style: TextStyle(
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                        if (tenant.phone.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: () => _launchWhatsApp(tenant.phone),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF25D366).withValues(alpha: 0.25),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 11,
                                    color: Color(0xFF25D366),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'WhatsApp',
                                    style: TextStyle(
                                      color: Color(0xFF25D366),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ref.watch(unitDebtProvider(tenant.unitId)).when(
                    data: (debt) {
                      if (debt > 0.1) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const StatusBadge(status: 'En Mora'),
                            const SizedBox(height: 4),
                            Text(
                              currencyFormat.format(debt),
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      }
                      return const StatusBadge(status: 'Al Día');
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final formattedPhone = cleanPhone.length == 10 ? '57$cleanPhone' : cleanPhone;
    final url = Uri.parse('whatsapp://send?phone=$formattedPhone');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
    } else {
      final webUrl = Uri.parse('https://wa.me/$formattedPhone');
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }
}
