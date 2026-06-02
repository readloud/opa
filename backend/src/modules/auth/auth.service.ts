import { Injectable, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcrypt';
import * as nodemailer from 'nodemailer';
import * as Twilio from 'twilio';

@Injectable()
export class AuthService {
  private twilioClient: Twilio.Twilio;
  private emailTransporter: nodemailer.Transporter;
  private otpStore: Map<string, { code: string; expiresAt: Date }> = new Map();

  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private configService: ConfigService,
  ) {
    // Initialize Twilio for SMS
    this.twilioClient = Twilio(
      this.configService.get('TWILIO_ACCOUNT_SID'),
      this.configService.get('TWILIO_AUTH_TOKEN'),
    );

    // Initialize Nodemailer for email
    this.emailTransporter = nodemailer.createTransport({
      host: this.configService.get('SMTP_HOST'),
      port: parseInt(this.configService.get('SMTP_PORT')),
      secure: false,
      auth: {
        user: this.configService.get('SMTP_USER'),
        pass: this.configService.get('SMTP_PASS'),
      },
    });
  }

  private generateOtp(): string {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  private isEmail(identifier: string): boolean {
    return identifier.includes('@');
  }

  private async sendOtpViaSms(phoneNumber: string, otpCode: string): Promise<void> {
    // Format phone number to E.164
    let formattedPhone = phoneNumber;
    if (!phoneNumber.startsWith('+')) {
      formattedPhone = phoneNumber.startsWith('0')
        ? `+62${phoneNumber.substring(1)}`
        : `+62${phoneNumber}`;
    }

    await this.twilioClient.messages.create({
      body: `Kode OTP Anda untuk Oil Palm Assistant: ${otpCode}. Berlaku selama 5 menit.`,
      to: formattedPhone,
      from: this.configService.get('TWILIO_PHONE_NUMBER'),
    });
  }

  private async sendOtpViaEmail(email: string, otpCode: string): Promise<void> {
    await this.emailTransporter.sendMail({
      from: `"Oil Palm Assistant" <${this.configService.get('SMTP_USER')}>`,
      to: email,
      subject: 'Kode Verifikasi OTP',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #2E7D32;">Oil Palm Assistant</h2>
          <p>Berikut adalah kode verifikasi Anda:</p>
          <div style="font-size: 32px; font-weight: bold; letter-spacing: 5px; padding: 20px; background: #f5f5f5; text-align: center;">
            ${otpCode}
          </div>
          <p>Kode ini berlaku selama <strong>5 menit</strong>.</p>
          <p>Jika Anda tidak meminta kode ini, abaikan email ini.</p>
          <hr />
          <p style="color: #666; font-size: 12px;">© ${new Date().getFullYear()} Oil Palm Assistant</p>
        </div>
      `,
    });
  }

  async requestOtp(identifier: string): Promise<{ message: string }> {
    const otpCode = this.generateOtp();
    const expiresAt = new Date();
    expiresAt.setMinutes(expiresAt.getMinutes() + 5);

    // Store OTP in memory (production: use Redis)
    this.otpStore.set(identifier, { code: otpCode, expiresAt });

    // Check if user exists, if not create placeholder
    let user = await this.prisma.user.findFirst({
      where: this.isEmail(identifier)
        ? { email: identifier }
        : { phone: identifier },
    });

    if (!user) {
      // Create new user if doesn't exist
      user = await this.prisma.user.create({
        data: this.isEmail(identifier)
          ? { email: identifier, name: identifier.split('@')[0], phone: '' }
          : { phone: identifier, name: `User_${identifier.slice(-4)}`, email: null },
      });
    }

    // Send OTP
    try {
      if (this.isEmail(identifier)) {
        await this.sendOtpViaEmail(identifier, otpCode);
      } else {
        await this.sendOtpViaSms(identifier, otpCode);
      }
    } catch (error) {
      throw new BadRequestException('Failed to send OTP. Please try again.');
    }

    return { message: 'OTP sent successfully' };
  }

  async verifyOtp(identifier: string, otpCode: string): Promise<{ accessToken: string; user: any }> {
    const storedOtp = this.otpStore.get(identifier);

    if (!storedOtp) {
      throw new UnauthorizedException('OTP not found or expired');
    }

    if (storedOtp.expiresAt < new Date()) {
      this.otpStore.delete(identifier);
      throw new UnauthorizedException('OTP has expired');
    }

    if (storedOtp.code !== otpCode) {
      throw new UnauthorizedException('Invalid OTP code');
    }

    // Get user
    const user = await this.prisma.user.findFirst({
      where: this.isEmail(identifier)
        ? { email: identifier }
        : { phone: identifier },
      include: {
        estate: true,
        block: true,
      },
    });

    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    // Clear OTP after successful verification
    this.otpStore.delete(identifier);

    // Generate JWT
    const payload = {
      sub: user.id,
      email: user.email,
      phone: user.phone,
      role: user.role,
    };
    const accessToken = this.jwtService.sign(payload);

    // Remove sensitive data
    const { passwordHash, ...userWithoutPassword } = user;

    return {
      accessToken,
      user: userWithoutPassword,
    };
  }

  async validateUser(userId: string): Promise<any> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        estate: true,
        block: true,
      },
    });

    if (!user) return null;

    const { passwordHash, ...result } = user;
    return result;
  }
}