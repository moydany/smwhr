import { ApiProperty } from '@nestjs/swagger';
import { IsEmail } from 'class-validator';

export class EmailRequestDto {
  @ApiProperty({ example: 'moi@orbit-m.dev' })
  @IsEmail()
  email!: string;
}
