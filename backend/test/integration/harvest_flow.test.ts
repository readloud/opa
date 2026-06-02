import request from 'supertest';
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { AppModule } from '../../src/app.module';

describe('Harvest Flow (e2e)', () => {
  let app: INestApplication;
  let authToken: string;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();
    await app.init();
    
    // Get auth token
    const loginResponse = await request(app.getHttpServer())
      .post('/v1/auth/verify-otp')
      .send({
        identifier: '08123456789',
        otpCode: '123456',
      });
    
    authToken = loginResponse.body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  describe('Harvest CRUD', () => {
    it('should create new harvest', async () => {
      const response = await request(app.getHttpServer())
        .post('/v1/harvests')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          blockId: 'block-1',
          tonase: 15.5,
          harvestDate: new Date().toISOString(),
        });
      
      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('id');
      expect(response.body.tonase).toBe(15.5);
    });
    
    it('should get harvest summary', async () => {
      const response = await request(app.getHttpServer())
        .get('/v1/harvests/summary')
        .set('Authorization', `Bearer ${authToken}`)
        .query({
          startDate: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
          endDate: new Date().toISOString(),
        });
      
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('totalTonase');
      expect(response.body).toHaveProperty('dailyData');
    });
  });
});