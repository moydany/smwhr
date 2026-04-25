import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../auth/decorators/public.decorator';
import { WaitlistSignupDto } from './dto/waitlist-signup.dto';
import { WaitlistService } from './waitlist.service';

@ApiTags('waitlist')
@Controller('waitlist')
export class WaitlistController {
  constructor(private readonly waitlist: WaitlistService) {}

  @Public()
  @Post()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Public landing-page waitlist signup' })
  signup(@Body() dto: WaitlistSignupDto) {
    return this.waitlist.signup(dto);
  }
}
