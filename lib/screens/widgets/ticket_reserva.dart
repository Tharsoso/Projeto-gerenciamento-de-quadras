import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../formatos.dart';

/// Ingresso verde da reserva: hora em destaque à esquerda, dados à direita.
class TicketReserva extends StatelessWidget {
  const TicketReserva({
    super.key,
    required this.quadra,
    required this.hora,
    required this.data,
    required this.valor,
    this.extras = const [],
  });

  final String quadra;
  final String hora;
  final DateTime data;
  final double? valor;

  /// Linhas além de data e duração, como (rótulo, valor).
  final List<(String, String)> extras;

  @override
  Widget build(BuildContext context) {
    const dias = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.greenDark,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.greenDark.withValues(alpha: 0.3),
            offset: const Offset(0, 18),
            blurRadius: 40,
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 16, 22),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.white.withValues(alpha: 0.28), width: 2),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HORA',
                    style: AppTheme.mono(
                      size: 10,
                      color: Colors.white.withValues(alpha: 0.65),
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hora,
                    style: AppTheme.display(size: 56, color: AppColors.ball, height: 0.82),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      quadra.toUpperCase(),
                      style: AppTheme.display(
                        size: 32,
                        color: Colors.white,
                        letterSpacing: 1,
                        height: 0.9,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _linha('DATA', '${dias[data.weekday % 7]} · ${formatarData(data)}'),
                    const SizedBox(height: 8),
                    _linha('DURAÇÃO', '1 hora'),
                    for (final (rotulo, texto) in extras) ...[
                      const SizedBox(height: 8),
                      _linha(rotulo, texto),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'VALOR',
                          style: AppTheme.mono(
                            size: 10,
                            color: Colors.white.withValues(alpha: 0.65),
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              valor != null ? formatarReal(valor!) : '—',
                              style: AppTheme.display(
                                size: 30,
                                color: AppColors.ball,
                                letterSpacing: 0.5,
                                height: 0.9,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linha(String rotulo, String texto) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              rotulo,
              style: AppTheme.mono(
                size: 10,
                color: Colors.white.withValues(alpha: 0.65),
                letterSpacing: 1.6,
              ),
            ),
          ),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      );
}
