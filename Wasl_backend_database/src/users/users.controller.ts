import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AuthUser, CurrentUser } from '../auth/current-user';
import { UpdateAreaDto } from './dto/update-area.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  /**
   * Account status for the polling "pending approval" screen.
   *
   * This used to take `?phone=` from the query string with no auth, which let
   * anyone enumerate the user base — feed it phone numbers and it answers with
   * the name, role, id and admin notes of whoever it finds. The phone is gone;
   * the account is now resolved from the caller's own token.
   */
  @Get('status')
  getStatus(@CurrentUser() user: AuthUser) {
    return this.usersService.getStatusById(user.sub);
  }

  /** The caller's own profile, including their saved delivery area. */
  @Get('me')
  getMe(@CurrentUser() user: AuthUser) {
    return this.usersService.getProfile(user.sub);
  }

  /**
   * Edit the caller's own name/email. Always acts on the token's account, so
   * there is no id in the path to tamper with.
   */
  @Patch('me')
  updateMe(@CurrentUser() user: AuthUser, @Body() dto: UpdateProfileDto) {
    return this.usersService.updateProfile(user.sub, dto);
  }

  /**
   * Change the caller's delivery area. Always acts on the token's own account,
   * so there is no id to tamper with.
   */
  @Patch('me/area')
  updateArea(@CurrentUser() user: AuthUser, @Body() dto: UpdateAreaDto) {
    return this.usersService.updateCustomerZone(user.sub, dto.customerZoneId);
  }
}
