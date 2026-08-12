import {
  Injectable,
  CanActivate,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Request } from 'express';
import { JWT_SECRET } from './jwt.constants';
import { AccountAccessService } from './account-access.service';

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
  constructor(
    private readonly jwtService: JwtService,
    private readonly accountAccess: AccountAccessService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const token = this.extractTokenFromHeader(request);

    if (!token) {
      throw new UnauthorizedException(
        'عفواً، يجب تسجيل الدخول أولاً للوصول لهذا المسار',
      );
    }

    let payload: JwtPayload;
    try {
      // 👈 إخبار الـ TypeScript بالنوع الصريح للـ Payload القادم
      payload = await this.jwtService.verifyAsync<JwtPayload>(token, {
        secret: JWT_SECRET,
      });
    } catch {
      throw new UnauthorizedException('جلسة الدخول منتهية أو التوكين غير صالح');
    }

    // 🔐 A valid signature only proves the token was ours when it was issued.
    // Closing an account keeps the row (its orders reference a driver who was
    // paid), so the old token stays verifiable — without this check every
    // protected route would keep answering a deleted account until the token
    // expired. Checked here, once, rather than in each controller.
    //
    // Note this is outside the catch above on purpose: a database failure must
    // surface as a server error, not be swallowed into "your session expired".
    if (await this.accountAccess.isClosed(payload.sub)) {
      throw new UnauthorizedException('تم حذف هذا الحساب');
    }

    // 👈 الآن الإسناد آمن 100% وبدون أي حقول مجهولة
    request.user = payload;
    return true;
  }

  private extractTokenFromHeader(request: Request): string | undefined {
    const [type, token] = request.headers.authorization?.split(' ') ?? [];
    return type === 'Bearer' ? token : undefined;
  }
}
