#!/usr/bin/env python3
"""Import the pinned SMB2J ca65 listings into the project source convention."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path

from asm_style import format_file


REFERENCE_FILES = {
    "main": ("sm2main.asm", "4b6d697c84e5c8b252b5eeb9361464c146eda49f"),
    "data2": ("sm2data2.asm", "44954bf69fb2fcfb43ba20312b098201391f9a66"),
    "data3": ("sm2data3.asm", "cd242c201277eba7f381f99f8527456fb70a0dc6"),
    "data4": ("sm2data4.asm", "55220612302acc2c40fa11e1656ea075f2024366"),
}

MAIN_MODULES = (
    ("system/definitions.inc", None),
    ("system/interfaces.inc", ";SUBROUTINES IN FAMICOM DISK SYSTEM BIOS"),
    ("system/reset.asm", "Start"),
    ("rendering/vram_buffers.asm", "VRAM_AddrTable"),
    ("game/scoring.asm", "FloateyNumTileData"),
    ("rendering/palettes.asm", "ColorRotatePalette"),
    ("rendering/name_tables.asm", "InitializeNameTables"),
    ("game/mode_dispatch.asm", "GameOverSubs"),
    ("game/area_attributes.asm", "AlterAreaAttributes"),
    ("game/area_objects.asm", "Bridge_High"),
    ("game/scrolling.asm", "GetScreenPosition"),
    ("game/player_control.asm", "PlayerMovementSubs"),
    ("game/timers_and_flagpole.asm", "RunGameTimer"),
    ("game/projectiles.asm", "BulletBillXSpdData"),
    ("game/blocks.asm", "BrickQBlockMetatiles"),
    ("game/enemy_dispatch.asm", "ChkEnemyFrenzy"),
    ("game/firebars_and_spawns.asm", "FirebarSpinSpdData"),
    ("game/piranha_and_platforms.asm", "InitPiranhaPlant"),
    ("game/enemy_movement.asm", "MoveJumpingEnemy"),
    ("game/bowser.asm", "PRandomSubtracter"),
    ("rendering/enemy_graphics.asm", "FlameTimerData"),
    ("game/platforms.asm", "YMovingPlatform"),
    ("game/player_enemy_collision.asm", "ResidualXSpdData"),
    ("game/platform_collision.asm", "ProcSPlatCollisions"),
    ("game/background_collision.asm", "SolidMTileUpperExt"),
    ("game/bounding_boxes.asm", "BoundBoxCtrlData"),
    ("rendering/sprite_helpers.asm", "MoveSixSpritesOffscreen"),
    ("rendering/enemy_sprites.asm", "EnemyGfxHandler"),
    ("rendering/block_sprites.asm", "DefaultBlockObjTiles"),
    ("rendering/player_sprites.asm", "PlayerGfxTblOffsets"),
    ("rendering/relative_positions.asm", "RelativePlayerPosition"),
    ("system/disk_loading.asm", "AttractModeSubs"),
    ("game/continue_menu.asm", "JumpFrictionData"),
    ("data/ui_messages.asm", "PlayerNameData"),
    ("data/course_bank.asm", "E_CastleArea1"),
    ("audio/engine_core.asm", "SoundEngine"),
    ("audio/music_engine.asm", "ContinueMusic"),
    ("audio/music_data.asm", "Star_CloudMData"),
)

OVERLAY_MODULES = {
    "data2": (("course_bank.asm", None),),
    "data3": (
        ("ending.asm", None),
        ("world_9.asm", "E_CastleArea9"),
        ("ending_audio.asm", "AlternateSoundEngine"),
        ("victory_music.asm", "MusicHeaderOffsetData"),
    ),
    "data4": (
        ("worlds_a_d_setup.asm", None),
        ("wind_and_pipes.asm", "UpsideDownPipe_High"),
        ("course_bank.asm", "E_CastleArea11"),
    ),
}

PAYLOAD_NAMES = {
    "main": "main",
    "data2": "supplemental_courses",
    "data3": "ending",
    "data4": "hard_courses",
}

COMMON_GAMEPLAY_RENAMES = {
    (payload, original): current
    for payload in ("data2", "data4")
    for original, current in {
        "UpsideDownPipe_High": "handler_late_fds_upside_down_pipe_high",
        "UpsideDownPipe_Low": "handler_late_fds_upside_down_pipe_low",
        "UDP": "bra_late_fds_render_upside_down_pipe_body",
        "NoUDP": "bra_late_fds_finish_upside_down_pipe",
        "MoveUpsideDownPiranhaP": (
            "handler_late_fds_move_upside_down_piranha_plant"
        ),
        "SetupToMovePPlant": "bra_late_fds_select_upside_down_piranha_limit",
        "RiseFallPiranhaPlant": "bra_late_fds_move_upside_down_piranha",
        "ExMoveUDPP": "bra_late_fds_exit_upside_down_piranha_movement",
    }.items()
}

COMMON_HARD_COURSE_RENAMES = {
    ("data4", "FindAreaPointer"): "handler_late_fds_get_hard_course_descriptor",
    ("data4", "GetAreaDataAddrs"): "handler_late_fds_load_hard_course_streams",
    ("data4", "StoreFore"): "bra_late_fds_store_hard_course_foreground_scenery",
    ("data4", "StoreStyle"): "bra_late_fds_store_hard_course_area_style",
    ("data4", "ChangeHalfwayPages"): (
        "sub_late_fds_initialize_hard_course_checkpoints"
    ),
    ("data4", "CHalfL"): "bra_late_fds_copy_hard_course_checkpoints",
}

SMB2_SHARED_GAMEPLAY_INTERFACE = (
    "; Bind the shared late-FDS gameplay runtime to SMB2 symbols",
    "",
    "con_late_fds_upside_down_piranha_object = $04",
    "sub_late_fds_get_pipe_height = sub_smb2_main_get_pipe_height",
    "sub_late_fds_find_empty_enemy_slot = sub_smb2_main_find_empty_enemy_slot",
    "sub_late_fds_initialize_upside_down_piranha = sub_smb2_main_setup_piranha_plant",
    "tbl_late_fds_vertical_pipe_metatiles = off_smb2_main_vertical_pipe_metatiles",
    "sub_late_fds_render_under_part = sub_smb2_main_render_under_part",
    "",
    "ram_area_object_length = AreaObjectLength",
    "ram_enemy_y_position = Enemy_Y_Position",
    "ram_piranha_plant_down_y_pos = PiranhaPlantDownYPos",
    "ram_piranha_plant_up_y_pos = PiranhaPlantUpYPos",
    "ram_piranha_plant_move_flag = PiranhaPlant_MoveFlag",
    "ram_metatile_buffer = MetatileBuffer",
    "ram_enemy_state = Enemy_State",
    "ram_enemy_frame_timer = EnemyFrameTimer",
    "ram_piranha_plant_y_speed = PiranhaPlant_Y_Speed",
    "ram_timer_control = TimerControl",
    "",
)

SMB2_SHARED_HARD_COURSE_INTERFACE = (
    "; Bind the shared late-FDS hard-course runtime to SMB2 symbols",
    "",
    "ram_late_fds_hard_course_number = WorldNumber",
    "ram_late_fds_hard_course_sub = AreaNumber",
    "tbl_late_fds_hard_course_world_offsets = tbl_smb2_data4_world_area_pointer_offsets",
    "tbl_late_fds_hard_course_area_offsets = tbl_smb2_data4_area_pointers",
    "sub_late_fds_get_course_type = sub_smb2_main_get_area_type",
    "tbl_late_fds_hard_course_enemy_pages = tbl_smb2_data4_enemy_data_offsets_by_area_type",
    "tbl_late_fds_hard_course_enemy_addresses = off_smb2_data4_enemy_data_addrs",
    "tbl_late_fds_hard_course_area_pages = tbl_smb2_data4_area_object_data_offsets_by_area_type",
    "tbl_late_fds_hard_course_area_addresses = off_smb2_data4_area_data_addrs",
    "",
    "ram_area_pointer = AreaPointer",
    "ram_area_addrs_l_offset = AreaAddrsLOffset",
    "ram_enemy_data_high = EnemyDataHigh",
    "ram_enemy_data_low = EnemyDataLow",
    "ram_area_type = AreaType",
    "ram_area_data_high = AreaDataHigh",
    "ram_area_data_low = AreaDataLow",
    "ram_area_data = AreaData",
    "ram_background_color_ctrl = BackgroundColorCtrl",
    "ram_foreground_scenery = ForegroundScenery",
    "ram_player_entrance_ctrl = PlayerEntranceCtrl",
    "ram_game_timer_setting = GameTimerSetting",
    "ram_terrain_control = TerrainControl",
    "ram_background_scenery = BackgroundScenery",
    "ram_cloud_type_override = CloudTypeOverride",
    "ram_area_style = AreaStyle",
    "",
    "off_late_fds_hard_course_checkpoint_starts = tbl_smb2_data4_ato_d_halfway_pages",
    "tbl_late_fds_halfway_page_nibbles = tbl_smb2_main_halfway_page_nibbles",
    "",
)

MNEMONICS = frozenset(
    """
    ADC AND ASL BCC BCS BEQ BIT BMI BNE BPL BRK BVC BVS CLC CLD CLI CLV
    CMP CPX CPY DEC DEX DEY EOR INC INX INY JMP JSR LDA LDX LDY LSR NOP
    ORA PHA PHP PLA PLP ROL ROR RTI RTS SBC SEC SED SEI STA STX STY TAX
    TAY TSX TXA TXS TYA
    """.split()
)
BRANCHES = frozenset({"BCC", "BCS", "BEQ", "BMI", "BNE", "BPL", "BVC", "BVS"})
LABEL_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*):(?P<tail>.*)$")
ASSIGNMENT_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=")
IMPORT_RE = re.compile(r"^\s*\.import\s+(.+?)(?:\s*;.*)?$", re.IGNORECASE)
EXPORT_RE = re.compile(r"^\s*\.export\s+(.+?)(?:\s*;.*)?$", re.IGNORECASE)
TOKEN_RE = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]*\b")
STATEMENT_RE = re.compile(r"^\s*([A-Za-z]{3})\b(?:\s+([^;]+))?", re.IGNORECASE)
DATA_DIRECTIVE_RE = re.compile(r"^\s*\.(?:byte|word|addr|dbyt|res)\b", re.IGNORECASE)

HARDWARE_DEFINITIONS = (
    "PPU_CTRL              = $2000",
    "PPU_MASK              = $2001",
    "PPU_STATUS            = $2002",
    "PPU_SPR_ADDR          = $2003",
    "PPU_SPR_DATA          = $2004",
    "PPU_SCROLL            = $2005",
    "PPU_ADDRESS           = $2006",
    "PPU_DATA              = $2007",
    "SND_REGISTER          = $4000",
    "SND_SQUARE1_REG       = $4000",
    "SND_SQUARE2_REG       = $4004",
    "SND_TRIANGLE_REG      = $4008",
    "SND_NOISE_REG         = $400c",
    "SND_DELTA_REG         = $4010",
    "SND_MASTERCTRL_REG    = $4015",
    "SPR_DMA               = $4014",
    "JOYPAD_PORT           = $4016",
    "JOYPAD_PORT1          = $4016",
    "JOYPAD_PORT2          = $4017",
    "FDS_IRQTIMER_LOW      = $4020",
    "FDS_IRQTIMER_HIGH     = $4021",
    "FDS_IRQTIMER_CTRL     = $4022",
    "FDS_CTRL_REG          = $4025",
    "FDS_STATUS            = $4030",
    "FDS_DRIVE_STATUS      = $4032",
    "FDSSND_WAVERAM        = $4040",
    "FDSSND_VOLUMECTRL     = $4080",
    "FDSSND_FREQLOW        = $4082",
    "FDSSND_FREQHIGH       = $4083",
    "FDSSND_SWEEPCTRL      = $4084",
    "FDSSND_SWEEPBIAS      = $4085",
    "FDSSND_MODFREQLOW     = $4086",
    "FDSSND_MODFREQHIGH    = $4087",
    "FDSSND_MODTBLAPPEND   = $4088",
    "FDSSND_WAVEENABLEWR   = $4089",
)
HARDWARE_SYMBOLS = frozenset(line.split("=", 1)[0].strip() for line in HARDWARE_DEFINITIONS)
ROLE_PREFIXES = frozenset({"bra", "handler", "loc", "off", "sub", "tbl", "unused", "vec"})

# Names that exist only in the later engine and whose reference abbreviations are
# expanded by direct control-flow or adjacent-comment evidence.
SMB2_SEMANTIC_OVERRIDES = {
    "BThr": "gate_wind_push_by_frame",
    "DLLoop": "draw_wind_leaves_loop",
    "DrawLeaf": "draw_wind_leaf",
    "ExBlow": "exit_wind_player_push",
    "ExMoveUDPP": "exit_upside_down_piranha_movement",
    "ExSimW": "exit_wind_simulation",
    "MLPLoop": "update_wind_leaf_positions_loop",
    "MoveUpsideDownPiranhaP": "move_upside_down_piranha_plant",
    "NoUDP": "finish_upside_down_pipe",
    "UDP": "render_upside_down_pipe_body",
    "WOn": "store_wind_state",
    "BlueULoop": "write_blue_transition_palette_loop",
    "BlueUpd": "update_blue_transition",
    "DrawFlashMRetainers": "draw_flashing_mushroom_retainers",
    "DrawMRetainers": "draw_mushroom_retainers",
    "DrawMRetLoop": "draw_mushroom_retainers_loop",
    "ELL": "erase_lives_lines_loop",
    "ExAEL": "advance_after_extra_life_awards",
    "ExFade": "exit_blue_fade",
    "ExRMR": "exit_mushroom_retainer_sequence",
    "FDSBIOS_WRITEFILE": "fds_bios_write_file",
    "FDSSND_EnvModRun": "fds_sound_envelope_modulation_run",
    "FDSSND_EnvModStart": "fds_sound_envelope_modulation_start",
    "FDSSND_NoteHandler": "fds_sound_note_handler",
    "FlashMRetainers": "flash_mushroom_retainers",
    "FlashMRSpriteDataOfs": "flashing_mushroom_retainer_sprite_data_offsets",
    "FullV": "set_full_wave_volume",
    "GWDLoop": "write_waveform_data_loop",
    "IncVMC": "increment_victory_message_counter",
    "LowV": "set_low_wave_volume",
    "MRetainerXPos": "mushroom_retainer_x_positions",
    "MRetainerYPos": "mushroom_retainer_y_positions",
    "MRSpriteDataOfs": "mushroom_retainer_sprite_data_offsets",
    "MTableL": "write_modulation_table_loop",
    "NextMRet": "advance_mushroom_retainer",
    "NoFW9": "finish_fantasy_world_9_message",
    "NotYet": "wait_for_extra_life_award",
    "OddT": "write_modulation_table_nibble",
    "PrintVM": "print_victory_message",
    "SNameL": "select_victory_player_name",
    "SetFreq_FDS": "set_fds_frequency",
    "SetupMRet": "setup_mushroom_retainer",
    "SetWMVol": "set_wave_output_volume",
    "VMsgNL": "write_victory_player_name_loop",
    "VictoryMusEnvData": "victory_music_envelope_data",
    "VictoryPart1AHdr": "victory_part_1a_header",
    "VictoryPart1BHdr": "victory_part_1b_header",
    "VictoryPart2AHdr": "victory_part_2a_header",
    "VictoryPart2BHdr": "victory_part_2b_header",
    "VictoryPart2CHdr": "victory_part_2c_header",
    "VictoryPart2DHdr": "victory_part_2d_header",
    "VolEnvData1": "volume_envelope_data_1",
    "VolEnvData2": "volume_envelope_data_2",
    "Wave1Hdr": "waveform_1_header",
    "Wave2Hdr": "waveform_2_header",
    "BaseW": "use_base_world_number",
    "BnceH": "set_high_enemy_bounce",
    "BnceL": "set_low_enemy_bounce",
    "BrdgSkip": "skip_bridge_player_draw",
    "ChgSel": "update_continue_selection",
    "ChgSelLoop": "draw_continue_selection_loop",
    "ChkVOffscr": "check_vertical_offscreen",
    "DTTLoop": "decrement_timer_loop",
    "DinP": "defeat_piranha_plant",
    "EraseClM": "erase_climbing_metatile_loop",
    "EvenDgs": "write_even_score_digits",
    "ExBalP": "exit_balance_platform",
    "ExEWA": "exit_end_castle_award",
    "ExIDBChk": "exit_enemy_background_check",
    "ExOGSS": "exit_player_scroll_update",
    "ExRGO": "exit_game_over_routine",
    "ExWGT": "exit_game_timer_update",
    "GreenJS": "use_green_jumpspring",
    "GrnJS": "draw_green_jumpspring",
    "ISCont": "initialize_continue_score_loop",
    "KKCheck": "check_bowser_enemy_slot",
    "LELoop": "copy_disk_error_message_loop",
    "LW14Files": "select_worlds_1_through_4_files",
    "MPhyLoop": "modify_player_physics_loop",
    "NoCHWP": "finish_halfway_page_check",
    "NoEL4F": "award_flagpole_points",
    "NoFWks": "skip_fireworks",
    "NoHBI": "finish_hammer_bro_initialization",
    "NoJs": "skip_jumpspring_setup",
    "NoLoadHW": "finish_hard_world_load",
    "NoSc4F": "finish_flagpole_score_award",
    "NoSkidS": "skip_skid_sound",
    "PatchPP": "patch_piranha_plant",
    "PrintToTS": "write_title_screen_star",
    "ProcVO": "process_vine_object",
    "RedJS": "use_red_jumpspring",
    "RedPP": "use_red_piranha_plant",
    "ScrnSwch": "apply_screen_enable_state",
    "SetDY": "set_destination_y_position",
    "SetJSF": "set_jumpspring_force",
    "SetLakXY": "set_lakitu_position",
    "SetLowLY": "set_lower_lakitu_y_position",
    "SetS2S": "store_games_beaten_count",
    "StG": "start_selected_game",
    "WNumD": "format_world_number_for_display",
    "WZMLoop": "write_warp_zone_message_loop",
}


@dataclass(frozen=True)
class SymbolKey:
    payload: str
    original: str
    kind: str


@dataclass
class Listing:
    payload: str
    path: Path
    lines: list[str]
    labels: dict[str, SymbolKey]
    assignments: dict[str, SymbolKey]
    imports: set[str]
    exports: set[str]


def fail(message: str) -> None:
    print(f"[ERROR] {message}", file=sys.stderr)
    raise SystemExit(1)


def sha1(payload: bytes) -> str:
    return hashlib.sha1(payload).hexdigest()


def snake_case(name: str) -> str:
    value = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", name)
    value = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", value)
    value = re.sub(r"[^A-Za-z0-9]+", "_", value)
    value = re.sub(r"_+", "_", value).strip("_").lower()
    return value or "symbol"


def comma_symbols(match: re.Match[str] | None) -> set[str]:
    if match is None:
        return set()
    return {item.strip() for item in match.group(1).split(",") if item.strip()}


def load_listing(payload: str, path: Path, expected_hash: str) -> Listing:
    raw = path.read_bytes()
    actual_hash = sha1(raw)
    if actual_hash != expected_hash:
        fail(
            f"reference listing hash mismatch for {path}: expected {expected_hash}, "
            f"got {actual_hash}"
        )
    text = raw.decode("ascii").replace("\r\n", "\n").replace("\r", "\n")
    lines = text.splitlines()
    labels: dict[str, SymbolKey] = {}
    assignments: dict[str, SymbolKey] = {}
    imports: set[str] = set()
    exports: set[str] = set()
    for number, line in enumerate(lines, start=1):
        label = LABEL_RE.match(line)
        if label is not None:
            name = label.group(1)
            if name in labels:
                fail(f"duplicate label {name} in {path}:{number}")
            labels[name] = SymbolKey(payload, name, "label")
        assignment = ASSIGNMENT_RE.match(line)
        if assignment is not None:
            name = assignment.group(1)
            assignments[name] = SymbolKey(payload, name, "assignment")
        imports.update(comma_symbols(IMPORT_RE.match(line)))
        exports.update(comma_symbols(EXPORT_RE.match(line)))
    return Listing(payload, path, lines, labels, assignments, imports, exports)


def exported_symbols(listings: dict[str, Listing]) -> dict[str, SymbolKey]:
    result: dict[str, SymbolKey] = {}
    for listing in listings.values():
        for name in listing.exports:
            key = listing.labels.get(name) or listing.assignments.get(name)
            if key is None:
                fail(f"export {name} has no definition in {listing.path}")
            if name in result:
                fail(f"export {name} is ambiguous between payloads")
            result[name] = key
    return result


def resolve_symbol(
    listing: Listing, name: str, exports: dict[str, SymbolKey]
) -> SymbolKey | None:
    local = listing.labels.get(name) or listing.assignments.get(name)
    if local is not None:
        return local
    if name in listing.imports:
        return exports.get(name)
    return None


def code_without_comment(line: str) -> str:
    return line.split(";", 1)[0].rstrip()


def statement_after_label(listing: Listing, index: int) -> str:
    label = LABEL_RE.match(listing.lines[index])
    if label is None:
        raise AssertionError("label index does not identify a label")
    tail = label.group("tail").strip()
    if tail:
        return tail
    for following in listing.lines[index + 1 :]:
        code = code_without_comment(following).strip()
        if not code:
            continue
        nested = LABEL_RE.match(code)
        if nested is not None:
            tail = nested.group("tail").strip()
            if tail:
                return tail
            continue
        return code
    return ""


def collect_roles(
    listings: dict[str, Listing], exports: dict[str, SymbolKey]
) -> tuple[dict[SymbolKey, set[str]], set[SymbolKey]]:
    roles: dict[SymbolKey, set[str]] = {
        key: set()
        for listing in listings.values()
        for key in (*listing.labels.values(), *listing.assignments.values())
    }
    address_references: set[SymbolKey] = set()
    for listing in listings.values():
        for line in listing.lines:
            code = code_without_comment(line)
            inline_label = LABEL_RE.match(code)
            if inline_label is not None:
                code = inline_label.group("tail").strip()
                if not code:
                    continue
            statement = STATEMENT_RE.match(code)
            if statement is not None:
                mnemonic = statement.group(1).upper()
                operand = (statement.group(2) or "").strip()
                target_match = re.match(r"([A-Za-z_][A-Za-z0-9_]*)\b", operand)
                if target_match is not None:
                    key = resolve_symbol(listing, target_match.group(1), exports)
                    if key is not None:
                        if mnemonic == "JSR":
                            roles[key].add("sub")
                        elif mnemonic in BRANCHES:
                            roles[key].add("branch")
                        elif mnemonic == "JMP":
                            roles[key].add("jump")
                for token in TOKEN_RE.findall(operand):
                    key = resolve_symbol(listing, token, exports)
                    if key is not None:
                        address_references.add(key)
            elif DATA_DIRECTIVE_RE.match(code):
                for token in TOKEN_RE.findall(code):
                    key = resolve_symbol(listing, token, exports)
                    if key is not None:
                        roles[key].add("address_table")
                        address_references.add(key)
    return roles, address_references


def label_is_code(listing: Listing, key: SymbolKey) -> bool:
    for index, line in enumerate(listing.lines):
        label = LABEL_RE.match(line)
        if label is None or label.group(1) != key.original:
            continue
        statement = statement_after_label(listing, index)
        match = STATEMENT_RE.match(statement)
        return match is not None and match.group(1).upper() in MNEMONICS
    raise AssertionError(f"label {key.original} not found")


def role_prefix(
    listing: Listing,
    key: SymbolKey,
    roles: dict[SymbolKey, set[str]],
    address_references: set[SymbolKey],
) -> str:
    evidence = roles[key]
    lower = key.original.lower()
    if "sub" in evidence:
        return "sub"
    if key.kind == "assignment":
        return "con"
    if lower in {"nmi", "irq", "reset"} or lower.endswith(("_nmi", "_irq")):
        return "vec"
    if lower.startswith("unused"):
        return "unused"
    if label_is_code(listing, key):
        if "branch" in evidence:
            return "bra"
        if "address_table" in evidence:
            return "handler"
        return "loc"
    if lower.startswith(("e_", "l_")):
        return "off"
    if any(word in lower for word in ("table", "tbl", "lookup", "offset")):
        return "tbl"
    if key in address_references and any(
        word in lower for word in ("data", "message", "msg", "music", "header", "palette")
    ):
        return "off"
    return "tbl"


def semantic_stems(path: Path) -> dict[str, str]:
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read SMB1 semantic provenance {path}: {exc}")
    stems: dict[str, str] = {}
    for original, current, _current_path in document.get("renames", []):
        prefix, separator, remainder = current.partition("_")
        if not separator or prefix not in ROLE_PREFIXES or not remainder:
            fail(f"invalid semantic provenance target for {original}: {current}")
        stems[original] = remainder
    return stems


def build_renames(
    listings: dict[str, Listing],
    exports: dict[str, SymbolKey],
    semantic_names: dict[str, str] | None = None,
) -> dict[SymbolKey, str]:
    semantic_names = semantic_names or {}
    roles, address_references = collect_roles(listings, exports)
    renames: dict[SymbolKey, str] = {}
    used: dict[str, SymbolKey] = {}
    for payload, listing in listings.items():
        keys = [*listing.labels.values()]
        keys.extend(key for key in listing.assignments.values() if "sub" in roles[key])
        for key in keys:
            common_name = COMMON_GAMEPLAY_RENAMES.get((payload, key.original))
            if common_name is None:
                common_name = COMMON_HARD_COURSE_RENAMES.get(
                    (payload, key.original)
                )
            if common_name is not None:
                renames[key] = common_name
                continue
            prefix = role_prefix(listing, key, roles, address_references)
            stem = semantic_names.get(key.original, snake_case(key.original))
            base = f"{prefix}_smb2_{payload}_{stem}"
            candidate = base
            suffix = 2
            while candidate in used and used[candidate] != key:
                candidate = f"{base}_variant_{suffix}"
                suffix += 1
            used[candidate] = key
            renames[key] = candidate
    return renames


def replacement_for(
    listing: Listing,
    token: str,
    exports: dict[str, SymbolKey],
    renames: dict[SymbolKey, str],
) -> str:
    key = resolve_symbol(listing, token, exports)
    return renames.get(key, token) if key is not None else token


def transform_line(
    listing: Listing,
    line: str,
    exports: dict[str, SymbolKey],
    renames: dict[SymbolKey, str],
) -> str:
    before, separator, comment = line.partition(";")
    assignment = ASSIGNMENT_RE.match(before)
    if assignment is not None and assignment.group(1) in HARDWARE_SYMBOLS:
        return ""

    def replace(match: re.Match[str]) -> str:
        return replacement_for(listing, match.group(0), exports, renames)

    transformed = TOKEN_RE.sub(replace, before)
    return transformed + (separator + comment if separator else "")


def split_at_anchors(
    listing: Listing, modules: tuple[tuple[str, str | None], ...]
) -> list[tuple[str, list[str]]]:
    starts: list[tuple[str, int]] = []
    for filename, anchor in modules:
        if anchor is None:
            index = 0
        elif anchor.startswith(";"):
            try:
                index = listing.lines.index(anchor)
            except ValueError:
                fail(f"module anchor {anchor!r} not found in {listing.path}")
        else:
            index = next(
                (
                    line_index
                    for line_index, line in enumerate(listing.lines)
                    if (match := LABEL_RE.match(line)) is not None
                    and match.group(1) == anchor
                ),
                -1,
            )
            if index < 0:
                fail(f"label anchor {anchor!r} not found in {listing.path}")
        starts.append((filename, index))
    indexes = [index for _, index in starts]
    if indexes != sorted(indexes) or len(indexes) != len(set(indexes)):
        fail(f"module anchors are not strictly ordered for {listing.path}")
    result: list[tuple[str, list[str]]] = []
    for position, (filename, start) in enumerate(starts):
        end = starts[position + 1][1] if position + 1 < len(starts) else len(listing.lines)
        result.append((filename, listing.lines[start:end]))
    return result


def wrapper(
    payload: str, load_address: int, hardware_include: str, includes: list[str]
) -> str:
    semantic_name = PAYLOAD_NAMES[payload]
    lines = [
        f"; Super Mario Bros. 2 {semantic_name.replace('_', '-')} payload",
        "; Reconstructed from the pinned doppelganger ca65 listing",
        "",
        f".scope smb2_{semantic_name}",
        f'.include "{hardware_include}"',
        f".org ${load_address:04x}",
    ]
    lines.extend(f'.include "{path}"' for path in includes)
    lines.extend((".reloc", f".endscope", ""))
    return "\n".join(lines)


def promote_common_gameplay(lines: list[str]) -> list[str]:
    def label_index(name: str, start: int = 0) -> tuple[int, str]:
        for index in range(start, len(lines)):
            match = LABEL_RE.match(lines[index])
            if match is not None and match.group(1) == name:
                return index, match.group("tail").strip()
        fail(f"shared late-FDS gameplay label is missing: {name}")

    start, _ = label_index("handler_late_fds_upside_down_pipe_high")
    end, tail = label_index(
        "bra_late_fds_exit_upside_down_piranha_movement", start
    )
    if tail.upper() != "RTS":
        end += 1
        while end < len(lines) and not lines[end].strip():
            end += 1
        if end >= len(lines) or lines[end].strip().upper() != "RTS":
            fail("shared late-FDS gameplay boundary does not end with RTS")
    return [
        *lines[:start],
        '.include "../shared_gameplay_interface.inc"',
        '.include "../../../common/gameplay/upside_down_pipe.asm"',
        *lines[end + 1 :],
    ]


def promote_common_hard_course_runtime(lines: list[str]) -> list[str]:
    def label_index(name: str, start: int = 0) -> tuple[int, str]:
        for index in range(start, len(lines)):
            match = LABEL_RE.match(lines[index])
            if match is not None and match.group(1) == name:
                return index, match.group("tail").strip()
        fail(f"shared hard-course label is missing: {name}")

    def routine_end(label: str, start: int = 0) -> tuple[int, int]:
        label_start, tail = label_index(label, start)
        end = label_start
        if tail.upper() != "RTS":
            end += 1
            while end < len(lines) and lines[end].strip().upper() != "RTS":
                end += 1
            if end >= len(lines):
                fail(f"shared hard-course routine does not end with RTS: {label}")
        return label_start, end

    loader_start, loader_end = routine_end(
        "handler_late_fds_get_hard_course_descriptor"
    )
    _, loader_end = routine_end(
        "handler_late_fds_load_hard_course_streams", loader_start
    )
    checkpoint_start, checkpoint_end = routine_end(
        "sub_late_fds_initialize_hard_course_checkpoints", loader_end
    )
    return [
        *lines[:loader_start],
        '.include "shared_interface.inc"',
        '.include "../../../common/game/hard_course_loader.asm"',
        *lines[loader_end + 1 : checkpoint_start],
        '.include "../../../common/game/hard_course_checkpoints.asm"',
        *lines[checkpoint_end + 1 :],
    ]


def collapse_main_unused_padding(lines: list[str]) -> list[str]:
    start = next(
        (
            index
            for index, line in enumerate(lines)
            if line.replace(" ", "").lower() == ";abunchofunusedspace"
        ),
        None,
    )
    if start is None:
        fail("SMB2 main unused padding marker is missing")
    end = start + 1
    values: list[str] = []
    while end < len(lines) and lines[end].strip().startswith(".byte "):
        values.extend(value.strip() for value in lines[end].split(".byte ", 1)[1].split(","))
        end += 1
    if values != ["$ff"] * 83:
        fail(f"SMB2 main unused padding differs: expected 83 bytes, found {len(values)}")
    return [*lines[: start + 1], "    .res 83, $ff", *lines[end:]]


def write_sources(
    project_root: Path,
    listings: dict[str, Listing],
    exports: dict[str, SymbolKey],
    renames: dict[SymbolKey, str],
) -> list[Path]:
    platform_root = project_root / "src" / "platforms" / "late_fds" / "smb2"
    revision_root = project_root / "src" / "revisions" / "smb2"
    for source_root in (platform_root, revision_root):
        if source_root.exists():
            shutil.rmtree(source_root)
        source_root.mkdir(parents=True)
    written: list[Path] = []

    hardware_path = platform_root / "system" / "hardware.inc"
    hardware_path.parent.mkdir(parents=True, exist_ok=True)
    hardware_path.write_text(
        "\n".join(
            (
                "; SMB2-owned NES and Famicom Disk System hardware registers",
                "",
                *HARDWARE_DEFINITIONS,
                "",
            )
        ),
        encoding="ascii",
        newline="\n",
    )
    format_file(hardware_path)
    written.append(hardware_path)

    shared_interface_path = platform_root / "overlays" / "shared_gameplay_interface.inc"
    shared_interface_path.parent.mkdir(parents=True, exist_ok=True)
    shared_interface_path.write_text(
        "\n".join(SMB2_SHARED_GAMEPLAY_INTERFACE),
        encoding="ascii",
        newline="\n",
    )
    format_file(shared_interface_path)
    written.append(shared_interface_path)

    hard_interface_path = (
        platform_root / "overlays" / "hard_courses" / "shared_interface.inc"
    )
    hard_interface_path.parent.mkdir(parents=True, exist_ok=True)
    hard_interface_path.write_text(
        "\n".join(SMB2_SHARED_HARD_COURSE_INTERFACE),
        encoding="ascii",
        newline="\n",
    )
    format_file(hard_interface_path)
    written.append(hard_interface_path)

    module_sets = {"main": MAIN_MODULES, **OVERLAY_MODULES}
    load_addresses = {"main": 0x6000, "data2": 0xC470, "data3": 0xC5D0, "data4": 0xC2B4}
    for payload, listing in listings.items():
        semantic_name = PAYLOAD_NAMES[payload]
        base = (
            platform_root
            if payload == "main"
            else platform_root / "overlays" / semantic_name
        )
        includes: list[str] = []
        for relative_name, raw_lines in split_at_anchors(listing, module_sets[payload]):
            target = base / relative_name
            target.parent.mkdir(parents=True, exist_ok=True)
            transformed = [
                transform_line(listing, line, exports, renames) for line in raw_lines
            ]
            if (payload, relative_name) in {
                ("data2", "course_bank.asm"),
                ("data4", "wind_and_pipes.asm"),
            }:
                transformed = promote_common_gameplay(transformed)
            if (payload, relative_name) == ("data4", "worlds_a_d_setup.asm"):
                transformed = promote_common_hard_course_runtime(transformed)
            if (payload, relative_name) == ("main", "data/course_bank.asm"):
                transformed = collapse_main_unused_padding(transformed)
            target.write_text("\n".join(transformed) + "\n", encoding="ascii", newline="\n")
            format_file(target)
            written.append(target)
            include = "../../platforms/late_fds/smb2/" + target.relative_to(
                platform_root
            ).as_posix()
            includes.append(include)

        wrapper_path = revision_root / f"{semantic_name}.asm"
        wrapper_path.parent.mkdir(parents=True, exist_ok=True)
        wrapper_path.write_text(
            wrapper(
                payload,
                load_addresses[payload],
                "../../platforms/late_fds/smb2/system/hardware.inc",
                includes,
            ),
            encoding="ascii",
            newline="\n",
        )
        format_file(wrapper_path)
        written.append(wrapper_path)

    build_path = revision_root / "build.asm"
    build_path.write_text(
        "\n".join(
            (
                "; Assemble the four independently loaded SMB2 program payloads",
                '.include "main.asm"',
                '.include "supplemental_courses.asm"',
                '.include "ending.asm"',
                '.include "hard_courses.asm"',
                "",
            )
        ),
        encoding="ascii",
        newline="\n",
    )
    format_file(build_path)
    written.append(build_path)
    return written


def write_provenance(
    project_root: Path,
    listings: dict[str, Listing],
    renames: dict[SymbolKey, str],
    semantic_names: dict[str, str],
    reviewed_semantic_names: dict[str, str],
) -> Path:
    current_paths: dict[str, str] = {}
    source_roots = (
        project_root / "src" / "revisions" / "smb2",
        project_root / "src" / "platforms" / "late_fds" / "smb2",
        project_root / "src" / "platforms" / "late_fds" / "common",
    )
    source_paths = sorted(path for root in source_roots for path in root.rglob("*"))
    for source_path in source_paths:
        if not source_path.is_file() or source_path.suffix.lower() not in {".asm", ".inc"}:
            continue
        relative_path = source_path.relative_to(project_root).as_posix()
        for line in source_path.read_text(encoding="ascii").splitlines():
            definition = re.match(r"^([a-z][a-z0-9_]*)\s*(?::|=)", line)
            if definition is not None:
                current_paths[definition.group(1)] = relative_path
    records = []
    for key, current in sorted(
        renames.items(), key=lambda item: (item[0].payload, item[0].original.lower())
    ):
        if current not in current_paths:
            fail(f"renamed symbol is absent from generated source: {current}")
        records.append(
            {
                "payload": key.payload,
                "original": key.original,
                "current": current,
                "current_path": current_paths[current],
                "kind": key.kind,
                "naming_basis": (
                    "reviewed-smb1-semantics"
                    if key.original in reviewed_semantic_names
                    else (
                        "reviewed-smb2-semantics"
                        if key.original in SMB2_SEMANTIC_OVERRIDES
                        else "smb2-reference-semantics"
                    )
                ),
            }
        )
    document = {
        "schema_version": 1,
        "description": (
            "Direct provenance map from the pinned SMB2J ca65 listings to the "
            "reviewed project symbols; source line numbers are intentionally omitted."
        ),
        "source": {
            "name": "doppelganger SMB2J disassembly, ca65 port",
            "url": "https://github.com/threecreepio/smb2j-disassembly",
            "commit": "9c40114626ecd07f13e16d5e67e217b98482d7af",
            "listings": {
                payload: {
                    "file": REFERENCE_FILES[payload][0],
                    "sha1": REFERENCE_FILES[payload][1],
                }
                for payload in REFERENCE_FILES
            },
        },
        "counts": {
            "labels": sum(len(listing.labels) for listing in listings.values()),
            "renamed_assignments": sum(key.kind == "assignment" for key in renames),
            "reviewed_smb1_semantics": sum(
                key.original in reviewed_semantic_names for key in renames
            ),
            "reviewed_smb2_semantics": sum(
                key.original in SMB2_SEMANTIC_OVERRIDES
                and key.original not in reviewed_semantic_names
                for key in renames
            ),
            "records": len(records),
            "project_additions": 1,
        },
        "project_additions": [
            {
                "current": "unused_late_fds_upside_down_pipe_return",
                "current_path": (
                    "src/platforms/late_fds/common/gameplay/upside_down_pipe.asm"
                ),
                "reason": (
                    "Named unreachable byte retained by the shared ANN and SMB2 "
                    "upside-down-pipe routine"
                ),
            }
        ],
        "renames": records,
    }
    path = project_root / "docs" / "provenance" / "smb2_label_renames.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(document, indent=2, ensure_ascii=True) + "\n",
        encoding="ascii",
        newline="\n",
    )
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--project-root", type=Path, default=Path(__file__).resolve().parent.parent
    )
    parser.add_argument(
        "--reference-root", type=Path, default=Path("references/threecreepio-smb2j")
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help=(
            "replace the SMB2 revision and late-FDS platform sources and write "
            "the direct provenance mapping"
        ),
    )
    args = parser.parse_args()
    project_root = args.project_root.resolve()
    reference_root = args.reference_root
    if not reference_root.is_absolute():
        reference_root = project_root / reference_root
    listings = {
        payload: load_listing(payload, reference_root / filename, expected_hash)
        for payload, (filename, expected_hash) in REFERENCE_FILES.items()
    }
    exports = exported_symbols(listings)
    reviewed_semantic_names = semantic_stems(
        project_root / "docs" / "provenance" / "label_renames.json"
    )
    semantic_names = {**SMB2_SEMANTIC_OVERRIDES, **reviewed_semantic_names}
    renames = build_renames(listings, exports, semantic_names)
    label_count = sum(len(listing.labels) for listing in listings.values())
    assignment_count = sum(key.kind == "assignment" for key in renames)
    print(
        f"[OK] Classified {label_count} labels and {assignment_count} callable constants "
        f"from {len(listings)} pinned listings"
    )
    if not args.write:
        print("[INFO] Pass --write to replace the tracked SMB2 source tree")
        return 0
    written = write_sources(project_root, listings, exports, renames)
    provenance = write_provenance(
        project_root,
        listings,
        renames,
        semantic_names,
        reviewed_semantic_names,
    )
    print(f"[OK] Wrote {len(written)} source files and {provenance.relative_to(project_root)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
