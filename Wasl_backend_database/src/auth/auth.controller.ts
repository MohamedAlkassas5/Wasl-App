import {
  Body,
  Controller,
  GoneException,
  Post,
  Delete,
  Param,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileFieldsInterceptor } from '@nestjs/platform-express';
import { Throttle } from '@nestjs/throttler';
import { diskStorage } from 'multer';
import { extname } from 'path';
import * as fs from 'fs';

import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { AuthUser, CurrentUser } from './current-user';
import { UserRole } from '../users/entities/user.entity';
import { RegisterDto } from './register.dto';
import { LoginDto } from './login.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  // 🎯 تم إزالة الـ Endpoint الخاصة بـ verify-otp لأن التحقق أصبح يتم بالكامل داخل الفلاتر عبر Firebase

  // Registration writes files to disk — cap it hard per IP.
  @Throttle({ default: { limit: 5, ttl: 3_600_000 } })
  @Post('register')
  @UseInterceptors(
    FileFieldsInterceptor(
      [
        { name: 'idFront', maxCount: 1 },
        { name: 'idBack', maxCount: 1 },
        { name: 'storeLogo', maxCount: 1 },
        { name: 'vehicleImage', maxCount: 1 },
      ],
      {
        storage: diskStorage({
          // ✅ الحفظ المباشر في الفولدر العام يمنع تعليق الـ Stream في الـ Localhost والمحاكي
          destination: (req, file, callback) => {
            const uploadPath = './uploads';
            if (!fs.existsSync(uploadPath)) {
              fs.mkdirSync(uploadPath, { recursive: true });
            }
            callback(null, uploadPath);
          },
          filename: (req, file, callback) => {
            const uniqueSuffix =
              Date.now() + '-' + Math.round(Math.random() * 1e9);
            const extension = extname(file.originalname);
            callback(null, `${file.fieldname}-${uniqueSuffix}${extension}`);
          },
        }),
      },
    ),
  )
  register(
    @Body() registerDto: RegisterDto,
    @UploadedFiles()
    files: {
      idFront?: Express.Multer.File[];
      idBack?: Express.Multer.File[];
      storeLogo?: Express.Multer.File[];
      vehicleImage?: Express.Multer.File[];
    },
  ) {
    // ✅ الحقول بتتقرأ هنا بسلاسة تامة بعد معالجة الـ Multi-part
    const idFrontName = files?.idFront?.[0]?.filename
      ? `uploads/${files.idFront[0].filename}`
      : 'pending_front.jpg';

    const idBackName = files?.idBack?.[0]?.filename
      ? `uploads/${files.idBack[0].filename}`
      : 'pending_back.jpg';

    const storeLogoName = files?.storeLogo?.[0]?.filename
      ? `uploads/${files.storeLogo[0].filename}`
      : 'pending_logo.jpg';

    const vehicleImageName = files?.vehicleImage?.[0]?.filename
      ? `uploads/${files.vehicleImage[0].filename}`
      : 'pending_vehicle.jpg';

    return this.authService.register(
      registerDto,
      idFrontName,
      idBackName,
      storeLogoName,
      vehicleImageName,
    );
  }

  // Password endpoint: 10 attempts per 5 minutes per IP blunts credential
  // stuffing without locking out a user who fat-fingers their password.
  @Throttle({ default: { limit: 10, ttl: 300_000 } })
  @Post('login')
  login(@Body() loginDto: LoginDto) {
    return this.authService.login(loginDto);
  }

  /**
   * 🚫 DISABLED — this was a full account-takeover hole.
   *
   * It looked a user up by `email` OR `firebaseUid` and, on a match, minted a
   * session token. Neither value was ever verified: posting a known email
   * address was enough to receive a valid JWT for that account. The Flutter
   * side never performed real Google/Facebook sign-in either — it sent a
   * hardcoded address (`ahmed_google@wasl.com`), so nothing legitimate depends
   * on this route.
   *
   * To bring social login back it must verify a real Firebase ID token
   * server-side (firebase-admin `verifyIdToken`) and trust only the uid inside
   * that verified token. Until then, phone + WhatsApp OTP is the login path.
   */
  @Post('social-check')
  socialCheck(): never {
    throw new GoneException(
      'الدخول عبر الحسابات الاجتماعية غير متاح حالياً، يرجى الدخول برقم الهاتف',
    );
  }

  /**
   * Account deletion. Previously unauthenticated: anyone who knew (or guessed)
   * a phone number could wipe that account. Now the caller must hold a valid
   * token, and a non-admin can only delete themselves — the `:phone` in the URL
   * is ignored for them and the id comes from the token.
   */
  @UseGuards(JwtAuthGuard)
  @Delete(':phone')
  async deleteAccount(
    @CurrentUser() requester: AuthUser,
    @Param('phone') phone: string,
  ): Promise<{ success: boolean; message: string }> {
    if (requester.role === UserRole.ADMIN) {
      return await this.authService.deleteAccountByPhone(phone);
    }
    return await this.authService.deleteAccountById(requester.sub);
  }
}
// import {
//   Body,
//   Controller,
//   Post,
//   UseInterceptors,
//   UploadedFiles,
// } from '@nestjs/common';
// import { FileFieldsInterceptor } from '@nestjs/platform-express';
// import { diskStorage } from 'multer';
// import { extname } from 'path';
// import * as fs from 'fs';

// import { AuthService } from './auth.service';
// import { RegisterDto } from './register.dto';
// import { LoginDto } from './login.dto';

// @Controller('auth')
// export class AuthController {
//   constructor(private readonly authService: AuthService) {}

//   @Post('register')
//   @UseInterceptors(
//     FileFieldsInterceptor(
//       [
//         { name: 'idFront', maxCount: 1 },
//         { name: 'idBack', maxCount: 1 },
//         { name: 'storeLogo', maxCount: 1 },
//         { name: 'vehicleImage', maxCount: 1 },
//       ],
//       {
//         storage: diskStorage({
//           // ✅ تم التعديل لحفظ الملفات في مجلد المرفوعات الرئيسي مباشرة
//           // ده بيمنع تعليق أو موت الـ Stream السحابي بسبب قراءة req.body المبكرة
//           destination: (req, file, callback) => {
//             const uploadPath = './uploads';

//             // التأكد من وجود المجلد الرئيسي، وإنشائه فوراً إذا لم يكن موجوداً
//             if (!fs.existsSync(uploadPath)) {
//               fs.mkdirSync(uploadPath, { recursive: true });
//             }
//             callback(null, uploadPath);
//           },
//           filename: (req, file, callback) => {
//             const uniqueSuffix =
//               Date.now() + '-' + Math.round(Math.random() * 1e9);
//             const ext = extname(file.originalname);
//             callback(null, `${file.fieldname}-${uniqueSuffix}${ext}`);
//           },
//         }),
//       },
//     ),
//   )
//   register(
//     @Body() registerDto: RegisterDto,
//     @UploadedFiles()
//     files: {
//       idFront?: Array<Record<string, any>>;
//       idBack?: Array<Record<string, any>>;
//       storeLogo?: Array<Record<string, any>>;
//       vehicleImage?: Array<Record<string, any>>;
//     },
//   ) {
//     // ✅ هنا الـ registerDto بيبقى اِتقرأ بالكامل وبشكل آمن بنسبة 100%
//     const idFrontName =
//       files?.idFront &&
//       files.idFront[0] &&
//       typeof files.idFront[0].filename === 'string'
//         ? `uploads/${files.idFront[0].filename}`
//         : 'pending_front.jpg';

//     const idBackName =
//       files?.idBack &&
//       files.idBack[0] &&
//       typeof files.idBack[0].filename === 'string'
//         ? `uploads/${files.idBack[0].filename}`
//         : 'pending_back.jpg';

//     const storeLogoName =
//       files?.storeLogo &&
//       files.storeLogo[0] &&
//       typeof files.storeLogo[0].filename === 'string'
//         ? `uploads/${files.storeLogo[0].filename}`
//         : 'pending_logo.jpg';

//     const vehicleImageName =
//       files?.vehicleImage &&
//       files.vehicleImage[0] &&
//       typeof files.vehicleImage[0].filename === 'string'
//         ? `uploads/${files.vehicleImage[0].filename}`
//         : 'pending_vehicle.jpg';

//     // تمرير البيانات كاملة والمحدثة لـ AuthService
//     return this.authService.register(
//       registerDto,
//       idFrontName,
//       idBackName,
//       storeLogoName,
//       vehicleImageName,
//     );
//   }

//   @Post('login')
//   login(@Body() loginDto: LoginDto) {
//     return this.authService.login(loginDto);
//   }
// }
