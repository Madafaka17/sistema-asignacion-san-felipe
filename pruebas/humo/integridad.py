"""Guardas de integridad de la experimentación: huellas registradas y semillas reservadas.

La prueba de humo no debe alterar nada de lo que sustenta el experimento registrado
ni el experimento futuro. Estas funciones solo leen archivos.
"""
from __future__ import annotations

import ast
import hashlib
import re
from pathlib import Path

# El paquete del experimento se registró como experimentos/sintetico_sanfelipe/ y en el
# repositorio del sistema se llama experimentos/sanfelipe/ (adaptación del 2026-11-04;
# las rutas del registro conservan el nombre anterior).
NOMBRE_REGISTRO = "experimentos/sintetico_sanfelipe"


def carpeta_experimento(raiz: Path) -> Path:
    """Carpeta del experimento: el nombre actual si existe; si no, el del registro."""
    for nombre in ("experimentos/sanfelipe", NOMBRE_REGISTRO):
        if (raiz / nombre / "registro_protocolo.txt").is_file():
            return Path(nombre)
    return Path(NOMBRE_REGISTRO)


def ruta_actual(raiz: Path, ruta_registrada: str) -> Path:
    """Ruta en disco de un archivo identificado con su ruta del registro."""
    return Path(ruta_registrada.replace(NOMBRE_REGISTRO, carpeta_experimento(raiz).as_posix(), 1))

METODOS = Path("experimentos/poc_cap3/metodos.py")
DIRECTORIOS_PROTEGIDOS = ("core", "experimentos")


def sha256_archivo(ruta: Path) -> str:
    h = hashlib.sha256()
    with open(ruta, "rb") as fh:
        for bloque in iter(lambda: fh.read(1 << 16), b""):
            h.update(bloque)
    return h.hexdigest()


def huellas_registradas(raiz: Path) -> dict[str, str]:
    """Pares archivo -> SHA-256 de registro_protocolo.txt (registrado el 2026-10-06)."""
    texto = (raiz / carpeta_experimento(raiz) / "registro_protocolo.txt").read_text(encoding="utf8")
    pares = re.findall(r"^([0-9a-f]{64})  (\S+)$", texto, flags=re.M)
    if not pares:
        raise ValueError("registro_protocolo.txt no contiene huellas")
    return {ruta: huella for huella, ruta in pares}


def verificar_registradas(raiz: Path) -> list[str]:
    """Devuelve la lista de archivos registrados que faltan o cambiaron (vacía = íntegro)."""
    diferencias = []
    for ruta, esperada in sorted(huellas_registradas(raiz).items()):
        p = raiz / ruta_actual(raiz, ruta)
        if not p.is_file():
            diferencias.append(f"{ruta}: no existe")
        elif sha256_archivo(p) != esperada:
            diferencias.append(f"{ruta}: huella distinta de la registrada")
    return diferencias


def instantanea(raiz: Path) -> dict[str, str]:
    """Huella de cada archivo de core/ y experimentos/ (se excluyen cachés de Python)."""
    out = {}
    for d in DIRECTORIOS_PROTEGIDOS:
        for p in sorted((raiz / d).rglob("*")):
            if p.is_file() and "__pycache__" not in p.parts and p.suffix != ".pyc":
                out[p.relative_to(raiz).as_posix()] = sha256_archivo(p)
    return out


def comparar_instantaneas(antes: dict[str, str], despues: dict[str, str]) -> list[str]:
    cambios = []
    for k in sorted(set(antes) | set(despues)):
        if k not in despues:
            cambios.append(f"{k}: eliminado")
        elif k not in antes:
            cambios.append(f"{k}: creado")
        elif antes[k] != despues[k]:
            cambios.append(f"{k}: modificado")
    return cambios


def _evaluar_literal(nodo):
    """Evalúa listas literales y la forma list(range(a, b)) sin ejecutar código arbitrario."""
    if isinstance(nodo, ast.Call) and isinstance(nodo.func, ast.Name) and nodo.func.id == "list" \
            and len(nodo.args) == 1 and isinstance(nodo.args[0], ast.Call) \
            and isinstance(nodo.args[0].func, ast.Name) and nodo.args[0].func.id == "range":
        return list(range(*[ast.literal_eval(a) for a in nodo.args[0].args]))
    return ast.literal_eval(nodo)


def semillas_reservadas(raiz: Path) -> dict[str, list[int]]:
    """Semillas del experimento registrado (leídas del código, sin importarlo)."""
    arbol = ast.parse((raiz / carpeta_experimento(raiz) / "experimento.py").read_text(encoding="utf8"))
    out = {}
    for nodo in arbol.body:
        if isinstance(nodo, ast.Assign) and len(nodo.targets) == 1 and isinstance(nodo.targets[0], ast.Name):
            nombre = nodo.targets[0].id
            if nombre in ("SEMILLAS_INSTANCIA", "SEMILLAS_METODO"):
                out[nombre] = [int(x) for x in _evaluar_literal(nodo.value)]
    if set(out) != {"SEMILLAS_INSTANCIA", "SEMILLAS_METODO"}:
        raise ValueError("no se encontraron las semillas del experimento registrado")
    return out


def configuracion_ag_v1(raiz: Path) -> dict:
    """Configuración del AG de la ejecución oficial v1, leída de resolver_ag (metodos.py)
    sin importar el módulo: valores literales de GAConfig y valores por omisión de los
    parámetros de la función."""
    arbol = ast.parse((raiz / METODOS).read_text(encoding="utf8"))
    for nodo in arbol.body:
        if isinstance(nodo, ast.FunctionDef) and nodo.name == "resolver_ag":
            args = nodo.args
            omision = dict(zip([a.arg for a in args.args][-len(args.defaults):],
                               [ast.literal_eval(d) for d in args.defaults]))
            for sub in ast.walk(nodo):
                if isinstance(sub, ast.Call) and isinstance(sub.func, ast.Name) and sub.func.id == "GAConfig":
                    cfg = {}
                    for kw in sub.keywords:
                        if isinstance(kw.value, ast.Name):
                            cfg[kw.arg] = omision.get(kw.value.id, f"<{kw.value.id}>")
                        else:
                            cfg[kw.arg] = ast.literal_eval(kw.value)
                    return cfg
    raise ValueError("no se encontró GAConfig en resolver_ag")
