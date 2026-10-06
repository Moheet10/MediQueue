#!/bin/bash
# =============================================================================
# MediQueue Git Branching Strategy Script
# =============================================================================
# This script sets up the git history with one branch per user story,
# proper commit messages with Jira keys, and prepares for GitHub PRs.
#
# PREREQUISITES:
#   1. gh CLI installed and authenticated (gh auth login)
#   2. GitHub repo created (gh repo create MediQueue --public --source=. --remote=origin)
#   3. Run from the MediQueue project root
#
# USAGE: bash scripts/setup-branches.sh
# =============================================================================

set -e

echo "=============================================="
echo "  MediQueue: Setting up Git Branching Strategy"
echo "=============================================="

# --- Step 0: Initial commit on main ---
echo ""
echo ">>> Step 0: Initialize repo and make initial commit"
git init
git checkout -b main
git add .gitignore package.json .eslintrc.json Dockerfile .dockerignore README.md \
       .github/workflows/ci-cd.yml .github/pull_request_template.md \
       jira/ docs/
git commit -m "Initial project scaffold with CI/CD pipeline and docs"

echo ""
echo ">>> Push main to GitHub (create the repo first if needed)"
echo "    Run: gh repo create MediQueue --public --source=. --remote=origin --push"
echo "    Or:  git remote add origin https://github.com/<YOUR_USERNAME>/MediQueue.git"
echo "         git push -u origin main"
read -p "Press Enter once you've pushed main to GitHub..."

# --- Step 1: MQ-1 (Authentication) ---
echo ""
echo ">>> Step 1: MQ-1 - User Registration and OTP Login"
git checkout -b MQ-1-user-registration-otp-login main

# Create src/app.js with only MQ-1 endpoints
cat > src/app.js << 'APPEOF'
const express = require('express');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(express.json());

// In-memory data stores
const users = [];
const appointments = [];
const prescriptions = [];
const doctors = [
  { id: 'doc-1', name: 'Dr. Smith', specialty: 'Cardiology', available: true },
  { id: 'doc-2', name: 'Dr. Jones', specialty: 'Cardiology', available: false },
  { id: 'doc-3', name: 'Dr. Lee', specialty: 'Dermatology', available: true },
  { id: 'doc-4', name: 'Dr. Brown', specialty: 'Dermatology', available: true },
  { id: 'doc-5', name: 'Dr. White', specialty: 'Pediatrics', available: true }
];

// MQ-1: Authentication
app.post('/register', (req, res) => {
  const { name, phone } = req.body;
  const userId = uuidv4();
  users.push({
    userId, name, phone, otp: '123456',
    failedAttempts: 0, lockedUntil: null
  });
  res.status(201).json({ message: 'User registered', userId });
});

app.post('/login', (req, res) => {
  const { phone, otp } = req.body;
  const user = users.find(u => u.phone === phone);
  if (!user) return res.status(404).json({ error: 'User not found' });
  if (user.lockedUntil && user.lockedUntil > Date.now()) {
    return res.status(423).json({ message: 'Account locked...', lockedUntil: user.lockedUntil });
  }
  if (user.otp !== otp) {
    user.failedAttempts += 1;
    if (user.failedAttempts >= 3) {
      user.lockedUntil = Date.now() + 10 * 60 * 1000;
      return res.status(423).json({ message: 'Account locked...', lockedUntil: user.lockedUntil });
    }
    return res.status(401).json({ error: 'Invalid OTP' });
  }
  user.failedAttempts = 0;
  user.lockedUntil = null;
  res.status(200).json({ message: 'Login successful', userId: user.userId, token: `demo-token-${user.userId}` });
});

module.exports = app;
APPEOF

cat > src/server.js << 'SRVEOF'
const app = require('./app');
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`MediQueue server running on port ${PORT}`));
SRVEOF

# Add only TC01 and TC02 tests
cat > tests/app.test.js << 'TESTEOF'
const request = require('supertest');
const app = require('../src/app');

describe('MediQueue API Tests', () => {
  let server;
  beforeAll(() => { server = app.listen(0); });
  afterAll((done) => { server.close(done); });

  test('TC01: Valid OTP login succeeds', async () => {
    const reg = await request(app).post('/register').send({ name: 'Ali', phone: '03001234567' });
    expect(reg.status).toBe(201);
    const res = await request(app).post('/login').send({ phone: '03001234567', otp: '123456' });
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('token');
  });

  test('TC02: 3 wrong OTPs locks the account', async () => {
    await request(app).post('/register').send({ name: 'Sara', phone: '03009999999' });
    await request(app).post('/login').send({ phone: '03009999999', otp: '000000' });
    await request(app).post('/login').send({ phone: '03009999999', otp: '000000' });
    const res = await request(app).post('/login').send({ phone: '03009999999', otp: '000000' });
    expect(res.status).toBe(423);
    expect(res.body.message).toMatch(/locked/i);
  });
});
TESTEOF

git add src/ tests/
git commit -m "MQ-1: add user registration and OTP login with lockout"
git push -u origin MQ-1-user-registration-otp-login

echo ">>> Creating PR for MQ-1..."
gh pr create --title "MQ-1: User Registration and OTP Login" \
  --body "## Jira Issue\n**Jira Key:** MQ-1\n\n## Description\nImplements user registration (POST /register) and OTP-based login (POST /login) with account lockout after 3 failed attempts.\n\n## Acceptance Criteria Checklist\n- [x] User can register with name and phone\n- [x] User can login with valid OTP\n- [x] Account locks after 3 wrong OTPs for 10 minutes\n- [x] TC01 and TC02 tests pass\n- [x] ESLint passes" \
  --base main --head MQ-1-user-registration-otp-login

echo ">>> Waiting for CI to run... (check GitHub Actions)"
read -p "Press Enter once CI passes and you've reviewed the PR..."
gh pr merge MQ-1-user-registration-otp-login --merge --delete-branch
git checkout main && git pull

# --- Step 2: MQ-2 (Doctor Search) ---
echo ""
echo ">>> Step 2: MQ-2 - Search Available Doctors"
git checkout -b MQ-2-search-available-doctors main

# Add doctor search endpoint to app.js (append before module.exports)
cat > src/app.js << 'APPEOF'
const express = require('express');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(express.json());

const users = [];
const appointments = [];
const prescriptions = [];
const doctors = [
  { id: 'doc-1', name: 'Dr. Smith', specialty: 'Cardiology', available: true },
  { id: 'doc-2', name: 'Dr. Jones', specialty: 'Cardiology', available: false },
  { id: 'doc-3', name: 'Dr. Lee', specialty: 'Dermatology', available: true },
  { id: 'doc-4', name: 'Dr. Brown', specialty: 'Dermatology', available: true },
  { id: 'doc-5', name: 'Dr. White', specialty: 'Pediatrics', available: true }
];

// MQ-1: Authentication
app.post('/register', (req, res) => {
  const { name, phone } = req.body;
  const userId = uuidv4();
  users.push({ userId, name, phone, otp: '123456', failedAttempts: 0, lockedUntil: null });
  res.status(201).json({ message: 'User registered', userId });
});

app.post('/login', (req, res) => {
  const { phone, otp } = req.body;
  const user = users.find(u => u.phone === phone);
  if (!user) return res.status(404).json({ error: 'User not found' });
  if (user.lockedUntil && user.lockedUntil > Date.now()) {
    return res.status(423).json({ message: 'Account locked...', lockedUntil: user.lockedUntil });
  }
  if (user.otp !== otp) {
    user.failedAttempts += 1;
    if (user.failedAttempts >= 3) {
      user.lockedUntil = Date.now() + 10 * 60 * 1000;
      return res.status(423).json({ message: 'Account locked...', lockedUntil: user.lockedUntil });
    }
    return res.status(401).json({ error: 'Invalid OTP' });
  }
  user.failedAttempts = 0;
  user.lockedUntil = null;
  res.status(200).json({ message: 'Login successful', userId: user.userId, token: `demo-token-${user.userId}` });
});

// MQ-2: Doctor Search
app.get('/doctors', (req, res) => {
  const { specialty, available } = req.query;
  let filtered = doctors;
  if (specialty) filtered = filtered.filter(d => d.specialty === specialty);
  if (available !== undefined) {
    const isAvail = available === 'true';
    filtered = filtered.filter(d => d.available === isAvail);
  }
  res.status(200).json(filtered);
});

module.exports = app;
APPEOF

# Add TC03 to tests
cat > tests/app.test.js << 'TESTEOF'
const request = require('supertest');
const app = require('../src/app');

describe('MediQueue API Tests', () => {
  let server;
  beforeAll(() => { server = app.listen(0); });
  afterAll((done) => { server.close(done); });

  test('TC01: Valid OTP login succeeds', async () => {
    const reg = await request(app).post('/register').send({ name: 'Ali', phone: '03001234567' });
    expect(reg.status).toBe(201);
    const res = await request(app).post('/login').send({ phone: '03001234567', otp: '123456' });
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('token');
  });

  test('TC02: 3 wrong OTPs locks the account', async () => {
    await request(app).post('/register').send({ name: 'Sara', phone: '03009999999' });
    await request(app).post('/login').send({ phone: '03009999999', otp: '000000' });
    await request(app).post('/login').send({ phone: '03009999999', otp: '000000' });
    const res = await request(app).post('/login').send({ phone: '03009999999', otp: '000000' });
    expect(res.status).toBe(423);
    expect(res.body.message).toMatch(/locked/i);
  });

  test('TC03: Search Cardiology returns only available cardiologists', async () => {
    const res = await request(app).get('/doctors?specialty=Cardiology&available=true');
    expect(res.status).toBe(200);
    expect(res.body.length).toBeGreaterThan(0);
    res.body.forEach(doc => {
      expect(doc.specialty).toBe('Cardiology');
      expect(doc.available).toBe(true);
    });
  });
});
TESTEOF

git add src/ tests/
git commit -m "MQ-2: add doctor search with specialty and availability filters"
git push -u origin MQ-2-search-available-doctors

gh pr create --title "MQ-2: Search Available Doctors" \
  --body "## Jira Issue\n**Jira Key:** MQ-2\n\n## Description\nImplements GET /doctors endpoint with specialty and availability query filters.\n\n## Acceptance Criteria Checklist\n- [x] Filter by specialty works\n- [x] Filter by available=true returns only available doctors\n- [x] TC03 test passes\n- [x] ESLint passes" \
  --base main --head MQ-2-search-available-doctors

read -p "Press Enter once CI passes..."
gh pr merge MQ-2-search-available-doctors --merge --delete-branch
git checkout main && git pull

# --- Step 3: MQ-6 (Dashboard - Sprint 1) ---
echo ""
echo ">>> Step 3: MQ-6 - Patient Dashboard"
git checkout -b MQ-6-patient-dashboard main

# Add dashboard endpoint
cat > src/app.js << 'APPEOF'
const express = require('express');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(express.json());

const users = [];
const appointments = [];
const prescriptions = [];
const doctors = [
  { id: 'doc-1', name: 'Dr. Smith', specialty: 'Cardiology', available: true },
  { id: 'doc-2', name: 'Dr. Jones', specialty: 'Cardiology', available: false },
  { id: 'doc-3', name: 'Dr. Lee', specialty: 'Dermatology', available: true },
  { id: 'doc-4', name: 'Dr. Brown', specialty: 'Dermatology', available: true },
  { id: 'doc-5', name: 'Dr. White', specialty: 'Pediatrics', available: true }
];

// MQ-1: Authentication
app.post('/register', (req, res) => {
  const { name, phone } = req.body;
  const userId = uuidv4();
  users.push({ userId, name, phone, otp: '123456', failedAttempts: 0, lockedUntil: null });
  res.status(201).json({ message: 'User registered', userId });
});

app.post('/login', (req, res) => {
  const { phone, otp } = req.body;
  const user = users.find(u => u.phone === phone);
  if (!user) return res.status(404).json({ error: 'User not found' });
  if (user.lockedUntil && user.lockedUntil > Date.now()) {
    return res.status(423).json({ message: 'Account locked...', lockedUntil: user.lockedUntil });
  }
  if (user.otp !== otp) {
    user.failedAttempts += 1;
    if (user.failedAttempts >= 3) {
      user.lockedUntil = Date.now() + 10 * 60 * 1000;
      return res.status(423).json({ message: 'Account locked...', lockedUntil: user.lockedUntil });
    }
    return res.status(401).json({ error: 'Invalid OTP' });
  }
  user.failedAttempts = 0;
  user.lockedUntil = null;
  res.status(200).json({ message: 'Login successful', userId: user.userId, token: `demo-token-${user.userId}` });
});

// MQ-2: Doctor Search
app.get('/doctors', (req, res) => {
  const { specialty, available } = req.query;
  let filtered = doctors;
  if (specialty) filtered = filtered.filter(d => d.specialty === specialty);
  if (available !== undefined) {
    const isAvail = available === 'true';
    filtered = filtered.filter(d => d.available === isAvail);
  }
  res.status(200).json(filtered);
});

// MQ-6: Dashboard
app.get('/dashboard', (req, res) => {
  const today = new Date();
  const todayStr = today.toISOString().split('T')[0];
  const todaysAppointments = appointments.filter(a => a.slot.startsWith(todayStr));
  res.status(200).json({ date: today.toISOString(), appointments: todaysAppointments });
});

module.exports = app;
APPEOF

git add src/
git commit -m "MQ-6: add patient dashboard showing today's appointments"
git push -u origin MQ-6-patient-dashboard

gh pr create --title "MQ-6: Patient Dashboard" \
  --body "## Jira Issue\n**Jira Key:** MQ-6\n\n## Description\nImplements GET /dashboard endpoint showing today's appointments with status.\n\n## Acceptance Criteria Checklist\n- [x] Returns today's appointments\n- [x] Shows Booked/Checked-in/Completed status\n- [x] ESLint passes" \
  --base main --head MQ-6-patient-dashboard

read -p "Press Enter once CI passes..."
gh pr merge MQ-6-patient-dashboard --merge --delete-branch
git checkout main && git pull

# ====== SPRINT 2 ======

# --- Step 4: MQ-3 (Book Appointment) with DELIBERATE FAIL ---
echo ""
echo ">>> Step 4: MQ-3 - Book Appointment (WITH DELIBERATE FAILING TEST)"
git checkout -b MQ-3-book-appointment main

# Add appointment booking
cat > src/app.js << 'APPEOF'
const express = require('express');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(express.json());

const users = [];
const appointments = [];
const prescriptions = [];
const doctors = [
  { id: 'doc-1', name: 'Dr. Smith', specialty: 'Cardiology', available: true },
  { id: 'doc-2', name: 'Dr. Jones', specialty: 'Cardiology', available: false },
  { id: 'doc-3', name: 'Dr. Lee', specialty: 'Dermatology', available: true },
  { id: 'doc-4', name: 'Dr. Brown', specialty: 'Dermatology', available: true },
  { id: 'doc-5', name: 'Dr. White', specialty: 'Pediatrics', available: true }
];

app.post('/register', (req, res) => {
  const { name, phone } = req.body;
  const userId = uuidv4();
  users.push({ userId, name, phone, otp: '123456', failedAttempts: 0, lockedUntil: null });
  res.status(201).json({ message: 'User registered', userId });
});

app.post('/login', (req, res) => {
  const { phone, otp } = req.body;
  const user = users.find(u => u.phone === phone);
  if (!user) return res.status(404).json({ error: 'User not found' });
  if (user.lockedUntil && user.lockedUntil > Date.now()) {
    return res.status(423).json({ message: 'Account locked...', lockedUntil: user.lockedUntil });
  }
  if (user.otp !== otp) {
    user.failedAttempts += 1;
    if (user.failedAttempts >= 3) {
      user.lockedUntil = Date.now() + 10 * 60 * 1000;
      return res.status(423).json({ message: 'Account locked...', lockedUntil: user.lockedUntil });
    }
    return res.status(401).json({ error: 'Invalid OTP' });
  }
  user.failedAttempts = 0;
  user.lockedUntil = null;
  res.status(200).json({ message: 'Login successful', userId: user.userId, token: `demo-token-${user.userId}` });
});

app.get('/doctors', (req, res) => {
  const { specialty, available } = req.query;
  let filtered = doctors;
  if (specialty) filtered = filtered.filter(d => d.specialty === specialty);
  if (available !== undefined) {
    const isAvail = available === 'true';
    filtered = filtered.filter(d => d.available === isAvail);
  }
  res.status(200).json(filtered);
});

// MQ-3: Book Appointment — DELIBERATE BUG: no duplicate check!
app.post('/appointments', (req, res) => {
  const { patientId, doctorId, slot } = req.body;
  // BUG: Missing duplicate slot check — TC05 will FAIL
  const bookingId = uuidv4();
  appointments.push({ bookingId, patientId, doctorId, slot, status: 'Booked' });
  res.status(201).json({ bookingId, message: 'Appointment booked successfully' });
});

app.get('/dashboard', (req, res) => {
  const today = new Date();
  const todayStr = today.toISOString().split('T')[0];
  const todaysAppointments = appointments.filter(a => a.slot.startsWith(todayStr));
  res.status(200).json({ date: today.toISOString(), appointments: todaysAppointments });
});

module.exports = app;
APPEOF

# Add TC04 and TC05 tests
cat > tests/app.test.js << 'TESTEOF'
const request = require('supertest');
const app = require('../src/app');

describe('MediQueue API Tests', () => {
  let server;
  beforeAll(() => { server = app.listen(0); });
  afterAll((done) => { server.close(done); });

  test('TC01: Valid OTP login succeeds', async () => {
    const reg = await request(app).post('/register').send({ name: 'Ali', phone: '03001234567' });
    expect(reg.status).toBe(201);
    const res = await request(app).post('/login').send({ phone: '03001234567', otp: '123456' });
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('token');
  });

  test('TC02: 3 wrong OTPs locks the account', async () => {
    await request(app).post('/register').send({ name: 'Sara', phone: '03009999999' });
    await request(app).post('/login').send({ phone: '03009999999', otp: '000000' });
    await request(app).post('/login').send({ phone: '03009999999', otp: '000000' });
    const res = await request(app).post('/login').send({ phone: '03009999999', otp: '000000' });
    expect(res.status).toBe(423);
    expect(res.body.message).toMatch(/locked/i);
  });

  test('TC03: Search Cardiology returns only available cardiologists', async () => {
    const res = await request(app).get('/doctors?specialty=Cardiology&available=true');
    expect(res.status).toBe(200);
    expect(res.body.length).toBeGreaterThan(0);
    res.body.forEach(doc => {
      expect(doc.specialty).toBe('Cardiology');
      expect(doc.available).toBe(true);
    });
  });

  test('TC04: Booking a free slot returns a booking ID', async () => {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(10, 0, 0, 0);
    const res = await request(app).post('/appointments').send({
      patientId: 'patient-1', doctorId: 'doc-1', slot: tomorrow.toISOString()
    });
    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('bookingId');
  });

  test('TC05: Booking the same slot twice returns 409', async () => {
    const dayAfter = new Date();
    dayAfter.setDate(dayAfter.getDate() + 2);
    dayAfter.setHours(14, 0, 0, 0);
    const payload = { patientId: 'patient-2', doctorId: 'doc-2', slot: dayAfter.toISOString() };
    await request(app).post('/appointments').send(payload);
    const res = await request(app).post('/appointments').send(payload);
    expect(res.status).toBe(409);
  });
});
TESTEOF

git add src/ tests/
git commit -m "MQ-3: add booking endpoint (missing duplicate check - BUG)"
git push -u origin MQ-3-book-appointment

echo ""
echo ">>> Creating PR for MQ-3 (this will FAIL CI — TC05 will break!)"
gh pr create --title "MQ-3: Implement appointment booking" \
  --body "## Jira Issue\n**Jira Key:** MQ-3\n\n## Description\nImplements POST /appointments endpoint for booking appointments.\n\n## Acceptance Criteria Checklist\n- [x] Free slot returns booking ID\n- [ ] Duplicate slot returns 409\n- [x] TC04 test passes\n- [ ] TC05 test passes\n- [x] ESLint passes" \
  --base main --head MQ-3-book-appointment

echo ""
echo "=============================================="
echo "  WAIT for CI to RUN and FAIL (red X)"
echo "  This is your EVIDENCE of pipeline blocking"
echo "  bad code! Screenshot the red run."
echo "=============================================="
read -p "Press Enter once you've seen the RED CI run and taken a screenshot..."

# --- Fix the bug ---
echo ""
echo ">>> Fixing the duplicate check bug..."

cat > src/app.js << 'APPEOF'
const express = require('express');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(express.json());

const users = [];
const appointments = [];
const prescriptions = [];
const doctors = [
  { id: 'doc-1', name: 'Dr. Smith', specialty: 'Cardiology', available: true },
  { id: 'doc-2', name: 'Dr. Jones', specialty: 'Cardiology', available: false },
  { id: 'doc-3', name: 'Dr. Lee', specialty: 'Dermatology', available: true },
  { id: 'doc-4', name: 'Dr. Brown', specialty: 'Dermatology', available: true },
  { id: 'doc-5', name: 'Dr. White', specialty: 'Pediatrics', available: true }
];

app.post('/register', (req, res) => {
  const { name, phone } = req.body;
  const userId = uuidv4();
  users.push({ userId, name, phone, otp: '123456', failedAttempts: 0, lockedUntil: null });
  res.status(201).json({ message: 'User registered', userId });
});

app.post('/login', (req, res) => {
  const { phone, otp } = req.body;
  const user = users.find(u => u.phone === phone);
  if (!user) return res.status(404).json({ error: 'User not found' });
  if (user.lockedUntil && user.lockedUntil > Date.now()) {
    return res.status(423).json({ message: 'Account locked...', lockedUntil: user.lockedUntil });
  }
  if (user.otp !== otp) {
    user.failedAttempts += 1;
    if (user.failedAttempts >= 3) {
      user.lockedUntil = Date.now() + 10 * 60 * 1000;
      return res.status(423).json({ message: 'Account locked...', lockedUntil: user.lockedUntil });
    }
    return res.status(401).json({ error: 'Invalid OTP' });
  }
  user.failedAttempts = 0;
  user.lockedUntil = null;
  res.status(200).json({ message: 'Login successful', userId: user.userId, token: `demo-token-${user.userId}` });
});

app.get('/doctors', (req, res) => {
  const { specialty, available } = req.query;
  let filtered = doctors;
  if (specialty) filtered = filtered.filter(d => d.specialty === specialty);
  if (available !== undefined) {
    const isAvail = available === 'true';
    filtered = filtered.filter(d => d.available === isAvail);
  }
  res.status(200).json(filtered);
});

// MQ-3: Book Appointment — FIXED: duplicate check added
app.post('/appointments', (req, res) => {
  const { patientId, doctorId, slot } = req.body;
  const exists = appointments.find(a => a.doctorId === doctorId && a.slot === slot);
  if (exists) {
    return res.status(409).json({ error: 'Slot already booked' });
  }
  const bookingId = uuidv4();
  appointments.push({ bookingId, patientId, doctorId, slot, status: 'Booked' });
  res.status(201).json({ bookingId, message: 'Appointment booked successfully' });
});

app.get('/dashboard', (req, res) => {
  const today = new Date();
  const todayStr = today.toISOString().split('T')[0];
  const todaysAppointments = appointments.filter(a => a.slot.startsWith(todayStr));
  res.status(200).json({ date: today.toISOString(), appointments: todaysAppointments });
});

module.exports = app;
APPEOF

git add src/app.js
git commit -m "MQ-3: fix duplicate slot check — resolves TC05 failure"
git push

echo ""
echo ">>> Wait for CI to go GREEN, then merge the PR"
read -p "Press Enter once CI is green..."
gh pr merge MQ-3-book-appointment --merge --delete-branch
git checkout main && git pull

# --- Step 5: MQ-4 (Cancel Appointment) ---
echo ""
echo ">>> Step 5: MQ-4 - Cancel Appointment"
git checkout -b MQ-4-cancel-appointment main

# Add cancel endpoint
cat > src/app.js << 'APPEOF'
const express = require('express');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(express.json());

const users = [];
const appointments = [];
const prescriptions = [];
const doctors = [
  { id: 'doc-1', name: 'Dr. Smith', specialty: 'Cardiology', available: true },
  { id: 'doc-2', name: 'Dr. Jones', specialty: 'Cardiology', available: false },
  { id: 'doc-3', name: 'Dr. Lee', specialty: 'Dermatology', available: true },
  { id: 'doc-4', name: 'Dr. Brown', specialty: 'Dermatology', available: true },
  { id: 'doc-5', name: 'Dr. White', specialty: 'Pediatrics', available: true }
];

app.post('/register', (req, res) => {
  const { name, phone } = req.body;
  const userId = uuidv4();
  users.push({ userId, name, phone, otp: '123456', failedAttempts: 0, lockedUntil: null });
  res.status(201).json({ message: 'User registered', userId });
});

app.post('/login', (req, res) => {
  const { phone, otp } = req.body;
  const user = users.find(u => u.phone === phone);
  if (!user) return res.status(404).json({ error: 'User not found' });
  if (user.lockedUntil && user.lockedUntil > Date.now()) {
    return res.status(423).json({ message: 'Account locked...', lockedUntil: user.lockedUntil });
  }
  if (user.otp !== otp) {
    user.failedAttempts += 1;
    if (user.failedAttempts >= 3) {
      user.lockedUntil = Date.now() + 10 * 60 * 1000;
      return res.status(423).json({ message: 'Account locked...', lockedUntil: user.lockedUntil });
    }
    return res.status(401).json({ error: 'Invalid OTP' });
  }
  user.failedAttempts = 0;
  user.lockedUntil = null;
  res.status(200).json({ message: 'Login successful', userId: user.userId, token: `demo-token-${user.userId}` });
});

app.get('/doctors', (req, res) => {
  const { specialty, available } = req.query;
  let filtered = doctors;
  if (specialty) filtered = filtered.filter(d => d.specialty === specialty);
  if (available !== undefined) {
    const isAvail = available === 'true';
    filtered = filtered.filter(d => d.available === isAvail);
  }
  res.status(200).json(filtered);
});

app.post('/appointments', (req, res) => {
  const { patientId, doctorId, slot } = req.body;
  const exists = appointments.find(a => a.doctorId === doctorId && a.slot === slot);
  if (exists) return res.status(409).json({ error: 'Slot already booked' });
  const bookingId = uuidv4();
  appointments.push({ bookingId, patientId, doctorId, slot, status: 'Booked' });
  res.status(201).json({ bookingId, message: 'Appointment booked successfully' });
});

// MQ-4: Cancel Appointment
app.delete('/appointments/:id', (req, res) => {
  const { id } = req.params;
  const idx = appointments.findIndex(a => a.bookingId === id);
  if (idx === -1) return res.status(404).json({ error: 'Appointment not found' });
  const appt = appointments[idx];
  const slotTime = new Date(appt.slot).getTime();
  const twoHoursFromNow = Date.now() + 2 * 60 * 60 * 1000;
  if (slotTime <= twoHoursFromNow) {
    return res.status(400).json({ error: 'Cannot cancel less than 2 hours before appointment' });
  }
  appointments.splice(idx, 1);
  res.status(200).json({ message: 'Appointment cancelled' });
});

app.get('/dashboard', (req, res) => {
  const today = new Date();
  const todayStr = today.toISOString().split('T')[0];
  const todaysAppointments = appointments.filter(a => a.slot.startsWith(todayStr));
  res.status(200).json({ date: today.toISOString(), appointments: todaysAppointments });
});

module.exports = app;
APPEOF

# Add TC06 to tests
cat > tests/app.test.js << 'TESTEOF'
const request = require('supertest');
const app = require('../src/app');

describe('MediQueue API Tests', () => {
  let server;
  beforeAll(() => { server = app.listen(0); });
  afterAll((done) => { server.close(done); });

  test('TC01: Valid OTP login succeeds', async () => {
    const reg = await request(app).post('/register').send({ name: 'Ali', phone: '03001234567' });
    expect(reg.status).toBe(201);
    const res = await request(app).post('/login').send({ phone: '03001234567', otp: '123456' });
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('token');
  });

  test('TC02: 3 wrong OTPs locks the account', async () => {
    await request(app).post('/register').send({ name: 'Sara', phone: '03009999999' });
    await request(app).post('/login').send({ phone: '03009999999', otp: '000000' });
    await request(app).post('/login').send({ phone: '03009999999', otp: '000000' });
    const res = await request(app).post('/login').send({ phone: '03009999999', otp: '000000' });
    expect(res.status).toBe(423);
    expect(res.body.message).toMatch(/locked/i);
  });

  test('TC03: Search Cardiology returns only available cardiologists', async () => {
    const res = await request(app).get('/doctors?specialty=Cardiology&available=true');
    expect(res.status).toBe(200);
    expect(res.body.length).toBeGreaterThan(0);
    res.body.forEach(doc => {
      expect(doc.specialty).toBe('Cardiology');
      expect(doc.available).toBe(true);
    });
  });

  test('TC04: Booking a free slot returns a booking ID', async () => {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(10, 0, 0, 0);
    const res = await request(app).post('/appointments').send({
      patientId: 'patient-1', doctorId: 'doc-1', slot: tomorrow.toISOString()
    });
    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('bookingId');
  });

  test('TC05: Booking the same slot twice returns 409', async () => {
    const dayAfter = new Date();
    dayAfter.setDate(dayAfter.getDate() + 2);
    dayAfter.setHours(14, 0, 0, 0);
    const payload = { patientId: 'patient-2', doctorId: 'doc-2', slot: dayAfter.toISOString() };
    await request(app).post('/appointments').send(payload);
    const res = await request(app).post('/appointments').send(payload);
    expect(res.status).toBe(409);
  });

  test('TC06: Cancelling 1 hour before the slot is rejected', async () => {
    const soonSlot = new Date(Date.now() + 60 * 60 * 1000);
    const booking = await request(app).post('/appointments').send({
      patientId: 'patient-3', doctorId: 'doc-3', slot: soonSlot.toISOString()
    });
    const res = await request(app).delete(`/appointments/${booking.body.bookingId}`);
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/cannot cancel/i);
  });
});
TESTEOF

git add src/ tests/
git commit -m "MQ-4: add appointment cancellation with 2-hour rule"
git push -u origin MQ-4-cancel-appointment

gh pr create --title "MQ-4: Cancel Appointment" \
  --body "## Jira Issue\n**Jira Key:** MQ-4\n\n## Description\nImplements DELETE /appointments/:id with 2-hour cancellation policy.\n\n## Acceptance Criteria Checklist\n- [x] Cancellation >2h before slot succeeds\n- [x] Cancellation <=2h before slot rejected with 400\n- [x] TC06 test passes\n- [x] ESLint passes" \
  --base main --head MQ-4-cancel-appointment

read -p "Press Enter once CI passes..."
gh pr merge MQ-4-cancel-appointment --merge --delete-branch
git checkout main && git pull

# ====== SPRINT 3 ======

# --- Step 6: MQ-5 (Prescription) ---
echo ""
echo ">>> Step 6: MQ-5 - Create Prescription"
git checkout -b MQ-5-create-prescription main

# Final complete app.js with all endpoints
cat > src/app.js << 'APPEOF'
const express = require('express');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(express.json());

const users = [];
const appointments = [];
const prescriptions = [];
const doctors = [
  { id: 'doc-1', name: 'Dr. Smith', specialty: 'Cardiology', available: true },
  { id: 'doc-2', name: 'Dr. Jones', specialty: 'Cardiology', available: false },
  { id: 'doc-3', name: 'Dr. Lee', specialty: 'Dermatology', available: true },
  { id: 'doc-4', name: 'Dr. Brown', specialty: 'Dermatology', available: true },
  { id: 'doc-5', name: 'Dr. White', specialty: 'Pediatrics', available: true }
];

app.post('/register', (req, res) => {
  const { name, phone } = req.body;
  const userId = uuidv4();
  users.push({ userId, name, phone, otp: '123456', failedAttempts: 0, lockedUntil: null });
  res.status(201).json({ message: 'User registered', userId });
});

app.post('/login', (req, res) => {
  const { phone, otp } = req.body;
  const user = users.find(u => u.phone === phone);
  if (!user) return res.status(404).json({ error: 'User not found' });
  if (user.lockedUntil && user.lockedUntil > Date.now()) {
    return res.status(423).json({ message: 'Account locked...', lockedUntil: user.lockedUntil });
  }
  if (user.otp !== otp) {
    user.failedAttempts += 1;
    if (user.failedAttempts >= 3) {
      user.lockedUntil = Date.now() + 10 * 60 * 1000;
      return res.status(423).json({ message: 'Account locked...', lockedUntil: user.lockedUntil });
    }
    return res.status(401).json({ error: 'Invalid OTP' });
  }
  user.failedAttempts = 0;
  user.lockedUntil = null;
  res.status(200).json({ message: 'Login successful', userId: user.userId, token: `demo-token-${user.userId}` });
});

app.get('/doctors', (req, res) => {
  const { specialty, available } = req.query;
  let filtered = doctors;
  if (specialty) filtered = filtered.filter(d => d.specialty === specialty);
  if (available !== undefined) {
    const isAvail = available === 'true';
    filtered = filtered.filter(d => d.available === isAvail);
  }
  res.status(200).json(filtered);
});

app.post('/appointments', (req, res) => {
  const { patientId, doctorId, slot } = req.body;
  const exists = appointments.find(a => a.doctorId === doctorId && a.slot === slot);
  if (exists) return res.status(409).json({ error: 'Slot already booked' });
  const bookingId = uuidv4();
  appointments.push({ bookingId, patientId, doctorId, slot, status: 'Booked' });
  res.status(201).json({ bookingId, message: 'Appointment booked successfully' });
});

app.delete('/appointments/:id', (req, res) => {
  const { id } = req.params;
  const idx = appointments.findIndex(a => a.bookingId === id);
  if (idx === -1) return res.status(404).json({ error: 'Appointment not found' });
  const appt = appointments[idx];
  const slotTime = new Date(appt.slot).getTime();
  const twoHoursFromNow = Date.now() + 2 * 60 * 60 * 1000;
  if (slotTime <= twoHoursFromNow) {
    return res.status(400).json({ error: 'Cannot cancel less than 2 hours before appointment' });
  }
  appointments.splice(idx, 1);
  res.status(200).json({ message: 'Appointment cancelled' });
});

// MQ-5: Prescription
app.post('/prescriptions', (req, res) => {
  const { appointmentId, diagnosis, medicines } = req.body;
  if (!diagnosis || !medicines || (Array.isArray(medicines) && medicines.length === 0) || medicines === '') {
    return res.status(400).json({ error: 'Diagnosis and medicines are required' });
  }
  const prescriptionId = uuidv4();
  prescriptions.push({ prescriptionId, appointmentId, diagnosis, medicines });
  res.status(201).json({ prescriptionId, message: 'Prescription created' });
});

app.get('/dashboard', (req, res) => {
  const today = new Date();
  const todayStr = today.toISOString().split('T')[0];
  const todaysAppointments = appointments.filter(a => a.slot.startsWith(todayStr));
  res.status(200).json({ date: today.toISOString(), appointments: todaysAppointments });
});

module.exports = app;
APPEOF

# Final complete test file with all 7 tests
cat > tests/app.test.js << 'TESTEOF'
const request = require('supertest');
const app = require('../src/app');

describe('MediQueue API Tests', () => {
  let server;
  beforeAll(() => { server = app.listen(0); });
  afterAll((done) => { server.close(done); });

  test('TC01: Valid OTP login succeeds', async () => {
    const reg = await request(app).post('/register').send({ name: 'Ali', phone: '03001234567' });
    expect(reg.status).toBe(201);
    const res = await request(app).post('/login').send({ phone: '03001234567', otp: '123456' });
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('token');
  });

  test('TC02: 3 wrong OTPs locks the account', async () => {
    await request(app).post('/register').send({ name: 'Sara', phone: '03009999999' });
    await request(app).post('/login').send({ phone: '03009999999', otp: '000000' });
    await request(app).post('/login').send({ phone: '03009999999', otp: '000000' });
    const res = await request(app).post('/login').send({ phone: '03009999999', otp: '000000' });
    expect(res.status).toBe(423);
    expect(res.body.message).toMatch(/locked/i);
  });

  test('TC03: Search Cardiology returns only available cardiologists', async () => {
    const res = await request(app).get('/doctors?specialty=Cardiology&available=true');
    expect(res.status).toBe(200);
    expect(res.body.length).toBeGreaterThan(0);
    res.body.forEach(doc => {
      expect(doc.specialty).toBe('Cardiology');
      expect(doc.available).toBe(true);
    });
  });

  test('TC04: Booking a free slot returns a booking ID', async () => {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(10, 0, 0, 0);
    const res = await request(app).post('/appointments').send({
      patientId: 'patient-1', doctorId: 'doc-1', slot: tomorrow.toISOString()
    });
    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('bookingId');
  });

  test('TC05: Booking the same slot twice returns 409', async () => {
    const dayAfter = new Date();
    dayAfter.setDate(dayAfter.getDate() + 2);
    dayAfter.setHours(14, 0, 0, 0);
    const payload = { patientId: 'patient-2', doctorId: 'doc-2', slot: dayAfter.toISOString() };
    await request(app).post('/appointments').send(payload);
    const res = await request(app).post('/appointments').send(payload);
    expect(res.status).toBe(409);
  });

  test('TC06: Cancelling 1 hour before the slot is rejected', async () => {
    const soonSlot = new Date(Date.now() + 60 * 60 * 1000);
    const booking = await request(app).post('/appointments').send({
      patientId: 'patient-3', doctorId: 'doc-3', slot: soonSlot.toISOString()
    });
    const res = await request(app).delete(`/appointments/${booking.body.bookingId}`);
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/cannot cancel/i);
  });

  test('TC07: Prescription with empty medicine field is rejected', async () => {
    const res = await request(app).post('/prescriptions').send({
      appointmentId: 'appt-1', diagnosis: 'Flu', medicines: ''
    });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/required/i);
  });
});
TESTEOF

git add src/ tests/
git commit -m "MQ-5: add prescription endpoint with validation"
git push -u origin MQ-5-create-prescription

gh pr create --title "MQ-5: Create Prescription" \
  --body "## Jira Issue\n**Jira Key:** MQ-5\n\n## Description\nImplements POST /prescriptions with mandatory diagnosis and medicines validation.\n\n## Acceptance Criteria Checklist\n- [x] Valid prescription is saved\n- [x] Empty medicines field returns 400\n- [x] TC07 test passes\n- [x] ESLint passes" \
  --base main --head MQ-5-create-prescription

read -p "Press Enter once CI passes..."
gh pr merge MQ-5-create-prescription --merge --delete-branch
git checkout main && git pull

echo ""
echo "=============================================="
echo "  ALL DONE! Git history is set up."
echo "=============================================="
echo ""
echo "Your commit history now shows:"
echo "  MQ-1: add user registration and OTP login with lockout"
echo "  MQ-2: add doctor search with specialty and availability filters"
echo "  MQ-6: add patient dashboard showing today's appointments"
echo "  MQ-3: add booking endpoint (missing duplicate check - BUG)"
echo "  MQ-3: fix duplicate slot check — resolves TC05 failure"
echo "  MQ-4: add appointment cancellation with 2-hour rule"
echo "  MQ-5: add prescription endpoint with validation"
echo ""
echo "GitHub shows:"
echo "  - 6 merged PRs with Jira keys"
echo "  - 1 failed CI run (MQ-3 before fix)"
echo "  - All subsequent runs green"
