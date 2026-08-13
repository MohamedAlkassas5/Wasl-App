import { IsEnum, IsOptional, IsString, Length } from 'class-validator';

import { DevicePlatform } from '../entities/device-token.entity';

export class RegisterDeviceDto {
  /** The FCM registration token. Opaque, long, and issued by the client SDK. */
  @IsString()
  @Length(20, 512)
  token!: string;

  @IsOptional()
  @IsEnum(DevicePlatform)
  platform?: DevicePlatform;
}

export class UnregisterDeviceDto {
  @IsString()
  @Length(20, 512)
  token!: string;
}
