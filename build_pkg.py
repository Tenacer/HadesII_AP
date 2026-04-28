"""Build the AP icon package for HadesII_AP.

Run from the HadesII_AP directory:
    python3 build_pkg.py

Produces:
    data/Tenacer_AP-HadesII_AP/Tenacer_AP-HadesII_AP.pkg
    data/Tenacer_AP-HadesII_AP/Tenacer_AP-HadesII_AP.pkg_manifest

These are copied by tcli build into plugins_data/ via thunderstore.toml.
"""

import os
import shutil

# deppth2 creates subdirectories with mode 0o666 (no execute bit), which
# prevents entering them on Linux. Patch os.mkdir to always use 0o777.
_real_mkdir = os.mkdir
def _mkdir_777(path, mode=0o777, **kw):
    _real_mkdir(path, 0o777, **kw)
os.mkdir = _mkdir_777

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SOURCE_DIR = os.path.join(SCRIPT_DIR, "icons_src")
PKG_NAME = "Tenacer_AP-HadesII_AP"
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "data", PKG_NAME)

os.makedirs(OUTPUT_DIR, exist_ok=True)

# deppth2 writes output relative to cwd, so work from a temp local dir.
build_tmp = os.path.join(SCRIPT_DIR, "_build_tmp")
os.makedirs(build_tmp, exist_ok=True)
target = os.path.join(build_tmp, PKG_NAME)

try:
    from deppth2.texpacking import build_atlases_hades
    # BC7 compression requires texconv.exe (Windows). Use RGBA on Linux.
    build_atlases_hades(SOURCE_DIR, target, deppth2_pack=True, codec="RGBA")

    for ext in (".pkg", ".pkg_manifest"):
        src = target + ext
        dst = os.path.join(OUTPUT_DIR, PKG_NAME + ext)
        shutil.copy2(src, dst)
        print(f"Copied {dst}")
finally:
    shutil.rmtree(build_tmp, ignore_errors=True)

print("Done.")
