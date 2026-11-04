# Corrida paso a paso del AG (tesis, capítulo IV, sección 4.4)

Archivos del paquete EP3 del autor (4 de noviembre de 2026), incorporados sin
cambios.

| Archivo | Contenido |
|---|---|
| `trazar_corrida.py` | Reproduce paso a paso una ejecución del AG con la configuración oficial v1, registra los resultados intermedios y comprueba que el cromosoma y el historial coinciden con `core.scheduler.run` y con `experimentos/sanfelipe/resultados_crudos_v1.csv` |
| `traza_n7_101_s1.json` | Traza de la instancia oficial n = 7, semilla 101, semilla del AG 1, usada en las Tablas 44 a 49 de la tesis |
| `figura_corrida.py`, `figura_corrida.png` | Figura 8 de la tesis, dibujada a partir de la traza |

## Reproducción

Desde la raíz del repositorio, con el entorno de `requirements.lock`:

```bash
source scripts/entorno_determinista.sh
python -I pruebas/corrida/trazar_corrida.py . 7 101 1 /tmp/traza.json
python pruebas/corrida/figura_corrida.py /tmp/traza.json /tmp/figura_corrida.png
```

## Verificación en este repositorio

`traza_n7_101_s1.json` se generó con el núcleo original (CPython 3.11.17). Al
ejecutar `trazar_corrida.py` en este repositorio, con el `core/` original
(huellas del registro), CPython 3.11.18, PyGAD 3.7.0 y NumPy 2.4.4 (4/11/2026),
el script pasa sus propias comprobaciones y la traza obtenida es **idéntica** a
la incorporada en todos sus campos —población inicial y reparada, progenitores,
cruces y mutaciones de la primera generación, estadísticas de las 101
generaciones, historial, mejor cromosoma, voraz, PLE, búsqueda tabú, hojas
factibles del óptimo y registro oficial—, salvo `tiempo_traza_s` y la versión de
Python de `entorno`.
