# Interfaz gráfica (bonus, criterio 25)

## Cómo se abre

```
cd cli
dart run bin/gui.dart
```

Se abre el navegador en `http://127.0.0.1:8080`. Opciones: `--puerto 8081`
(si el 8080 está ocupado) y `--no-abrir`. Se cierra con Ctrl+C.

La BD es la misma del CLI (`datos/axios.db`). Si está vacía, primero carga
`lexico_inicial.csv` desde la pestaña **Cargar**.

## Qué tiene

| Pestaña | Orden del CLI | Qué muestra |
|---|---|---|
| Traducir | `traducir "<pregunta>"` | Kethari y Ozh lado a lado, correcciones, decisiones del parser y, si no hay traducción, por qué. |
| Cargar | `cargar <archivo>` | Sube un archivo de señales, correcciones o léxico. Las traducciones lo usan enseguida (K-11). |
| Historial | `historial [desde <fecha>]` | Preguntas registradas con sus traducciones y validación. |
| Palabra | `palabra <término>` | La palabra en las tres lenguas (versión vigente). |

## Cómo está hecha

- `bin/gui.dart`: arranca el servidor y abre el navegador.
- `lib/gui/servidor_axios.dart`: servidor con `HttpServer` de `dart:io`
  (biblioteca estándar, sin librerías nuevas).
- `lib/gui/api_axios.dart`: convierte las cuatro órdenes de `AxiosCli` a JSON.
  **No tiene lógica de traducción propia**: la interfaz y el CLI dan siempre
  el mismo resultado.
- `web/index.html`: la página (HTML, CSS y JavaScript sin librerías).

## Restricciones del enunciado

- **Sin conexión:** el servidor solo escucha en 127.0.0.1 (el propio
  computador). No usa internet ni servicios en red.
- **Sin librerías prohibidas:** solo `dart:io` y `dart:convert`.
- **Ninguna pregunta se pierde:** cada traducción pasa por `AxiosCli.traducir`,
  que la registra en la BD; si algo falla, la interfaz muestra la explicación.

Pruebas: `test/gui/servidor_test.dart`.
