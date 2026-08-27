# Editor Research References

The tracked studios are original implementations over this project's tested
codecs. The following projects were inspected locally beneath the ignored
`references/` directory to confirm format coverage and learn from established
editor workflows. None of their source code is copied into this repository.

| Project | Useful evidence | Reuse decision |
| --- | --- | --- |
| [SMB Utility](https://github.com/Maseya/SMB-Utility) | Mature visual workflow for SMB1 areas, objects, enemies, and point test play from an arbitrary position | Reference only; AGPL-3.0 code is not incorporated |
| [SMBLevelDrawer](https://github.com/IsoFrieze/SMBLevelDrawer) | Cross-version area rendering coverage for cartridge, FDS, VS., and derivative releases | Reference only; GPL-3.0 code is not incorporated |
| [smb-vanilla-port](https://github.com/nukep/smb-vanilla-port) | Engine-faithful gameplay behavior and portable runtime architecture | Behavioral reference only; no source is incorporated |
| [Level-Headed](https://github.com/Coolcord/Level-Headed) | Complete enemy identifiers, area commands, and fixed-buffer constraints | Reference only; GPL-3.0 code is not incorporated |
| [MushROMs SMB1 level format](https://github.com/bonimy/MushROMs/blob/master/doc/SMB1%20Level%20Format.md) | Bit-level documentation for headers, objects, page controls, enemies, and area transitions | Used to cross-check independently written codecs |
| [SMBMusEdit](https://github.com/anakrusis/SMBMusEdit) | Confirms that all vanilla song headers, shared streams, allocation limits, and playback need to be visible together | Reference only; the repository does not declare a software license |
| [MarioNESEditor](https://github.com/howerpower/MarioNESEditor) | Small SMB-specific CHR browser and pixel-editing workflow | Reference only; the repository does not declare a software license |
| [SMB1Base](https://github.com/smbstudio/smb1base) | Modern hacking workflow and import compatibility with established level tools | Architectural reference only |

The Pac-Man reconstruction remains the local interaction benchmark: visual
selection, direct manipulation, semantic labels, previews, undo, atomic save,
capacity feedback, isolated ROM builds, and emulator launch all belong in the
subject-specific program rather than in a generic data-tree editor.
