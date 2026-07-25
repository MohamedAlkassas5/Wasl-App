import {
  Injectable,
  CanActivate,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Request } from 'express';
import { JWT_SECRET } from './jwt.constants';

// 👈 تحديد شكل البيانات القادمة من الـ JWT بدقة لإرضاء الـ ESLint
interface JwtPayload {
  sub: number;
  role: string;
}

// 👈 توسيع واجهة الـ Request لتشمل حقل الـ user بشكل رسمي
interface AuthenticatedRequest extends Request {
  user?: JwtPayload;
}

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly jwtService: JwtService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const token = this.extractTokenFromHeader(request);

    if (!token) {
      throw new UnauthorizedException(
        'عفواً، يجب تسجيل الدخول أولاً للوصول لهذا المسار',
      );
    }

    try {
      // 👈 إخبار الـ TypeScript بالنوع الصريح للـ Payload القادم
      const payload = await this.jwtService.verifyAsync<JwtPayload>(token, {
        secret: JWT_SECRET,
      });

      // 👈 الآن الإسناد آمن 100% وبدون أي حقول مجهولة
      request.user = payload;
    } catch {
      throw new UnauthorizedException('جلسة الدخول منتهية أو التوكين غير صالح');
    }

    return true;
  }

  private extractTokenFromHeader(request: Request): string | undefined {
    const [type, token] = request.headers.authorization?.split(' ') ?? [];
    return type === 'Bearer' ? token : undefined;
  }
}
