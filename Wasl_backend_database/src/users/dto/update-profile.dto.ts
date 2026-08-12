import {
  IsEmail,
  IsOptional,
  IsString,
  Length,
  ValidateIf,
} from 'class-validator';
import { Transform } from 'class-transformer';

/** Trims a submitted string and leaves any other value untouched. */
const trim = ({ value }: { value: unknown }): unknown =>
  typeof value === 'string' ? value.trim() : value;

/**
 * Editable parts of a customer's own profile.
 *
 * The phone number is deliberately absent: it is the login identifier and its
 * ownership is proven by a WhatsApp code, so changing it is a verification
 * flow rather than a profile edit.
 *
 * Both fields are optional so the client can send only what changed, but at
 * least one must be present — see `UsersService.updateProfile`.
 */
export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @Transform(trim)
  @Length(2, 100, { message: 'الاسم يجب أن يكون بين حرفين و100 حرف' })
  name?: string;

  /**
   * An empty string clears the stored address; anything else must be a real
   * email. `ValidateIf` is what allows both — without it `@IsEmail` would
   * reject the empty string and there would be no way to remove an address
   * once saved.
   */
  @IsOptional()
  @Transform(trim)
  @ValidateIf((dto: UpdateProfileDto) => dto.email !== '')
  @IsEmail({}, { message: 'برجاء إدخال بريد إلكتروني صحيح' })
  email?: string;
}
