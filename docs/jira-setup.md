Click-by-click guide with these sections:

### 1. Create the Jira Project
1. Go to https://id.atlassian.com and sign up / log in
2. Navigate to Jira Software > Projects > Create Project
3. Select "Scrum" template
4. Project name: MediQueue, Key: MQ
5. Click Create

### 2. Import the Backlog CSV
1. Go to Project Settings > System > External System Import (or use the global import: Settings > System > Import > CSV)
2. Alternatively: Jira top menu > Settings (gear) > System > External System Import > CSV
3. Upload `jira/mediqueue-backlog.csv`
4. Map columns: Summary → Summary, Issue Type → Issue Type, Epic Name → Epic Name, Story Points → Story Points, Description → Description, Priority → Priority
5. Map "Acceptance Criteria" to a custom text field or Description
6. Map "Sprint" to Sprint
7. Click Import, verify all 10 rows imported

### 3. Configure Sprints
1. Go to Backlog view (left sidebar > Backlog)
2. You should see Sprint 1, Sprint 2, Sprint 3 created from import
3. If not, create sprints manually and drag stories into them:
   - Sprint 1 (13 points): MQ-1, MQ-2, MQ-6
   - Sprint 2 (13 points): MQ-3, MQ-4
   - Sprint 3 (8 points): MQ-5
4. Set Sprint 1 duration to 2 weeks, click "Start Sprint"

### 4. Use the Scrum Board
1. Click "Board" in left sidebar
2. You'll see columns: To Do, In Progress, Done
3. Drag MQ-1 to "In Progress" to start work
4. After completing MQ-1, drag it to "Done"
5. Repeat for other stories in the sprint

### 5. View Reports
1. **Backlog**: Left sidebar > Backlog — see all epics, stories, points
2. **Scrum Board**: Left sidebar > Board — see Kanban-style columns
3. **Burndown Chart**: Left sidebar > Reports > Burndown Chart (available after sprint starts)
4. **Sprint Report**: Left sidebar > Reports > Sprint Report (shows completed vs incomplete)

### 6. Tips for Screenshots
- Backlog view: expand epics to show stories with story points
- Board: have cards in different columns (To Do, In Progress, Done)
- Burndown: complete some stories first to see the line go down
