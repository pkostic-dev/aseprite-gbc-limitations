# GBC Limitations Tools

A collection of Aseprite scripts for managing Game Boy Color hardware limitations during pixel art creation. Specifically made for use with GB Studio.

## Tools

### GBC Tile Tool

Analyzes sprites for standard GBC palette compatibility. Ideal for backgrounds, tilesets, and traditional GBC game assets.

**Features:**
- Counts unique palettes and merges compatible ones
- Counts unique tile patterns (color-agnostic)
- Analyzes single or multiple layers (supports image and tilemap layers)
- Warns when tiles exceed 4 colors, shows problem tile coordinates
- Export button to generate palettes in GPL format (compatible with Aseprite and GIMP)

### GBC Actor Tool

Creates GB Studio actors with more than 3 colors using sprite layering.

**Features:**
- Analyzes 8x8 tiles and counts colors per tile
- Optimizes palette usage to minimize total palette count
- Exports layered sprites separated by palette for GB Studio import
- Warns when exceeding 8 palettes (GB Studio limit)
- Safety limit at 32 palettes to prevent crashes

## Installation

1. Download the `.lua` files from [Releases](https://github.com/pkostic-dev/aseprite-gbc-limitations/releases)
2. Place them in your Aseprite scripts folder:
   - **Linux/Debian:** `~/.config/aseprite/scripts`
   - **Windows:** `%appdata%\Aseprite\scripts\`
   - **macOS:** `~/Library/Application Support/Aseprite/scripts/`
3. In Aseprite: `File > Scripts > Rescan Scripts Folder`
4. Run via `File > Scripts > [Tool Name]`

## Usage

### GBC Tile Tool
1. Open your sprite in Aseprite
2. Run the script
3. Click "Analyze" for current layer or "Analyze All" for all visible layers
4. Review palette count and any warnings
5. Export palettes if needed

### GBC Actor Tool
1. Open your actor sprite (must be multiple of 8x8)
2. Run the script
3. Click "Analyze" to see palette breakdown
4. Click "Export" to generate layered sprite file for GB Studio

## Requirements

- Aseprite v1.2.10 or newer
- Sprite dimensions must be multiples of 8

## Future Ideas

- Attribute map generator for GBDK
- Individual palette export
- Duplicate tile pattern detection
- GBC 15-bit color validation
- Advanced sprite layer analysis

![GBC Tile Tool](https://imgur.com/jvn2BHQ.png)
![GBC Actor Tool](https://i.imgur.com/asP3pAZ.png)
