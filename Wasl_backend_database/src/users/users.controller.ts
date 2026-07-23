import {
  Controller,
  Get,
  Query,
  BadRequestException,
} from '@nestjs/common';
import { UsersService } from './users.service';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('status')
  getStatus(@Query('phone') phone?: string) {
    if (!phone || phone.trim().length === 0) {
      throw new BadRequestException('رقم الهاتف مطلوب');
    }

    const cleanPhone = phone.replace(/\+/g, '').replace(/\s/g, '').trim();
    return this.usersService.getStatusByPhone(cleanPhone);
  }
}
