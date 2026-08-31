#!/usr/bin/env python3
"""Embed the native Windows FCEUX game window inside a Tk host widget."""

from __future__ import annotations

import ctypes
import os
import re
import subprocess
import sys
import tkinter as tk
from pathlib import Path
from typing import Callable


if sys.platform == "win32":
    from ctypes import wintypes


class EmbeddedFceux:
    """Own one FCEUX process and reparent its main window into Tk."""

    WINDOW_CLASS = "FCEUXWindowClass"
    GWL_STYLE = -16
    GWL_EXSTYLE = -20
    WS_CHILD = 0x40000000
    WS_VISIBLE = 0x10000000
    WS_CAPTION = 0x00C00000
    WS_THICKFRAME = 0x00040000
    WS_MINIMIZEBOX = 0x00020000
    WS_MAXIMIZEBOX = 0x00010000
    WS_SYSMENU = 0x00080000
    WS_POPUP = 0x80000000
    WS_EX_DLGMODALFRAME = 0x00000001
    WS_EX_WINDOWEDGE = 0x00000100
    WS_EX_CLIENTEDGE = 0x00000200
    WS_EX_APPWINDOW = 0x00040000
    SWP_FRAMECHANGED = 0x0020
    SWP_NOMOVE = 0x0002
    SWP_NOSIZE = 0x0001
    SWP_SHOWWINDOW = 0x0040
    WM_CLOSE = 0x0010
    WM_COMMAND = 0x0111
    MENU_INPUT = 321
    GW_ENABLEDPOPUP = 6
    EO_FORCEISCALE = 0x00004000
    EO_BESTFIT = 0x00010000
    EO_SQUAREPIXELS = 0x00100000
    NES_WIDTH = 256
    NES_HEIGHT = 240
    RESIZE_DELAY_MS = 180

    @staticmethod
    def _user32() -> object:
        user32 = ctypes.windll.user32
        user32.SetParent.argtypes = (wintypes.HWND, wintypes.HWND)
        user32.SetParent.restype = wintypes.HWND
        user32.GetWindowLongPtrW.argtypes = (wintypes.HWND, ctypes.c_int)
        user32.GetWindowLongPtrW.restype = ctypes.c_ssize_t
        user32.SetWindowLongPtrW.argtypes = (wintypes.HWND, ctypes.c_int, ctypes.c_ssize_t)
        user32.SetWindowLongPtrW.restype = ctypes.c_ssize_t
        user32.SetWindowPos.argtypes = (
            wintypes.HWND, wintypes.HWND, ctypes.c_int, ctypes.c_int,
            ctypes.c_int, ctypes.c_int, wintypes.UINT,
        )
        user32.SetWindowPos.restype = wintypes.BOOL
        user32.GetClientRect.argtypes = (wintypes.HWND, ctypes.POINTER(wintypes.RECT))
        user32.GetClientRect.restype = wintypes.BOOL
        user32.PostMessageW.argtypes = (
            wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM,
        )
        user32.PostMessageW.restype = wintypes.BOOL
        user32.IsWindowEnabled.argtypes = (wintypes.HWND,)
        user32.IsWindowEnabled.restype = wintypes.BOOL
        user32.GetWindow.argtypes = (wintypes.HWND, wintypes.UINT)
        user32.GetWindow.restype = wintypes.HWND
        user32.SetForegroundWindow.argtypes = (wintypes.HWND,)
        user32.SetForegroundWindow.restype = wintypes.BOOL
        return user32

    def __init__(
        self,
        host: tk.Widget,
        status: Callable[[str], None],
        config_directory: Path | None = None,
    ) -> None:
        self.host = host
        self.status = status
        self.config_directory = config_directory
        self.process: subprocess.Popen[bytes] | None = None
        self.window = 0
        self.poll_count = 0
        self.poll_job: str | None = None
        self.resize_job: str | None = None
        self.input_dialog_job: str | None = None
        self.input_dialog_seen = False
        self.input_dialog_polls = 0
        self.top_level_style: int | None = None
        self.top_level_exstyle: int | None = None
        self.host.bind("<Configure>", self._schedule_resize)
        self.host.bind("<Button-1>", lambda _event: self.focus())

    @property
    def running(self) -> bool:
        return self.process is not None and self.process.poll() is None

    def start(
        self,
        executable: Path,
        rom: Path,
        lua: Path,
        environment: dict[str, str],
    ) -> None:
        if sys.platform != "win32":
            raise OSError("Embedded FCEUX is currently supported on Windows only")
        self.stop()
        for path in (executable, rom, lua):
            if not path.is_file():
                raise OSError(f"Required playtest file is missing: {path}")
        self.top_level_style = None
        self.top_level_exstyle = None
        command = [
            str(executable.resolve()),
        ]
        embedded_config = self._prepare_config(
            executable,
            self.config_directory or rom.parent,
        )
        if embedded_config is not None:
            command.extend(["-cfg", str(embedded_config.resolve())])
        command.extend([
            "-window-x", "-10000",
            "-window-y", "-10000",
            "-turbo", "1",
            "-lua", str(lua.resolve()),
            str(rom.resolve()),
        ])
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
        child_environment = os.environ.copy()
        child_environment.update(environment)
        self.process = subprocess.Popen(
            command,
            cwd=rom.parent,
            env=child_environment,
            startupinfo=startup,
        )
        self.window = 0
        self.poll_count = 0
        self.status("Starting embedded FCEUX")
        self.poll_job = self.host.after(25, self._poll_window)

    def _poll_window(self) -> None:
        self.poll_job = None
        if not self.running:
            self.status("FCEUX exited before its window could be embedded")
            self.process = None
            return
        self.window = self._find_process_window(self.process.pid)
        if self.window:
            self._embed()
            self.status("Playtest running; click the game screen for keyboard input")
            return
        self.poll_count += 1
        if self.poll_count >= 200:
            self.stop()
            self.status("Timed out while waiting for the FCEUX window")
            return
        self.poll_job = self.host.after(25, self._poll_window)

    def _embed(self) -> None:
        user32 = self._user32()
        user32.ShowWindow(self.window, 0)
        user32.SetMenu(self.window, 0)
        user32.SetParent(self.window, self.host.winfo_id())
        style = user32.GetWindowLongPtrW(self.window, self.GWL_STYLE)
        if self.top_level_style is None:
            self.top_level_style = style
        style &= ~(
            self.WS_CAPTION | self.WS_THICKFRAME | self.WS_MINIMIZEBOX
            | self.WS_MAXIMIZEBOX | self.WS_SYSMENU | self.WS_POPUP
        )
        style |= self.WS_CHILD | self.WS_VISIBLE
        user32.SetWindowLongPtrW(self.window, self.GWL_STYLE, style)
        exstyle = user32.GetWindowLongPtrW(self.window, self.GWL_EXSTYLE)
        if self.top_level_exstyle is None:
            self.top_level_exstyle = exstyle
        exstyle &= ~(
            self.WS_EX_DLGMODALFRAME | self.WS_EX_WINDOWEDGE
            | self.WS_EX_CLIENTEDGE | self.WS_EX_APPWINDOW
        )
        user32.SetWindowLongPtrW(self.window, self.GWL_EXSTYLE, exstyle)
        self.resize()
        user32.ShowWindow(self.window, 5)
        self.focus()
        self.host.after(50, self.resize)
        self.host.after(250, self.resize)

    def _schedule_resize(self, _event: tk.Event | None = None) -> None:
        """Fit once after Tk has finished a burst of layout changes."""
        if not self.window:
            return
        if self.resize_job is not None:
            self.host.after_cancel(self.resize_job)
        self.resize_job = self.host.after(self.RESIZE_DELAY_MS, self._finish_resize)

    def _finish_resize(self) -> None:
        self.resize_job = None
        self.resize()

    def resize(self) -> None:
        if not self.window:
            return
        user32 = self._user32()
        width, height = self._host_client_size(user32)
        left, top, game_width, game_height = self._fit_game_rectangle(width, height)
        user32.SetWindowPos(
            self.window,
            0,
            left,
            top,
            game_width,
            game_height,
            self.SWP_FRAMECHANGED | self.SWP_SHOWWINDOW,
        )

    def _host_client_size(self, user32: object) -> tuple[int, int]:
        """Read the final Win32 client area instead of intermediate Tk geometry."""
        rectangle = wintypes.RECT()
        if user32.GetClientRect(self.host.winfo_id(), ctypes.byref(rectangle)):
            return max(1, rectangle.right), max(1, rectangle.bottom)
        return max(1, self.host.winfo_width()), max(1, self.host.winfo_height())

    @classmethod
    def _fit_game_rectangle(cls, width: int, height: int) -> tuple[int, int, int, int]:
        """Fit and center a 256:240 NES frame without changing its aspect ratio."""
        width = max(1, width)
        height = max(1, height)
        if width * cls.NES_HEIGHT <= height * cls.NES_WIDTH:
            game_width = width
            game_height = max(1, width * cls.NES_HEIGHT // cls.NES_WIDTH)
        else:
            game_height = height
            game_width = max(1, height * cls.NES_WIDTH // cls.NES_HEIGHT)
        left = (width - game_width) // 2
        top = (height - game_height) // 2
        return left, top, game_width, game_height

    @classmethod
    def _prepare_config(cls, executable: Path, output_directory: Path) -> Path | None:
        destination = output_directory / "fceux-embedded.cfg"
        source = (
            destination
            if destination.is_file()
            else executable.with_name("fceux.cfg")
        )
        if not source.is_file():
            return None
        contents = source.read_text(encoding="utf-8")
        pattern = re.compile(r'^("?eoptions"?\s+)(\d+)(\s*)$', re.MULTILINE)
        match = pattern.search(contents)
        if match is None:
            return None
        options = int(match.group(2))
        options |= cls.EO_BESTFIT
        options &= ~(cls.EO_FORCEISCALE | cls.EO_SQUAREPIXELS)
        contents = pattern.sub(
            lambda item: f"{item.group(1)}{options}{item.group(3)}",
            contents,
            count=1,
        )
        output_directory.mkdir(parents=True, exist_ok=True)
        temporary = destination.with_suffix(".tmp")
        temporary.write_text(contents, encoding="utf-8")
        temporary.replace(destination)
        return destination

    def focus(self) -> None:
        if self.window:
            self._user32().SetFocus(self.window)

    def configure_input(self) -> None:
        """Open FCEUX's native input configuration for the running playtest."""
        if not self.window or not self.running:
            raise OSError("Start a playtest before opening FCEUX controls")
        if self.input_dialog_job is not None:
            raise OSError("FCEUX input configuration is already open")
        user32 = self._user32()
        self._detach_for_input_dialog(user32)
        if not user32.PostMessageW(
            self.window,
            self.WM_COMMAND,
            self.MENU_INPUT,
            0,
        ):
            self._embed()
            raise OSError("FCEUX did not accept the input configuration command")
        self.input_dialog_seen = False
        self.input_dialog_polls = 0
        self.status("Opening FCEUX input configuration")
        self.input_dialog_job = self.host.after(50, self._poll_input_dialog)

    def _detach_for_input_dialog(self, user32: object) -> None:
        """Restore a top-level HWND while DirectInput changes cooperative mode."""
        user32.ShowWindow(self.window, 0)
        user32.SetParent(self.window, 0)
        if self.top_level_style is not None:
            user32.SetWindowLongPtrW(
                self.window,
                self.GWL_STYLE,
                self.top_level_style,
            )
        if self.top_level_exstyle is not None:
            user32.SetWindowLongPtrW(
                self.window,
                self.GWL_EXSTYLE,
                self.top_level_exstyle,
            )
        user32.SetWindowPos(
            self.window,
            0,
            0,
            0,
            0,
            0,
            self.SWP_FRAMECHANGED | self.SWP_NOMOVE | self.SWP_NOSIZE,
        )

    def _poll_input_dialog(self) -> None:
        self.input_dialog_job = None
        if not self.window or not self.running:
            return
        user32 = self._user32()
        popup = user32.GetWindow(self.window, self.GW_ENABLEDPOPUP)
        if popup and popup != self.window:
            self.input_dialog_seen = True
            user32.ShowWindow(popup, 5)
            user32.SetForegroundWindow(popup)
        if not user32.IsWindowEnabled(self.window):
            self.input_dialog_seen = True
        elif self.input_dialog_seen:
            self._embed()
            self.status("Playtest running; FCEUX controls applied")
            return
        self.input_dialog_polls += 1
        if not self.input_dialog_seen and self.input_dialog_polls >= 100:
            self._embed()
            self.status("FCEUX input configuration did not open")
            return
        self.input_dialog_job = self.host.after(50, self._poll_input_dialog)

    def stop(self) -> None:
        if self.poll_job is not None:
            self.host.after_cancel(self.poll_job)
            self.poll_job = None
        if self.resize_job is not None:
            self.host.after_cancel(self.resize_job)
            self.resize_job = None
        if self.input_dialog_job is not None:
            self.host.after_cancel(self.input_dialog_job)
            self.input_dialog_job = None
        process = self.process
        if self.window:
            self._user32().PostMessageW(self.window, self.WM_CLOSE, 0, 0)
        self.window = 0
        if process is not None and process.poll() is None:
            try:
                process.wait(timeout=1.0)
            except subprocess.TimeoutExpired:
                process.terminate()
        self.process = None

    @classmethod
    def _find_process_window(cls, process_id: int) -> int:
        user32 = cls._user32()
        result = 0
        callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

        def visit(window: int, _parameter: int) -> bool:
            nonlocal result
            candidate_process_id = wintypes.DWORD()
            user32.GetWindowThreadProcessId(window, ctypes.byref(candidate_process_id))
            if candidate_process_id.value != process_id:
                return True
            class_name = ctypes.create_unicode_buffer(128)
            user32.GetClassNameW(window, class_name, len(class_name))
            if class_name.value == cls.WINDOW_CLASS:
                result = window
                return False
            return True

        user32.EnumWindows(callback_type(visit), 0)
        return result
