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
    userId,
    name,
    phone,
    otp: '123456',
    failedAttempts: 0,
    lockedUntil: null
  });
  res.status(201).json({ message: 'User registered', userId });
});

app.post('/login', (req, res) => {
  const { phone, otp } = req.body;
  const user = users.find(u => u.phone === phone);
  
  if (!user) {
    return res.status(404).json({ error: 'User not found' });
  }

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
  res.status(200).json({
    message: 'Login successful',
    userId: user.userId,
    token: `demo-token-${user.userId}`
  });
});

// MQ-2: Doctor Search
app.get('/doctors', (req, res) => {
  const { specialty, available } = req.query;
  let filtered = doctors;
  
  if (specialty) {
    filtered = filtered.filter(d => d.specialty === specialty);
  }
  
  if (available !== undefined) {
    const isAvail = available === 'true';
    filtered = filtered.filter(d => d.available === isAvail);
  }
  
  res.status(200).json(filtered);
});

// MQ-3: Book Appointment
app.post('/appointments', (req, res) => {
  const { patientId, doctorId, slot } = req.body;
  const exists = appointments.find(a => a.doctorId === doctorId && a.slot === slot);
  
  if (exists) {
    return res.status(409).json({ error: 'Slot already booked' });
  }
  
  const bookingId = uuidv4();
  appointments.push({
    bookingId,
    patientId,
    doctorId,
    slot,
    status: 'Booked'
  });
  
  res.status(201).json({ bookingId, message: 'Appointment booked successfully' });
});

// MQ-4: Cancel Appointment
app.delete('/appointments/:id', (req, res) => {
  const { id } = req.params;
  const idx = appointments.findIndex(a => a.bookingId === id);
  
  if (idx === -1) {
    return res.status(404).json({ error: 'Appointment not found' });
  }
  
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

// MQ-6: Dashboard
app.get('/dashboard', (req, res) => {
  const today = new Date();
  const todayStr = today.toISOString().split('T')[0];
  
  const todaysAppointments = appointments.filter(a => {
    return a.slot.startsWith(todayStr);
  });
  
  res.status(200).json({
    date: today.toISOString(),
    appointments: todaysAppointments
  });
});

module.exports = app;
