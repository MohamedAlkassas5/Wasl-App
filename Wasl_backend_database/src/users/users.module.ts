import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from './entities/user.entity';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';
import { ZonesModule } from '../zones/zones.module';

@Module({
  // ZonesModule owns "is this an approved area?", so registration, profile
  // updates and order creation can't drift apart on that answer.
  imports: [TypeOrmModule.forFeature([User]), ZonesModule],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
