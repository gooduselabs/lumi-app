import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Gender } from '@prisma/client';
import { Transform } from 'class-transformer';
import {
  ArrayMaxSize, IsArray, IsDateString, IsEnum, IsIn, IsOptional, IsString, Length, MaxLength,
} from 'class-validator';
import { AVATAR_IDS, INTERESTS, MAX_INTERESTS } from '../meta';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

export class OnboardingDto {
  @ApiProperty({ example: 'Hải' })
  @Transform(trim)
  @IsString()
  @Length(2, 24)
  nickname: string;

  @ApiProperty({ enum: Gender })
  @IsEnum(Gender)
  gender: Gender;

  @ApiProperty({ example: '2000-05-20' })
  @IsDateString({ strict: true })
  birthday: string;

  @ApiProperty({ example: 'a07' })
  @IsIn(AVATAR_IDS)
  avatarId: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(160)
  bio?: string;

  @ApiProperty({ example: ['music', 'travel'] })
  @IsArray()
  @ArrayMaxSize(MAX_INTERESTS)
  @IsIn(INTERESTS as unknown as string[], { each: true })
  interests: string[];
}

export class UpdateProfileDto {
  @ApiPropertyOptional() @IsOptional() @Transform(trim) @IsString() @Length(2, 24) nickname?: string;
  @ApiPropertyOptional() @IsOptional() @IsIn(AVATAR_IDS) avatarId?: string;
  @ApiPropertyOptional() @IsOptional() @Transform(trim) @IsString() @MaxLength(160) bio?: string;
  @ApiPropertyOptional() @IsOptional() @IsArray() @ArrayMaxSize(MAX_INTERESTS)
  @IsIn(INTERESTS as unknown as string[], { each: true }) interests?: string[];
  @ApiPropertyOptional({ enum: ['vi', 'en'] }) @IsOptional() @IsIn(['vi', 'en']) locale?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(4096) fcmToken?: string;
}
