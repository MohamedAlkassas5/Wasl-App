import { IsString, Length } from 'class-validator';

export class RefreshSessionDto {
  /**
   * The opaque refresh token issued at sign-in or by the previous refresh.
   *
   * Length-bounded so the route cannot be used to push arbitrary payloads
   * through a SHA-256; 48 random bytes render to 64 base64url characters, and
   * the range leaves room for a format change without being an open door.
   */
  @IsString()
  @Length(32, 256)
  refreshToken!: string;
}
