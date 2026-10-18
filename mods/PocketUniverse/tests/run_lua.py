"""Run Lua mocked tests using system liblua5.4 (no pip dependencies)."""
import ctypes
from pathlib import Path
from ctypes.util import find_library
lib=ctypes.CDLL(find_library('lua5.4') or 'liblua5.4.so.0')
lib.luaL_newstate.restype=ctypes.c_void_p
lib.luaL_openlibs.argtypes=[ctypes.c_void_p]
lib.luaL_loadstring.argtypes=[ctypes.c_void_p,ctypes.c_char_p]
lib.luaL_loadstring.restype=ctypes.c_int
lib.luaL_loadfilex.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_char_p]
lib.luaL_loadfilex.restype=ctypes.c_int
lib.lua_pcallk.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_void_p]
lib.lua_pcallk.restype=ctypes.c_int
lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p]
lib.lua_tolstring.restype=ctypes.c_char_p
lib.lua_close.argtypes=[ctypes.c_void_p]
base=Path(__file__).resolve().parents[1]
script=base/'reframework'/'autorun'/'pocket_universe.lua'
test=Path(__file__).with_name('test_engine.lua')
L=lib.luaL_newstate()
try:
 lib.luaL_openlibs(L)
 prefix='arg={[1]='+repr(str(script)).replace('\\\\','\\')+'}'
 err=lib.luaL_loadstring(L,prefix.encode())
 if err==0:err=lib.lua_pcallk(L,0,0,0,0,None)
 if err==0:err=lib.luaL_loadfilex(L,str(test).encode(),None)
 if err==0:err=lib.lua_pcallk(L,0,-1,0,0,None)
 if err:
  msg=lib.lua_tolstring(L,-1,None)
  raise RuntimeError((msg or b'unknown').decode(errors='replace'))
finally:
 lib.lua_close(L)
