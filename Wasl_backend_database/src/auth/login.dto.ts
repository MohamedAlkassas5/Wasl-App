import { IsString, IsNotEmpty } from 'class-validator';

export class LoginDto {
  @IsString()
  @IsNotEmpty({ message: 'برجاء إدخال رقم الهاتف' })
  phone!: string;

  @IsString()
  @IsNotEmpty({ message: 'برجاء إدخال كلمة المرور' })
  password!: string;
}
