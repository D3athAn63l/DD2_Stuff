"""Run Lua regression tests using system liblua5.4 (no third-party pip dependencies)."""
import ctypes
import sys
from pathlib import Path
from ctypes.util import find_library
lib=ctypes.CDLL(find_library('lua5.4') or 'liblua5.4.so.0')
lib.luaL_newstate.restype=ctypes.c_void_p
lib.luaL_openlibs.argtypes=[ctypes.c_void_p]
lib.luaL_loadfilex.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_char_p]
lib.luaL_loadfilex.restype=ctypes.c_int
lib.lua_pcallk.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_void_p]
lib.lua_pcallk.restype=ctypes.c_int
lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p]
lib.lua_tolstring.restype=ctypes.c_char_p
lib.lua_close.argtypes=[ctypes.c_void_p]
L=lib.luaL_newstate()
try:
    lib.luaL_openlibs(L)
    filename=sys.argv[1] if len(sys.argv)>1 else str(Path(__file__).with_name('test_engine.lua'))
    err=lib.luaL_loadfilex(L,filename.encode(),None)
    if err==0: err=lib.lua_pcallk(L,0,-1,0,0,None)
    if err:
        print('Lua error: '+(lib.lua_tolstring(L,-1,None) or b'unknown').decode(errors='replace'),file=sys.stderr)
        raise SystemExit(1)
finally:
    lib.lua_close(L)
