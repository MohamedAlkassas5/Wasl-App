import { IsString, IsNotEmpty, Length, Matches } from 'class-validator';

export class SendOtpDto {
  @IsString()
  @IsNotEmpty()
  @Matches(/^[0-9+\s]{8,20}$/, { message: 'رقم الهاتف غير صالح' })
  phone!: string;
}

export class VerifyOtpDto {
  @IsString()
  @IsNotEmpty()
  @Matches(/^[0-9+\s]{8,20}$/, { message: 'رقم الهاتف غير صالح' })
  phone!: string;

  @IsString()
  @Length(4, 8)
  code!: string;
}

/**
 * Password reset. The code is re-submitted rather than trusted from a previous
 * call so the reset is always tied to a proven OTP, never to a phone number
 * alone.
 */
export class ResetPasswordDto {
  @IsString()
  @IsNotEmpty()
  @Matches(/^[0-9+\s]{8,20}$/, { message: 'رقم الهاتف غير صالح' })
  phone!: string;

  @IsString()
  @Length(4, 8)
  code!: string;

  @IsString()
  @Length(6, 50, { message: 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' })
  newPassword!: string;
}
