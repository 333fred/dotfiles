#!/usr/bin/python3

import sys
from collections import deque

from gi.repository import Gio, GLib


class LockPause:
    def __init__(self, screensaver, dunst):
        self.screensaver = screensaver
        self.dunst = dunst
        self.locked = None
        self.restore_paused = None
        # Dunst emits a property change even when a pause request is a no-op.
        self.pending_changes = deque()
        self.retry_id = None

        screensaver.connect("g-signal", self.on_screensaver_signal)
        screensaver.connect("notify::g-name-owner", self.on_screensaver_owner)
        dunst.connect("g-properties-changed", self.on_dunst_changed)
        dunst.connect("notify::g-name-owner", self.on_dunst_owner)

    def retry(self):
        self.retry_id = None
        self.sync_screensaver()
        self.sync_dunst()
        return GLib.SOURCE_REMOVE

    def report_error(self, operation, error):
        print(f"dunst lock monitor: {operation}: {error}", file=sys.stderr, flush=True)
        if self.retry_id is None:
            self.retry_id = GLib.timeout_add_seconds(5, self.retry)

    def sync_screensaver(self):
        if not self.screensaver.get_name_owner():
            return
        try:
            active = self.screensaver.call_sync(
                "GetActive", None, Gio.DBusCallFlags.NONE, -1, None
            ).unpack()[0]
            self.update_lock(active)
        except GLib.Error as error:
            self.report_error("cannot get screen-saver state", error)

    def sync_dunst(self):
        if not self.dunst.get_name_owner():
            return
        paused = self.dunst.get_cached_property("paused")
        if paused is None:
            self.report_error("cannot get dunst pause state", "property unavailable")
            return
        paused = paused.unpack()
        if self.locked and self.restore_paused is None:
            self.restore_paused = paused
        target = True if self.locked else self.restore_paused
        if target is not None and paused != target and not self.set_paused(target):
            return
        if self.locked is False and self.restore_paused is not None:
            self.restore_paused = None

    def set_paused(self, paused):
        self.pending_changes.append(paused)
        try:
            self.dunst.get_connection().call_sync(
                "org.freedesktop.Notifications",
                "/org/freedesktop/Notifications",
                "org.freedesktop.DBus.Properties",
                "Set",
                GLib.Variant(
                    "(ssv)",
                    ("org.dunstproject.cmd0", "paused", GLib.Variant("b", paused)),
                ),
                None,
                Gio.DBusCallFlags.NONE,
                -1,
                None,
            )
        except GLib.Error as error:
            self.pending_changes.pop()
            self.report_error("cannot set dunst pause state", error)
            return False
        return True

    def update_lock(self, locked):
        if self.locked == locked:
            return
        self.locked = locked
        self.sync_dunst()

    def on_screensaver_signal(self, proxy, sender, signal, parameters):
        if signal == "ActiveChanged":
            self.update_lock(parameters.unpack()[0])

    def on_screensaver_owner(self, proxy, param):
        self.sync_screensaver()

    def on_dunst_owner(self, proxy, param):
        self.pending_changes.clear()
        self.sync_dunst()

    def on_dunst_changed(self, proxy, changed, invalidated):
        changes = changed.unpack()
        if "paused" not in changes:
            return
        paused = changes["paused"]
        if self.pending_changes and self.pending_changes[0] == paused:
            self.pending_changes.popleft()
            return
        if self.locked:
            self.restore_paused = paused
            if not paused:
                self.sync_dunst()


def new_proxy(name, path, interface):
    return Gio.DBusProxy.new_for_bus_sync(
        Gio.BusType.SESSION,
        Gio.DBusProxyFlags.DO_NOT_AUTO_START,
        None,
        name,
        path,
        interface,
        None,
    )


def main():
    screensaver = new_proxy(
        "org.gnome.ScreenSaver", "/org/gnome/ScreenSaver", "org.gnome.ScreenSaver"
    )
    dunst = new_proxy(
        "org.freedesktop.Notifications",
        "/org/freedesktop/Notifications",
        "org.dunstproject.cmd0",
    )
    pause = LockPause(screensaver, dunst)
    pause.sync_screensaver()
    pause.sync_dunst()
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
