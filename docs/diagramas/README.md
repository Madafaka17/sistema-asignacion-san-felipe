# Diagramas del capítulo V de la tesis

Archivos del paquete EP3 del autor (4 de noviembre de 2026), incorporados sin
cambios. Los PNG son los que contiene la tesis; los scripts los regeneran.

| Archivo | Figura de la tesis | Herramienta |
|---|---|---|
| `cun_modelo.py` → `cun_modelo.png` | Figura 9: casos de uso del negocio y flujos de información | matplotlib |
| `objetos_cun.py` → `objetos_a.png`, `objetos_b.png` | Figuras 10 y 11: objetos del negocio | Graphviz (`dot`) y Pillow |
| `estados_unidad.dot` → `estados_unidad.png` | Figura 35: estados de la unidad | `dot -Tpng estados_unidad.dot -o estados_unidad.png` |
| `er.py` → `er_nucleo.png` | Figura 41: entidad-relación del esquema del núcleo | Graphviz; `python3 er.py ../../bd/esquema.sql` |

Los scripts escriben en la carpeta desde la que se ejecutan. `er.py` lee
[`bd/esquema.sql`](../../bd/esquema.sql), el esquema de persistencia del núcleo de
la Tabla 79; con ese archivo, el diagrama regenerado muestra las mismas nueve
tablas, claves y cardinalidades que la Figura 41.

Los diagramas UML del prototipo (casos de uso, componentes, clases, secuencias,
estados, despliegue y ER del prototipo) están en [`../uml.md`](../uml.md).
