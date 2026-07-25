import { Controller, Post, Body, BadRequestException } from '@nestjs/common';
import { PricingService } from './pricing.service';
import { QuoteDto } from './dto/quote.dto';
import { isValidCoordinate } from '../common/geo.util';

/**
 * Public pricing quote endpoint. The customer app calls this before creating
 * an order to show the estimated delivery fee up front.
 */
@Controller('pricing')
export class PricingController {
  constructor(private readonly pricingService: PricingService) {}

  @Post('quote')
  quote(@Body() dto: QuoteDto) {
    // Preferred path: compute distance from real coordinates.
    if (
      isValidCoordinate(dto.pickupLatitude, dto.pickupLongitude) &&
      isValidCoordinate(dto.destinationLatitude, dto.destinationLongitude)
    ) {
      return this.pricingService.quoteForTrip(
        { latitude: dto.pickupLatitude!, longitude: dto.pickupLongitude! },
        {
          latitude: dto.destinationLatitude!,
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
