# Contributing

Thank you for your interest in improving **ubopt**.

## Workflow Summary
1. Fork and create a feature branch.
2. Keep changes focused and modular.
3. Run local tests:
   - `bash tests/modules/test_backup.sh`
   - `bash tests/modules/test_benchmark.sh`
   - `bash tests/modules/test_hardening.sh`
4. Run `make shellcheck` and ensure no high‑severity issues.
5. Submit a PR describing motivation and design.

## Commit Style
Use conventional commits where practical:
`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`.

## Dry-Run Semantics
System changing commands MUST support `--dry-run` and return exit code **20** for planned changes.

## Versioning
Increment version via `tools/version_bump.sh` only on main after merge.

## Testing Philosophy
- Fast, deterministic Bash tests.
- Avoid requiring root for tests (use dry-run paths).

## Reporting Issues
Include:
- Platform / distro version
- ubopt version (`ubopt --version`)
- Reproduction steps
- Relevant log excerpt from `ubopt.log`

## Security
Report security issues privately (open an issue with `SECURITY` label and minimal detail requesting a contact channel).
