import 'dart:io';
import 'package:test/test.dart';
import '../../lib/bd/conexion.dart';
import '../../lib/bd/lexico_repo.dart';

void main() {
  test('el léxico del manual carga y conserva ʔ y ü', () {
    final db = abrirBd(':memory:');
    final repo = LexicoRepo(db);

    expect(repo.cargarLexico('datos/lexico_inicial.csv'), 49);

    expect(repo.buscar('agua')?.kethari, 'dahl');
    expect(repo.buscar('agua')?.ozh, 'naʔ');
    expect(repo.buscar('planeta')?.ozh, 'thüm');
    expect(repo.buscar('año')?.kethari, 'sorlun');
    expect(repo.buscar('casa'), isNull); // ya no hay palabras inventadas

    db.close();
  });

  test('las 15 señales del manual se cargan en la BD', () {
    final db = abrirBd(':memory:');
    final repo = LexicoRepo(db);

    expect(repo.cargarSenales('datos/senales_inicial.csv'), 15);
    expect(repo.cargarSenales('datos/senales_inicial.csv'), 0);

    final s = repo.listarSenales();
    expect(s.length, 15);
    expect(s.any((x) => x['voz'] == 'Desconocida' && x['dia'] == 6), isTrue);

    db.close();
  });
}