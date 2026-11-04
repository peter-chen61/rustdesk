# CCKF RustDesk Custom Client

This is an independent customization of [RustDesk](https://github.com/rustdesk/rustdesk), primarily intended for organization-authorized remote support using a self-hosted server. It is not an official RustDesk release or a product endorsed by the upstream maintainers.

The desktop source change hides the ID/Relay Server settings entry. It does not encrypt the server configuration or prevent an administrator from inspecting network connections or local files. Users can still see the application, their ID, and the connection interface. Existing upstream consent and permission controls remain in place.

## Source and build status

The baseline is upstream 1.5.1, commit `23e5bb471a040d62f0a6ad52591fb30784265b73`. Submodule commits remain recorded in the upstream Git tree. The CCKF UI modification is committed in `src/ui_interface.rs`; it is not applied as an undocumented build-time patch.

The earlier internal deployment wrapper r7 passed a maintainer-reported Windows installation and remote-connection test. The generic scripts in this directory are derived from that wrapper but load deployment details from a local profile and obtain the access password separately. They are a new review candidate, not a claim that this exact public bundle passed the internal end-to-end test.

- [Build and verification](BUILD.md)
- [Privacy and deployment changes](PRIVACY.md)
- [Code signing policy](CODE_SIGNING_POLICY.md)
- [Maintenance and security reporting](MAINTENANCE.md)
- [Readiness gaps](REVIEW_STATUS.md)

## Installation template

The unsigned review-build workflow produces a ZIP containing a custom portable EXE, the generic deployment scripts, a SHA256 manifest and a source commit identifier. It is not a signed release.

1. Extract the entire review ZIP into a local directory.
2. Copy `deployment.example.json` to `deployment.private.json`; enter the server and its public key. The example intentionally cannot pass validation.
3. Run `Install.cmd` and approve Windows elevation. The administrator supplies the permanent password through a masked prompt. For managed provisioning, the script also accepts a local `-PasswordFile`; protect that file and do not commit or publish it.
4. The script installs RustDesk, waits for its final service, sets the selected server/key and permanent password, selects permanent-password verification, checks saved service options, and opens RustDesk after successful completion.
5. Test a connection and service behavior after reboot before any wider deployment. The password's actual usability requires a connection test; the script does not claim to prove it from an exit code.

For an existing installation use `Install.ps1 -RepairOnly` with the same local profile. Repair changes network settings and replaces the permanent password. Do not run this during an active support session.

The tested internal single-EXE package with a preset password is a separate private artifact. Whether SignPath would approve that packaging model must be confirmed with them. This repository does not publish that password or private package and does not claim signing approval for it.

## System changes and removal

The upstream installer copies application files to Program Files and registers the RustDesk service and installation records, and may add shortcuts, firewall rules or upstream driver components. The deployment script changes RustDesk's network and password configuration. Review these changes with your organization before installation.

Uninstall using Windows **Settings → Apps → Installed apps → RustDesk → Uninstall**. Configuration files can remain under user/service profiles; follow your organization's retention policy for removal. This project does not silently delete them.

## License and attribution

The existing upstream [LICENSE](../LICENSE) and third-party notices remain in place. CCKF additions and modifications are provided under the repository's AGPL-3.0 license. Upstream copyrights are retained. Dependency and redistribution eligibility must still be reviewed for SignPath; this README is not a statement that every signing-program condition is already met.
