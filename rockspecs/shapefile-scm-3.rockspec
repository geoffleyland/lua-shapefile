package = "shapefile"
version = "scm-3"
source =
{
  url = "git+ssh://github.com/geoffleyland/lua-shapefile.git"
}
description =
{
  summary = "Read ESRI shapefiles",
  homepage = "https://github.com/geoffleyland/lua-shapefile",
  license = "MIT/X11",
  maintainer = "Geoff Leyland <geoff.leyland@incremental.co.nz>",
}
dependencies =
{
  "lua >= 5.1",
  "luafilesystem",
  "dbf",
}
build =
{
  type = "builtin",
  modules =
  {
    ["shapefile"] = "src-lua/shapefile.lua",
    ["shapedir"] = "src-lua/shapedir.lua",
  },
}
