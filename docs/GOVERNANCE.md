# Governance and release authority

This is an independent project maintained by Nobuo Yoshida, not a World Bank
Group repository. It has no institutional product owner, method owner, release approver, security
owner or support service level. Author names and affiliations that appear in
documents do not imply institutional endorsement.

## Interim change control

1. Every candidate change is linked to an issue-register item or release note.
2. Statistical-method changes require a named method owner, validation evidence
   and recorded approval before production use.
3. Data, documentation, image and third-party rights require an approved asset
   inventory before an official or production release.
4. Security/privacy changes require review of data flows, providers, retention,
   residency, incident response and user notices.
5. A release manager records test, checksum, platform and document-QA evidence
   in `docs/RELEASE_CHECKLIST.md` and signs the exact commit/tag.
6. A production release must name the responsible organization, approvers,
   support channel, maintenance policy and vulnerability contact.

Until these roles and approvals are recorded, the package remains a release
candidate for review and testing, without a support commitment. Whether to
publish estimates as official statistics is for each national statistical
office to decide.
