"""Run manually in CanMV IDE on K230; read-only, no camera/UART setup."""
import os
import sys

print("K230_PREFLIGHT_V1")
print("sys.version:", sys.version)
print("implementation:", sys.implementation)
try:
    print("uname:", os.uname())
except Exception as exc:
    print("uname unavailable:", repr(exc))

for name in ("nncase_runtime", "aicube", "ulab.numpy", "libs.PipeLine",
             "libs.AIBase", "libs.AI2D"):
    try:
        module = __import__(name, None, None, ["*"])
        print("IMPORT_OK", name, "version:", getattr(module, "__version__", "not exposed"))
    except Exception as exc:
        print("IMPORT_ERROR", name, repr(exc))

for path in ("/sdcard/kmodel/hand_det.kmodel",
             "/sdcard/kmodel/handkp_det.kmodel"):
    try:
        print("MODEL_FILE", path, "bytes:", os.stat(path)[6])
    except Exception as exc:
        print("MODEL_FILE_ERROR", path, repr(exc))
print("END: file/import checks only; model compatibility and inference NOT verified")
