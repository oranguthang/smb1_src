#!/usr/bin/env python3
"""Embed the native Windows FCEUX game window inside a Tk host widget."""

from __future__ import annotations

import ctypes
import os
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
    SWP_NOZORDER = 0x0004
    SWP_FRAMECHANGED = 0x0020
    SWP_SHOWWINDOW = 0x0040
    WM_CLOSE = 0x0010

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
        return user32

    def __init__(self, host: tk.Widget, status: Callable[[str], None]) -> None:
        self.host = host
        self.status = status
        self.process: subprocess.Popen[bytes] | None = None
        self.window = 0
        self.poll_count = 0
        self.poll_job: str | None = None
        self.host.bind("<Configure>", lambda _event: self.resize())
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
        command = [
            str(executable.resolve()),
            "-window-x", "-10000",
            "-window-y", "-10000",
            "-lua", str(lua.resolve()),
            str(rom.resolve()),
        ]
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
        style &= ~(
            self.WS_CAPTION | self.WS_THICKFRAME | self.WS_MINIMIZEBOX
            | self.WS_MAXIMIZEBOX | self.WS_SYSMENU | self.WS_POPUP
        )
        style |= self.WS_CHILD | self.WS_VISIBLE
        user32.SetWindowLongPtrW(self.window, self.GWL_STYLE, style)
        exstyle = user32.GetWindowLongPtrW(self.window, self.GWL_EXSTYLE)
        exstyle &= ~(
            self.WS_EX_DLGMODALFRAME | self.WS_EX_WINDOWEDGE
            | self.WS_EX_CLIENTEDGE | self.WS_EX_APPWINDOW
        )
        user32.SetWindowLongPtrW(self.window, self.GWL_EXSTYLE, exstyle)
        self.resize()
        user32.ShowWindow(self.window, 5)
        self.focus()

    def resize(self) -> None:
        if not self.window:
            return
        width = max(1, self.host.winfo_width())
        height = max(1, self.host.winfo_height())
        scale = max(1, min(width // 256, height // 240))
        game_width = 256 * scale
        game_height = 240 * scale
        left = (width - game_width) // 2
        top = (height - game_height) // 2
        self._user32().SetWindowPos(
            self.window,
            0,
            left,
            top,
            game_width,
            game_height,
            self.SWP_NOZORDER | self.SWP_FRAMECHANGED | self.SWP_SHOWWINDOW,
        )

    def focus(self) -> None:
        if self.window:
            self._user32().SetFocus(self.window)

    def stop(self) -> None:
        if self.poll_job is not None:
            self.host.after_cancel(self.poll_job)
            self.poll_job = None
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
