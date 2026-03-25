---
name: pr-feedback-executor
description: Read PR comments/reviews, implement all feedback, add tests, update docs, execute related improvements, and push clean commit
author: David Griswold
version: 1.0
status: active
---

# PR Feedback Executor

Execute all feedback from a PR review in a single, clean commit.

## When to Use

- You have a PR with reviewer feedback
- You want all comments addressed automatically
- You want tests added for new functionality
- You want docs updated
- You're open to related improvements the executor spots

## How to Invoke

**Direct:**
```
Repo: dgrizzy/Amplify
PR: #14
```

**Via Sessions:**
Use `sessions_spawn` with `runtime="subagent"`:
```json
{
  "task": "Execute PR feedback for [repo] PR [number]",
  "runtime": "subagent",
  "mode": "run"
}
```

## Workflow

### 1. **Gather Feedback**
- Fetch PR comments, reviews, and discussions
- Parse reviewer requirements
- Understand context and intent

### 2. **Implement Changes**
- Address all explicitly requested changes
- Fix related issues spotted during review
- Maintain existing code patterns/conventions

### 3. **Test**
- Add tests for all new functionality (TDD)
- Run full test suite to verify no regressions
- Update fixtures/mocks if needed

### 4. **Document**
- Update relevant docstrings
- Update README/docs if applicable
- Add inline comments where helpful

### 5. **Improve**
- Make any additional improvements I recommend
- Fix style/quality issues
- Refactor for clarity if needed

### 6. **Commit**
- Single squashed commit
- Message format: `fix: address PR feedback (#<number>)`
- Include references to key changes

### 7. **Push**
- Push to the PR's feature branch
- Leave PR open for continued review
- Do NOT approve own work

## Constraints

- ✅ Fix related issues discovered during review
- ✅ Add tests for new functionality
- ✅ Run full test suite (verify no regressions)
- ✅ Update all relevant documentation
- ✅ Make recommended improvements
- ✅ Single squashed commit
- ✅ Leave PR open (don't merge or approve)
- ❌ Don't approve own work
- ❌ Don't merge PR

## Output Expectations

When complete, deliver:

1. **Summary** — What feedback was addressed
2. **Changes** — High-level description of what changed
3. **Tests** — What tests were added/modified
4. **Docs** — What documentation was updated
5. **Improvements** — Any additional changes made
6. **Commit Hash** — The squashed commit ID
7. **Status** — "Ready for your review" (PR left open)

## Example

**Input:**
```
Repo: dgrizzy/Amplify
PR: #14
```

**Output (summary):**
```
## PR #14 Feedback Executed ✅

**Feedback Addressed:**
- [x] Add validation to PmsClientPool
- [x] Handle calendar API timeout edge case
- [x] Improve error messages

**Changes:**
- Modified: libs/amplify/pms/pool.py (added validation)
- Modified: libs/amplify/pms/refresh_jobs.py (timeout handling)
- Modified: apps/amplify_api/handlers.py (error messages)
- Added: tests/amplify_api/unit/test_pms_pool.py (12 new tests)
- Updated: docs/PMS_INTEGRATION.md

**Tests:**
- 12 new tests for validation logic
- All existing tests pass ✅
- No regressions detected

**Additional Improvements:**
- Refactored retry logic for clarity
- Added type hints to helper functions
- Improved logging in error paths

**Commit:**
`fix: address PR feedback (#14)` (abc1234)

**Status:** Ready for your review. PR left open.
```

## Notes

- This skill assumes you have git/GitHub access and are on the correct branch
- All changes should follow your existing code patterns (TDD, type hints, docstrings)
- If feedback is ambiguous, make reasonable assumptions and note them in the summary
- Related improvements are *your* call — I'll flag them, you decide if they're in scope

---

This skill is designed for efficiency: read once, execute completely, one clean commit, no back-and-forth.
