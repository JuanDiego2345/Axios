# Interfaz del módulo de generadores

> **Estado: generador de Kethari para oraciones simples (semana 1).**
> Pendiente: cantidades en base 6, generador de Ozh y validador (semana 2).

## Cómo se usa

```dart
import 'package:cli/generadores.dart';

final kethari = GeneradorKethari(FuenteKethariJson()); // datos/kethari
final r = kethari.generar(arbol);                      // arbol: Oracion del parser

r.ok;     // true si hay traducción
r.texto;  // "kom ulesh vinime ka"
r.error;  // por qué no hay traducción (palabra desconocida, cantidad...)
r.traza;  // cada decisión, para el modo traza
```

## Datos

- `cli/datos/kethari/lexico.json`: palabras por **concepto** del árbol
  (`NAVE` → `kum`) y pronombres por código (`2p` → `ulesh`).
- `cli/datos/kethari/gramatica.json`: afijos (`-ok`, `-ime`, `nu-`, `-esh`)
  y la partícula `ka`.

## Para la base de datos (integrante 4)

El generador pide las palabras por **concepto** (`VENIR`, `PLANETA`,
`CUANDO`) y los pronombres por persona y número. Para leerlas de SQLite
basta una clase que implemente `FuenteKethari` (`pronombre`, `sustantivo`,
`verbo`, `interrogativo`, `afijos`). Los JSON sirven como datos iniciales.

## Decisiones

Ver `docs/bitacora-generadores.md` (K-01 a K-06).
