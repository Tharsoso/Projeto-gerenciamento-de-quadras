import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/horario_slot.dart';

class QuadrasService {
  final SupabaseClient _client;
  QuadrasService(this._client);

  Future<List<HorarioSlot>> horariosDoDia(DateTime data) async {
    final iso = _dataIso(data);
    final res = await _client.rpc('horarios_do_dia', params: {'p_data': iso});
    final lista = (res as List).cast<Map<String, dynamic>>();
    return lista.map(HorarioSlot.fromMap).toList();
  }

  RealtimeChannel assinarOcupacoes(void Function() onChange) {
    final ch = _client.channel('public:ocupacoes');
    ch.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'ocupacoes',
      callback: (_) => onChange(),
    );
    ch.subscribe();
    return ch;
  }

  String _dataIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
