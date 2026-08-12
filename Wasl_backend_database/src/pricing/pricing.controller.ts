import {
  Controller,
  Post,
  Body,
  BadRequestException,
  UseGuards,
} from '@nestjs/common';
import { PricingService } from './pricing.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { QuoteDto } from './dto/quote.dto';
import { isValidCoordinate } from '../common/geo.util';

/**
 * Pricing quote endpoint. The customer app calls this before creating an order
 * to show the estimated delivery fee up front. Logged-in only: the response
 * exposes our commission split and tier table, which is business config, not
 * public data. (The Flutter client already sends the token here.)
 */
@Controller('pricing')
@UseGuards(JwtAuthGuard)
export class PricingController {
  constructor(private readonly pricingService: PricingService) {}

  @Post('quote')
  quote(@Body() dto: QuoteDto) {
    if (dto.pickupZoneId && dto.dropoffZoneId) {
      return this.pricingService.quoteForZones(
        dto.pickupZoneId,
        dto.dropoffZoneId,
      );
    }
    // Preferred path: compute distance from real coordinates.
    if (
      isValidCoordinate(dto.pickupLatitude, dto.pickupLongitude) &&
      isValidCoordinate(dto.destinationLatitude, dto.destinationLongitude)
    ) {
      return this.pricingService.quoteForTrip(
        { latitude: dto.pickupLatitude, longitude: dto.pickupLongitude! },
        {
          latitude: dto.destinationLatitude,
          longitude: dto.destinationLongitude!,
        },
      );
    }

    // Fallback: caller supplied a distance directly.
    if (typeof dto.distanceKm === 'number') {
      return this.pricingService.quoteForDistance(dto.distanceKm);
    }

    throw new BadRequestException(
      'يجب إرسال إحداثيات الاستلام والتوصيل أو مسافة الرحلة لحساب السعر',
    );
  }
}
