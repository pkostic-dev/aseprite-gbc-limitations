-- GBC Actor Tool
-- Analyzes sprites for multi-palette actor creation for GB Studio
-- Script version 1.0

local TILE_SIZE = 8
local MAX_COLORS_PER_SPRITE = 3  -- Excluding transparency
local MAX_PALETTES = 8
local MAX_PALETTES_LIMIT = 32  -- Hard limit to prevent crashes

local dlg = nil
local analysisResults = nil

-- ---------- Utilities ----------

-- Create a unique key for a color
local function colorKey(c)
  return string.format("%d,%d,%d,%d", c.red, c.green, c.blue, c.alpha)
end

-- Create a palette key (sorted to handle order independence)
local function paletteKey(colors)
  local keys = {}
  for k in pairs(colors) do
    table.insert(keys, k)
  end
  table.sort(keys)
  return table.concat(keys, "|")
end

-- Check if two palettes are the same (ignoring order)
local function palettesEqual(p1, p2)
  return paletteKey(p1) == paletteKey(p2)
end

-- Count colors in a palette
local function paletteSize(palette)
  local count = 0
  for _ in pairs(palette) do
    count = count + 1
  end
  return count
end

-- Convert palette to sorted array
local function paletteToArray(palette)
  local colors = {}
  for _, color in pairs(palette) do
    table.insert(colors, color)
  end
  -- Sort by brightness
  table.sort(colors, function(a, b)
    local brightnessA = a.red + a.green + a.blue
    local brightnessB = b.red + b.green + b.blue
    return brightnessA < brightnessB
  end)
  return colors
end

-- Generate all possible palette combinations for a set of colors
local function generatePaletteCombinations(colors)
  local colorList = {}
  for k, v in pairs(colors) do
    table.insert(colorList, {key = k, color = v})
  end
  
  local numColors = #colorList
  local combinations = {}
  
  -- If 3 or fewer colors, only one palette needed
  if numColors <= MAX_COLORS_PER_SPRITE then
    table.insert(combinations, colors)
    return combinations
  end
  
  -- Generate all combinations of MAX_COLORS_PER_SPRITE colors
  local function combine(start, current)
    if #current == MAX_COLORS_PER_SPRITE then
      local palette = {}
      for _, item in ipairs(current) do
        palette[item.key] = item.color
      end
      table.insert(combinations, palette)
      return
    end
    
    for i = start, numColors do
      table.insert(current, colorList[i])
      combine(i + 1, current)
      table.remove(current)
    end
  end
  
  combine(1, {})
  return combinations
end

-- ---------- Analysis ----------

local function analyzeTile(img, tx, ty)
  local tileColors = {}
  
  -- Collect all non-transparent colors in this tile
  for y = 0, TILE_SIZE - 1 do
    for x = 0, TILE_SIZE - 1 do
      local pixelX = tx * TILE_SIZE + x
      local pixelY = ty * TILE_SIZE + y
      
      if pixelX < img.width and pixelY < img.height then
        local pixelValue = img:getPixel(pixelX, pixelY)
        local color = Color(pixelValue)
        
        if color.alpha > 0 then
          tileColors[colorKey(color)] = color
        end
      end
    end
  end
  
  local colorCount = paletteSize(tileColors)
  local spritesNeeded = math.ceil(colorCount / MAX_COLORS_PER_SPRITE)
  
  return {
    x = tx,
    y = ty,
    colors = tileColors,
    colorCount = colorCount,
    spritesNeeded = spritesNeeded,
    isEmpty = colorCount == 0
  }
end

local function findOptimalPalettes(tiles)
  -- Collect all possible 3-color palettes from all tiles
  local allPalettes = {}
  local paletteToKey = {}
  
  for tileIdx, tile in ipairs(tiles) do
    if not tile.isEmpty then
      local combinations = generatePaletteCombinations(tile.colors)
      
      for _, palette in ipairs(combinations) do
        local key = paletteKey(palette)
        if not paletteToKey[key] then
          paletteToKey[key] = palette
          table.insert(allPalettes, palette)
        end
      end
    end
  end
  
  -- Use greedy set cover to find minimum palettes
  local selectedPalettes = {}
  local coveredByTile = {}
  
  -- Initialize coverage tracking
  for tileIdx, tile in ipairs(tiles) do
    if not tile.isEmpty then
      coveredByTile[tileIdx] = {}
    end
  end
  
  -- Keep adding palettes until all tiles are covered
  while true do
    -- Check palette limit
    if #selectedPalettes >= MAX_PALETTES_LIMIT then
      return nil, string.format("Palette limit exceeded (%d palettes). Sprite has too many colors.", MAX_PALETTES_LIMIT)
    end
    
    -- Check if all tiles are fully covered
    local allCovered = true
    for tileIdx, tile in ipairs(tiles) do
      if not tile.isEmpty then
        for colorK in pairs(tile.colors) do
          if not coveredByTile[tileIdx][colorK] then
            allCovered = false
            break
          end
        end
        if not allCovered then break end
      end
    end
    
    if allCovered then break end
    
    -- Find palette that covers the most uncovered colors across all tiles
    local bestPalette = nil
    local bestScore = 0
    
    for _, palette in ipairs(allPalettes) do
      local score = 0
      
      -- Count how many uncovered colors this palette would cover
      for tileIdx, tile in ipairs(tiles) do
        if not tile.isEmpty then
          for colorK in pairs(tile.colors) do
            if palette[colorK] and not coveredByTile[tileIdx][colorK] then
              score = score + 1
            end
          end
        end
      end
      
      if score > bestScore then
        bestScore = score
        bestPalette = palette
      end
    end
    
    if not bestPalette or bestScore == 0 then
      break
    end
    
    -- Add this palette
    table.insert(selectedPalettes, bestPalette)
    
    -- Mark colors as covered
    for tileIdx, tile in ipairs(tiles) do
      if not tile.isEmpty then
        for colorK in pairs(tile.colors) do
          if bestPalette[colorK] then
            coveredByTile[tileIdx][colorK] = true
          end
        end
      end
    end
  end
  
  return selectedPalettes, nil
end

local function assignPalettesToTiles(tiles, palettes)
  local tileAssignments = {}
  
  for tileIdx, tile in ipairs(tiles) do
    if not tile.isEmpty then
      local assignments = {}
      local remainingColors = {}
      
      -- Copy colors
      for k, v in pairs(tile.colors) do
        remainingColors[k] = v
      end
      
      -- Assign palettes in order
      for paletteIdx, palette in ipairs(palettes) do
        local usedInTile = false
        
        for colorK in pairs(palette) do
          if remainingColors[colorK] then
            usedInTile = true
            remainingColors[colorK] = nil
          end
        end
        
        if usedInTile then
          table.insert(assignments, paletteIdx)
        end
      end
      
      tileAssignments[tileIdx] = assignments
    end
  end
  
  return tileAssignments
end

local function analyzeSprite(sprite)
  if not sprite then
    return nil, "No sprite provided"
  end
  
  -- Check if sprite dimensions are multiples of 8
  if sprite.width % TILE_SIZE ~= 0 or sprite.height % TILE_SIZE ~= 0 then
    return nil, string.format("Sprite dimensions must be multiples of 8 (current: %dx%d)", sprite.width, sprite.height)
  end
  
  -- Get flattened image of the current frame
  local frame = app.activeFrame or sprite.frames[1]
  local img = Image(sprite.spec)
  img:drawSprite(sprite, frame)
  
  local tilesX = math.floor(sprite.width / TILE_SIZE)
  local tilesY = math.floor(sprite.height / TILE_SIZE)
  
  -- Analyze each tile
  local tiles = {}
  for ty = 0, tilesY - 1 do
    for tx = 0, tilesX - 1 do
      local tile = analyzeTile(img, tx, ty)
      table.insert(tiles, tile)
    end
  end
  
  -- Find optimal palettes
  local palettes, err = findOptimalPalettes(tiles)
  if err then
    return nil, err
  end
  
  -- Assign palettes to tiles
  local assignments = assignPalettesToTiles(tiles, palettes)
  
  -- Calculate max sprites per tile
  local maxSpritesPerTile = 0
  for _, tile in ipairs(tiles) do
    if tile.spritesNeeded > maxSpritesPerTile then
      maxSpritesPerTile = tile.spritesNeeded
    end
  end
  
  return {
    tiles = tiles,
    palettes = palettes,
    assignments = assignments,
    tilesX = tilesX,
    tilesY = tilesY,
    maxSpritesPerTile = maxSpritesPerTile,
    sourceImage = img
  }
end

-- ---------- Export ----------

local function exportSprites(results)
  local sprite = app.activeSprite
  if not sprite then return end
  
  local numPalettes = #results.palettes
  local outputWidth = results.tilesX * TILE_SIZE * numPalettes
  local outputHeight = results.tilesY * TILE_SIZE
  
  -- Create new image
  local outputImg = Image(outputWidth, outputHeight, sprite.colorMode)
  
  -- Clear to transparent
  outputImg:clear()
  
  -- Process each tile
  local tileIdx = 1
  for ty = 0, results.tilesY - 1 do
    for tx = 0, results.tilesX - 1 do
      local tile = results.tiles[tileIdx]
      
      if not tile.isEmpty then
        local tilePalettes = results.assignments[tileIdx]
        
        if tilePalettes then
          -- For each palette this tile uses
          for _, paletteIdx in ipairs(tilePalettes) do
            local palette = results.palettes[paletteIdx]
            
            -- Copy pixels that belong to this palette
            for y = 0, TILE_SIZE - 1 do
              for x = 0, TILE_SIZE - 1 do
                local srcX = tx * TILE_SIZE + x
                local srcY = ty * TILE_SIZE + y
                
                if srcX < results.sourceImage.width and srcY < results.sourceImage.height then
                  local pixelValue = results.sourceImage:getPixel(srcX, srcY)
                  local color = Color(pixelValue)
                  
                  if color.alpha > 0 then
                    local key = colorKey(color)
                    
                    -- Check if this color is in the current palette
                    if palette[key] then
                      local dstX = (paletteIdx - 1) * results.tilesX * TILE_SIZE + tx * TILE_SIZE + x
                      local dstY = ty * TILE_SIZE + y
                      
                      outputImg:drawPixel(dstX, dstY, pixelValue)
                    end
                  end
                end
              end
            end
          end
        end
      end
      
      tileIdx = tileIdx + 1
    end
  end
  
  -- Save the image
  local filename = app.fs.filePath(sprite.filename)
  if filename == "" then
    filename = "untitled"
  else
    filename = app.fs.fileTitle(filename)
  end
  
  local exportPath = app.fs.joinPath(
    app.fs.userConfigPath,
    filename .. "_gb_studio_export.png"
  )
  
  outputImg:saveAs(exportPath)
  app.alert("Exported to:\n" .. exportPath)
end

-- ---------- UI ----------

local function buildDialog(results, errorMsg)
  if dlg then
    dlg:close()
  end
  
  dlg = Dialog {
    title = "GB Studio Actor Analyzer",
    dockable = true
  }
  
  -- Analyze button
  dlg:button {
    id = "analyze_btn",
    text = "Analyze",
    focus = true,
    onclick = function()
      local sprite = app.activeSprite
      if not sprite then
        app.alert("No active sprite.")
        return
      end
      
      local data, err = analyzeSprite(sprite)
      if err then
        app.alert("Error: " .. err)
        return
      end
      
      analysisResults = data
      buildDialog(data, nil)
    end
  }
  
  -- Export button (only show if we have results)
  if results then
    dlg:button {
      id = "export_btn",
      text = "Export",
      onclick = function()
        exportSprites(analysisResults)
      end
    }
  end
  
  dlg:separator()
  
  -- Display results
  if errorMsg then
    dlg:label {
      text = "Error: " .. errorMsg
    }
  elseif results then
    local numPalettes = #results.palettes
    
    -- Summary
    dlg:label {
      text = string.format("Grid: %dx%d tiles", results.tilesX, results.tilesY)
    }
    
    dlg:label {
      text = string.format("Max sprites per tile: %d", results.maxSpritesPerTile)
    }
    
    dlg:separator()
    
    -- Palette count warning
    if numPalettes > MAX_PALETTES then
      dlg:label {
        text = string.format("Total palettes: %d ⚠", numPalettes)
      }
      dlg:label {
        text = string.format(" (GB Studio limit: %d)", MAX_PALETTES)
      }
    else
      dlg:label {
        text = string.format("Total palettes: %d", numPalettes)
      }
    end
    
    dlg:separator()
    
    -- Display palettes
    if numPalettes > 0 then
      for i, palette in ipairs(results.palettes) do
        local colors = paletteToArray(palette)
        
        dlg:separator {
          text = string.format("Palette %d (%d colors)", i, #colors)
        }
        
        dlg:shades {
          id = "palette_" .. i,
          colors = colors,
          mode = "pick"
        }
      end
    end
  else
    dlg:label {
      text = "Click 'Analyze' to analyze the sprite"
    }
  end
  
  dlg:show { wait = false }
end

-- ---------- Start ----------

buildDialog(nil, nil)
