import ctypes,ctypes.util,sys
lib=ctypes.CDLL(ctypes.util.find_library('lua5.4') or '/usr/lib/x86_64-linux-gnu/liblua5.4.so.0')
lib.luaL_newstate.restype=ctypes.c_void_p
lib.luaL_openlibs.argtypes=[ctypes.c_void_p]
lib.luaL_loadfilex.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_char_p]
lib.luaL_loadfilex.restype=ctypes.c_int
lib.lua_pcallk.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_void_p]
lib.lua_pcallk.restype=ctypes.c_int
lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p]
lib.lua_tolstring.restype=ctypes.c_char_p
lib.lua_close.argtypes=[ctypes.c_void_p]
L=lib.luaL_newstate();lib.luaL_openlibs(L)
try:
 from pathlib import Path
 p=sys.argv[1] if len(sys.argv)>1 else str(Path(__file__).with_name('test_main_pawn.lua'))
 status=lib.luaL_loadfilex(L,p.encode(),None)
 if status==0:status=lib.lua_pcallk(L,0,-1,0,0,None)
 if status:
  print('FAIL:',lib.lua_tolstring(L,-1,None).decode());sys.exit(1)
finally:lib.lua_close(L)
