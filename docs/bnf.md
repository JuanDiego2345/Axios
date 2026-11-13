# Gramática del español (BNF)

> **Versión 0.1 (12/11/2026).** Cubre lo de la semana 1: afirmaciones cortas,
> preguntas de sí o no y preguntas con qué, quién, cuándo, dónde y cuántos,
> en presente, pasado y futuro (incluido "ir a"), con negación, plurales,
> cantidades y posesivos. Se amplía en la semana 2.

El parser (`cli/lib/sintactico/analizador_sintactico.dart`) es descendente
recursivo: **cada regla de abajo es una función con el mismo nombre**
(`_entrada`, `_clausula`, `_interrogativo`, `_nucleo`, `_complemento`,
`_grupoVerbal`, `_sn`).

## Gramática

```bnf
<entrada>        ::= [ "¿" ] <clausula> [ "?" ] [ "." ] FIN

<clausula>       ::= <interrogativo> <nucleo>
                   | <nucleo>

<interrogativo>  ::= INTERROGATIVO_CANTIDAD [ SUSTANTIVO ]
                   | INTERROGATIVO

<nucleo>         ::= [ <sn> ] [ NEGACION ] <grupo-verbal> [ <complemento> [ <complemento> ] ]

<complemento>    ::= [ PREPOSICION ] <sn>

<grupo-verbal>   ::= AUXILIAR_FUTURO ENLACE_FUTURO INFINITIVO
                   | VERBO_CONJUGADO

<sn>             ::= PRONOMBRE
                   | [ <determinante> ] [ NUMERO ] SUSTANTIVO

<determinante>   ::= ARTICULO | POSESIVO
```

`[ x ]` significa que `x` es opcional.

## Terminales

Los tokens del léxico solo dicen si algo es una palabra, un
número o un signo. **La categoría de cada palabra la decide el parser
consultando el vocabulario** (`datos/espanol/`), nunca el código.

| Terminal | Qué es | Ejemplos | De dónde sale |
|---|---|---|---|
| `"¿"` `"?"` `"."` | signos | | token `abreInterrogacion`, `cierraInterrogacion`, `punto` |
| `FIN` | fin de la entrada | | token `fin` |
| `NUMERO` | cantidad en cifras o en letras | `15`, `dos mil` | token `numero` |
| `INTERROGATIVO` | palabra interrogativa | qué, quién, cuándo, dónde | `palabras.json` → `interrogativos` |
| `INTERROGATIVO_CANTIDAD` | interrogativo con rol `cantidad` | cuántos, cuántas | `palabras.json` → `interrogativos` |
| `NEGACION` | negación | no | `palabras.json` → `negaciones` |
| `PRONOMBRE` | pronombre personal | yo, usted, ustedes | `palabras.json` → `pronombres` |
| `ARTICULO` | artículo | el, las, una | `palabras.json` → `articulos` |
| `POSESIVO` | posesivo | su, nuestro | `palabras.json` → `posesivos` |
| `SUSTANTIVO` | sustantivo del manual | nave, planetas | `palabras.json` → `sustantivos` |
| `PREPOSICION` | preposición | a | `palabras.json` → `preposiciones` |
| `VERBO_CONJUGADO` | forma verbal con persona y tiempo | llegan, vieron | morfología (`verbos.json` + `morfologia.json`) |
| `INFINITIVO` | infinitivo | llegar | morfología |
| `AUXILIAR_FUTURO` | "ir" en presente | van, vamos | morfología, `perifrasisFuturo` |
| `ENLACE_FUTURO` | la "a" de "ir a" | a | `morfologia.json` → `perifrasisFuturo.enlace` |

Las comas no forman parte de la gramática: el parser las ignora.

## Reglas para palabras con dos categorías

Sin tildes, algunas palabras pertenecen a dos categorías. La gramática se
mantiene LL(1) mirando un token más:

- **"el" / "él"** y **"tu" / "tú"** son `ARTICULO`/`POSESIVO` y también
  `PRONOMBRE`. En `<sn>`, si el siguiente token es `SUSTANTIVO` o `NUMERO`, se
  leen como determinante ("tu planeta"); si no, como pronombre ("tú vienes").
- **"a"** después de `AUXILIAR_FUTURO` y antes de `INFINITIVO` es
  `ENLACE_FUTURO` ("van a llegar"); en cualquier otro lugar es `PREPOSICION`
  ("vieron a las criaturas").

## Después de la gramática: funciones de cada grupo

La gramática dice **qué grupos hay**; el paso siguiente decide **cuál es el
sujeto y cuál el objeto**, porque el español permite varios órdenes
("¿Ustedes quieren paz?", "¿Quieren paz ustedes?"). Las reglas, en orden:

1. Un pronombre es sujeto; si ya hay sujeto, es objeto.
2. Un sustantivo antes del verbo es sujeto ("las naves llegaron").
3. Un sustantivo con "a" delante es objeto ("vieron a las criaturas").
4. Un sustantivo después del verbo es objeto si el verbo es transitivo
   ("queremos paz") y sujeto si no lo es ("¿llegaron las naves?").
5. La palabra interrogativa ocupa el hueco que su rol indica: `quién` el
   sujeto, `qué` el objeto (o el sujeto si el verbo no es transitivo),
   `cuántos` el sujeto con verbos intransitivos y el objeto con transitivos.
   `cuándo` y `dónde` no ocupan ninguno.
6. Si no queda sujeto, se deduce de la persona del verbo con la tabla
   `sujetoOmitido` de `morfologia.json` (bitácora S-01).
7. El verbo se elige entre sus análisis posibles por concordancia con el
   sujeto; si hay empate de tiempo, decide `prioridadTiempos` (bitácora S-03).

## Ejemplos

| Entrada (ya normalizada) | Derivación resumida |
|---|---|
| `queremos paz` | `<nucleo>` = `<grupo-verbal>`(queremos) `<complemento>`(paz) |
| `¿cuando llegaran ustedes?` | `"¿"` `<interrogativo>`(cuando) `<nucleo>`(llegaran, ustedes) `"?"` |
| `¿ustedes no vieron nuestro planeta?` | `"¿"` `<nucleo>`(`<sn>` ustedes, no, vieron, `<sn>` nuestro planeta) `"?"` |
| `¿cuantas naves llegaron?` | `"¿"` `<interrogativo>`(cuantas naves) `<nucleo>`(llegaron) `"?"` |
| `van a llegar 15 naves` | `<grupo-verbal>`(van a llegar) `<complemento>`(15 naves) |

## Lo que todavía no cubre (semana 2)

- Dos verbos seguidos ("¿quieren visitar la tierra?").
- "de dónde", "en dónde" y otras preposiciones (bitácora S-07).
- Oraciones compuestas o con más de un objeto.
