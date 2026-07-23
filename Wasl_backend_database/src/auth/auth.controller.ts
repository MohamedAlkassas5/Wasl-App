import {
  Body,
  Controller,
  Post,
  Delete,
  Param,
  UploadedFiles,
  UseInterceptors,
} from '@nestjs/common';
import { FileFieldsInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import * as fs from 'fs';

import { AuthService } from './auth.service';
import { RegisterDto } from './register.dto';
import { LoginDto } from './login.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  // 🎯 تم إزالة الـ Endpoint الخاصة بـ verify-otp لأن التحقق أصبح يتم بالكامل داخل الفلاتر عبر Firebase

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

  @Post('login')
  login(@Body() loginDto: LoginDto) {
    return this.authService.login(loginDto);
  }

  // 🌐 2️⃣ [تم الإصلاح ومسح await] فحص الدخول الاجتماعي عبر البريد أو فيسبوك من الفلاتر لتأمين الدخول السريع
  @Post('social-check')
  async socialCheck(@Body() body: { email: string; firebaseUid: string }) {
    const { email, firebaseUid } = body;

    // البحث في قاعدة البيانات عن المستخدم بالبريد أو الـ UID من خلال الـ authService
    const user = await this.authService.findOneByEmailOrUid(email, firebaseUid);

    if (user) {
      // 🎉 الحساب مسجل فعلياً! توليد Access Token مباشرة بدون await لأن الدالة زامنية (Sync)
      const token = this.authService.generateJwtToken(user);
      return {
        success: true,
        isRegistered: true,
        data: {
          user: user,
          token: token,
        },
      };
    }

    // 🆕 الحساب جديد تماماً ومحتاج يروح لشاشة استكمال البيانات في الفلاتر
    return {
      success: true,
      isRegistered: false,
      message: 'الحساب غير مسجل، يرجى استكمال البيانات الجغرافية ورقم الهاتف.',
    };
  }

  @Delete(':phone')
  async deleteAccount(
    @Param('phone') phone: string,
  ): Promise<{ success: boolean; message: string }> {
    const cleanPhone = phone.replace(/[^a-zA-Z0-9]/g, '');
    return await this.authService.deleteAccountByPhone(cleanPhone);
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
