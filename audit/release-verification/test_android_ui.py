"""Synthetic helper tests. These never connect to Android or Firebase."""

import shlex
import unittest
from unittest import mock
import xml.etree.ElementTree as ET

import android_ui as ui


def screen(extra=""):
    return ET.fromstring(
        '<hierarchy><node bounds="[0,0][400,800]" enabled="true">'
        '<node text="Sign In" clickable="true" enabled="true" bounds="[10,500][390,560]"/>'
        '<node class="android.widget.EditText" text="private@example.test" enabled="true" bounds="[10,100][390,150]"/>'
        '<node content-desc="Owner private@example.test" bounds="[10,200][390,250]"/>'
        + extra + '</node></hierarchy>'
    )


class HelperTests(unittest.TestCase):
    def test_foreground_reads_global_window_focus(self):
        class Fake(ui.AndroidUi):
            def adb(self, *arguments, **kwargs):
                self.arguments = arguments
                if arguments != ("shell", "dumpsys", "window"):
                    return "Window subsection has no global focus field"
                return "  mCurrentFocus=Window{23194f u0 com.example.whatmeal.showcase/com.example.whatmeal.MainActivity}"
        fake = Fake(ui.SERIAL, ui.EVIDENCE_BASE)
        self.assertEqual(fake.foreground(), ui.PACKAGE)
        self.assertEqual(fake.arguments, ("shell", "dumpsys", "window"))

    def test_rejects_existing_user_device(self):
        with self.assertRaisesRegex(ui.UiFailure, "DEVICE_NOT_ALLOWED"):
            ui.AndroidUi("emulator-5564", ui.EVIDENCE_BASE)

    def test_requires_private_evidence_tree(self):
        with self.assertRaisesRegex(ui.UiFailure, "EVIDENCE_PATH_NOT_ALLOWED"):
            ui.evidence_path("audit/stage15")
        with self.assertRaisesRegex(ui.UiFailure, "EVIDENCE_PATH_NOT_ALLOWED"):
            ui.evidence_path("build/release-safety-audit/../../audit")
        self.assertTrue(ui.evidence_path("build/release-safety-audit/new").is_relative_to(ui.EVIDENCE_BASE))

    def test_redacts_editable_and_email_labels(self):
        labels = ui.public_labels(screen())
        serialized = str(labels)
        self.assertNotIn("private@example.test", serialized)
        self.assertIn("[editable redacted]", serialized)
        self.assertIn("[email redacted]", serialized)
        self.assertIn("Sign In", serialized)

    def test_ambiguous_taps_require_explicit_index(self):
        root = screen('<node text="Sign In" clickable="true" enabled="true" bounds="[10,600][390,660]"/>')
        with self.assertRaisesRegex(ui.UiFailure, "EXPECTED_ONE_CLICKABLE_CONTROL"):
            ui.select_tap(root, "Sign In")
        self.assertEqual(ui.bounds(ui.select_tap(root, "Sign In", index=1)), (10, 600, 390, 660))
        with self.assertRaisesRegex(ui.UiFailure, "CONTROL_INDEX_OUT_OF_RANGE"):
            ui.select_tap(root, "Sign In", index=2)

    def test_invitation_tokens_and_action_links_are_redacted(self):
        token = "aB_9" * 8
        root = screen(f'<node text="Invitation: {token}" bounds="[10,300][390,350]"/>'
                      '<node text="http://localhost/action?oobCode=private" bounds="[10,360][390,400]"/>')
        labels = str(ui.public_labels(root))
        self.assertNotIn(token, labels)
        self.assertNotIn("oobCode=private", labels)
        self.assertIn("[token redacted]", labels)
        self.assertIn("[account action link redacted]", labels)

    def test_contains_matching_is_explicit_and_disabled_controls_ignored(self):
        root = screen('<node text="Sign" clickable="true" enabled="false" bounds="[10,600][390,660]"/>')
        with self.assertRaisesRegex(ui.UiFailure, "EXPECTED_ONE_CLICKABLE_CONTROL"):
            ui.select_tap(root, "Sign")
        self.assertEqual(ui.select_tap(root, "Sign", contains=True).get("text"), "Sign In")

    def test_offscreen_and_zero_bounds_are_not_tappable(self):
        root = screen('<node text="Outside" clickable="true" enabled="true" bounds="[410,10][420,50]"/>'
                      '<node text="Hidden" clickable="true" enabled="true" bounds="[1,1][1,1]"/>')
        for label in ("Outside", "Hidden"):
            with self.assertRaises(ui.UiFailure):
                ui.select_tap(root, label)

    def test_text_shell_metacharacters_are_one_remote_argument(self):
        value = "sample'p$ss;word &test"
        self.assertEqual(shlex.split(ui.text_argument(value)), [value.replace(" ", "%s")])
        for invalid in ("", "literal%svalue", "line\nbreak", "nonascii\u00e9"):
            with self.assertRaisesRegex(ui.UiFailure, "TEXT_INPUT_NOT_SUPPORTED"):
                ui.text_argument(invalid)

    def test_detects_anr_without_dismissing_it(self):
        self.assertTrue(ui.has_crash_label(screen('<node text="WhatMeal isn’t responding" bounds="[1,1][300,100]"/>')))
        self.assertFalse(ui.has_crash_label(screen()))

    def test_replace_paces_bounded_delete_events_and_settles_before_verifying(self):
        class Fake(ui.AndroidUi):
            def adb(self, *arguments, **kwargs):
                self.commands.append(arguments)
                return ""
            def guard_foreground(self, allow_system=False):
                return ui.PACKAGE
        fake = Fake(ui.SERIAL, ui.EVIDENCE_BASE)
        fake.commands = []
        node = ET.fromstring('<node text="abc"/>')
        with mock.patch.object(ui.time, "sleep") as settle:
            fake.replace_field(node)
            self.assertEqual(settle.call_args_list, [mock.call(0.25), mock.call(0.5)])
        self.assertEqual(fake.commands, [
            ("shell", "input", "keyevent", "123"),
            ("shell", "input", "keyevent", "--delay", "100", "67", "67", "67", "67", "67"),
        ])
        fake.commands.clear()
        with mock.patch.object(ui.time, "sleep"):
            fake.replace_field(ET.fromstring('<node text=""/>'))
        self.assertEqual(fake.commands[-1], ("shell", "input", "keyevent", "--delay", "100", "67", "67"))
        fake.commands.clear()
        with self.assertRaisesRegex(ui.UiFailure, "EXISTING_TEXT_TOO_LONG_TO_REPLACE"):
            fake.replace_field(ET.Element("node", {"text": "x" * 513}))
        self.assertEqual(fake.commands, [])

    def test_clear_verification_rejects_residual_text_before_any_insertion(self):
        root = screen()
        field = ui.editable_fields(root)[0]
        field.set("focused", "true")
        field.set("text", "13 cups")
        with self.assertRaisesRegex(ui.UiFailure, "FIELD_NOT_EMPTY_AFTER_CLEAR"):
            ui.verify_empty_field(root, field)
        field.set("text", "")
        self.assertIs(ui.verify_empty_field(root, field), field)

    def test_focused_verification_survives_other_field_visibility_changes(self):
        root = screen()
        field = ui.editable_fields(root)[0]
        field.set("text", "3 cups")
        field.set("focused", "true")
        self.assertEqual(ui.verify_typed_value(root, 1, "3 cups", False,
                                             require_focus=True), "TEXT_VALUE_VERIFIED")
        field.set("focused", "false")
        with self.assertRaisesRegex(ui.UiFailure, "FIELD_FOCUS_NOT_CONFIRMED"):
            ui.verify_typed_value(root, 0, "3 cups", False, require_focus=True)

    def test_type_operation_stops_before_insertion_if_clear_leaves_residue(self):
        class Fake(ui.AndroidUi):
            def guard_device(self):
                pass
            def guard_foreground(self, allow_system=False):
                return ui.PACKAGE
            def new_step(self, name):
                self.step = ui.EVIDENCE_BASE / "synthetic-no-files"
            def adb(self, *arguments, **kwargs):
                self.commands.append(arguments)
                return ""
            def capture(self, name, allow_system=False):
                root = screen()
                field = ui.editable_fields(root)[0]
                field.set("text", "13 cups" if name == "cleared" else "1 cup")
                field.set("focused", "false" if name == "before" else "true")
                return root
        fake = Fake(ui.SERIAL, ui.EVIDENCE_BASE)
        fake.commands = []
        args = ui.parser().parse_args([
            "--serial", ui.SERIAL, "--evidence-root", str(ui.EVIDENCE_BASE),
            "type", "--field-index", "0", "--private-file", "build/private.json",
            "--key", "quantity", "--replace",
        ])
        with mock.patch.object(ui.time, "sleep"), mock.patch.object(ui, "private_value", return_value="3 cups"):
            with self.assertRaisesRegex(ui.UiFailure, "FIELD_NOT_EMPTY_AFTER_CLEAR"):
                fake.operate(args)
        self.assertFalse(any(command[:3] == ("shell", "input", "text")
                             for command in fake.commands))

    def test_typed_text_is_verified_without_value_in_errors_or_labels(self):
        root = screen()
        self.assertEqual(ui.verify_typed_value(root, 0, "private@example.test", False), "TEXT_VALUE_VERIFIED")
        with self.assertRaises(ui.UiFailure) as failure:
            ui.verify_typed_value(root, 0, "different-secret@example.test", False)
        self.assertEqual(str(failure.exception), "TEXT_VALUE_MISMATCH")
        self.assertNotIn("different-secret", str(failure.exception))
        self.assertNotIn("private@example.test", str(ui.public_labels(root)))

    def test_password_only_checks_complete_mask_length_when_available(self):
        root = screen()
        field = ui.editable_fields(root)[0]
        field.set("password", "true")
        field.set("text", "\u2022" * 5)
        self.assertEqual(ui.verify_typed_value(root, 0, "abcde", True), "PASSWORD_MASK_LENGTH_VERIFIED")
        with self.assertRaisesRegex(ui.UiFailure, "PASSWORD_LENGTH_MISMATCH"):
            ui.verify_typed_value(root, 0, "longer-password", True)
        field.set("text", "\u2022\u2022e")
        self.assertEqual(ui.verify_typed_value(root, 0, "abcde", True), "PASSWORD_MASK_LENGTH_UNAVAILABLE")
        self.assertNotIn("\u2022\u2022e", str(ui.public_labels(root)))

    def test_wrong_avd_stops_before_any_app_operation(self):
        class Fake(ui.AndroidUi):
            def adb(self, *arguments, **kwargs):
                self.asserted_arguments = arguments
                return "whatmeal-stage9-aosp\nOK\n"
        fake = Fake(ui.SERIAL, ui.EVIDENCE_BASE)
        with self.assertRaisesRegex(ui.UiFailure, "AVD_IDENTITY_NOT_ALLOWED"):
            fake.guard_device()
        self.assertEqual(fake.asserted_arguments, ("emu", "avd", "name"))


if __name__ == "__main__":
    unittest.main()
