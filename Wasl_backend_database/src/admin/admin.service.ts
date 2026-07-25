import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { User, UserRole, AccountStatus } from '../users/entities/user.entity';
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

  /**
   * List driver/merchant registrations for the admin panel, optionally filtered
   * by role and status, each joined with its verification documents.
   */
  async getRegistrations(role?: UserRole, status?: AccountStatus) {
    const where: Record<string, unknown> = {};
    if (role) where.role = role;
    else where.role = undefined; // handled below
    if (status) where.status = status;

    const users = await this.userRepository.find({
      where: role
        ? { role, ...(status ? { status } : {}) }
        : [
            { role: UserRole.DELIVERY, ...(status ? { status } : {}) },
            { role: UserRole.MERCHANT, ...(status ? { status } : {}) },
          ],
      order: { created_at: 'DESC' },
    });

    // Attach the role-specific document record to each user.
    const enriched = await Promise.all(
      users.map(async (u) => {
        let details: DeliveryPartner | Merchant | null = null;
        if (u.role === UserRole.DELIVERY) {
          details = await this.deliveryRepository.findOne({
            where: { userId: u.id },
          });
        } else if (u.role === UserRole.MERCHANT) {
          details = await this.merchantRepository.findOne({
            where: { ownerId: u.id },
          });
        }
        return {
          id: u.id,
          name: u.name,
          phone: u.phone,
          email: u.email || '',
          role: u.role,
          status: u.status,
          adminNotes: u.admin_notes || '',
          createdAt: u.created_at,
          details,
        };
      }),
    );
    return enriched;
  }

  /** Headline counts for the admin dashboard. */
  async getDashboardStats() {
    const [pendingDrivers, pendingMerchants, activeDrivers, totalCustomers] =
      await Promise.all([
        this.userRepository.count({
          where: { role: UserRole.DELIVERY, status: AccountStatus.PENDING },
        }),
        this.userRepository.count({
          where: { role: UserRole.MERCHANT, status: AccountStatus.PENDING },
        }),
        this.userRepository.count({
          where: { role: UserRole.DELIVERY, status: AccountStatus.ACTIVE },
        }),
        this.userRepository.count({ where: { role: UserRole.CUSTOMER } }),
      ]);
    return {
      pendingDrivers,
      pendingMerchants,
      activeDrivers,
      totalCustomers,
    };
  }

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
