import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsISO8601, IsOptional, Max, Min } from 'class-validator';

export class HistoryQuery {
  @ApiPropertyOptional({ description: 'ISO timestamp; return messages strictly older' })
  @IsOptional() @IsISO8601() before?: string;

  @ApiPropertyOptional({ default: 30 })
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) limit?: number;
}
