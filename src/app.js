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
    return res.status(423).json({
      message: 'Account locked. Try again later.',
      lockedUntil: user.lockedUntil
    });
  }

  if (user.otp !== otp) {
    user.failedAttempts += 1;
    if (user.failedAttempts >= 3) {
      user.lockedUntil = Date.now() + 10 * 60 * 1000;
      return res.status(423).json({
        message: 'Account locked. Try again later.',
        lockedUntil: user.lockedUntil
      });
    }
    return res.status(401).json({ error: 'Invalid OTP' });
  }

  user.failedAttempts = 0;
  user.lockedUntil = null;
  res.status(200).json({
    message: 'Login successful',
    userId: user.userId,
    token: `demo-token-${user.userId}`
  });
});

module.exports = app;
