import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ReportReason } from '@prisma/client';
import { IsEnum, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

export class ReportDto {
  @ApiProperty() @IsUUID() targetId: string;
  @ApiProperty({ enum: ReportReason }) @IsEnum(ReportReason) reason: ReportReason;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(500) details?: string;
  @ApiPropertyOptional({ description: 'e.g. soul:<sessionId> or chat:<conversationId>' })
  @IsOptional() @IsString() @MaxLength(80) context?: string;
}
