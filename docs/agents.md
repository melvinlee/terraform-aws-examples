# Claude Code agents

Project agents live in [`.claude/agents/`](../.claude/agents/). Each file's `description:` is the source of truth for what the agent does and when Claude uses it; this page is an overview and may lag behind. To use one, ask Claude, for example "use tf-planner on ec2" or "use issue-worker on #31".

## Agents

| Agent | Purpose | Edits files |
|---|---|---|
| [`issue-worker`](../.claude/agents/issue-worker.md) | Starts work on a GitHub issue: reads it (asks if unclear), runs `git pull --rebase` on `main`, creates `feat/<n>-<slug>` or `fix/<n>-<slug>`, returns a hand-off brief for `module-builder` | No (creates a local branch only) |
| [`module-builder`](../.claude/agents/module-builder.md) | Builds or changes a standalone Terraform module following `CLAUDE.md`, then validates it | Yes |
| [`tf-auditor`](../.claude/agents/tf-auditor.md) | Read-only audit of modules against the `CLAUDE.md` conventions | No |
| [`tf-planner`](../.claude/agents/tf-planner.md) | Runs `tofu plan` in one module, summarises the changes in a table and gives a safe-to-proceed verdict. Needs AWS credentials; never applies | No |
| [`pr-reviewer`](../.claude/agents/pr-reviewer.md) | Read-only PR review: diff, fmt, validate, CI status, security, conventions | No |
| [`azure-pipeline`](../.claude/agents/azure-pipeline.md) | Builds and reviews Azure DevOps pipelines | Yes, in build mode |

## Typical workflow

1. `issue-worker` reads the issue and creates a fresh branch from an up-to-date `main`.
2. `module-builder` implements it from the hand-off brief.
3. `tf-auditor` checks the result against the conventions.
4. `tf-planner` plans the module and reports whether it is safe to proceed.
5. Commit, push and open a PR (done by hand or by asking Claude).
6. `pr-reviewer` reviews the PR.

`azure-pipeline` is separate: use it for Azure DevOps pipeline files.

## Notes

- Agents cannot start other agents, so `issue-worker` returns a brief and the main session passes it to `module-builder`.
- None of the agents commit, push or apply unless explicitly told to.
- Check files on disk after an agent reports; an agent's report can claim changes that were not made.
- Commits and PRs in this repo carry no `Co-Authored-By` line.
