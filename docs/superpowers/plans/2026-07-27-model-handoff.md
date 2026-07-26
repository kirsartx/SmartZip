# SmartZip 跨模型交接 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** 建立不依赖 Codex 或 EchoBird 会话 ID 的、可由任意模型在新会话中读取并继续的 SmartZip 项目交接协议。

**Architecture:** Git 工作树是事实来源；根目录 AGENTS.md 规定接手顺序和安全边界；docs/continuity/ 保存当前任务、稳定决定与固定续接提示。任何模型都在新会话中从这些文件恢复上下文，不继续另一供应商的会话。

**Tech Stack:** Markdown、Git、PowerShell、Pester 3.4（仅使用既有测试环境和文档化命令）。

## Global Constraints

- 不修改 SmartZip.ahk、lib/、生产构建或发布产物。
- 不修改 tests/RunCmdCapture.Fragment.ahk 的现有 LF 换行符工作树差异。
- 不写入 API 密钥、密码、会话 ID、响应项 ID 或未脱敏日志。
- 同一时间只允许一个模型编辑工作区；任一模型接手时必须新建会话。
- 必须使用 git status --short 和 git diff --check 验证交接状态；未运行的测试要明确标记为未运行。

---

## File Structure

| File | Responsibility |
| --- | --- |
| AGENTS.md | 对 Codex、EchoBird 和其他模型通用的项目入口、读取顺序、写入规则和验证规则。 |
| docs/continuity/ACTIVE_TASK.md | 唯一当前工作项、工作树状态、已完成/未完成事项与下一条验证命令。 |
| docs/continuity/DECISIONS.md | 跨会话必须保留的架构和工作流决定。 |
| docs/continuity/RESUME_PROMPT.md | 可直接粘贴到任一新会话的启动指令。 |

### Task 1: 创建跨模型入口与当前交接状态

**Files:**
- Create: AGENTS.md
- Create: docs/continuity/ACTIVE_TASK.md
- Create: docs/continuity/DECISIONS.md
- Create: docs/continuity/RESUME_PROMPT.md

**Interfaces:**
- Consumes: README.md, tests/README.md, git status --short 和提交 d390d32。
- Produces: 一套可由任何新会话按固定顺序读取的 Markdown 交接接口。

- [ ] **Step 1: 创建根目录接手规则**

在 AGENTS.md 写入以下完整内容：

~~~
# SmartZip Agent Handoff Rules

## Start Here

Before proposing or editing code, read in this order:

1. docs/continuity/ACTIVE_TASK.md
2. docs/continuity/DECISIONS.md
3. README.md
4. tests/README.md
5. git status --short

Summarize the current task, working-tree state, and next verification command. Wait for the user's confirmation before editing.

## Cross-Model Continuity

- Treat project files and Git history as the source of truth; never rely on another provider's conversation, response ID, or session ID.
- Start a new conversation when switching between Codex and EchoBird.
- Only one model may edit this worktree at a time.
- Preserve existing user changes. Do not use git reset --hard, git checkout --, or overwrite an uncommitted file to make the tree clean.

## Before Handoff

Update docs/continuity/ACTIVE_TASK.md with the goal, completed work, remaining work, changed files, commands run, and their exact results. Record stable choices in docs/continuity/DECISIONS.md.

## Verification

Run git diff --check after edits. Run the focused or complete test command from tests/README.md when the task changes executable behavior. State explicitly when tests were not run.

## Sensitive Data

Do not record API keys, passwords, session IDs, response IDs, or unredacted logs in project files or prompts.
~~~

- [ ] **Step 2: 创建当前任务快照**

在 docs/continuity/ACTIVE_TASK.md 写入以下完整内容：

~~~~
# Active Task

## Purpose

Maintain a portable handoff state so Codex and EchoBird can continue SmartZip work in separate new conversations.

## Current Git State

- Branch: main
- Latest committed handoff design: d390d32 docs: add cross-model handoff design
- Existing user worktree change: tests/RunCmdCapture.Fragment.ahk
- Change classification: CRLF-to-LF conversion only; no functional code difference from HEAD has been observed.

## Completed

- Inspected the current SmartZip worktree and its test documentation.
- Recorded the cross-model handoff design in docs/superpowers/specs/2026-07-27-model-handoff-design.md.
- Confirmed that the pending fragment change is formatting-only.

## Remaining

- Create the project-level handoff files defined by the approved design.
- Decide whether the pending LF-only test-fragment change should be reverted or committed as an intentional formatting change. Do not make that decision without user direction.

## Verification History

- git diff --check: passed before creation of the project-level handoff files.
- SmartZip Pester suites: not run during this documentation-only task.

## Next Verification Command

~~~powershell
git status --short
git diff --check
~~~
~~~~

- [ ] **Step 3: 创建稳定决定记录**

在 docs/continuity/DECISIONS.md 写入以下完整内容：

~~~
# Cross-Model Decisions

## Conversation Boundary

Codex and EchoBird are separate conversation providers. Every provider switch starts a new conversation; models must rebuild context from repository files rather than continuing an old provider session.

## Source of Truth

Git history, the current worktree, and docs/continuity/ are authoritative. Model summaries are disposable convenience text.

## EchoBird Boundary

The installed EchoBird application contains its Responses-to-Chat translation and session storage in a compiled executable. This project does not patch that executable. An EchoBird conversation therefore receives the repository handoff prompt rather than a resumed Codex session.

## Mutation Safety

Only one model edits the worktree at a time. Existing uncommitted changes are user-owned until explicitly confirmed otherwise.
~~~

- [ ] **Step 4: 创建新会话续接提示词**

在 docs/continuity/RESUME_PROMPT.md 写入以下完整内容：

~~~
# Resume Prompt

Use the following text as the first message in a new Codex or EchoBird conversation:

> Open the SmartZip repository and continue it safely. Before editing anything, read AGENTS.md, docs/continuity/ACTIVE_TASK.md, docs/continuity/DECISIONS.md, README.md, and tests/README.md; then run git status --short. Reply with: (1) your understanding of the active task, (2) every existing uncommitted change and whether it is functional or formatting-only, (3) the next verification command, and (4) a concise edit plan. Do not modify files until I confirm the plan. Do not rely on, request, or reuse any prior conversation/session/response IDs.
~~~

- [ ] **Step 5: Verify the handoff contract before committing**

Run:

~~~powershell
@(
  'AGENTS.md',
  'docs/continuity/ACTIVE_TASK.md',
  'docs/continuity/DECISIONS.md',
  'docs/continuity/RESUME_PROMPT.md'
) | ForEach-Object {
  if (-not (Test-Path -LiteralPath $_)) { throw "Missing handoff file: $_" }
}
rg -n "conversation|new conversation|git status --short|git diff --check" AGENTS.md docs/continuity
git diff --check
git status --short
~~~

Expected: all four files exist; the required continuation and verification rules are found; git diff --check exits 0; tests/RunCmdCapture.Fragment.ahk remains the only pre-existing modification.

- [ ] **Step 6: Commit only the new handoff files**

Run:

~~~powershell
git add AGENTS.md docs/continuity/ACTIVE_TASK.md docs/continuity/DECISIONS.md docs/continuity/RESUME_PROMPT.md
git diff --cached --check
git commit -m "docs: add cross-model handoff protocol"
~~~

Expected: the commit contains only the four new handoff files. Do not stage tests/RunCmdCapture.Fragment.ahk.

### Task 2: Validate a provider-neutral restart

**Files:**
- Modify: docs/continuity/ACTIVE_TASK.md only if verification exposes a false status statement.

**Interfaces:**
- Consumes: the four files created in Task 1 and the current Git worktree.
- Produces: evidence that either a Codex or EchoBird new conversation can reconstruct the same state without old session metadata.

- [ ] **Step 1: Run the restart-readiness verification**

Run:

~~~powershell
$required = @(
  'AGENTS.md',
  'docs/continuity/ACTIVE_TASK.md',
  'docs/continuity/DECISIONS.md',
  'docs/continuity/RESUME_PROMPT.md',
  'README.md',
  'tests/README.md'
)
$required | ForEach-Object {
  $item = Get-Item -LiteralPath $_ -ErrorAction Stop
  "READABLE: $($item.FullName)"
}
git status --short
git diff --check
~~~

Expected: every required file is readable; only the user-owned tests/RunCmdCapture.Fragment.ahk remains unstaged; whitespace validation exits 0.

- [ ] **Step 2: Use a new EchoBird conversation for manual acceptance**

Paste the block under # Resume Prompt into a brand-new EchoBird conversation. Do not use a resume/continue command. Confirm that the model's first response identifies the formatting-only fragment change and proposes git status --short / git diff --check before editing.

- [ ] **Step 3: Record only discrepancies**

If the first response misses a required fact, update the relevant wording in AGENTS.md or RESUME_PROMPT.md, rerun Step 1, and commit the corrected documentation with:

~~~powershell
git add AGENTS.md docs/continuity/RESUME_PROMPT.md
git diff --cached --check
git commit -m "docs: clarify model handoff instructions"
~~~

If the response includes every required fact, do not create an unnecessary follow-up commit.

## Plan Self-Review

- Spec coverage: Task 1 implements project-local source of truth, new-session handoff, safety rules, active-state recording, stable decisions, and a reusable prompt. Task 2 verifies that those artifacts are provider-neutral.
- Placeholder scan: no incomplete markers, undefined interfaces, or unspecified commands remain.
- Consistency: every file named in AGENTS.md is created by Task 1; Task 2 consumes exactly those files.
