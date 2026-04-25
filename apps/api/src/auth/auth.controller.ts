import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { Public } from './decorators/public.decorator';
import { AppleAuthDto } from './dto/apple-auth.dto';
import { EmailRequestDto } from './dto/email-request.dto';
import { EmailVerifyDto } from './dto/email-verify.dto';
import { GoogleAuthDto } from './dto/google-auth.dto';
import { RefreshDto } from './dto/refresh.dto';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @Post('email/request')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Send a magic-link OTP to the email' })
  emailRequest(@Body() dto: EmailRequestDto) {
    return this.auth.requestEmailMagicLink(dto.email);
  }

  @Public()
  @Post('email/verify')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verify the OTP and exchange for an auth session' })
  emailVerify(@Body() dto: EmailVerifyDto) {
    return this.auth.verifyEmailMagicLink(dto.email, dto.token);
  }

  @Public()
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Refresh the access token' })
  refresh(@Body() dto: RefreshDto) {
    return this.auth.refreshSession(dto.refreshToken);
  }

  @Public()
  @Post('logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Client-side logout (server is stateless for JWT)' })
  logout() {
    return;
  }

  @Public()
  @Post('apple')
  @HttpCode(HttpStatus.NOT_IMPLEMENTED)
  @ApiOperation({ summary: 'Sign in with Apple — not yet wired' })
  apple(@Body() _dto: AppleAuthDto) {
    return this.auth.notImplemented('apple');
  }

  @Public()
  @Post('google')
  @HttpCode(HttpStatus.NOT_IMPLEMENTED)
  @ApiOperation({ summary: 'Sign in with Google — not yet wired' })
  google(@Body() _dto: GoogleAuthDto) {
    return this.auth.notImplemented('google');
  }
}
