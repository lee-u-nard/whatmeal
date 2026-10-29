# Narrow approval: valid-recipe save failure

Read-only inspection on 2026-10-26 confirms the active Firestore rules in `whatmeal-101` match the preserved local baseline after line-ending normalization. They do not match the verified optimized candidate. No user documents were read and no rules were changed.

The baseline has a reproduced evaluation-cost defect: a valid populated recipe exhausts Firestore's 1,000-expression budget, returning HTTP 403 with zero documents written. This is separate from AI inference and affects saving. The same captured recipe succeeds with the candidate below.

Proposed action, only after explicit approval: deploy **only Firestore rules** from `audit/cloud-test/recipe-budget-candidate.rules` to `whatmeal-101`.

- Candidate SHA-256: `49AA394DC5E125072AA73CB1DCF495CAD9185550D19532BA5037FA03AAC5B999`.
- Existing hash-bound evidence: exact captured recipe replay HTTP 200/two documents; **71/71 isolated emulator security cases passed**. Before deployment, rerun that security verification through the normal approved path. Do not deploy if it fails.
- The candidate reduces validator evaluation cost. It preserves field/type/length allowlists, ownership and roles, parent membership, and immutable reciprocal replacement links. It includes adversarial field-injection, Unicode, linked-meal and populated weekly-plan tests.
- No database migration, document edit/delete, authentication, indexes, App Check, billing, API-key restriction, Functions or GitHub change is proposed.
- Preserve the current rules source/release metadata before deployment. After deployment, read back and compare exact source. The previous rules can be restored if explicitly approved; that also restores the known save limitation.

Evidence: `audit/cloud-test/README.md`, `candidate-security-receipt.json`, `candidate-replay.txt`, and `recipe-budget-candidate.rules`. The 71-case result belongs to this exact candidate and the earlier approved **test-project** deployment; it does not certify the baseline currently active in `whatmeal-101`.

Without approval, leave `whatmeal-101` unchanged and report rich-recipe saving there as a release limitation. App-side retained-draft/save-only retry stays intact, so a failed save must not discard generated meals.

## Approved and completed

The owner explicitly approved **only this rules optimization**. The fresh suite passed **71/71, exit 0**. The connector job's success was not accepted because independent readback still showed the old source. The explicit project-scoped `firestore:rules` CLI deployment then completed with exit 0. Independent Rules API readback confirms raw active SHA-256 `49AA394DC5E125072AA73CB1DCF495CAD9185550D19532BA5037FA03AAC5B999`. The local rules file was aligned to that exact approved source after preserving the original backup. No production user documents, App Check, billing, Auth, indexes or Functions changed. Evidence: `build/prototype-final-20261026-d8c1/rules-explicit-deploy.txt`, `rules-independent-after.json`, `rules-local-alignment.json`, and the fresh candidate-security receipt. [Final handoff](ACADEMIC_RELEASE_20261026.md).
