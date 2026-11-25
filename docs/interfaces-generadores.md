# Interfaz del módulo de generadores

> **Estado: generador de Kethari con cantidades en base 6 (19/11/2026).**
> Pendiente: generador de Ozh y validador (semana 2).

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
- `cli/datos/kethari/lexico.json` → `cifras`: `0` → `vo` … `5` → `pai`.
- `cli/datos/kethari/gramatica.json`: afijos (`-ok`, `-ime`, `nu-`, `-esh`),
  la partícula `ka` y las reglas de cantidades (`base: 6`, `separador: "-"`).

## Cantidades

`lib/generadores/numeros.dart` escribe una cantidad en cualquier base:
`escribirNumero(15, reglas, cifra)` → `ra-sel` en Kethari. Ozh usará la misma
función con `base: 10` (15 → `ois-ulo`).

## Léxico desde la base de datos (K-11)

```dart
final db = abrirBd('datos/axios.db');
final espanol = FuenteLexicoJson('datos/espanol');   // la misma del parser
final kethari = GeneradorKethari(FuenteKethariBd(db, espanol));
final ozh = GeneradorOzh(FuenteOzhBd(db, espanol));

// "qué se habría transmitido" en una fecha:
GeneradorKethari(FuenteKethariBd(db, espanol, fecha: '2026-11-20'));
```

Cada búsqueda lee la BD en ese momento: lo que entra con `cargar` se usa en
la traducción siguiente. Las reglas siguen en `datos/<lengua>/gramatica.json`.

**Para el CLI (`lib/cli.dart`, `AxiosCli.crear`):** cambiar

```dart
final generadorKethari = GeneradorKethari(FuenteKethariJson('$datos/kethari'));
final generadorOzh = GeneradorOzh(FuenteOzhJson('$datos/ozh'));
```
por
```dart
final generadorKethari = GeneradorKethari(
    FuenteKethariBd(db, fuenteEspanol, carpeta: '$datos/kethari'));
final generadorOzh =
    GeneradorOzh(FuenteOzhBd(db, fuenteEspanol, carpeta: '$datos/ozh'));
```
La BD debe tener cargado `datos/lexico_inicial.csv` antes de traducir.

## Para la base de datos (integrante 4)

El generador pide las palabras por **concepto** (`VENIR`, `PLANETA`,
`CUANDO`) y los pronombres por persona y número. Para leerlas de SQLite
basta una clase que implemente `FuenteKethari` (`pronombre`, `sustantivo`,
`verbo`, `interrogativo`, `cifra`, `afijos`, `numeros`). Los JSON sirven como datos iniciales.

## Decisiones

Ver `docs/bitacora-generadores.md` (K-01 a K-11).
