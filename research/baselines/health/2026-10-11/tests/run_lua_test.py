"""Execute syntax + mock capture using the installed Lua 5.4 shared library."""
from pathlib import Path
import ctypes
root=Path(__file__).resolve().parents[1]
lib=ctypes.CDLL('liblua5.4.so.0')
lib.luaL_newstate.restype=ctypes.c_void_p
lib.luaL_openlibs.argtypes=[ctypes.c_void_p]
lib.luaL_loadstring.argtypes=[ctypes.c_void_p,ctypes.c_char_p];lib.luaL_loadstring.restype=ctypes.c_int
lib.lua_pcallk.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_long,ctypes.c_void_p];lib.lua_pcallk.restype=ctypes.c_int
lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p];lib.lua_tolstring.restype=ctypes.c_char_p
lib.lua_close.argtypes=[ctypes.c_void_p]
state=lib.luaL_newstate();lib.luaL_openlibs(state)
try:
    source=root/'reframework/autorun/Health_API_Probe.lua'
    test=root/'tests/test_health_probe.lua'
    code=f'PROBE_SOURCE = {str(source)!r}\ndofile({str(test)!r})'
    rc=lib.luaL_loadstring(state,code.encode())
    if rc==0: rc=lib.lua_pcallk(state,0,-1,0,0,None)
    if rc: raise RuntimeError(lib.lua_tolstring(state,-1,None).decode(errors='replace'))
    print('Lua 5.4 syntax + mock execution: PASSED')
finally: lib.lua_close(state)
