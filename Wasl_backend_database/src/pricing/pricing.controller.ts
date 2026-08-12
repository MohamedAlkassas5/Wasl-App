import {
  Controller,
  Post,
  Body,
  BadRequestException,
  UseGuards,
} from '@nestjs/common';
import { PricingService } from './pricing.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { NormalQuoteDto, QuoteDto, WasllyQuoteDto } from './dto/quote.dto';
import { isValidCoordinate } from '../common/geo.util';
import { CurrentUser, AuthUser } from '../auth/current-user';
import { UsersService } from '../users/users.service';

/**
 * Pricing quote endpoints. The customer app calls these before creating an
 * order so the fee shown is the fee that will be charged. Logged-in only: the
 * response exposes our commission split, which is business config, not public
 * data.
 */
@Controller('pricing')
@UseGuards(JwtAuthGuard)
export class PricingController {
  constructor(
    private readonly pricingService: PricingService,
    private readonly usersService: UsersService,
  ) {}

  /**
   * Normal order fee, by destination area.
   *
   * With no `dropoffZoneId` the caller's saved area is used, which is why a
   * customer who has not chosen one yet gets a pointed error rather than a
   * default price.
   */
  @Post('normal-quote')
  async normalQuote(
    @CurrentUser() user: AuthUser,
    @Body() dto: NormalQuoteDto,
  ) {
    const dropoffZoneId =
      dto.dropoffZoneId ??
      (await this.usersService.getCustomerZoneId(user.sub));

    if (!dropoffZoneId) {
      throw new BadRequestException(
        'اختر منطقة التوصيل من حسابك أولاً لحساب سعر التوصيل',
      );
    }
    return this.pricingService.quoteForDestinationZone(dropoffZoneId);
  }

  /** Waslly fee, by pickup area → drop-off area. */
  @Post('waslly-quote')
  wasllyQuote(@Body() dto: WasllyQuoteDto) {
    return this.pricingService.quoteForZones(
      dto.pickupZoneId,
      dto.dropoffZoneId,
    );
  }

  /**
   * @deprecated Legacy distance/zone quote kept so existing clients keep
   * working. New callers should use `normal-quote` or `waslly-quote`, which
   * express which pricing rule they actually mean instead of inferring it from
   * whichever fields happen to be filled in.
   */
  @Post('quote')
  quote(@Body() dto: QuoteDto) {
    if (dto.pickupZoneId && dto.dropoffZoneId) {
      return this.pricingService.quoteForZones(
        dto.pickupZoneId,
        dto.dropoffZoneId,
      );
    }
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

    if (typeof dto.distanceKm === 'number') {
      return this.pricingService.quoteForDistance(dto.distanceKm);
    }

    throw new BadRequestException(
      'يجب إرسال إحداثيات الاستلام والتوصيل أو مسافة الرحلة لحساب السعر',
    );
  }
}
