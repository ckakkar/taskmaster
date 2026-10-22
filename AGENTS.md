# Repository Guidelines

## Project Structure & Module Organization

The `taskmaster/` directory currently has no source files, dependency manifests, tests, or Git metadata. Establish the structure alongside the first implementation:

- `src/`: application code, grouped by feature or responsibility.
- `tests/`: automated tests, mirroring source modules where practical.
- `assets/`: static resources, if needed.
- `docs/`: setup instructions and architectural decisions.

These directories are proposed conventions; create them only when they contain useful files.

## Build, Test, and Development Commands

No installation, development, build, or test commands are configured yet. When introducing a toolchain, document exact commands in `README.md` for dependency installation, local development, production builds, tests, and linting. Ensure contributors can run them from the repository root. Commit the relevant dependency manifest and lockfile, and exclude generated outputs and installed dependencies through `.gitignore`.

## Coding Style & Naming Conventions

No language, indentation standard, formatter, or linter has been selected. Follow the chosen language's established conventions and configure formatting and linting with the initial implementation. Use descriptive names, keep modules focused, and apply consistent indentation within each file. Document any naming rules that automated tools cannot enforce.

## Testing Guidelines

No testing framework or coverage threshold exists. Introduce a suitable framework with the first application code and document its invocation. Follow the framework's discovery conventions, such as `test_<module>.py` or `<module>.test.ts`, depending on the stack. Test observable behavior, including failure cases, and add regression tests when fixing bugs.

## Commit & Pull Request Guidelines

There is no Git history from which to infer commit conventions. Use short, imperative commit subjects, such as `Add task creation endpoint`, and keep commits focused. Pull requests should explain the purpose, summarize changes, link relevant issues, and report validation commands and results. Include screenshots for visible interface changes and identify any setup or migration steps.

## Security & Configuration

Keep credentials and local configuration out of version control. Document required configuration with placeholder values in an example file, such as `.env.example`, and ignore local overrides.
