import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_manager.dart';
import '../config/environment_config.dart';

class ConnectionStatusBadge extends ConsumerWidget {
  const ConnectionStatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    final isLocal = EnvironmentConfig.isLocal;

    Color badgeColor;
    IconData icon;
    String label;

    if (syncState.isSyncing) {
      badgeColor = const Color(0xFF38BDF8); // Azul celeste
      icon = Icons.sync_rounded;
      label = 'Sincronizando...';
    } else if (syncState.connectionState == SyncConnectionState.offline) {
      badgeColor = const Color(0xFFEF4444); // Rojo
      icon = Icons.cloud_off_rounded;
      label = syncState.pendingCount > 0
          ? '${syncState.pendingCount} pendientes'
          : 'Sin conexión';
    } else if (syncState.serverUnreachable) {
      // Hay red en el dispositivo pero el servidor no responde (p. ej. el
      // proyecto de Supabase está pausado o inaccesible).
      badgeColor = const Color(0xFFEF4444); // Rojo
      icon = Icons.cloud_off_rounded;
      label = syncState.pendingCount > 0
          ? 'Servidor no responde (${syncState.pendingCount})'
          : 'Servidor no responde';
    } else {
      // Online
      if (isLocal) {
        badgeColor = const Color(0xFFF59E0B); // Ámbar para local
        icon = Icons.dns_rounded;
        label = syncState.pendingCount > 0
            ? 'Local (${syncState.pendingCount})'
            : 'Local (Dev)';
      } else {
        badgeColor = const Color(0xFF10B981); // Verde esmeralda para prod
        icon = Icons.cloud_done_rounded;
        label = syncState.pendingCount > 0
            ? '${syncState.pendingCount} por subir'
            : 'En línea';
      }
    }

    return InkWell(
      onTap: () {
        ref.read(syncProvider.notifier).syncAll();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              syncState.serverUnreachable
                  ? 'No se puede contactar al servidor. Tus cambios están a salvo en este dispositivo y se subirán cuando vuelva.'
                  : syncState.pendingCount > 0
                  ? 'Sincronizando ${syncState.pendingCount} operaciones pendientes...'
                      '${syncState.lastError != null ? '\nÚltimo error: ${syncState.lastError}' : ''}'
                  : 'Todo está sincronizado con la nube.',
            ),
            duration: Duration(seconds: syncState.lastError != null ? 8 : 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (syncState.isSyncing)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                ),
              )
            else
              Icon(icon, size: 13, color: badgeColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: badgeColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
