import ctypes
import pathlib
import sys

lib = ctypes.CDLL('liblua5.4.so.0')
lib.luaL_newstate.restype = ctypes.c_void_p
lib.luaL_openlibs.argtypes = [ctypes.c_void_p]
lib.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
lib.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_longlong, ctypes.c_void_p]
lib.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lib.lua_tolstring.restype = ctypes.c_char_p
lib.lua_close.argtypes = [ctypes.c_void_p]

for path in pathlib.Path('.').rglob('*.lua'):
    state = lib.luaL_newstate()
    if lib.luaL_loadfilex(state, str(path).encode(), None):
        sys.exit(lib.lua_tolstring(state, -1, None).decode())
    lib.lua_close(state)
print('All Lua files parsed.')
checks = ['tests/actionbars.lua']
if pathlib.Path('../tomtom-test-libs/AceDB-3.0.lua').exists():
    checks.append('tests/tomtom-real-acedb.lua')
for check in checks:
    state = lib.luaL_newstate()
    lib.luaL_openlibs(state)
    status = lib.luaL_loadfilex(state, check.encode(), None)
    if not status:
        status = lib.lua_pcallk(state, 0, 0, 0, 0, None)
    if status:
        sys.exit(lib.lua_tolstring(state, -1, None).decode())
    lib.lua_close(state)
