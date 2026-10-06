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
