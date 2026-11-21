import 'package:test/test.dart';
import '../../lib/bd/conexion.dart';
import '../../lib/bd/lexico_repo.dart';

void main() {
  test('registra una pregunta con su corrección y sus traducciones', () {
    final db = abrirBd(':memory:');
    final repo = LexicoRepo(db);

    repo.registrarPregunta(
      original: 'cuando vendran ustedes',
      corregido: '¿Cuándo vendrán ustedes?',
      kethari: 'kom ulesh vinime ka',
      ozh: 'ʔasur mar shavi wem',
      validacion: 'válida',
      fecha: '2026-11-18T10:00:00',
    );

    final h = repo.historialPreguntas();
    expect(h.length, 1);
    expect(h[0]['original'], 'cuando vendran ustedes');
    expect(h[0]['corregido'], '¿Cuándo vendrán ustedes?');
    expect(h[0]['ozh'], 'ʔasur mar shavi wem');
    expect(h[0]['validacion'], 'válida');

    db.close();
  });

  test('el historial se puede filtrar desde una fecha', () {
    final db = abrirBd(':memory:');
    final repo = LexicoRepo(db);

    repo.registrarPregunta(original: 'a', fecha: '2026-11-17T09:00:00');
    repo.registrarPregunta(original: 'b', fecha: '2026-11-18T09:00:00');
    repo.registrarPregunta(original: 'c', fecha: '2026-11-19T09:00:00');

    expect(repo.historialPreguntas().length, 3);
    expect(repo.historialPreguntas(desde: '2026-11-18').length, 2);
    expect(repo.historialPreguntas(desde: '2026-11-20').length, 0);

    db.close();
  });
}