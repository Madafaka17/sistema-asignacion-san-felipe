"""Genera los diagramas UML de componentes y de despliegue a partir de la evidencia del
despliegue (informe de la prueba de humo y registro de la construcción) y comprueba que
cada dependencia dibujada exista en el código.

    .venv/bin/python -s docs/diagramas/generar_diagramas.py pruebas/humo/salidas/<id>/informe.json
    plantuml -tpng docs/diagramas/componentes.puml docs/diagramas/despliegue.puml
    plantuml -tsvg docs/diagramas/componentes.puml docs/diagramas/despliegue.puml

Nada de lo que muestran los diagramas se escribe a mano: versiones, puertos, equipo y
nombres salen de los archivos JSON de la ejecución. Las dependencias entre componentes se
verifican contra las sentencias import de los archivos fuente (grafo de módulos agregado
por componente) y las dependencias entre bibliotecas, contra sus metadatos de instalación.
"""
from __future__ import annotations

import ast
import json
import re
import sys
from importlib import metadata
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
AQUI = Path(__file__).resolve().parent

# Componente del despliegue -> módulos fuente que lo forman
COMPONENTES = {
    "PH": ["pruebas/humo/prueba_humo.py", "pruebas/humo/integridad.py"],
    "PER": ["persistencia/config.py", "persistencia/conexion.py", "persistencia/repositorio.py",
            "persistencia/canonico.py"],
    "CORE": ["core/domain.py", "core/conflicts.py", "core/fitness.py", "core/repair.py", "core/scheduler.py"],
    "VAL": ["experimentos/poc_cap3/validador.py"],
}
# Nombre importado -> componente o biblioteca
DESTINOS = {
    "pruebas.humo": "PH", "persistencia": "PER", "core": "CORE", "validador": "VAL",
    "numpy": "NP", "pygad": "PYGAD", "pymysql": "PYM", "cryptography": "CRY", "pulp": "PULP",
}
BIBLIOTECAS = {"NP", "PYGAD", "PYM", "CRY", "PULP"}
# Dependencias que muestran los diagramas (origen, destino). "LIBS" es el paquete de bibliotecas:
# la prueba importa todas en el paso P02 para verificar su carga.
DIBUJADAS = {("PH", "PER"), ("PH", "CORE"), ("PH", "VAL"), ("PH", "LIBS"), ("PER", "CORE"), ("PER", "PYM"),
             ("CORE", "PYGAD"), ("CORE", "NP")}
ENTRE_BIBLIOTECAS = {("pygad", "numpy"), ("pymysql", "cryptography")}


def _modulo_de(ruta: str) -> str:
    return ruta[:-3].replace("/", ".")


def _destino(nombre: str) -> str | None:
    partes = nombre.split(".")
    for i in range(len(partes), 0, -1):
        if ".".join(partes[:i]) in DESTINOS:
            return DESTINOS[".".join(partes[:i])]
    return None


def aristas_reales() -> set[tuple[str, str]]:
    aristas = set()
    for comp, rutas in COMPONENTES.items():
        for ruta in rutas:
            paquete = _modulo_de(ruta).rsplit(".", 1)[0]
            for nodo in ast.walk(ast.parse((RAIZ / ruta).read_text(encoding="utf8"))):
                nombres = []
                if isinstance(nodo, ast.Import):
                    nombres = [a.name for a in nodo.names]
                elif isinstance(nodo, ast.ImportFrom):
                    base = nodo.module or ""
                    if nodo.level:
                        partes = paquete.split(".")
                        base = ".".join(partes[: len(partes) - nodo.level + 1] + ([base] if base else []))
                    nombres = [base]
                for n in nombres:
                    d = _destino(n)
                    if d and d != comp:
                        aristas.add((comp, "LIBS" if comp == "PH" and d in BIBLIOTECAS else d))
    return aristas


def verificar() -> list[str]:
    reales = aristas_reales()
    problemas = [f"dibujada sin import en el código: {a} -> {b}" for a, b in sorted(DIBUJADAS - reales)]
    problemas += [f"import del código no dibujado: {a} -> {b}" for a, b in sorted(reales - DIBUJADAS)]
    for origen, destino in sorted(ENTRE_BIBLIOTECAS):
        requeridas = [re.split(r"[ ;<>=!~\[]", r, maxsplit=1)[0].lower() for r in metadata.requires(origen) or []]
        if destino not in requeridas:
            problemas.append(f"{origen} no declara a {destino} en sus metadatos")
    return problemas


def _gib(kib: int) -> str:
    return f"{kib / 1024 / 1024:.1f} GiB".replace(".", ",")


def componentes(inf: dict) -> str:
    m = inf["entorno"]["modulos"]
    bd = inf["base_datos"]
    return f"""@startuml
!include common.iuml
skinparam componentStyle uml2
skinparam nodesep 55
skinparam ranksep 60

artifact "config/humo.json" as CH
artifact "registro_protocolo.txt\\n(huellas del 6/10/2026)" as REG
component "Prueba de humo\\n(pruebas/humo/)\\nprueba_humo.py · integridad.py" as PH

component "Adaptador de persistencia\\n(persistencia/)\\nconfig.py · conexion.py\\nrepositorio.py · canonico.py" as PER
interface "API del adaptador\\n(configuración, conexión,\\ninstancia, programación)" as IPER
component "Núcleo de optimización\\n(core/, sin cambios)\\nscheduler.py · fitness.py · repair.py\\nconflicts.py · domain.py" as CORE
interface "run(Instance, GAConfig)\\n→ ScheduleResult" as IRUN
component "Validador independiente\\n(experimentos/poc_cap3/validador.py)" as VAL

artifact ".env\\n(no versionado)" as ENV
artifact "bd/esquema.sql\\nbd/semilla_humo.sql" as SQL
interface "Protocolo MySQL\\nTCP {bd['host']}:{bd['puerto']}" as IMY
database "MySQL {bd['servidor'].split('-')[0]}\\nbase efímera sf_test_humo_<id>" as BD

package "Bibliotecas fijadas (requirements.lock)" as LIBS {{
  component "PyMySQL {m['pymysql']}" <<biblioteca>> as PYM
  component "cryptography {m['cryptography']}" <<biblioteca>> as CRY
  component "PyGAD {m['pygad']}" <<biblioteca>> as PYGAD
  component "NumPy {m['numpy']}" <<biblioteca>> as NP
  component "PuLP {m['pulp']} + CBC {m['cbc']}" <<biblioteca>> as PULP
}}

PER -up- IPER
CORE -up- IRUN
BD -up- IMY

PH .left.> CH : lee
PH .right.> REG : verifica huellas
PH ..> IPER : usa
PH ..> IRUN : invoca
PH ..> VAL : verifica Φ
PH ..> LIBS : verifica la carga (P02)
PER .right.> CORE : construye Instance\\n(core.domain)
PER ..> ENV : lee
PER ..> SQL : aplica
PER ..> IMY : SQL
PER ..> PYM
PYM .right.> CRY : autenticación
CORE ..> PYGAD : ciclo generacional
CORE ..> NP
PYGAD .right.> NP

legend bottom left
  Dependencias verificadas contra las sentencias import del código y los metadatos de las bibliotecas.
  Valores de la ejecución de referencia {inf['id_ejecucion']}. Datos sintéticos (CHECK origen_datos = 'sintetico').
  No se despliegan la capa de presentación ni la construcción de alternativas desde las reglas de la cola (Figura 4).
endlegend
@enduml
"""


def despliegue(inf: dict) -> str:
    e = inf["entorno"]
    bd = inf["base_datos"]
    n_paq = len(e["paquetes"])
    usuario = next(p["detalle"]["conexion"]["usuario"] for p in inf["pasos"] if p["codigo"] == "P03")
    return f"""@startuml
!include common.iuml
skinparam nodesep 45
skinparam ranksep 50

cloud "Archivo de Ubuntu\\n(archive.ubuntu.com)" as UBU
cloud "Índice de paquetes de Python\\n(pypi.org)" as PYPI

node "Máquina virtual efímera {e['arquitectura']}\\n{e['nucleos_logicos']} vCPU {e.get('procesador', '')}; {_gib(e['memoria_total_kib'])} de RAM" <<device>> as VM {{
  node "{e['sistema_operativo']} (núcleo Linux {e['nucleo_linux']})" <<sistema operativo>> as SO {{
    folder "Carpeta del proyecto" as FS {{
      artifact "scripts/construir_y_probar.sh\\naprovisionar.sh · bd_efimera.sh" as A_SH
      artifact "requirements.lock · sistema.lock\\nSHA256SUMS" as A_LOCK
      artifact ".env (permiso 600, no versionado)\\nconfig/humo.json" as A_CFG
      artifact "bd/esquema.sql\\nbd/semilla_humo.sql" as A_SQL
      artifact "pruebas/humo/salidas/<id>/\\nlog · informe.json · salidas" as A_OUT
    }}
    node "Python {e['python']} (entorno virtual .venv)\\npip {e['pip']}; {n_paq} paquetes de requirements.lock\\nPYTHONHASHSEED=0; un hilo; TZ=UTC" <<entorno de ejecución>> as PY {{
      artifact "core/\\n(5 módulos, huellas registradas)" as A_CORE
      artifact "persistencia/\\n(4 módulos)" as A_PER
      artifact "pruebas/humo/\\nprueba_humo.py · integridad.py" as A_PH
      artifact "poc_cap3/validador.py" as A_VAL
      artifact ".build/pycache\\n(bytecode checked-hash)" as A_PYC
    }}
    node "MySQL Server {bd['servidor'].split('-')[0]} (mysqld efímero)\\n--no-defaults · datos en .build/mysql\\nsolo {bd['host']}:{bd['puerto']} · usuario {usuario} (sf_test_%)\\nroot bloqueado" <<entorno de ejecución>> as MY {{
      database "sf_test_humo_<id>\\n9 tablas; se elimina\\nal terminar" as DB
    }}
  }}
}}

UBU .down.> SO : paquetes .deb\\n(versión y SHA-256 fijados)
PYPI .down.> PY : ruedas de Python\\n(--require-hashes)
DB <-right- A_PER : TCP/IP {bd['host']}:{bd['puerto']}\\nprotocolo MySQL (PyMySQL)
PY -[hidden]right- FS
A_SH -[hidden]down- A_LOCK
A_LOCK -[hidden]down- A_CFG
A_CFG -[hidden]down- A_SQL
A_SQL -[hidden]down- A_OUT
A_CORE -[hidden]down- A_PER
A_PER -[hidden]down- A_PH
A_PH -[hidden]down- A_VAL
A_VAL -[hidden]down- A_PYC

legend bottom left
  Entorno nuevo, aprovisionado solo con scripts/construir_y_probar.sh.
  Valores de la ejecución de referencia {inf['id_ejecucion']}. La capa de presentación (Figura 4) no se despliega.
endlegend
@enduml
"""


def main() -> int:
    informe = json.loads(Path(sys.argv[1]).read_text(encoding="utf8"))
    problemas = verificar()
    if problemas:
        print("\n".join(problemas), file=sys.stderr)
        return 1
    (AQUI / "componentes.puml").write_text(componentes(informe), encoding="utf8")
    (AQUI / "despliegue.puml").write_text(despliegue(informe), encoding="utf8")
    print(f"dependencias verificadas: {len(DIBUJADAS)} entre componentes y {len(ENTRE_BIBLIOTECAS)} entre "
          f"bibliotecas; diagramas escritos en {AQUI.relative_to(RAIZ)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
