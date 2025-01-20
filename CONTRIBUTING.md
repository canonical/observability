Here are some guidelines to follow when contributing to this repository.

We use [`just`](https://github.com/casey/just) to run quality checks on this repo. Whenever you open a PR with some changes, CI will run them automatically. To run them locally, simply run `just` and look at the available commands.

## GitHub Workflows

Our CI adheres to these **guiding principles**:
- **simplicity**: our workflows strive to minimize the amount of moving parts (external actions and tooling);
- **stability**: our workflows should be tested (e.g., statically and manually on [`o11y-tester`](https://github.com/canonical/o11y-tester-operator)) and versioned, to avoid breaking us and other users;
- **repeatability**: when possible, workflows should be composed of commands that are also executable locally, in order to ease testing;
- **decoupling from GitHub CI**: minimize the amount of GitHub-specific features (e.g., actions), relying on Bash where possible.

The workflows are versioned via GitHub tags. When making a change, please follow this process:
1. open a PR to `main` and use `just` to lint your workflows;
2. test your changes manually on [`o11y-tester`](https://github.com/canonical/o11y-tester-operator) by pointing its workflows to your dev branch;
3. once you're confident everything works and your PR is approved by a CODEOWNER and merged, determine if your changes are breaking or not:
  - for **breaking changes**, create a new version tag (if the latest is `v1`, create `v2`)
  - for **non-breaking changes**, update the latest version tag to point to `main`

## Scripts

Helper scripts live in the `scripts` folder. When contributing a new one, remember to:
- add an entrypoint for your script in `scripts/pyproject.toml`;
- add a brief description of your script in the `README.md`.

