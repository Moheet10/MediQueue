const request = require('supertest');
const app = require('../src/app');

describe('MediQueue API Tests', () => {
  let server;
  
  beforeAll(() => {
    server = app.listen(0); // random port
  });
  
  afterAll((done) => {
    server.close(done);
  });

  // TC01: Valid OTP login succeeds
  test('TC01: Valid OTP login succeeds', async () => {
    // First register
    const reg = await request(app).post('/register').send({ name: 'Ali', phone: '03001234567' });
    expect(reg.status).toBe(201);
    // Then login with correct OTP
    const res = await request(app).post('/login').send({ phone: '03001234567', otp: '123456' });
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('token');
  });

  // TC02: 3 wrong OTPs locks account
  test('TC02: 3 wrong OTPs locks the account', async () => {
    await request(app).post('/register').send({ name: 'Sara', phone: '03009999999' });
    await request(app).post('/login').send({ phone: '03009999999', otp: '000000' });
    await request(app).post('/login').send({ phone: '03009999999', otp: '000000' });
    const res = await request(app).post('/login').send({ phone: '03009999999', otp: '000000' });
    expect(res.status).toBe(423);
    expect(res.body.message).toMatch(/locked/i);
  });

  // TC03: Search Cardiology returns only available cardiologists
  test('TC03: Search Cardiology returns only available cardiologists', async () => {
    const res = await request(app).get('/doctors?specialty=Cardiology&available=true');
    expect(res.status).toBe(200);
    expect(res.body.length).toBeGreaterThan(0);
    res.body.forEach(doc => {
      expect(doc.specialty).toBe('Cardiology');
      expect(doc.available).toBe(true);
    });
  });

  // TC04: Booking a free slot returns a booking ID
  test('TC04: Booking a free slot returns a booking ID', async () => {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(10, 0, 0, 0);
    const res = await request(app).post('/appointments').send({
      patientId: 'patient-1',
      doctorId: 'doc-1',
      slot: tomorrow.toISOString()
    });
    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('bookingId');
  });

  // TC05: Booking the same slot twice returns 409
  test('TC05: Booking the same slot twice returns 409', async () => {
    const dayAfter = new Date();
    dayAfter.setDate(dayAfter.getDate() + 2);
    dayAfter.setHours(14, 0, 0, 0);
    const payload = { patientId: 'patient-2', doctorId: 'doc-2', slot: dayAfter.toISOString() };
    await request(app).post('/appointments').send(payload);
    const res = await request(app).post('/appointments').send(payload);
    expect(res.status).toBe(409);
  });

  // TC06: Cancelling 1 hour before slot is rejected
  test('TC06: Cancelling 1 hour before the slot is rejected', async () => {
    const soonSlot = new Date(Date.now() + 60 * 60 * 1000); // 1 hour from now
    const booking = await request(app).post('/appointments').send({
      patientId: 'patient-3',
      doctorId: 'doc-3',
      slot: soonSlot.toISOString()
    });
    const res = await request(app).delete(`/appointments/${booking.body.bookingId}`);
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/cannot cancel/i);
  });

  // TC07: Prescription with empty medicine field is rejected
  test('TC07: Prescription with empty medicine field is rejected', async () => {
    const res = await request(app).post('/prescriptions').send({
      appointmentId: 'appt-1',
      diagnosis: 'Flu',
      medicines: ''
    });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/required/i);
  });
});
