import {
  IsEnum,
  IsNotEmpty,
  IsString,
  Length,
  IsOptional,
  IsEmail,
  IsNumber,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';
import { UserRole } from '../users/entities/user.entity';

export class RegisterDto {
  @IsString()
  @IsNotEmpty()
  name!: string;

  @IsString()
  @Length(8, 20)
  phone!: string;

  @IsString()
  @Length(6, 50)
  password!: string;

  @IsEnum(UserRole)
  role!: UserRole;

  @IsString()
  @IsOptional()
  storeName?: string;

  @IsString()
  @IsOptional()
  storeType?: string;

  @IsString()
  @IsOptional()
  vehicleType?: string;

  /**
   * The customer's home area, one of the approved zones.
   *
   * Optional at the DTO level rather than required: drivers, merchants and
   * admins have no customer area, and an app build that predates the area
   * picker must still be able to create an account. When it *is* sent it is
   * validated against the live zone list — an unsupported area is rejected,
   * never silently stored.
   */
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  customerZoneId?: number;

  // 🌐 [جديد ولايف] حقول التحقق الاجتماعي القادمة من الفلاتر لشغل استكمال البيانات الاجتماعي
  @IsEmail({}, { message: 'برجاء إدخال بريد إلكتروني صحيح' })
  @IsOptional()
  email?: string;

  @IsString()
  @IsOptional()
  firebaseUid?: string;
}
