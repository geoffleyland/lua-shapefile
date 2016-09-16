-- (c) Copyright 2010-2016 Geoff Leyland.
-- See LICENSE for license information

local shapefile = require("shapefile")
local projection_map = require("shapefile.projections")
local dbf = require("dbf")
local lfs = require("lfs")


------------------------------------------------------------------------------

local function files(dir_name, file_pattern, projection)

  local function _files()
    for filename in lfs.dir(dir_name) do
      if filename:match("%.shp$") and
        (not file_pattern or filename:match(file_pattern)) then
        local name = filename:match("(.*)%.shp$")
        local sfi = io.open(dir_name.."/"..filename, "rb")
        local dfi = io.open(dir_name.."/"..name..".dbf", "rb")

        if projection then
          local projection_file = io.open(dir_name.."/"..name..".prj", "r")
          if projection_file then
            local l = projection_file:read("*all")
            local projection_string = l:match('^%w+%["?([^",]+)')
            local proj_projection = projection_map[projection_string]
            if proj_projection then
              projection:set_input(proj_projection)
            else
              error(("Unkown Projection: %s"):format(projection_string))
            end
          end
        end

        local sf, xmin, ymin, xmax, ymax = shapefile.use(sfi, projection)
        local df = dbf.use(dfi)

        local function _shapes()
          while true do
            local s = sf:read()
            if not s then break end
            if s == "null shape" then
              df:skip()
            else
              local d = df:read()
              coroutine.yield(s, d)
            end
          end
        end

        coroutine.yield(coroutine.wrap(_shapes), name, xmin, xmax, ymin, ymax)

        sf:close()
        df:close()
      end
    end
  end
  return coroutine.wrap(_files)
end


------------------------------------------------------------------------------

return { files=files }

------------------------------------------------------------------------------
