dependencies = {
  -- "https://github.com/daurnimator/lua-http.git#v0.2",
  "https://github.com/aleclarson/lua-http.git",
  "https://github.com/aleclarson/lua-emitter.git#0.0.3",
  "https://github.com/aleclarson/lua-linenoise.git#0.9",
}
scripts = {
  test = "luajit test.lua",
  watch = "moonw src -o quest",
}
