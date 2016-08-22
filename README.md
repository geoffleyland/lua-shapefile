# lua-shapefile - Read ESRI Shapefiles in Lua

## 1. What?

shapefile format is documented [here](http://www.esri.com/library/whitepapers/pdfs/shapefile.pdf)


## 2. Why?

Reading geographic data.


## 3. How?

``luarocks install shapefile``

then

    local sd = require"shapedir"
    for shapes, filename in sd.files("path/to/files", "filename-pattern") do
      for shape, data in shapes do
        -- something with the shape and descriptive data
      end
    end


## 4. Requirements

Lua >= 5.1 or LuaJIT >= 2.0.0.


## 5. Issues

+ Incomplete


## 6. Wishlist

+ Tests?
+ Documentation?

## 6. Alternatives

+ I don't know of any