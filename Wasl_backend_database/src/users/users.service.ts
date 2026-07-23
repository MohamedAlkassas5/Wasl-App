import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './entities/user.entity';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  async getStatusByPhone(phone: string) {
    const user = await this.userRepository.findOne({ where: { phone } });

    if (!user) {
      throw new NotFoundException('المستخدم غير موجود');
    }

    return {
      success: true,
      status: user.status,
      role: user.role,
      adminNotes: user.admin_notes || '',
      name: user.name,
      id: user.id,
    };
  }
}
