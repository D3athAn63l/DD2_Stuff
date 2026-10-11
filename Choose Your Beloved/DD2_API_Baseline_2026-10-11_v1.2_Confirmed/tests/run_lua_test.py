"""Use the container's installed liblua5.4 to run the Lua mock test."""
import ctypes
from pathlib import Path
lib = ctypes.CDLL('liblua5.4.so.0')
lib.luaL_newstate.restype = ctypes.c_void_p
lib.luaL_openlibs.argtypes = (ctypes.c_void_p,)
lib.luaL_loadstring.argtypes = (ctypes.c_void_p, ctypes.c_char_p)
lib.luaL_loadstring.restype = ctypes.c_int
lib.lua_pcallk.argtypes = (ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_long, ctypes.c_void_p)
lib.lua_pcallk.restype = ctypes.c_int
lib.lua_tolstring.argtypes = (ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p)
lib.lua_tolstring.restype = ctypes.c_char_p
lib.lua_close.argtypes = (ctypes.c_void_p,)
root = Path(__file__).resolve().parents[1]
probe = root / 'reframework' / 'autorun' / 'Beloved_API_Probe.lua'
test = root / 'tests' / 'test_probe_v12.lua'
state = lib.luaL_newstate(); lib.luaL_openlibs(state)
try:
    code = f'PROBE_PATH = {str(probe)!r}\ndofile({str(test)!r})'
    status = lib.luaL_loadstring(state, code.encode())
    if status == 0:
        status = lib.lua_pcallk(state, 0, -1, 0, 0, None)
    if status:
        raise RuntimeError(lib.lua_tolstring(state, -1, None).decode(errors='replace'))
    print('Lua 5.4: syntax and simulated runtime passed')
finally:
    lib.lua_close(state)
