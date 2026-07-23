import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { ROLES_KEY } from './decorators/roles.decorator';
import { UserRole } from '../users/entities/user.entity';

// 👈 تعريف نوع الـ User القادم من التوكين بدقة لإرضاء الـ ESLint
interface AuthenticatedRequest extends Request {
  user?: {
    sub: number;
    role: UserRole;
  };
}

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<UserRole[]>(
      ROLES_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (!requiredRoles) {
      return true;
    }

    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const user = request.user;

    // 👈 الفحص الآمن بدون Unsafe Calls
    if (!user || !requiredRoles.includes(user.role)) {
      throw new ForbiddenException(
        'عفواً، لا تمتلك الصلاحيات الكافية للوصول لهذا الإجراء',
      );
    }

    return true;
  }
}
