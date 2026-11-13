# Interfaz del módulo sintáctico

> **Estado: PROPUESTA (12/11/2026). Pendiente de aprobación del grupo.**
> Generadores y base de datos: si necesitan otro campo en el
> árbol o la base de datos guarda algo distinto, díganlo antes de que sus
> módulos dependan de esto.

## Cómo se usa

```dart
import 'package:cli/lexico.dart';
import 'package:cli/sintactico.dart';

final parser = AnalizadorSintactico.desde(FuenteLexicoJson()); // datos/espanol
final lexico = FaseLexica(parser.vocabulario);                 // vocabulario para el corrector

final tokens = lexico.procesar('¿Cuándo vendrán ustedes?').tokens;
final r = parser.analizar(tokens, conTraza: true);

r.arbol;          // Oracion? -> lo que consumen los generadores
r.error;          // ErrorSintactico? con explicación y columna
r.advertencias;   // decisiones tomadas (sujeto deducido, verbo ambiguo...)
r.traza;          // reglas de la BNF por las que pasó (modo traza)
r.arbol!.toMap(); // para guardar en el historial
r.arbol!.dibujar();
```

## El árbol (`lib/sintactico/arbol.dart`)

El árbol **no tiene palabras del español**: tiene conceptos (`VENIR`, `NAVE`)
y rasgos (persona, número, tiempo). El generador busca cada concepto en la
base de datos para sacar la palabra Kethari u Ozh.

### `Oracion` (la raíz)

| Campo | Tipo | Ejemplo | Para qué le sirve al generador |
|---|---|---|---|
| `modo` | `Modo` | `afirmacion`, `preguntaSiNo`, `preguntaAbierta` | Kethari: partícula `ka`. Ozh: prefijo `ʔa-` |
| `interrogativo` | `String?` | `CUANDO`, `QUIEN`, `QUE`, `DONDE`, `CUANTOS` | Kethari: va al principio. Ozh: al final |
| `rolInterrogativo` | `RolInterrogativo?` | `tiempo`, `lugar`, `sujeto`, `objeto`, `cantidad` | Qué hueco ocupa la palabra interrogativa |
| `negada` | `bool` | | Kethari: `nu-`. Ozh: `ne` |
| `tiempo` | `Tiempo` | `presente`, `pasado`, `futuro` | Kethari: `-ok` / `-ime`. Ozh: `ʔoka` / `venu` |
| `verbo` | `String` | `VENIR` | Concepto del verbo |
| `sujeto` | `Participante` | | **Siempre existe** (Kethari y Ozh exigen sujeto) |
| `objeto` | `Participante?` | | |

### `Participante` (sujeto u objeto): una de tres clases

| Clase | Campos | Ejemplo en español |
|---|---|---|
| `Pronominal` | `persona` (primera/segunda/tercera), `numero` (singular/plural), `inferido` | "ustedes" → segunda plural. `inferido: true` si el español lo omitió |
| `Nominal` | `concepto`, `numero`, `cantidad?`, `poseedor?`, `preguntaCantidad` | "quince naves" → `NAVE`, plural, 15 |
| `Incognita` | `concepto` | "¿**Quién** envió...?" → sujeto = `Incognita(QUIEN)` |

`Poseedor` tiene `persona` y `numero`: "nuestro planeta" → primera plural.

**Ojo con la persona:** es la del significado, no la de la conjugación.
"ustedes" es **segunda** plural aunque el verbo vaya en tercera ("ustedes
llegan"). Así el generador elige `ulesh` / `shavi` sin pensar en el español.

## Ejemplos

**"¿Cuándo vendrán ustedes?"** (señal del día 5)

```json
{
  "modo": "preguntaAbierta", "interrogativo": "CUANDO", "rolInterrogativo": "tiempo",
  "negada": false, "tiempo": "futuro", "verbo": "VENIR",
  "sujeto": { "clase": "pronominal", "persona": "segunda", "numero": "plural" }
}
```
Kethari esperado: `kom ulesh vinime ka`

**"Queremos paz"**

```json
{
  "modo": "afirmacion", "negada": false, "tiempo": "presente", "verbo": "QUERER",
  "sujeto": { "clase": "pronominal", "persona": "primera", "numero": "plural", "inferido": true },
  "objeto": { "clase": "nominal", "concepto": "PAZ", "numero": "singular" }
}
```
Kethari esperado: `anir parn thal` (o `anul`, ver abajo)

**"¿Ustedes no vieron nuestro planeta?"**

```json
{
  "modo": "preguntaSiNo", "negada": true, "tiempo": "pasado", "verbo": "VER",
  "sujeto": { "clase": "pronominal", "persona": "segunda", "numero": "plural" },
  "objeto": { "clase": "nominal", "concepto": "PLANETA", "numero": "singular",
              "poseedor": { "persona": "primera", "numero": "plural" } }
}
```
Kethari esperado: `ulesh anir vael nukorok ka`

**"¿Quién envió el mensaje?"** (señal del día 6)

```json
{
  "modo": "preguntaAbierta", "interrogativo": "QUIEN", "rolInterrogativo": "sujeto",
  "negada": false, "tiempo": "pasado", "verbo": "ENVIAR",
  "sujeto": { "clase": "incognita", "concepto": "QUIEN" },
  "objeto": { "clase": "nominal", "concepto": "MENSAJE", "numero": "singular" }
}
```
Kethari esperado: `sem ombra salok ka`

## Conceptos que usa el parser

Salen de `datos/espanol/` y deben existir también en el léxico Kethari/Ozh de
la base de datos:

- **Verbos:** `VENIR` (venir, llegar), `ENVIAR`, `VER`, `QUERER`, `SER` (ser,
  estar), `HABLAR`, `ESCUCHAR`, `ESPERAR`, `VISITAR`.
- **Sustantivos:** `PLANETA` (planeta, mundo), `ESTRELLA`, `TIERRA`, `AGUA`,
  `NAVE`, `MENSAJE`, `PAZ`, `CICLO`, `ANIO`, `LUZ`, `CRIATURA`, `HOGAR`.
- **Interrogativos:** `QUE`, `QUIEN`, `CUANDO`, `DONDE`, `CUANTOS`.

## Preguntas abiertas para el generador (Heili)

1. **`anul` / `anir`.** El español no distingue si "nosotros" incluye a quien
   escucha, así que el árbol no lo dice: llega `Pronominal(primera, plural)`.
   Cuando la Tierra habla con los alienígenas, "nosotros" no los incluye, y
   eso apunta a `anir`. Es una decisión del generador.
2. **Partícula de Ozh en preguntas** (`zi` / `mar` / `tho`): el árbol no la
   decide. Las dos preguntas registradas usan `mar`.
3. **Kethari en base 6:** `cantidad` llega en base 10 (15); la conversión a
   `ra-sel` es del generador.

## Para la base de datos

- Hoy el vocabulario español y las reglas de morfología se leen de
  `datos/espanol/*.json` con `FuenteLexicoJson`. Cuando exista la BD, basta
  con una clase nueva que implemente `FuenteLexicoEspanol` (tres métodos:
  `palabras()`, `verbos()`, `reglas()`) leyendo de SQLite. El parser no cambia.
- Los JSON sirven como datos iniciales para el script que crea la BD.

## Para el módulo léxico

Respuesta a la pregunta de `interfaces-lexico.md` sobre las formas verbales:
**la morfología las genera** a partir de las reglas, y
`AnalizadorSintactico.vocabulario` entrega palabras + formas conjugadas (236
hoy) para construir `FaseLexica`. No hay que guardar cada conjugación en la
BD (bitácora S-06).
