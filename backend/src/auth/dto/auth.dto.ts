import { ApiProperty } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsEmail, IsOptional, IsString, Length, Matches, MaxLength, MinLength } from 'class-validator';

const normEmail = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim().toLowerCase() : value);

export class EmailDto {
  @ApiProperty({ example: 'hai@example.com' })
  @Transform(normEmail)
  @IsEmail()
  @MaxLength(254)
  email: string;
}

export class RegisterDto extends EmailDto {
  @ApiProperty({ example: 'S3cret!pass', minLength: 8 })
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  @Matches(/^(?=.*[A-Za-z])(?=.*\d).+$/, { message: 'password must contain letters and digits' })
  password: string;

  @ApiProperty({ required: false, example: 'vi' })
  @IsOptional()
  @IsString()
  @MaxLength(5)
  locale?: string;
}

export class LoginDto extends EmailDto {
  @ApiProperty()
  @IsString()
  @MinLength(1)
  @MaxLength(72)
  password: string;
}

export class VerifyCodeDto extends EmailDto {
  @ApiProperty({ example: '123456' })
  @IsString()
  @Length(6, 6)
  @Matches(/^\d{6}$/)
  code: string;
}

export class ResetPasswordDto extends VerifyCodeDto {
  @ApiProperty({ minLength: 8 })
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  @Matches(/^(?=.*[A-Za-z])(?=.*\d).+$/, { message: 'password must contain letters and digits' })
  newPassword: string;
}

export class RefreshDto {
  @ApiProperty()
  @IsString()
  @MinLength(10)
  refreshToken: string;
}
