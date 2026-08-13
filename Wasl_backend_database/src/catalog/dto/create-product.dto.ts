import {
  IsBoolean,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateProductDto {
  @IsInt() @Min(1) merchantId!: number;
  @IsOptional() @IsInt() @Min(1) categoryId?: number;
  @IsString() @MaxLength(160) name!: string;
  @IsOptional() @IsString() description?: string;
  @IsNumber() @Min(0) price!: number;
  @IsOptional() @IsString() imageUrl?: string;
  @IsOptional() @IsBoolean() isAvailable?: boolean;
}
