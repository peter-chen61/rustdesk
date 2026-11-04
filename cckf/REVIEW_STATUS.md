# Signing application readiness

## Prepared in this branch

- The upstream 1.5.1 baseline is identified by commit.
- The server-settings UI change is committed directly to the source fork.
- Windows application ProductName/FileDescription identify the independent CCKF client; upstream copyright notices remain.
- The generic deployment template is derived from the internally tested r7 logic and excludes organization-specific server/key/password values.
- The review workflow builds the triggering fork commit and publishes unsigned review artifacts, not a signed Release.
- Local tests and a Windows source-check workflow cover the deployment regressions already encountered.
- Project purpose, privacy, system changes, removal, maintenance and pending code-signing policy are documented.

## Still required; do not claim complete

- SignPath acceptance and an approved project/artifact/signing configuration.
- Owner confirmation of maintainer/reviewer/approver roles and MFA.
- Dependency/license eligibility review, external binary ownership and signing coverage.
- Audit and pin/checksum all external release downloads used by the inherited upstream build steps.
- A new full CI build from this branch and end-to-end tests of this exact public deployment variant.
- Confirmation of metadata requirements for every owned binary; only Windows runner metadata is customized here.
- A decision from the provider about signing a company-private single-EXE installer that presets an access password.
- Script signing/execution-policy validation and a complete approved nested signing pipeline.
- A public vulnerability-reporting contact, release/download page and signed release evidence.

The existing internal r7 binary is retained separately. These source preparations neither replace it nor retroactively sign it.
