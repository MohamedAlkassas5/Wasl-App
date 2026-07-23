import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { User, UserRole } from '../users/entities/user.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { Merchant } from '../merchant/entities/merchant.entity';
import { UpdateApprovalDto } from './dto/update-approval.dto';

@Injectable()
export class AdminService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,

    @InjectRepository(DeliveryPartner)
    private readonly deliveryRepository: Repository<DeliveryPartner>,

    @InjectRepository(Merchant)
    private readonly merchantRepository: Repository<Merchant>,
  ) {}

  async reviewRegistration(
    targetUserId: number,
    updateApprovalDto: UpdateApprovalDto,
  ) {
    const user = await this.userRepository.findOne({
      where: {
        id: targetUserId,
      },
    });

    if (!user) {
      throw new NotFoundException('عفواً، لم يتم العثور على هذا المستخدم');
    }

    if (user.role === UserRole.CUSTOMER || user.role === UserRole.ADMIN) {
      throw new BadRequestException('يمكن فقط مراجعة طلبات المناديب والمتاجر');
    }

    // تحديث حالة الحساب
    user.status = updateApprovalDto.status;

    await this.userRepository.save(user);

    // ملاحظات الإدارة
    const adminNotes = updateApprovalDto.adminNotes?.trim() || undefined;

    if (user.role === UserRole.DELIVERY) {
      await this.deliveryRepository.update(
        {
          userId: user.id,
        },
        {
          adminNotes,
        },
      );
    }

    if (user.role === UserRole.MERCHANT) {
      await this.merchantRepository.update(
        {
          ownerId: user.id,
        },
        {
          adminNotes,
        },
      );
    }

    return {
      success: true,
      userId: user.id,
      role: user.role,
      status: user.status,
      message: `تم تحديث حالة الحساب بنجاح إلى [${updateApprovalDto.status}]`,
    };
  }
}
