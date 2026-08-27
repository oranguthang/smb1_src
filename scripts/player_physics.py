#!/usr/bin/env python3
"""Decode SMB1 player-physics tables and emit deterministic jump traces."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path


TABLE_NAMES = (
    "tbl_jump_gravity",
    "tbl_fall_gravity",
    "tbl_initial_player_y_speed",
    "tbl_initial_player_y_speed_fraction",
    "tbl_maximum_left_speed",
    "tbl_maximum_right_speed",
    "tbl_horizontal_friction",
)


@dataclass(frozen=True)
class JumpProfile:
    index: int
    jump_gravity: int
    fall_gravity: int
    initial_y_speed: int
    initial_y_speed_fraction: int


@dataclass(frozen=True)
class VerticalState:
    page: int
    pixel: int
    position_fraction: int
    speed: int
    speed_fraction: int

    @property
    def absolute_pixel(self) -> int:
        return (self.page << 8) | self.pixel

    @property
    def signed_speed(self) -> int:
        return self.speed if self.speed < 0x80 else self.speed - 0x100


@dataclass(frozen=True)
class JumpTraceRow:
    frame: int
    a_held: bool
    applied_gravity: int
    state: VerticalState


def parse_number(token: str) -> int:
    token = token.strip()
    if token.startswith("$"):
        return int(token[1:], 16)
    if token.startswith("%"):
        return int(token[1:], 2)
    return int(token, 0)


def load_byte_tables(
    source_path: Path,
    *,
    revision_profile: str = "ju",
) -> dict[str, tuple[int, ...]]:
    if revision_profile not in {"ju", "pc10", "pal"}:
        raise ValueError(f"unsupported revision profile: {revision_profile}")
    wanted = set(TABLE_NAMES)
    tables: dict[str, list[int]] = {}
    current: str | None = None
    active = True
    condition_stack: list[tuple[bool, bool]] = []

    for raw_line in source_path.read_text(encoding="utf-8").splitlines():
        code = raw_line.split(";", 1)[0].strip()
        if code == ".if con_revision_profile = con_revision_profile_pal":
            condition = revision_profile == "pal"
            condition_stack.append((active, condition))
            active = active and condition
            continue
        if code == ".else":
            parent_active, condition = condition_stack[-1]
            active = parent_active and not condition
            continue
        if code == ".endif":
            active, _ = condition_stack.pop()
            continue
        if code.endswith(":"):
            label = code[:-1]
            current = label if label in wanted else None
            if current is not None:
                tables[current] = []
            continue
        if not active or current is None or not code.startswith(".byte "):
            continue
        values = code.removeprefix(".byte ").split(",")
        tables[current].extend(parse_number(value) for value in values)

    missing = wanted.difference(tables)
    if missing:
        names = ", ".join(sorted(missing))
        raise ValueError(f"missing player-physics table(s): {names}")
    return {name: tuple(values) for name, values in tables.items()}


def select_jump_profile_index(
    horizontal_speed_absolute: int,
    *,
    swimming: bool = False,
    whirlpool: bool = False,
    revision_profile: str = "ju",
) -> int:
    if not 0 <= horizontal_speed_absolute <= 0xFF:
        raise ValueError("horizontal speed must fit in one byte")
    if swimming:
        return 6 if whirlpool else 5

    index = 0
    thresholds = (
        (0x0A, 0x12, 0x1D, 0x22)
        if revision_profile == "pal"
        else (0x09, 0x10, 0x19, 0x1C)
    )
    for threshold in thresholds:
        if horizontal_speed_absolute < threshold:
            break
        index += 1
    return index


def jump_profile(
    tables: dict[str, tuple[int, ...]],
    horizontal_speed_absolute: int,
    *,
    swimming: bool = False,
    whirlpool: bool = False,
    revision_profile: str = "ju",
) -> JumpProfile:
    index = select_jump_profile_index(
        horizontal_speed_absolute,
        swimming=swimming,
        whirlpool=whirlpool,
        revision_profile=revision_profile,
    )
    return JumpProfile(
        index=index,
        jump_gravity=tables["tbl_jump_gravity"][index],
        fall_gravity=tables["tbl_fall_gravity"][index],
        initial_y_speed=tables["tbl_initial_player_y_speed"][index],
        initial_y_speed_fraction=tables[
            "tbl_initial_player_y_speed_fraction"
        ][index],
    )


def add_byte(left: int, right: int, carry: int = 0) -> tuple[int, int]:
    total = left + right + carry
    return total & 0xFF, 1 if total > 0xFF else 0


def advance_player_vertical(
    state: VerticalState,
    downward_gravity: int,
    *,
    maximum_downward_speed: int = 0x04,
) -> VerticalState:
    position_fraction, carry = add_byte(
        state.position_fraction, state.speed_fraction
    )
    pixel, carry = add_byte(state.pixel, state.speed, carry)
    page_delta = 0xFF if state.speed & 0x80 else 0x00
    page, _ = add_byte(state.page, page_delta, carry)

    speed_fraction, carry = add_byte(
        state.speed_fraction, downward_gravity
    )
    speed, _ = add_byte(state.speed, 0, carry)
    speed_limit_difference = (speed - maximum_downward_speed) & 0xFF
    below_speed_limit = speed_limit_difference & 0x80 != 0
    if not below_speed_limit and speed_fraction >= 0x80:
        speed = maximum_downward_speed
        speed_fraction = 0

    return VerticalState(
        page=page,
        pixel=pixel,
        position_fraction=position_fraction,
        speed=speed,
        speed_fraction=speed_fraction,
    )


def trace_jump(
    profile: JumpProfile,
    *,
    held_frames: int,
    frame_count: int,
    initial_page: int = 1,
    initial_pixel: int = 0x80,
) -> list[JumpTraceRow]:
    if held_frames < 0 or frame_count < 0:
        raise ValueError("frame counts cannot be negative")

    state = VerticalState(
        page=initial_page,
        pixel=initial_pixel,
        position_fraction=0,
        speed=profile.initial_y_speed,
        speed_fraction=profile.initial_y_speed_fraction,
    )
    origin_pixel = initial_pixel
    previous_a = False
    rows: list[JumpTraceRow] = []

    for frame in range(frame_count):
        current_a = frame < held_frames
        rising = state.speed & 0x80 != 0
        displacement = (origin_pixel - state.pixel) & 0xFF
        use_jump_gravity = rising and (
            (current_a and previous_a) or displacement < 1
        )
        applied_gravity = (
            profile.jump_gravity if use_jump_gravity else profile.fall_gravity
        )
        state = advance_player_vertical(state, applied_gravity)
        rows.append(
            JumpTraceRow(
                frame=frame,
                a_held=current_a,
                applied_gravity=applied_gravity,
                state=state,
            )
        )
        previous_a = current_a

    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        type=Path,
        default=Path(__file__).resolve().parent.parent
        / "src"
        / "game"
        / "player"
        / "physics.asm",
    )
    parser.add_argument("--speed", type=lambda value: int(value, 0), default=0x1C)
    parser.add_argument("--held-frames", type=int, default=8)
    parser.add_argument("--frames", type=int, default=24)
    parser.add_argument("--swimming", action="store_true")
    parser.add_argument("--whirlpool", action="store_true")
    parser.add_argument(
        "--profile",
        choices=("ju", "pc10", "pal"),
        default="ju",
    )
    args = parser.parse_args()

    tables = load_byte_tables(args.source, revision_profile=args.profile)
    profile = jump_profile(
        tables,
        args.speed,
        swimming=args.swimming,
        whirlpool=args.whirlpool,
        revision_profile=args.profile,
    )
    rows = trace_jump(
        profile,
        held_frames=args.held_frames,
        frame_count=args.frames,
    )

    print(
        "frame a gravity page pixel pos_frac y_speed speed_frac absolute_y"
    )
    for row in rows:
        state = row.state
        print(
            f"{row.frame:5d} {int(row.a_held):1d} ${row.applied_gravity:02X} "
            f"${state.page:02X} ${state.pixel:02X} ${state.position_fraction:02X} "
            f"{state.signed_speed:7d} ${state.speed_fraction:02X} "
            f"${state.absolute_pixel:04X}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
