return {
  version = 0;
  enabled = true;

  -- Fallback points awarded per room clear for unrecognized biomes.
  -- Per-biome weights live in lib/score.lua (BIOME_POINTS).
  points_per_room = 1;

  -- Font size of the on-screen AP notification toasts (sent/received/score).
  notify_font_size = 15;

  -- Leave empty to auto-detect (recommended). Default resolves to the OS
  -- user-data dir: ~/.local/share/HadesII_AP/ on Linux/Proton,
  -- %LOCALAPPDATA%\HadesII_AP\ on native Windows.
  -- Linux/Proton override example: "Z:\\home\\yourname\\.local\\share\\HadesII_AP\\"
  -- Windows override example:      "C:\\Users\\yourname\\AppData\\Local\\HadesII_AP\\"
  ap_path = "";
}
