import { IsBoolean } from 'class-validator';
import { Transform } from 'class-transformer';

export class SetMerchantAvailabilityDto {
  /**
   * True to open the store for new orders, false to close it.
   *
   * Transformed because the admin panel posts JSON but the same route is easy
   * to hit from a form, where `"false"` would otherwise be a truthy string and
   * silently re-open a shop somebody meant to close.
   */
  @Transform(({ value }): unknown => {
    if (typeof value === 'string') return value.toLowerCase() === 'true';
    return value;
  })
  @IsBoolean()
  isAcceptingOrders!: boolean;
}
