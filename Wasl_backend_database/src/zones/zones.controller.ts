import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ZonesService } from './zones.service';
import { CreateZoneDto } from './dto/create-zone.dto';
import { CreateZoneRateDto } from './dto/create-zone-rate.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { UserRole } from '../users/entities/user.entity';

@Controller('zones')
export class ZonesController {
  constructor(private readonly service: ZonesService) {}

  @Get()
  list(@Query('all') all?: string) {
    return this.service.list(all !== 'true');
  }

  @Get('rates')
  rates() {
    return this.service.listRates();
  }

  @Post()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  create(@Body() dto: CreateZoneDto) {
    return this.service.create(dto);
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: Partial<CreateZoneDto>,
  ) {
    return this.service.update(id, dto);
  }

  @Post('rates')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  createRate(@Body() dto: CreateZoneRateDto) {
    return this.service.createRate(dto);
  }
}
