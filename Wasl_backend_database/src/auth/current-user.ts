import {
  createParamDecorator,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';
import { Request } from 'express';
import { UserRole } from '../users/entities/user.entity';

/** The verified identity carried by a JWT, attached by `JwtAuthGuard`. */
export interface AuthUser {
  sub: number;
  role: UserRole;
}

export interface AuthenticatedRequest extends Request {
  user?: AuthUser;
}

/**
 * Injects the JWT-verified user into a handler:
 *   `myOrders(@CurrentUser() user: AuthUser)`
 *
 * Always prefer this over an id taken from the URL or body — the token is the
 * only identity the server actually verified.
 */
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): AuthUser => {
    const request = ctx.switchToHttp().getRequest<AuthenticatedRequest>();
    if (!request.user) {
      // Only reachable if a route forgot JwtAuthGuard — fail closed.
      throw new ForbiddenException('تعذّر التحقق من هوية المستخدم');
    }
    return request.user;
  },
);

/**
 * Authorization check: the caller must be acting on their **own** resource,
 * unless they are an admin.
 *
 * Authentication (`JwtAuthGuard`) only proves *who* the caller is. Without this
 * check, any logged-in user could pass someone else's id in the path and read
 * or modify their data (IDOR).
 */
export function assertSelfOrAdmin(user: AuthUser, resourceOwnerId: number) {
  if (user.role === UserRole.ADMIN) return;
  if (Number(user.sub) !== Number(resourceOwnerId)) {
    throw new ForbiddenException(
      'عفواً، لا يمكنك الوصول إلى بيانات مستخدم آخر',
    );
  }
}
