# P-18b — restauración del respaldo (Tabla 87; RNF-05)

`herramientas/medir_restauracion.sh` levanta la base del prototipo (MySQL 8.4.11 de
`docker-compose.yml`) en un proyecto aparte, la respalda con `herramientas/respaldo.sh`,
simula su pérdida (borra el contenedor y el volumen) y mide desde ahí hasta tener la base
restaurada y verificada (mismas tablas, filas y `CHECKSUM TABLE`, y la fila marcadora).

| Ejecución (4/11/2026) | Datos | Respaldo (gzip) | Restauración total | Resultado |
|---|---|---|---|---|
| `restauracion_20261104T153140Z.md` | datos de ejemplo (ficticios) | 8.0 KiB | 17.3 s | Aprobado (≤ 2 h, datos iguales) |
| `restauracion_20261104T153229Z.md` | datos de ejemplo + 500 000 filas sintéticas de bitácora | 4.1 MiB | 25.3 s | Aprobado |

Entorno: contenedor Linux con 4 CPU lógicas, Docker 29.9.2. Con datos reales, la medición
debe repetirse en el servidor local de la empresa con el respaldo del día.
