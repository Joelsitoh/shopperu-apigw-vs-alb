"""Envia la misma carga a las dos URL y compara latencia, errores y quien atendio."""
import json
import statistics
import sys
import time
import urllib.request
from collections import Counter
from concurrent.futures import ThreadPoolExecutor

PETICIONES = 600
CONCURRENCIA = 30


def pedir(url):
    inicio = time.perf_counter()
    try:
        with urllib.request.urlopen(url, timeout=10) as r:
            cuerpo = json.loads(r.read())
            return (time.perf_counter() - inicio) * 1000, r.status, cuerpo.get("atendidoPor", "")
    except Exception as e:
        return (time.perf_counter() - inicio) * 1000, getattr(e, "code", "error"), ""


def probar(nombre, url):
    with ThreadPoolExecutor(CONCURRENCIA) as ex:
        inicio = time.perf_counter()
        res = list(ex.map(pedir, [url] * PETICIONES))
        total = time.perf_counter() - inicio
    lat = sorted(r[0] for r in res)
    ok = sum(1 for r in res if r[1] == 200)
    print(f"\n== {nombre} ==")
    print(f"peticiones: {PETICIONES}  concurrencia: {CONCURRENCIA}  correctas: {ok}  errores: {PETICIONES - ok}")
    print(f"peticiones/seg: {PETICIONES / total:.1f}")
    print(f"latencia ms -> p50: {statistics.median(lat):.1f}  p95: {lat[int(len(lat) * 0.95)]:.1f}  max: {lat[-1]:.1f}")
    if nombre.startswith("ALB"):
        for instancia, n in Counter(r[2] for r in res if r[2]).items():
            print(f"  atendidas por {instancia}: {n}")
    else:
        print(f"  ejecuciones distintas de Lambda: {len(set(r[2] for r in res if r[2]))}")


if __name__ == "__main__":
    probar("API Gateway + Lambda", sys.argv[1])
    probar("ALB + EC2", sys.argv[2])
