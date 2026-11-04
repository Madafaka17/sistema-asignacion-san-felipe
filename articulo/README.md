# Pruebas del código del artículo (tesis, sección 5.6.11 y Tabla I3 del Anexo I)

`pruebas/` es la suite de pruebas del código del artículo *Asignación de vehículo,
conductor y salida en operadores interprovinciales pequeños* (Rios Sepúlveda &
Ramírez Romero, 2026b), cuyo código está en la carpeta `02_codigo` del depósito de
Zenodo (doi 10.5281/zenodo.23604918). Se incorpora sin cambios, tal como la
entregó el autor en el paquete EP3 (4 de noviembre de 2026), junto con el
registro de su ejecución del 24/10/2026 (`pruebas/salidas/`: `casos.jsonl`,
`junit.xml`, `pytest.log`, `entorno.json`, `cobertura.*`, `reproduccion.*` y la
comparación con Python 3.11).

Resultado registrado: 121 casos, 120 aprobados y una falla esperada (anomalía
B-01), con CPython 3.13.16. Los casos A10-07 a A10-10 usan los horarios GTFS reales
de Łódź (CC BY 4.0) y de Buzău (MIT) y los casos A12-01 a A12-07, la
transcripción anonimizada de los once manifiestos de la empresa.

**Esta suite no prueba el código de este repositorio.** Importa los módulos del
código del artículo (`modelo.py`, `genetico.py`, `metodos.py`…), que no están
aquí. Para repetirla, copie `pruebas/` dentro de la carpeta `02_codigo` del
depósito y ejecute, desde esa carpeta:

```bash
pip install -r requirements.txt pytest==9.1.1
SIN_REPRODUCCION=1 bash pruebas/ejecutar_pruebas.sh
```

Las pruebas del núcleo de este repositorio están en
[`../pruebas/nucleo/`](../pruebas/nucleo/) y las del prototipo, en
[`../docs/pruebas.md`](../docs/pruebas.md).
