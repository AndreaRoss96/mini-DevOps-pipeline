const request = require('supertest');
const app = require('../app');

describe('GET /', () => {
  it('should return 200 OK and "Hello, World!"', async () => {
    const res = await request(app)
      .get('/')
      .expect(200);

    expect(res.text).toBe('Hello, World!');
  });
});