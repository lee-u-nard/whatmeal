"""Run explicit ordinary-UI steps on the isolated release AVD; never print input.

Scenario: [{"name":"open-home","command":["tap","--label","Home"],
            "expectAll":["WhatMeal"],"expectNone":["Retry"]}]
Type commands accept only the existing helper's private-file/key mechanism.
"""

from __future__ import annotations

import argparse
from contextlib import redirect_stderr
from datetime import datetime, timezone
import io
import json
from pathlib import Path
import re
import sys
import time
from uuid import uuid4
import xml.etree.ElementTree as ET

import android_ui as ui


ACTIONS = {"inspect", "tap", "type", "scroll", "back"}


def command_args(command: list[str], name: str, root: Path) -> argparse.Namespace:
    if (not isinstance(command, list) or not command
            or not all(isinstance(part, str) for part in command)
            or command[0] not in ACTIONS
            or any(part in {"--name", "--help", "-h"} for part in command)):
        raise ui.UiFailure("SCENARIO_COMMAND_NOT_ALLOWED")
    try:
        # argparse errors may quote argument values. Keep them entirely private.
        with redirect_stderr(io.StringIO()):
            return ui.parser().parse_args([
                "--serial", ui.SERIAL, "--evidence-root", str(root),
                *command, "--name", name,
            ])
    except SystemExit:
        raise ui.UiFailure("SCENARIO_COMMAND_INVALID") from None


def load_steps(path: Path, root: Path) -> list[dict]:
    try:
        steps = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, ValueError):
        raise ui.UiFailure("SCENARIO_UNAVAILABLE") from None
    if not isinstance(steps, list) or not steps or len(steps) > 200:
        raise ui.UiFailure("SCENARIO_SCHEMA_INVALID")
    names = set()
    for step in steps:
        if not isinstance(step, dict) or set(step) - {
                "name", "command", "expectAll", "expectNone"}:
            raise ui.UiFailure("SCENARIO_SCHEMA_INVALID")
        name = step.get("name")
        if (not isinstance(name, str) or not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,69}", name)
                or name in names):
            raise ui.UiFailure("SCENARIO_NAME_INVALID")
        names.add(name)
        for field in ("expectAll", "expectNone"):
            expectations = step.get(field, [])
            if (not isinstance(expectations, list) or len(expectations) > 50
                    or not all(isinstance(value, str) and 0 < len(value) <= 1000
                               for value in expectations)):
                raise ui.UiFailure("SCENARIO_EXPECTATIONS_INVALID")
        command_args(step.get("command"), name, root)
    return steps


def evaluate(root: ET.Element, step: dict) -> dict:
    labels = [node.get(key, "") for node in ui.visible_nodes(root)
              for key in ("text", "content-desc") if node.get(key)]
    return {
        "expectAll": [any(expected in label for label in labels)
                      for expected in step.get("expectAll", [])],
        "expectNone": [not any(expected in label for label in labels)
                       for expected in step.get("expectNone", [])],
    }


def expectations_pass(checks: dict) -> bool:
    return all(checks["expectAll"]) and all(checks["expectNone"])


class DeadlineAndroidUi(ui.AndroidUi):
    deadline: float | None = None

    def adb(self, *arguments: str, timeout: int = 30) -> str:
        if self.deadline is not None:
            remaining = self.deadline - time.monotonic()
            if remaining <= 0:
                raise ui.UiFailure("EXPECTATION_TIMEOUT")
            timeout = min(timeout, remaining)
        return super().adb(*arguments, timeout=timeout)


def action_xml(controller: ui.AndroidUi, action: str) -> ET.Element:
    if controller.step is None:
        raise ui.UiFailure("ACTION_EVIDENCE_MISSING")
    filename = "before.xml" if action == "inspect" else "after.xml"
    try:
        return ET.fromstring((controller.step / filename).read_text(encoding="utf-8"))
    except (OSError, ET.ParseError):
        raise ui.UiFailure("ACTION_EVIDENCE_UNAVAILABLE") from None


def run_steps(steps: list[dict], root: Path, controller_factory=DeadlineAndroidUi) -> tuple[int, Path]:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    folder = root / f"scenario-{timestamp}-{uuid4().hex[:8]}"
    folder.mkdir(parents=True, exist_ok=False)
    result_path = folder / "results.json"
    results = {"status": "RUNNING", "totalPassed": 0, "steps": []}

    def save() -> None:
        result_path.write_text(json.dumps(results, indent=2), encoding="utf-8")

    save()
    for step in steps:
        # ADB's Windows file writer rejects MAX_PATH destinations. Keep unique
        # action captures beside the scenario folder, matching standalone UI.
        controller = controller_factory(ui.SERIAL, root)
        row = {"name": step["name"], "status": "RUNNING", "evidence": [],
               "expectAll": [], "expectNone": []}
        results["steps"].append(row)
        save()
        try:
            args = command_args(step["command"], step["name"], folder)
            controller.operate(args)
            if controller.step is not None:
                row["evidence"].append(str(controller.step))
            controller.guard_foreground()  # A system capture is never an app pass.
            checks = evaluate(action_xml(controller, args.action), step)
            row.update(checks)
            deadline = time.monotonic() + 30
            poll = 0
            while not expectations_pass(checks):
                if time.monotonic() >= deadline:
                    raise ui.UiFailure("EXPECTATION_TIMEOUT")
                time.sleep(min(0.5, max(0, deadline - time.monotonic())))
                poll += 1
                controller.deadline = deadline
                inspect = command_args(["inspect"], f"{step['name']}-wait-{poll}", folder)
                controller.operate(inspect)
                row["evidence"].append(str(controller.step))
                controller.guard_foreground()
                checks = evaluate(action_xml(controller, "inspect"), step)
                row.update(checks)
                save()
            row["status"] = "PASS"
            results["totalPassed"] += 1
            save()
            print(json.dumps({"name": step["name"], "status": "PASS",
                              "path": str(controller.step), "totalPassed": results["totalPassed"]}), flush=True)
        except ui.UiFailure as failure:
            row["status"] = "FAIL"
            row["reason"] = str(failure)
            if controller.step is not None and str(controller.step) not in row["evidence"]:
                row["evidence"].append(str(controller.step))
            results["status"] = "FAIL"
            save()
            print(json.dumps({"name": step["name"], "status": "FAIL", "reason": str(failure),
                              "path": str(result_path), "totalPassed": results["totalPassed"]}), flush=True)
            return 1, result_path
        except Exception:
            row["status"] = "FAIL"
            row["reason"] = "SCENARIO_INTERNAL_FAILURE"
            results["status"] = "FAIL"
            save()
            print(json.dumps({"name": step["name"], "status": "FAIL", "reason": row["reason"],
                              "path": str(result_path), "totalPassed": results["totalPassed"]}), flush=True)
            return 1, result_path
    results["status"] = "PASS"
    save()
    print(json.dumps({"status": "PASS", "path": str(result_path),
                      "totalPassed": results["totalPassed"]}), flush=True)
    return 0, result_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence-root", required=True)
    parser.add_argument("--scenario", required=True)
    try:
        args = parser.parse_args()
        root = ui.evidence_path(args.evidence_root)
        scenario = ui.evidence_path(args.scenario)
        steps = load_steps(scenario, root)
        return run_steps(steps, root)[0]
    except ui.UiFailure as failure:
        print(json.dumps({"status": "FAIL", "reason": str(failure), "totalPassed": 0}))
        return 1
    except Exception:
        print(json.dumps({"status": "FAIL", "reason": "SCENARIO_INTERNAL_FAILURE", "totalPassed": 0}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
