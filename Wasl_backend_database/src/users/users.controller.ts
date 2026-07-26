import { Controller, Get, UseGuards } from '@nestjs/common';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AuthUser, CurrentUser } from '../auth/current-user';

@Controller('users')
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
  @UseGuards(JwtAuthGuard)
  @Get('status')
  getStatus(@CurrentUser() user: AuthUser) {
    return this.usersService.getStatusById(user.sub);
  }
}
