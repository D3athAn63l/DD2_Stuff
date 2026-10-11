"""Syntax check Lua via system liblua5.4, no REFramework needed."""
import ctypes
from pathlib import Path
import sys

lib = ctypes.CDLL('liblua5.4.so.0')
lib.luaL_newstate.restype = ctypes.c_void_p
lib.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
lib.luaL_loadfilex.restype = ctypes.c_int
lib.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
lib.lua_tolstring.restype = ctypes.c_char_p
lib.lua_close.argtypes=[ctypes.c_void_p]

def check(path):
    state = lib.luaL_newstate()
    try:
        err = lib.luaL_loadfilex(state, str(path).encode(), None)
        if err:
            message = lib.lua_tolstring(state, -1, None)
            raise RuntimeError(message.decode() if message else f'Lua error {err}')
        print('PASS Lua parse:', path)
    finally:
        lib.lua_close(state)

if __name__ == '__main__':
    check(Path(sys.argv[1]))
