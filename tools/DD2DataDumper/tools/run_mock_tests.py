"""Runs mock REFramework Lua test with the system Lua 5.4 shared library."""
import ctypes,sys
from pathlib import Path
lib=ctypes.CDLL('liblua5.4.so.0')
lib.luaL_newstate.restype=ctypes.c_void_p
lib.luaL_openlibs.argtypes=[ctypes.c_void_p]
lib.luaL_loadfilex.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_char_p]
lib.luaL_loadfilex.restype=ctypes.c_int
lib.lua_pcallk.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_void_p]
lib.lua_pcallk.restype=ctypes.c_int
lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.POINTER(ctypes.c_size_t)]
lib.lua_tolstring.restype=ctypes.c_char_p
lib.lua_createtable.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int]
lib.lua_pushstring.argtypes=[ctypes.c_void_p,ctypes.c_char_p]
lib.lua_rawseti.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_longlong]
lib.lua_setglobal.argtypes=[ctypes.c_void_p,ctypes.c_char_p]
lib.lua_close.argtypes=[ctypes.c_void_p]
state=lib.luaL_newstate()
try:
  lib.luaL_openlibs(state)
  lib.lua_createtable(state,1,0)
  lib.lua_pushstring(state,str(Path(__file__).parent.parent/'reframework/autorun/DD2_DataDumper.lua').encode())
  lib.lua_rawseti(state,-2,1)
  lib.lua_setglobal(state,b'arg')
  script=str(Path(__file__).parent/'mock_runtime_test.lua').encode()
  assert lib.luaL_loadfilex(state,script,None)==0
  code=lib.lua_pcallk(state,0,0,0,0,None)
  if code:
    err=lib.lua_tolstring(state,-1,None)
    raise RuntimeError(err.decode() if err else str(code))
finally:
  lib.lua_close(state)
