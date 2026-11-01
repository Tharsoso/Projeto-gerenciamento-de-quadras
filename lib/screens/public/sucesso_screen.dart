import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_theme.dart';
import '../../formatos.dart';
import '../../publico/reservas_repositorio.dart';
import '../widgets/ticket_reserva.dart';

/// Confirmação da reserva (4.2). O comprovante pelo WhatsApp entra na 4.4.
class SucessoScreen extends StatelessWidget {
  const SucessoScreen({super.key, required this.reserva});

  final ReservaConfirmada reserva;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'RESERVA CONFIRMADA',
          style: AppTheme.display(
            size: 20,
            color: AppColors.ink,
            letterSpacing: 1.5,
            height: 1,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 18),
                Center(
                  child: Container(
                    width: 124,
                    height: 124,
                    decoration: const BoxDecoration(
                      color: AppColors.ball,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, size: 76, color: AppColors.greenDark),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'TÁ',
                  textAlign: TextAlign.center,
                  style: AppTheme.display(size: 72, color: AppColors.ink),
                ),
                Text(
                  'confirmado!',
                  textAlign: TextAlign.center,
                  style: AppTheme.serif(size: 52, color: AppColors.green),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Guarde o código da reserva. Chegue 10 minutos antes do horário.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surf,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'CÓDIGO ${reserva.codigo}',
                      key: const Key('sucesso-codigo'),
                      style: AppTheme.mono(
                        size: 13,
                        weight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                TicketReserva(
                  quadra: reserva.quadra,
                  hora: reserva.hora,
                  data: reserva.data,
                  valor: reserva.valor,
                  extras: [
                    ('CLIENTE', reserva.nome),
                    ('TELEFONE', mascararTelefone(reserva.telefone)),
                  ],
                ),
                const SizedBox(height: 22),
                OutlinedButton(
                  key: const Key('sucesso-voltar'),
                  onPressed: () => context.go('/'),
                  child: const Text('Ver outros horários'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
