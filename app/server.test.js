const request = require('supertest');
const app = require('./server');

describe('Health & API endpoints', () => {
  it('GET /health returns 200 and healthy status', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('healthy');
    expect(res.body).toHaveProperty('version');
    expect(res.body).toHaveProperty('timestamp');
  });

  it('GET /api/info returns app info', async () => {
    const res = await request(app).get('/api/info');
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('version');
    expect(res.body).toHaveProperty('memory');
    expect(res.body.app).toBe('devops_mini_project');
  });

  it('GET / serves the frontend', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
  });
});
