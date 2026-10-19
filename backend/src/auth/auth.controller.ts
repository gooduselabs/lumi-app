import { Body, Controller, Headers, HttpCode, Post } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../common/public.decorator';
import { AuthService } from './auth.service';
import { EmailDto, LoginDto, RefreshDto, RegisterDto, ResetPasswordDto, VerifyCodeDto } from './dto/auth.dto';

@ApiTags('auth')
@Public()
@Throttle({ default: { limit: 10, ttl: 60_000 } })
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  @ApiOperation({ summary: 'Create account and email a 6-digit verification code' })
  register(@Body() dto: RegisterDto) {
    return this.auth.register(dto.email, dto.password, dto.locale);
  }

  @Post('verify-email')
  @HttpCode(200)
  @ApiOperation({ summary: 'Verify email with code; returns tokens' })
  verify(@Body() dto: VerifyCodeDto, @Headers('user-agent') ua?: string) {
    return this.auth.verifyEmail(dto.email, dto.code, ua);
  }

  @Post('resend-code')
  @HttpCode(200)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  resend(@Body() dto: EmailDto) {
    return this.auth.resendVerification(dto.email);
  }

  @Post('login')
  @HttpCode(200)
  login(@Body() dto: LoginDto, @Headers('user-agent') ua?: string) {
    return this.auth.login(dto.email, dto.password, ua);
  }

  @Post('refresh')
  @HttpCode(200)
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  refresh(@Body() dto: RefreshDto, @Headers('user-agent') ua?: string) {
    return this.auth.refresh(dto.refreshToken, ua);
  }

  @Post('logout')
  @HttpCode(200)
  logout(@Body() dto: RefreshDto) {
    return this.auth.logout(dto.refreshToken);
  }

  @Post('forgot-password')
  @HttpCode(200)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  forgot(@Body() dto: EmailDto) {
    return this.auth.forgotPassword(dto.email);
  }

  @Post('reset-password')
  @HttpCode(200)
  reset(@Body() dto: ResetPasswordDto, @Headers('user-agent') ua?: string) {
    return this.auth.resetPassword(dto.email, dto.code, dto.newPassword, ua);
  }
}
