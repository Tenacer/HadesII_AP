return {
  version = 0;
  enabled = true;

  -- Points awarded per room clear
  points_per_room = 1;
  -- Score needed to unlock each AP location check
  points_per_location = 10;

  -- Leave empty to auto-detect (recommended). Default resolves to the OS
  -- user-data dir: ~/.local/share/HadesII_AP/ on Linux/Proton,
  -- %LOCALAPPDATA%\HadesII_AP\ on native Windows.
  -- Linux/Proton override example: "Z:\\home\\yourname\\.local\\share\\HadesII_AP\\"
  -- Windows override example:      "C:\\Users\\yourname\\AppData\\Local\\HadesII_AP\\"
  ap_path = "";
}
