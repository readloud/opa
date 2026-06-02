import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from '../../src/modules/auth/auth.service';
import { PrismaService } from '../../src/modules/prisma/prisma.service';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';

describe('AuthService', () => {
  let service: AuthService;
  let prisma: PrismaService;
  let jwtService: JwtService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        {
          provide: PrismaService,
          useValue: {
            user: {
              findFirst: jest.fn(),
              create: jest.fn(),
              findUnique: jest.fn(),
            },
          },
        },
        {
          provide: JwtService,
          useValue: {
            sign: jest.fn().mockReturnValue('mock-jwt-token'),
          },
        },
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn().mockReturnValue('mock-value'),
          },
        },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
    prisma = module.get<PrismaService>(PrismaService);
    jwtService = module.get<JwtService>(JwtService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('requestOtp', () => {
    it('should send OTP to existing user', async () => {
      const mockUser = { id: '1', phone: '08123456789', name: 'Test User' };
      jest.spyOn(prisma.user, 'findFirst').mockResolvedValue(mockUser as any);
      
      // Mock send OTP method
      jest.spyOn(service as any, 'sendOtpViaSms').mockResolvedValue(undefined);
      
      const result = await service.requestOtp('08123456789');
      expect(result.message).toBe('OTP sent successfully');
    });

    it('should create new user if not exists', async () => {
      jest.spyOn(prisma.user, 'findFirst').mockResolvedValue(null);
      jest.spyOn(prisma.user, 'create').mockResolvedValue({
        id: '2',
        phone: '08987654321',
        name: 'User_4321',
      } as any);
      jest.spyOn(service as any, 'sendOtpViaSms').mockResolvedValue(undefined);
      
      const result = await service.requestOtp('08987654321');
      expect(result.message).toBe('OTP sent successfully');
    });
  });
});