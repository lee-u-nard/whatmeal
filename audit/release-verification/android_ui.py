"""Restricted, ordinary Android UI controls for the disposable release AVD.

Run with --serial emulator-5570 --evidence-root build/release-safety-audit/...
before the subcommand. Raw XML/screenshots stay in that ignored evidence tree.
`type` appends text unless --replace is explicit. No credential value is printed.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time
from uuid import uuid4
import xml.etree.ElementTree as ET


ADB = "C:/Android/Sdk/platform-tools/adb.exe"
SERIAL = "emulator-5570"
PACKAGE = "com.example.whatmeal.showcase"
WORKSPACE = Path(__file__).resolve().parents[2]
EVIDENCE_BASE = WORKSPACE / "build/release-safety-audit"
SYSTEM_PACKAGES = {
    "android", "com.android.systemui", "com.android.permissioncontroller",
    "com.google.android.permissioncontroller", "com.android.inputmethod.latin",
    "com.google.android.inputmethod.latin", "com.android.browser",
    "com.android.chrome", "com.google.android.apps.chrome",
    "org.chromium.chrome", "com.android.intentresolver",
}
CRASH_PATTERN = re.compile(
    r"isn.t responding|keeps stopping|has stopped|application error", re.I
)


class UiFailure(Exception):
    """Only fixed, non-sensitive error codes may leave the helper."""


def evidence_path(value: str) -> Path:
    path = Path(value)
    if not path.is_absolute():
        path = WORKSPACE / path
    path = path.resolve()
    if not path.is_relative_to(EVIDENCE_BASE.resolve()):
        raise UiFailure("EVIDENCE_PATH_NOT_ALLOWED")
    return path


def bounds(node: ET.Element) -> tuple[int, int, int, int] | None:
    match = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds", ""))
    if not match:
        return None
    left, top, right, bottom = map(int, match.groups())
    return (left, top, right, bottom) if right > left and bottom > top else None


def visible_nodes(root: ET.Element) -> list[ET.Element]:
    nodes = list(root.iter("node"))
    rectangles = [rect for node in nodes if (rect := bounds(node))]
    if not rectangles:
        return []
    viewport = max(rectangles, key=lambda rect: (rect[2] - rect[0]) * (rect[3] - rect[1]))
    result = []
    for node in nodes:
        rect = bounds(node)
        if not rect or node.get("visible-to-user") == "false":
            continue
        x, y = (rect[0] + rect[2]) // 2, (rect[1] + rect[3]) // 2
        if viewport[0] <= x < viewport[2] and viewport[1] <= y < viewport[3]:
            result.append(node)
    return result


def public_labels(root: ET.Element) -> list[dict]:
    result = []
    for node in visible_nodes(root):
        editable = node.get("class", "").endswith("EditText")
        label = node.get("content-desc") or node.get("text") or ""
        if editable:
            label = "[editable redacted]"
        elif "@" in label:
            label = "[email redacted]"
        elif "oobCode=" in label:
            label = "[account action link redacted]"
        else:
            label = re.sub(r"(?<![A-Za-z0-9_-])[A-Za-z0-9_-]{32,}(?![A-Za-z0-9_-])",
                           "[token redacted]", label)
        if label:
            result.append({
                "label": label,
                "editable": editable,
                "clickable": node.get("clickable") == "true",
                "enabled": node.get("enabled") == "true",
                "bounds": node.get("bounds"),
            })
    return result


def has_crash_label(root: ET.Element) -> bool:
    return any(CRASH_PATTERN.search(node.get(key, ""))
               for node in root.iter("node") for key in ("text", "content-desc"))


def select_tap(root: ET.Element, label: str, contains: bool = False,
               index: int | None = None) -> ET.Element:
    matches = []
    for node in visible_nodes(root):
        if node.get("clickable") != "true" or node.get("enabled") != "true":
            continue
        candidates = (node.get("text", ""), node.get("content-desc", ""))
        if any(label in candidate if contains else label == candidate
               for candidate in candidates):
            matches.append(node)
    if index is None:
        if len(matches) != 1:
            raise UiFailure("EXPECTED_ONE_CLICKABLE_CONTROL")
        return matches[0]
    if index < 0 or index >= len(matches):
        raise UiFailure("CONTROL_INDEX_OUT_OF_RANGE")
    return matches[index]


def text_argument(value: str) -> str:
    # Android input text interprets literal %s as a space and cannot reliably
    # type arbitrary Unicode. Refuse unsupported input rather than corrupt it.
    if not value or len(value) > 256 or "%s" in value or any(
            ord(character) < 32 or ord(character) > 126 for character in value):
        raise UiFailure("TEXT_INPUT_NOT_SUPPORTED")
    return shlex.quote(value.replace(" ", "%s"))


def private_value(filename: str, key: str) -> str:
    path = Path(filename)
    if not path.is_absolute():
        path = WORKSPACE / path
    path = path.resolve()
    if not path.is_relative_to((WORKSPACE / "build").resolve()):
        raise UiFailure("PRIVATE_FILE_PATH_NOT_ALLOWED")
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
        for component in key.split("."):
            value = value[int(component)] if isinstance(value, list) else value[component]
        if not isinstance(value, str):
            raise ValueError()
        return value
    except (OSError, ValueError, KeyError, IndexError, TypeError):
        raise UiFailure("PRIVATE_INPUT_UNAVAILABLE") from None


def editable_fields(root: ET.Element) -> list[ET.Element]:
    return [node for node in visible_nodes(root)
            if node.get("class", "").endswith("EditText")
            and node.get("enabled") == "true"]


def focused_field(root: ET.Element, previous: ET.Element | None = None) -> ET.Element:
    fields = [node for node in editable_fields(root) if node.get("focused") == "true"]
    if len(fields) != 1:
        raise UiFailure("FIELD_FOCUS_NOT_CONFIRMED")
    field = fields[0]
    if previous is not None:
        for attribute in ("class", "password", "resource-id", "content-desc"):
            expected = previous.get(attribute)
            if expected and field.get(attribute) != expected:
                raise UiFailure("FIELD_FOCUS_CHANGED")
    return field


def verify_empty_field(root: ET.Element, previous: ET.Element) -> ET.Element:
    field = focused_field(root, previous)
    if field.get("text", ""):
        raise UiFailure("FIELD_NOT_EMPTY_AFTER_CLEAR")
    return field


def verify_typed_value(root: ET.Element, index: int, value: str,
                       password: bool, *, require_focus: bool = False) -> str:
    if require_focus:
        field = focused_field(root)
    else:
        fields = editable_fields(root)
        if index < 0 or index >= len(fields):
            raise UiFailure("FIELD_NOT_AVAILABLE_AFTER_INPUT")
        field = fields[index]
    actual = field.get("text", "")
    if password or field.get("password") == "true":
        # Do not compare plaintext password values. Some Android versions omit
        # the text or briefly expose its last character; only a complete mask
        # supports a truthful length check.
        if re.fullmatch(r"[\u2022\u25cf\u25e6*\u00b7]+", actual):
            if len(actual) != len(value):
                raise UiFailure("PASSWORD_LENGTH_MISMATCH")
            return "PASSWORD_MASK_LENGTH_VERIFIED"
        return "PASSWORD_MASK_LENGTH_UNAVAILABLE"
    if actual != value:
        raise UiFailure("TEXT_VALUE_MISMATCH")
    return "TEXT_VALUE_VERIFIED"


class AndroidUi:
    def __init__(self, serial: str, root: Path):
        if serial != SERIAL:
            raise UiFailure("DEVICE_NOT_ALLOWED")
        self.serial = serial
        self.root = root
        self.step: Path | None = None

    def adb(self, *arguments: str, timeout: int = 30) -> str:
        try:
            result = subprocess.run(
                [ADB, "-s", self.serial, *arguments], capture_output=True,
                timeout=timeout, check=False, encoding="utf-8", errors="replace",
            )
        except (OSError, subprocess.TimeoutExpired):
            raise UiFailure("ADB_EXECUTION_FAILED_OR_TIMED_OUT") from None
        if result.returncode:
            raise UiFailure("ADB_NONZERO_EXIT")
        return result.stdout

    def guard_device(self) -> None:
        name = self.adb("emu", "avd", "name").splitlines()
        if not name or not re.fullmatch(r"whatmeal-release-[A-Za-z0-9_-]+", name[0].strip()):
            raise UiFailure("AVD_IDENTITY_NOT_ALLOWED")

    def foreground(self) -> str:
        # Android 15's "windows" subsection omits the global focus fields.
        state = self.adb("shell", "dumpsys", "window")
        match = re.search(r"mCurrentFocus=.*?\s([A-Za-z0-9_.]+)/", state)
        if not match:
            raise UiFailure("FOREGROUND_NOT_IDENTIFIED")
        return match.group(1)

    def guard_foreground(self, allow_system: bool = False) -> str:
        package = self.foreground()
        if package != PACKAGE and not (allow_system and package in SYSTEM_PACKAGES):
            raise UiFailure("FOREGROUND_NOT_ALLOWED")
        return package

    def new_step(self, name: str) -> None:
        if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,79}", name):
            raise UiFailure("EVIDENCE_NAME_NOT_ALLOWED")
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        self.step = self.root / f"{name}-{timestamp}-{uuid4().hex[:8]}"
        self.step.mkdir(parents=True, exist_ok=False)

    def capture(self, name: str, allow_system: bool = False) -> ET.Element:
        package = self.guard_foreground(allow_system)
        remote = f"/sdcard/whatmeal-release-{uuid4().hex}"
        assert self.step is not None
        xml_path = self.step / f"{name}.xml"
        self.adb("shell", "uiautomator", "dump", remote + ".xml", timeout=45)
        self.adb("pull", remote + ".xml", str(xml_path))
        self.adb("shell", "screencap", "-p", remote + ".png")
        self.adb("pull", remote + ".png", str(self.step / f"{name}.png"))
        try:
            root = ET.fromstring(xml_path.read_text(encoding="utf-8"))
        except (OSError, ET.ParseError):
            raise UiFailure("UI_XML_UNAVAILABLE") from None
        report = {"foreground": package, "labels": public_labels(root),
                  "systemErrorVisible": has_crash_label(root)}
        (self.step / f"{name}.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
        if report["systemErrorVisible"]:
            raise UiFailure("SYSTEM_ERROR_VISIBLE_NO_DISMISSAL")
        return root

    def tap_node(self, node: ET.Element) -> None:
        rect = bounds(node)
        if rect is None:
            raise UiFailure("CONTROL_BOUNDS_UNAVAILABLE")
        self.adb("shell", "input", "tap", str((rect[0] + rect[2]) // 2),
                 str((rect[1] + rect[3]) // 2))

    def replace_field(self, node: ET.Element) -> None:
        length = len(node.get("text", ""))
        if length > 512:
            raise UiFailure("EXISTING_TEXT_TOO_LONG_TO_REPLACE")
        # Pace ordinary Android delete events so Flutter can commit each edit.
        # Ctrl+A is not reliably handled by the Android/Flutter input bridge.
        # Two harmless extra deletes account for a stale displayed length;
        # capture and verify empty before insertion rather than assuming it.
        self.adb("shell", "input", "keyevent", "123")
        time.sleep(0.25)
        self.guard_foreground()
        self.adb("shell", "input", "keyevent", "--delay", "100",
                 *("67" for _ in range(length + 2)))
        time.sleep(0.5)

    def operate(self, args: argparse.Namespace) -> dict:
        self.guard_device()
        self.new_step(args.name or args.action)
        allow_system = args.action == "inspect" and args.allow_system_screen
        root = self.capture("before", allow_system=allow_system)
        if args.action == "inspect":
            return {"status": "PASS", "action": args.action,
                    "evidence": str(self.step), "labels": public_labels(root)}
        self.guard_foreground()
        if args.action == "tap":
            self.tap_node(select_tap(root, args.label, args.contains, args.index))
        elif args.action == "type":
            fields = editable_fields(root)
            if args.field_index < 0 or args.field_index >= len(fields):
                raise UiFailure("FIELD_INDEX_OUT_OF_RANGE")
            value = private_value(args.private_file, args.key)
            argument = text_argument(value)
            target = fields[args.field_index]
            password = target.get("password") == "true"
            self.tap_node(target)
            time.sleep(0.3)
            self.guard_foreground()
            focused = focused_field(self.capture("focused"), target)
            if not password and focused.get("text", "") != target.get("text", ""):
                raise UiFailure("FIELD_FOCUS_CHANGED")
            if args.replace:
                self.replace_field(focused)
                verify_empty_field(self.capture("cleared"), focused)
            self.adb("shell", "input", "text", argument)
        elif args.action == "scroll":
            rectangles = [rect for node in visible_nodes(root) if (rect := bounds(node))]
            if not rectangles:
                raise UiFailure("VIEWPORT_UNAVAILABLE")
            left, top, right, bottom = max(rectangles, key=lambda rect: (rect[2]-rect[0])*(rect[3]-rect[1]))
            x = (left + right) // 2
            upper, lower = top + (bottom-top)*3//10, top + (bottom-top)*7//10
            start, end = (lower, upper) if args.direction == "down" else (upper, lower)
            self.adb("shell", "input", "swipe", str(x), str(start), str(x), str(end), "350")
        elif args.action == "back":
            self.adb("shell", "input", "keyevent", "4")
        time.sleep(0.7)
        # Preserve any system dialog without dismissing it; never treat a
        # permission/error screen after an action as an application pass.
        package = self.guard_foreground(allow_system=True)
        after = self.capture("after", allow_system=True)
        if package != PACKAGE:
            raise UiFailure("FOREGROUND_CHANGED_NO_DISMISSAL")
        report = {"status": "PASS", "action": args.action, "evidence": str(self.step)}
        if args.action == "type":
            report["inputVerification"] = verify_typed_value(
                after, args.field_index, value, password, require_focus=True)
        return report


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--serial", required=True, choices=[SERIAL])
    result.add_argument("--evidence-root", required=True)
    commands = result.add_subparsers(dest="action", required=True)
    inspect = commands.add_parser("inspect")
    inspect.add_argument("--name", required=True)
    inspect.add_argument("--allow-system-screen", action="store_true")
    tap = commands.add_parser("tap")
    tap.add_argument("--label", required=True)
    tap.add_argument("--contains", action="store_true")
    tap.add_argument("--index", type=int)
    typing = commands.add_parser("type")
    typing.add_argument("--field-index", type=int, required=True)
    typing.add_argument("--private-file", required=True)
    typing.add_argument("--key", required=True)
    typing.add_argument("--replace", action="store_true")
    scroll = commands.add_parser("scroll")
    scroll.add_argument("--direction", choices=["up", "down"], required=True)
    back = commands.add_parser("back")
    for command in (tap, typing, scroll, back):
        command.add_argument("--name")
    return result


def main() -> int:
    controller = None
    try:
        args = parser().parse_args()
        controller = AndroidUi(args.serial, evidence_path(args.evidence_root))
        report = controller.operate(args)
        print(json.dumps(report))
        return 0
    except UiFailure as failure:
        report = {"status": "FAIL", "reason": str(failure)}
    except Exception:
        # Do not expose command lines, stderr, JSON contents or values through
        # tracebacks when a native command or private credential read fails.
        report = {"status": "FAIL", "reason": "HELPER_INTERNAL_FAILURE"}
    if controller is not None and controller.step is not None:
        report["evidence"] = str(controller.step)
        (controller.step / "failure.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report))
    return 1


if __name__ == "__main__":
    sys.exit(main())
