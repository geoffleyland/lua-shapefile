-- (c) Copyright 2010-2016 Geoff Leyland.
-- See LICENSE for license information

-- Shapefile format is documented in
-- http://www.esri.com/library/whitepapers/pdfs/shapefile.pdf


local unpack

if not string.unpack then
  require("struct")
  unpack = function(file, length, format)
    return struct.unpack(format, file:read(length))
  end
else
  unpack = function(file, length, format)
    return file:read(length):unpack(format)
  end
end


------------------------------------------------------------------------------

-- Shape types from page 4
local shape_types =
{
  [ 0] = "null",
  [ 1] = "point",
  [ 3] = "polyline",
  [ 5] = "polygon",
  [ 8] = "multipoint",
  [11] = "pointz",
  [13] = "polylinez",
  [15] = "polygonz",
  [18] = "multipointz",
  [21] = "pointm",
  [23] = "polylinem",
  [25] = "polygonm",
  [28] = "multipointm",
  [31] = "multipatch",
}


-- Header from pages 3 & 4
local function read_header(f)
  local file_code = unpack(f, 4, ">i")
  assert(file_code == 9994, "This file does not appear to be a shapefile: wrong file code")
  f:read(20) -- five unused integers
  local length, version, shape_type = unpack(f, 12, ">i<ii")
  assert(version == 1000, "This file does not appear to be a shapefile: wrong version")
  shape_type = shape_types[shape_type]
  assert(shape_type, "This file does not appear to be a shapefile: unknown shape type")

  -- 4 doubles for bounding box, xmin, ymin, xmax, ymax
  local xmin, ymin, xmax, ymax = unpack(f, 32, "<dddd")
   -- 4 more doubles for bounding box, zmin, zmax, mmin, mmax
  f:read(32) --unpack(f, 32, "<dddd")

  return xmin, ymin, xmax, ymax
end


-- Read a point with a projection
local function read_point(f, projection, bounds)
  local x, y = unpack(f, 16, "<dd")
  if projection then x, y = projection(x, y) end
  if bounds then
    bounds.min[1] = math.min(x, bounds.min[1] or math.huge)
    bounds.min[2] = math.min(y, bounds.min[2] or math.huge)
    bounds.max[1] = math.max(x, bounds.max[1] or -math.huge)
    bounds.max[2] = math.max(y, bounds.max[2] or -math.huge)
  end
  return x, y
end


local function skip_bounds(f)
  unpack(f, 32, "<dddd")
end


local function read_bounds(f, projection)
  local xmin, ymin, xmax, ymax = unpack(f, 32, "<dddd")
  if projection then
    xmin, ymin = projection(xmin, ymin)
    xmax, ymax = projection(xmax, ymax)
  end
  return xmin, ymin, xmax, ymax
end


-- Polyline and polygon from pages 7 & 8
local function polygon_or_polyline(f, projection, shape_type)
  -- 4 doubles defining xy bounding box
  local bounds = {min = {}, max = {}}
  -- We'll skip reading the bounds because they don't work if there's a projection
  skip_bounds(f)
--  bounds.xmin, bounds.ymin, bounds.xmax, bounds.ymax =
--    read_bounds(f, projection)

  local part_count, point_count = unpack(f, 8, "<ii")
  local part_starts = {}
  for i = 1, part_count do
    part_starts[i] = unpack(f, 4, "<i")
  end
  local part_index = 0

  local parts = {}
  local part
  for point_index = 0, point_count - 1 do
    if part_starts[part_index+1] == point_index then
      part_index = part_index + 1
      part = {}
      parts[part_index] = part
    end
    part[#part+1] = { read_point(f, projection, bounds) }
  end

  return { type = shape_type, bounds = bounds, parts = parts }, point_count
end


-- Polylinem and polygonm from pages 17-20
local function polygonm_or_polylinem(f, projection, shape_type)
  local shape = polygon_or_polyline(f, projection, shape_type)

  -- 2 doubles defining mmin and mmax
  shape.bounds.mmin, shape.bounds.mmax = unpack(f, 16, "<dd")

  for _, part in ipairs(shape.parts) do
    for _, p in ipairs(part) do
      p[3] = unpack(f, 8, "<d")
    end
  end

  return shape
end


-- Polylinez and polygonz from pages 17-20
local function polygonz_or_polylinez(f, projection, shape_type, record_length_bytes)
  local shape, point_count = polygon_or_polyline(f, projection, shape_type)

  -- 2 doubles defining zmin and zmax
  shape.bounds.zmin, shape.bounds.zmax = unpack(f, 16, "<dd")

  for i, part in ipairs(shape.parts) do
    for j, p in ipairs(part) do
      p[3] = unpack(f, 8, "<d")
    end
  end

  local base_length = 3*4 + 4*#shape.parts + 6*8 + 3*8*point_count
  local length_with_M = base_length + 2*8 + 8*point_count

  if record_length_bytes == length_with_M then
    -- 2 doubles defining mmin and mmax
    shape.bounds.mmin, shape.bounds.mmax = unpack(f, 16, "<dd")

    for i, part in ipairs(shape.parts) do
      for j, p in ipairs(part) do
        p[4] = unpack(f, 8, "<d")
      end
    end
  else
    assert(record_length_bytes == base_length, "Wrong length for polylineZ or polygonZ")
  end

  return shape
end


local readers =
{
  -- null from page 6
  null = function() return "null shape" end,

  -- Point from page 6
  point = function(f, projection)
    local x, y = read_point(f, projection)
    return { type = "point", bounds = { min = {x, y}, max = {x, y} }, points = { x, y } }
  end,

  -- multipoint from page 7
  multipoint = function(f, projection)
    skip_bounds(f)
    local bounds = { min = {}, max = {}}
    local point_count = unpack(f, 4, "<i")
    local points = {}
    for i = 1, point_count do
      points[i] = read_point(f, projection, bounds)
    end
    return { type = "multipoint", bounds, points = points }
  end,

  polygon = polygon_or_polyline,
  polyline = polygon_or_polyline,
  polygonm = polygonm_or_polylinem,
  polylinem = polygonm_or_polylinem,
  polygonz = polygonz_or_polylinez,
  polylinez = polygonz_or_polylinez,
}


local function read_shape(f, projection)
  local ok, record, record_length_words, shape_index = pcall(unpack, f, 12, ">ii<i")
  if not ok then return end
  shape_type = shape_types[shape_index]
  assert(shape_type, "This file does not appear to be a shapefile: unknown shape type: "..tonumber(shape_index))
  assert(readers[shape_type], "No reader for shape type '"..shape_type.."'")
  return readers[shape_type](f, projection, shape_type, record_length_words*2)
end


-- file objects --------------------------------------------------------------

local file_mt =
{
  read = function(t)
      return read_shape(t.file, t.projection)
    end,
  lines = function(t)
      return function() return t:read() end
    end,
  close = function(t)
      t.file:close()
    end,
}
file_mt.__index = file_mt


local function use(file, projection)
  local xmin, ymin, xmax, ymax = read_header(file)
  return setmetatable({file=file, projection=projection}, file_mt), xmin, ymin, xmax, ymax
end


local function open(filename, projection)
  local file, message = io.open(filename, "r")
  if not file then return nil, message end
  return use(file, projection)
end


------------------------------------------------------------------------------

return { use = use, open = open }


------------------------------------------------------------------------------
