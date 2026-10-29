"""Synthetic runner checks; no device, Firebase, shell, or network operations."""

from contextlib import redirect_stdout
import io
import json
import unittest
from unittest import mock
from uuid import uuid4
import xml.etree.ElementTree as ET

import android_ui as ui
import run_scenario as runner


def workspace_scratch():
    # Python 3.14 TemporaryDirectory's restrictive directory ACL is incompatible
    # with the Windows restricted-token temp directory used by this workspace.
    # Inherit the approved workspace ACL instead; retain tiny synthetic evidence
    # without deleting anything or changing the process's TEMP configuration.
    root = ui.evidence_path("build/release-safety-audit/synthetic-host-tests")
    folder = root / ("fixture-" + uuid4().hex)
    folder.mkdir(parents=True, exist_ok=False)
    return folder


class ScenarioTests(unittest.TestCase):
    def test_scratch_files_stay_in_approved_writable_workspace(self):
        folder = workspace_scratch()
        self.assertTrue(folder.is_relative_to(ui.EVIDENCE_BASE))
        fixture = folder / "roundtrip.txt"
        fixture.write_text("synthetic fixture", encoding="utf-8")
        self.assertEqual(fixture.read_text(encoding="utf-8"), "synthetic fixture")

    def test_rejects_shell_and_inline_text_commands(self):
        for command in (["shell", "rm"], ["type", "--text", "inline-value"],
                        ["inspect", "--name", "override"], ["inspect", "--help"]):
            with self.assertRaises(ui.UiFailure):
                runner.command_args(command, "safe-step", ui.EVIDENCE_BASE)

    def test_accepts_explicit_private_file_typing_and_replace(self):
        args = runner.command_args([
            "type", "--field-index", "0", "--private-file", "build/private/accounts.json",
            "--key", "owner.email", "--replace"], "email-field", ui.EVIDENCE_BASE)
        self.assertTrue(args.replace)
        self.assertEqual(args.action, "type")

    def test_checks_visible_nonclickable_labels_without_returning_values(self):
        root = ET.fromstring('<hierarchy><node bounds="[0,0][400,800]">'
                            '<node text="Saved demonstration plan" clickable="false" bounds="[10,10][350,50]"/>'
                            '<node text="Previous account" visible-to-user="false" bounds="[10,100][350,150]"/>'
                            '</node></hierarchy>')
        checks = runner.evaluate(root, {"expectAll": ["demonstration"], "expectNone": ["Previous account"]})
        self.assertEqual(checks, {"expectAll": [True], "expectNone": [True]})
        self.assertNotIn("demonstration", str(checks))
        self.assertTrue(runner.expectations_pass(checks))

    def test_stop_on_action_failure_preserves_previous_pass_and_hides_commands(self):
        class FakeController:
            calls = []

            def __init__(self, serial, root):
                self.root = root
                self.step = None

            def operate(self, args):
                self.calls.append(args.name)
                self.step = self.root / args.name
                self.step.mkdir()
                (self.step / "before.xml").write_text(
                    '<hierarchy><node text="private-expectation-marker" bounds="[0,0][400,800]"/></hierarchy>',
                    encoding="utf-8")
                if args.name == "second":
                    raise ui.UiFailure("ADB_NONZERO_EXIT")
                return {"labels": ["not-for-output"]}

            def guard_foreground(self):
                return ui.PACKAGE

        temporary = workspace_scratch()
        output = io.StringIO()
        with redirect_stdout(output):
            code, result_path = runner.run_steps([
                {"name": "first", "command": ["inspect"], "expectAll": ["private-expectation-marker"]},
                {"name": "second", "command": ["inspect"]},
                {"name": "never", "command": ["inspect"]},
            ], temporary, controller_factory=FakeController)
        self.assertEqual(code, 1)
        self.assertEqual(FakeController.calls, ["first", "second"])
        result = json.loads(result_path.read_text(encoding="utf-8"))
        self.assertEqual(result["totalPassed"], 1)
        self.assertEqual(result["steps"][-1]["status"], "FAIL")
        self.assertEqual(result["steps"][-1]["reason"], "ADB_NONZERO_EXIT")
        self.assertNotIn("private-expectation-marker", output.getvalue())
        self.assertNotIn("private-expectation-marker", str(result))
        self.assertNotIn("not-for-output", output.getvalue())

    def test_load_rejects_duplicate_names_and_invalid_expectations(self):
        path = workspace_scratch() / "scenario.json"
        for steps in ([{"name": "same", "command": ["inspect"]}] * 2,
                      [{"name": "valid", "command": ["inspect"], "expectAll": "text"}]):
            path.write_text(json.dumps(steps), encoding="utf-8")
            with self.assertRaises(ui.UiFailure):
                runner.load_steps(path, ui.EVIDENCE_BASE)

    def test_wait_only_inspects_without_repeating_original_mutation(self):
        class FakeController:
            calls = []

            def __init__(self, serial, root):
                self.root = root
                self.step = None

            def operate(self, args):
                self.calls.append(args.action)
                self.step = self.root / args.name
                self.step.mkdir()
                label = "Loading" if args.action == "tap" else "Ready"
                filename = "after.xml" if args.action == "tap" else "before.xml"
                (self.step / filename).write_text(
                    f'<hierarchy><node text="{label}" bounds="[0,0][400,800]"/></hierarchy>', encoding="utf-8")
                return {}

            def guard_foreground(self):
                return ui.PACKAGE

        temporary = workspace_scratch()
        with redirect_stdout(io.StringIO()), mock.patch.object(runner.time, "sleep"):
            code, result_path = runner.run_steps([
                {"name": "save-once", "command": ["tap", "--label", "Save"], "expectAll": ["Ready"]}
            ], temporary, controller_factory=FakeController)
            self.assertEqual(code, 0)
            self.assertEqual(FakeController.calls, ["tap", "inspect"])
            self.assertEqual(json.loads(result_path.read_text(encoding="utf-8"))["totalPassed"], 1)

    def test_capture_root_does_not_add_scenario_nesting_for_windows_adb(self):
        class FakeController:
            roots = []

            def __init__(self, serial, root):
                self.roots.append(root)
                self.root = root
                self.step = None

            def operate(self, args):
                self.step = self.root / "capture"
                self.step.mkdir()
                (self.step / "before.xml").write_text(
                    '<hierarchy><node text="Ready" bounds="[0,0][400,800]"/></hierarchy>', encoding="utf-8")
                return {}

            def guard_foreground(self):
                return ui.PACKAGE

        root = workspace_scratch()
        with redirect_stdout(io.StringIO()):
            code, result_path = runner.run_steps([
                {"name": "inspect-release", "command": ["inspect"], "expectAll": ["Ready"]}
            ], root, controller_factory=FakeController)
        self.assertEqual(code, 0)
        self.assertEqual(FakeController.roots, [root])
        self.assertNotEqual(result_path.parent, root)
        result = json.loads(result_path.read_text(encoding="utf-8"))
        self.assertEqual(result["steps"][0]["evidence"], [str(root / "capture")])

    def test_expired_wait_deadline_never_starts_an_adb_command(self):
        controller = runner.DeadlineAndroidUi(ui.SERIAL, ui.EVIDENCE_BASE)
        controller.deadline = 99
        with mock.patch.object(runner.time, "monotonic", return_value=100), mock.patch.object(ui.AndroidUi, "adb") as adb:
            with self.assertRaisesRegex(ui.UiFailure, "EXPECTATION_TIMEOUT"):
                controller.adb("shell", "uiautomator", "dump")
            adb.assert_not_called()


if __name__ == "__main__":
    unittest.main()
