import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Gender } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import {
  IsBoolean, IsInt, IsLatitude, IsLongitude, IsNumber, Max, Min,
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
  @ApiPropertyOptional({ minimum: 18, maximum: 99 }) @IsOptional() @IsInt() @Min(18) @Max(99) agePrefMin?: number;
  @ApiPropertyOptional({ minimum: 18, maximum: 99 }) @IsOptional() @IsInt() @Min(18) @Max(99) agePrefMax?: number;
  @ApiPropertyOptional({ description: 'Hide me from Nearby and distance-based matching' })
  @IsOptional() @IsBoolean() locationHidden?: boolean;
}

export class LocationDto {
  @ApiProperty({ example: 10.7769 }) @IsNumber() @IsLatitude() lat: number;
  @ApiProperty({ example: 106.7009 }) @IsNumber() @IsLongitude() lng: number;
}

export class NearbyQuery {
  @ApiPropertyOptional({ default: 25, minimum: 1, maximum: 200 })
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(200) radiusKm?: number;
  @ApiPropertyOptional({ minimum: 18, maximum: 99 }) @IsOptional() @Type(() => Number) @IsInt() @Min(18) @Max(99) minAge?: number;
  @ApiPropertyOptional({ minimum: 18, maximum: 99 }) @IsOptional() @Type(() => Number) @IsInt() @Min(18) @Max(99) maxAge?: number;
  @ApiPropertyOptional({ enum: ['ANY', 'MALE', 'FEMALE'] }) @IsOptional() @IsIn(['ANY', 'MALE', 'FEMALE']) gender?: 'ANY' | 'MALE' | 'FEMALE';
  @ApiPropertyOptional({ default: 50 }) @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) limit?: number;
}
