# P-17 — núcleo Dart con 112 servicios (Tabla 87; RNF-02 y RNF-07)

Medición del 4/11/2026 con `paquetes/dominio/tool/p17.dart` y `herramientas/cobertura.sh`
(Dart 3.13.5, contenedor Linux con 4 CPU lógicas Intel Xeon a 2.10 GHz). La integración
continua repite ambas mediciones en cada cambio (trabajo «Núcleo (paquetes/dominio)»,
artefacto `cobertura-dominio`).

| Criterio | Esperado | Observado | Resultado |
|---|---|---|---|
| Tiempo por ejecución del AG oficial (n = 112, instancia 101, semillas 1 a 10) | ≤ 300 s | media 0.351 s (DE 0.043 s); máximo 0.449 s | Aprobado |
| Programaciones factibles según el validador | — | 10 de 10 (Φ = 0) | — |
| Cobertura de líneas del núcleo (`lib/src/optimizacion`) | ≥ 80 % | 97.9 % (695 de 710 líneas) | Aprobado |

Archivos: `p17_tiempos.csv` (una fila por semilla), `p17_resumen.txt` y `cobertura.txt`.
Los tiempos son del entorno de pruebas, no del servidor local de la empresa (mini PC), donde
debe repetirse antes de la compra (sección 7 de la tesis). La cobertura total del paquete
`dominio` es 79.0 %; RNF-07 se refiere al núcleo de optimización.
