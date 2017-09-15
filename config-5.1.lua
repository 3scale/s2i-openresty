lua_interpreter = [[resty]]

rocks_trees = {
   {
      name = [[openresty]],
      root = [[/usr/local/openresty/luajit]],
      bin_dir = os_getenv('LUA_BIN_PATH'),
   }
}

lib_modules_path = [[/lib/lua/]]..lua_version

variables = {
  LUA_INCDIR = [[/usr/local/openresty/luajit/include/luajit-2.1]],
  LUA_LIBDIR = [[/usr/local/openresty/luajit/lib]]..lua_version
}