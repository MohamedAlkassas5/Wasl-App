import {
  IsEnum,
  IsNotEmpty,
  IsString,
  Length,
  IsOptional,
  IsEmail,
} from 'class-validator';
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

  // 🌐 [جديد ولايف] حقول التحقق الاجتماعي القادمة من الفلاتر لشغل استكمال البيانات الاجتماعي
  @IsEmail({}, { message: 'برجاء إدخال بريد إلكتروني صحيح' })
  @IsOptional()
  email?: string;

  @IsString()
  @IsOptional()
  firebaseUid?: string;
}
