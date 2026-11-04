# Build and verification

Use a commit from the CCKF preparation branch. The workflow `.github/workflows/cckf-review-build.yml` checks out `${{ github.sha }}` from this fork, so the source and UI patch are reviewable at the triggering commit. It builds Windows x64 only, using the upstream Windows, bridge and helper-program steps. It does not request signing or publish a Release.

Start **CCKF unsigned review build** manually in GitHub Actions after reviewing the source. The build depends on external toolchains and upstream engine/driver downloads; it is traceable but not claimed to be bit-for-bit reproducible. Some upstream download URLs remain mutable and need a pinned/checksummed dependency audit before signing approval.

The `CCKF-unsigned-deployment-review` artifact contains a custom EXE, a SHA256 manifest, `SOURCE_COMMIT.txt`, deployment sources and documentation. Its `deployment.example.json` is a placeholder. No company password, host or private key is supplied by CI. A separate artifact contains the custom portable EXE. Artifacts expire after seven days; none is an approved signed distribution.

Run local deployment tests with Windows PowerShell 5.1:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\cckf\tests\Test-Deployment.ps1
```

The source-check workflow runs the same tests on Windows pull requests. Tests cover script syntax, profile validation, password-property rejection, empty CLI output, null verification values and exact public-key comparison. They do not install a service or connect to a real support server.

Before release, also test clean install, repair, upgrade, uninstall, ID registration, password access, hidden settings, automatic UI launch and restart behavior on a representative Windows machine with normal security controls. A source change or new signature requires testing the exact final artifact again.
