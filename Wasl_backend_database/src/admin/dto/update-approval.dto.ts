import { IsEnum, IsOptional, IsString } from 'class-validator';
import { AccountStatus } from '../../users/entities/user.entity';

export class UpdateApprovalDto {
  @IsEnum(AccountStatus, {
    message: 'الحالة يجب أن تكون قيمة صحيحة من حالات الحساب المعتمدة',
  })
  status!: AccountStatus;

  @IsString({
    message: 'الملاحظات يجب أن تكون عبارة عن نص صحيح',
  })
  @IsOptional()
  adminNotes?: string;
}
