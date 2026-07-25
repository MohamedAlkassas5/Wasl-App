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
