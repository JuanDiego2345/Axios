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

  test('el archivo de señales tiene las 15 señales del manual', () {
    final lineas = File('datos/senales_inicial.csv')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();

    expect(lineas.first, 'dia,voz,transcripcion,salida');
    expect(lineas.length - 1, 15);
  });
}