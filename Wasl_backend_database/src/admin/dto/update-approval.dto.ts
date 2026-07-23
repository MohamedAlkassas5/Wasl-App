import { IsEnum, IsOptional, IsString } from 'class-validator';
import { AccountStatus } from '../../users/entities/user.entity';

export class UpdateApprovalDto {
  // eslint-disable-next-line @typescript-eslint/no-unsafe-call
  @IsEnum(AccountStatus, {
    message: 'الحالة يجب أن تكون قيمة صحيحة من حالات الحساب المعتمدة',
  })
  status!: AccountStatus;

  // eslint-disable-next-line @typescript-eslint/no-unsafe-call
  @IsString({
    message: 'الملاحظات يجب أن تكون عبارة عن نص صحيح',
  })
  // eslint-disable-next-line @typescript-eslint/no-unsafe-call
  @IsOptional()
  adminNotes?: string;
}
