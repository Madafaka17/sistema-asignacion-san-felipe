# Pruebas de concepto del capítulo 3 (sección 3.2.3 de la tesis)

Comparación empírica de los cuatro candidatos del capítulo 3 —programación lineal
entera (PLE), algoritmo voraz, búsqueda tabú y algoritmo genético (AG)— con las
mismas instancias, el mismo equipo, la misma función de evaluación
(`core.fitness.evaluate`) y el mismo límite de tiempo. El protocolo completo, fijado
antes de la ejecución oficial, está en [PROTOCOLO.md](PROTOCOLO.md).

## Archivos

| Archivo | Contenido |
|---|---|
| `PROTOCOLO.md` | Protocolo preregistrado (secciones 1 a 7), correcciones de fidelidad tras el piloto (8) y análisis de sensibilidad v2 (9) |
| `generador.py` | Instancias sintéticas factibles por construcción (semillas 101, 102 y 103; *n* = 7 a 112) |
| `metodos.py` | Implementación de los cuatro candidatos sobre las estructuras de `core/` |
| `exhaustivo.py` | Óptimo certificado por enumeración exhaustiva con poda (*n* = 7) |
| `validador.py` | Conteo independiente de restricciones duras incumplidas |
| `experimento.py` | Ejecución (`ejecutar`) y cálculo de criterios, puntajes y totales (`analizar`) |
| `resultados_crudos.csv`, `resumen.json`, `optimos_n7.csv` | Resultados de la ejecución oficial (v1) |
| `resultados_crudos_v2.csv`, `resumen_v2.json`, `optimos_n7_v2.csv` | Resultados del análisis de sensibilidad (v2) |
| `figura_poc.py`, `figura_poc.png` | Figura 6 de la tesis (monocromática) |

## Reproducción

Desde la raíz del repositorio:

```bash
pip install -r experimentos/poc_cap3/requirements.txt
cd experimentos/poc_cap3
python3 experimento.py ejecutar        # ejecución oficial (v1): 330 ejecuciones
python3 experimento.py analizar        # criterios C1-C5, puntajes 1-5 y totales -> resumen.json
python3 experimento.py ejecutar v2     # análisis de sensibilidad
python3 experimento.py analizar v2     # -> resumen_v2.json
python3 figura_poc.py                  # Figura 6
```

Las semillas son fijas, por lo que la brecha y los incumplimientos se reproducen
exactamente mientras ninguna ejecución alcance el límite de 300 s; los tiempos
dependen del equipo. Equipo de la ejecución reportada en la tesis: máquina virtual
Linux (núcleo 6.18, x86_64), 2 vCPU Intel Xeon a 2.10 GHz, 7.8 GiB de RAM;
Python 3.11.15, NumPy 2.4.4, PyGAD 3.7.0, PuLP 2.9.0 con CBC 2.10.3.

## Resultado

| Candidato | Total v1 | Total v2 |
|---|---|---|
| Programación lineal entera | 4.35 | 4.35 |
| Búsqueda tabú | 2.80 | 2.65 |
| Algoritmo genético | 2.65 | 3.30 |
| Algoritmo voraz | 2.50 | 2.50 |

El validador independiente coincidió con el conteo de la función de evaluación en
las 330 ejecuciones de cada variante.
