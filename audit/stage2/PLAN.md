# Stage 2 work batches

Stage 1 report is the baseline. Existing uncommitted changes are preserved.
No Firestore rules, production records, deployments, paid services, or storage migration.

1. Approval-only proposal: C01/C02 + H07/H08/M10; M05 storage options.
2. Safe data repairs: transactional meal replacement (H09), quota reservations (M04),
   nested plan streams (M14); inject storage boundaries for tests.
3. Grocery initialization/deduplication (M03): preserve existing lists and records;
   no destructive consolidation or permission changes.
4. Provider settings stream (M06), safe error boundary (M07), explicit supported
   custom protocol (M13), transport/repository tests (M09).
5. Read-only host diagnostics for Java/Gradle/loopback. Only retry a release build
   if diagnostics identify a justified non-security-weakening remedy.
6. Per-batch tests and analysis, final report and approval request for the proposal.
