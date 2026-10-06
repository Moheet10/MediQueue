# Evidence Checklist — MediQueue Assignment

Numbered list of exactly 10 screenshots to capture:

| # | What to Screenshot | Where to Find It | What Must Be Visible |
|---|-------------------|-------------------|---------------------|
| 1 | ✅ Green CI/CD run with both jobs | GitHub → Actions tab → latest run on main | Both "Build & Test" and "Deploy to Staging" jobs green with checkmarks |
| 2 | ❌→✅ Red run then green run | GitHub → Actions tab → show the failed run (broken TC05) and the subsequent fixed green run | Failed run with red ✗, then the next run with green ✓ |
| 3 | Test report: TC01–TC07 passed | GitHub → Actions → green run → Build & Test job → expand "Run tests" step | All 7 test names (TC01 to TC07) with PASS status |
| 4 | Jira Product Backlog | Jira → MediQueue project → Backlog view | Epics (Authentication, Appointments, Consultation, Admin) with stories and story points visible |
| 5 | Sprint 1 planning view | Jira → Backlog → Sprint 1 section | Sprint 1 with MQ-1, MQ-2, MQ-6, total = 13 story points |
| 6 | Scrum board with cards | Jira → Board view | Cards in at least 2 different columns (e.g., To Do, In Progress, Done) |
| 7 | Burndown Chart or Sprint Report | Jira → Reports → Burndown Chart or Sprint Report | Chart showing sprint progress with story points |
| 8 | Jira issue with GitHub integration | Jira → Open MQ-3 → Development panel | Linked branch, commits, PR, and build/deployment status |
| 9 | GitHub PR with Jira key | GitHub → Pull requests → any merged PR | PR title containing MQ-key, green CI checks passed |
| 10 | Git commit history | GitHub → repository → Commits | Multiple commits with MQ-key prefixes (MQ-1:, MQ-2:, etc.) |

> **Instructions**: Open each page/URL listed above, capture the screenshot, and paste it into your assignment document. Number them 1–10 matching this checklist.
