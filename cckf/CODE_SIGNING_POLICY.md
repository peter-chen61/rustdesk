# Code signing policy

**Status: application submitted; review pending. No SignPath signing authorization, certificate or signed CCKF release has been issued or verified for this project.** Current review artifacts are unsigned. Do not describe them as SignPath-signed or as automatically accepted by Smart App Control.

The repository owner is `peter-chen61`. The proposed roles are maintainer/reviewer and release approver, subject to the owner's confirmation and the signing provider's requirements. MFA and provider account controls must be confirmed by the owner; this document does not claim they have been verified.

If the application is accepted, the intended policy is:

1. Review and commit source/build changes to the fork, identify the exact source commit, retain upstream license and dependency notices, and confirm artifact metadata.
2. Build artifacts in the approved CI workflow. Do not submit unrelated binaries or manually modified local packages as if they came from that build.
3. Have an authorized maintainer manually approve every signing request through the approved provider workflow. Do not expose provider credentials in source, logs or artifacts.
4. Sign approved owned EXE/DLL payloads and portable packers in the required order, then create and sign the outer installer. Audit upstream binaries and script execution separately; a signed wrapper does not confer a signature on its contents.
5. Timestamp and verify signatures, retain provenance and SHA256 manifests, and test the exact final distribution with Smart App Control enabled.
6. Publish only after policy, release evidence and organizational authorization are in place. Investigate reported signing misuse and withdraw affected releases where appropriate.

The provider's required sponsorship attribution will be added only after acceptance and confirmation of the applicable wording. No free-signing sponsorship is claimed now. No code-signing provider is currently configured in the workflow.

The earlier internal installer presets an access password; approval of such a private deployment artifact is an open question. Public review artifacts contain no organizational password. Code signing is not encryption and cannot conceal a bundled password.

References: [SignPath Foundation conditions](https://signpath.org/terms), [Smart App Control signing](https://learn.microsoft.com/en-us/windows/apps/develop/smart-app-control/code-signing-for-smart-app-control).
