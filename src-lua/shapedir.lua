-- (c) Copyright 2010-2016 Geoff Leyland.
-- See LICENSE for license information

local shapefile = require("shapefile")
local dbf = require("dbf")
local lfs = require("lfs")


------------------------------------------------------------------------------

local function files(dir_name, file_pattern, projection)
  local function _files()
    for filename in lfs.dir(dir_name) do
      if filename:match("%.shp$") and
        (not file_pattern or filename:match(file_pattern)) then
        local name = filename:match("(.*)%.shp$")
        local sf = io.open(dir_name.."/"..filename, "rb")
        local df = io.open(dir_name.."/"..name..".dbf", "rb")

        local sf, xmin, ymin, xmax, ymax = shapefile.use(sf, projection)
        local df = dbf.use(df)

        local function _shapes()
          while true do
            local s = sf:read()
            if not s then break end
            if s == "null shape" then
              df:skip(fields)
            else
              local d = df:read(fields)
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
