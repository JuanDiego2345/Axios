# Bitácora de decisiones — Generadores (integrante 3)

Formato: problema, opciones, decisión y prueba que la demuestra.
Pruebas en `cli/test/generadores/generador_kethari_test.dart`.

### K-01 · 17/11/2026 · "nosotros": `anul` o `anir`
- **Problema:** el manual da `anul` y `anir` para "nosotros" y la nota 3.5 dice que no son sinónimos. El árbol solo trae `Pronominal(primera, plural)` porque el español no los distingue.
- **Opciones:** (a) `anul` siempre; (b) `anir` siempre; (c) no traducir "nosotros".
- **Evidencia en las señales:** `anir` aparece en el día 1 (enviamos mensajes) y el día 4 (no los vimos *a ustedes*); `anul` en el día 2 (queremos paz) y el día 7 (esperaremos). En el día 4 "nosotros" excluye a los oyentes. La hipótesis más usada en lenguas reales es exclusivo/inclusivo, pero el día 2 no la confirma ni la descarta.
- **Decisión:** (b) `anir`. Quien habla es la Tierra y se dirige a los alienígenas, así que "nosotros" no incluye al oyente, como en el día 4. Está en `datos/kethari/lexico.json` → `pronombres.1p`, no en el código: si lingüística decide otra cosa, se cambia el dato.
- **Prueba:** "día 2: Queremos paz -> anir parn thal" y "día 4: anir ulesh nukorok".

### K-02 · 17/11/2026 · Interrogativo que ocupa el sujeto u objeto
- **Problema:** en "¿Quién envió el mensaje?" el árbol trae `interrogativo: QUIEN` y además `sujeto: Incognita(QUIEN)`. Si se generan los dos, sale `sem sem ombra salok ka`.
- **Opciones:** (a) poner la palabra en su hueco (sujeto/objeto) y no al principio; (b) ponerla al principio y saltar la incógnita.
- **Decisión:** (b). El manual dice que va al principio, y la señal del día 6 (`sem ombra salok ka`) la muestra una sola vez. Para el sujeto (a) y (b) coinciden; para el objeto, (b) da `kel ulesh thal ka`.
- **Prueba:** "día 6: sem ombra salok ka" y "qué es el objeto: kel ulesh thal ka".

### K-03 · 17/11/2026 · "¿Cuántas naves llegaron?"
- **Problema:** el manual no muestra preguntas de cantidad.
- **Opciones:** (a) `kai` al principio y el sustantivo en su lugar; (b) `kai` delante del sustantivo, como un número.
- **Decisión:** (a), porque aplica la regla general de las preguntas ("la palabra interrogativa va al principio") sin inventar otra. El sustantivo va en plural (`kumesh`) porque el árbol lo marca plural. Se revisa si llega una señal con `kai`.
- **Prueba:** "cuántos: kai kumesh vinok ka".

### K-04 · 17/11/2026 · Léxico y afijos fuera del código
- **Problema:** el enunciado prohíbe el léxico y las reglas en el código, y la base de datos todavía no guarda el léxico por concepto (`VENIR`, `NAVE`), que es lo que entrega el árbol.
- **Opciones:** (a) esperar a la BD; (b) escribir las palabras en el generador; (c) archivos de datos detrás de una interfaz, como hizo el parser (S-10).
- **Decisión:** (c). `FuenteKethari` dice qué necesita el generador y `FuenteKethariJson` lo lee de `datos/kethari/` (`lexico.json` y `gramatica.json` con `-ok`, `-ime`, `nu-`, `-esh`, `ka`). Cuando la BD tenga el léxico, se implementa la misma interfaz con SQLite y el generador no cambia. (b) está prohibido.
- **Prueba:** todas las pruebas usan `FuenteKethariJson()` con los datos reales.

### K-05 · 17/11/2026 · Cantidades (pendiente, semana 2)
- **Problema:** Kethari no tiene palabras de 6 a 9 (nota 3.5) y las señales muestran base 6: `ra-sel` = 15 (2·6 + 3), `ti-vo` = 6.
- **Decisión provisional:** en la semana 1 el generador no traduce oraciones con cantidad y lo explica, en vez de producir algo incorrecto. La conversión a base 6 entra en la semana 2 junto con los números de Ozh.
- **Prueba:** "cantidades todavía no se generan".

### K-06 · 17/11/2026 · Palabra sin traducción
- **Problema:** el árbol puede traer un concepto sin palabra Kethari conocida.
- **Decisión:** no se genera nada y el error dice qué concepto falta ("No se inventan palabras"). Se listan todos los que falten, no solo el primero.
- **Prueba:** "verbo sin palabra Kethari: no traduce y lo explica".
