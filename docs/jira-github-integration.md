Write a comprehensive guide with these sections:

### Overview
Explain how "GitHub for Jira" app connects Jira Cloud and GitHub, enabling bidirectional traceability between code and issues.

### Step 1: Install GitHub for Jira App
1. Go to https://github.com/marketplace/jira-software-github
2. Click "Set up a plan" > Install it for free
3. Authorize it to access your GitHub account/org
4. In Jira: Apps > Manage apps > GitHub > Connect repository
5. Select the MediQueue repository

### Step 2: How Linking Works
Explain each linkage:
- **Branches**: Name branch with Jira key (e.g., `MQ-3-book-appointment`) → automatically linked to MQ-3 issue
- **Commits**: Include Jira key in commit message (e.g., `MQ-3: add booking endpoint`) → commit shows under the issue's Development panel
- **Pull Requests**: Include Jira key in PR title (e.g., `MQ-3: Implement appointment booking`) → PR shows under the issue with status (open/merged)
- **Build Status**: GitHub Actions CI status shows on the Jira issue under Deployments/Builds

### Step 3: View Development Info in Jira
1. Open any Jira issue (e.g., MQ-3)
2. Look at the "Development" panel on the right side
3. You'll see: X branches, Y commits, Z pull requests
4. Click each to see details and direct links back to GitHub

### Step 4: Create Automation Rule — PR Merged → Move to Done
1. In Jira: Project Settings > Automation (or Board > Automation)
2. Click "Create Rule"
3. Trigger: "Pull request merged" (under DevOps triggers)
4. Condition: Issue matches `project = MQ`
5. Action: "Transition issue" → set status to "Done"
6. Name the rule: "Auto-close on PR merge"
7. Click "Turn it on"

### Step 5: End-to-End Workflow
Describe the full flow:
1. Pick up MQ-3 from sprint backlog, move to In Progress
2. Create branch `MQ-3-book-appointment`
3. Commit with message `MQ-3: add booking endpoint`
4. Push and create PR titled `MQ-3: Implement appointment booking`
5. CI runs → green checks on PR
6. Merge PR → automation rule moves MQ-3 to Done
7. All artifacts visible in Jira Development panel
