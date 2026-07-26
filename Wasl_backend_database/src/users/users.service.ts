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

  /** Status of the caller's own account, keyed on the id carried by the JWT. */
  async getStatusById(userId: number) {
    const user = await this.userRepository.findOne({ where: { id: userId } });

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
