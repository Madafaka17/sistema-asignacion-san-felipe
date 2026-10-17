# Experimento comparativo con datos sintéticos del caso San Felipe

Compara los cuatro candidatos del capítulo III —programación lineal entera (PLE),
algoritmo voraz, búsqueda tabú y algoritmo genético (AG)— con instancias
sintéticas que representan turnos de operación desde el terminal de Soritor:
viajes redondos a Moyobamba y a Tarapoto, unidades que salen según su turno en la
cola, conductores fijos y reemplazos autorizados.

**Datos sintéticos.** Las instancias no son registros de la Empresa de Transportes
y Turismo San Felipe S.A.C. Los valores de referencia del caso (tiempos de ida de
30 y 150 min, 37 unidades por día, 44 conductores, 16 asientos) son declarados y
están pendientes de validación; los demás parámetros son supuestos del generador
(ver `PROTOCOLO.md`). Los identificadores US01… y CS01… son ficticios.

**No modifica el capítulo III.** Usa el mismo modelo (ecuaciones 1 a 8), las mismas
implementaciones de `experimentos/poc_cap3` (importadas sin copiarlas), las mismas
configuraciones (Tablas 18 y 20) y los mismos criterios, anclajes y pesos (Tablas 14
a 16). Solo cambia el generador de instancias.

**Código importado.** Los archivos de `core/` y `experimentos/poc_cap3/` con los que
se ejecutó este experimento (huellas en `registro_protocolo.txt`) no se conservaron.
El repositorio incluye una **reimplementación** del 17 de octubre de 2026, con otras
huellas, que reproduce la evaluación, el validador, los óptimos de n = 7, el voraz y
la F de la PLE registrados, pero no las ejecuciones de la búsqueda tabú y del AG
(ver [`../../core/README.md`](../../core/README.md)).

## Archivos

| Archivo | Contenido |
|---|---|
| `PROTOCOLO.md` | Protocolo fijado antes de ejecutar |
| `registro_protocolo.txt` | Fecha y huellas SHA-256 del protocolo y del código antes de ejecutar |
| `DESVIACIONES.md` | Lo hecho después del registro (análisis exploratorio de D, incidencias del entorno) |
| `generador_sanfelipe.py` | Generador de instancias sintéticas del caso (factibles por construcción) |
| `verificar_generador.py` | Verificación previa del generador (no ejecuta candidatos) |
| `exportar_datos.py`, `datos/` | Instancias en CSV: servicios, alternativas, unidades, conductores y resumen |
| `experimento.py` | Ejecución (`ejecutar v1|v2`) y análisis (`analizar v1|v2`) |
| `sensibilidad_D.py` | Análisis exploratorio con D sobre todos los conductores (v1D y v2D) |
| `resultados_crudos_*.csv` | Una fila por ejecución: método, tamaño, instancia, semilla, tiempo, F, Φ, validador e indicadores operativos |
| `soluciones_*.jsonl` | Cromosoma de cada ejecución |
| `optimos_n7_*.csv` | Óptimo certificado por enumeración exhaustiva en n = 7 |
| `resumen_*.json` | Criterios C1 a C5, puntajes, totales e indicadores por tamaño |
| `figura_rendimiento.py`, `figura_turno.py` | Figuras del informe |
| `reevaluar_cromosomas.py` | Suplementario (2026-10-17): reevalúa las 1 320 soluciones registradas y los óptimos de n = 7 |
| `incertidumbre_bootstrap.py`, `incertidumbre_brecha.csv` | Suplementario (2026-10-17): intervalos bootstrap de la brecha media (C1) y de la diferencia AG − PLE |
| `repetir_reimplementacion.py`, `reimplementacion/` | Suplementario (2026-10-17): repetición completa con la reimplementación, en una carpeta aparte |

## Reproducción

Desde esta carpeta, con las dependencias de `experimentos/poc_cap3/requirements.txt`.
**`experimento.py ejecutar` y `sensibilidad_D.py ejecutar` sobrescriben los
resultados registrados**; para repetir el experimento con la reimplementación sin
tocarlos, use `repetir_reimplementacion.py`:

```bash
python3 reevaluar_cromosomas.py                  # las 1 320 soluciones registradas, sin ejecutar candidatos
python3 incertidumbre_bootstrap.py               # -> incertidumbre_brecha.csv (solo lee resultados registrados)
python3 repetir_reimplementacion.py ejecutar v1  # -> reimplementacion/ (también v2, v1D y v2D)
python3 repetir_reimplementacion.py analizar v1
python3 repetir_reimplementacion.py comparar     # registrado frente a la repetición
```

Instrucciones originales del paquete:

```bash
python3 verificar_generador.py          # factibilidad de las 15 instancias
python3 exportar_datos.py               # datos/*.csv
python3 experimento.py ejecutar v1      # ejecución oficial: 330 ejecuciones
python3 experimento.py analizar v1      # -> resumen_v1.json
python3 experimento.py ejecutar v2      # sensibilidad del presupuesto
python3 experimento.py analizar v2      # -> resumen_v2.json
python3 sensibilidad_D.py ejecutar v1   # exploratorio (definido después de los resultados)
python3 sensibilidad_D.py analizar v1   # -> resumen_v1D.json
python3 sensibilidad_D.py ejecutar v2
python3 sensibilidad_D.py analizar v2   # -> resumen_v2D.json
python3 figura_rendimiento.py
python3 figura_turno.py
```

Con el código original y las mismas semillas, la brecha y los incumplimientos se
reproducían exactamente (`DESVIACIONES.md`); los tiempos (C2 y C4) dependen del
equipo. Con la reimplementación, eso vale para el voraz y la PLE; la búsqueda tabú y
el AG dan otras ejecuciones (ver «Material suplementario»).

## Resultado (puntaje total ponderado)

| Candidato | v1 (oficial) | v2 (presupuesto) | v1D (exploratorio) | v2D (exploratorio) |
|---|---|---|---|---|
| Algoritmo genético | 4.45 | 4.85 | 4.45 | 4.70 |
| Programación lineal entera | 4.05 | 4.05 | 4.50 | 4.35 |
| Búsqueda tabú | 2.80 | 2.65 | 2.80 | 2.65 |
| Algoritmo voraz | 2.35 | 2.50 | 2.50 | 2.50 |

El validador independiente coincidió con Φ en las 1 320 ejecuciones.
