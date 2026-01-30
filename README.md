# GBC Limitations Tool

Aseprite script that helps with managing GBC limitations.

Made to be using for creating background for GBC games made using GB Studio.

## Features

- Counts the number of unique palettes
  - Groups palettes with less than 4 colors with 4-color palettes if possible 
- Counts the number of unique patterns
- Analyze a single layer or multiple layers
  - Supports sprite layers and tilemap layers
- Warns on palettes with more than 5 colors
  - Indicates the position of the first incorrect tile
- Export palettes (GPL format that can be reimported into Aseprite or GIMP)

## Installing

Download the release file and place the lua file in your Aseprite scripts folder. To find it open Aseprite -> File -> Scripts -> Open Scripts Folder.

Debian : `/home/USER/.config/aseprite/scripts`

## Future

- Attribute map generator for GBDK ?
- Export individual palettes 
- Tile comparison to find duplicate tile patterns (very similar tiles)
- Additional gbc sprite layer analysis
  - Separate palette and tile pattern count
- Check if colors match GBC limitations : 15-bit
