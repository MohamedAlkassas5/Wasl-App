import {
  Injectable,
  BadRequestException,
  UnauthorizedException,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Like } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { User, UserRole, AccountStatus } from '../users/entities/user.entity';
import {
  DeliveryPartner,
  VehicleType,
} from '../delivery/entities/delivery-partner.entity';
import { Merchant } from '../merchant/entities/merchant.entity';
import { RegisterDto } from './register.dto';
import { LoginDto } from './login.dto';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User) private readonly userRepository: Repository<User>,
    @InjectRepository(DeliveryPartner)
    private readonly deliveryRepository: Repository<DeliveryPartner>,
    @InjectRepository(Merchant)
    private readonly merchantRepository: Repository<Merchant>,
    private readonly jwtService: JwtService,
  ) {}

  // 🎯 1️⃣ دالة تسجيل الحسابات الشاملة (تستقبل طلب الـ Multipart المباشر من الفلاتر)
  async register(
    registerDto: RegisterDto,
    idFront?: string,
    idBack?: string,
    storeLogo?: string,
    vehicleImage?: string,
  ) {
    const {
      name,
      phone,
      password,
      role,
      storeName,
      storeType,
      vehicleType,
      email,
      firebaseUid,
    } = registerDto;

    const cleanPhone = phone.replace(/[^0-9]/g, '');

    const existingUser = await this.userRepository.findOne({
      where: { phone: cleanPhone },
    });
    if (existingUser) {
      throw new BadRequestException('رقم الهاتف مستخدم بالفعل بالمنظومة');
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const status =
      role === UserRole.DELIVERY || role === UserRole.MERCHANT
        ? AccountStatus.PENDING
        : AccountStatus.ACTIVE;

    const user = this.userRepository.create({
      name: name.trim(),
      phone: cleanPhone,
      passwordHash,
      role,
      status,
      email: email ? email.trim() : undefined,
      firebaseUid,
    });
    const savedUser = await this.userRepository.save(user);

    if (role === UserRole.DELIVERY) {
      const deliveryRecord = this.deliveryRepository.create({
        userId: savedUser.id,
        nationalIdFront: idFront || 'pending_front.jpg',
        nationalIdBack: idBack || 'pending_back.jpg',
        selfie: 'pending_selfie.jpg',
        vehicleImage: vehicleImage || 'pending_vehicle.jpg',
        vehicleType: (vehicleType as VehicleType) || VehicleType.MOTORCYCLE,
      });
      await this.deliveryRepository.save(deliveryRecord);
    } else if (role === UserRole.MERCHANT) {
      const merchantRecord = this.merchantRepository.create({
        ownerId: savedUser.id,
        storeName: storeName ? storeName.trim() : `${name.trim()} Store`,
        storeType: storeType || 'مطاعم',
        logo: storeLogo || 'pending_logo.jpg',
      });
      await this.merchantRepository.save(merchantRecord);
    }

    const token = this.generateToken(savedUser);
    return {
      message: 'تم التحقق من رقم الهاتف وإنشاء الحساب في النظام بنجاح 🎉',
      token,
      user: {
        id: savedUser.id,
        name: savedUser.name,
        phone: savedUser.phone,
        role: savedUser.role,
        status: savedUser.status,
        email: savedUser.email || '',
        firebaseUid: savedUser.firebaseUid || '',
        adminNotes: savedUser.admin_notes || '',
      },
    };
  }

  // 🎯 2️⃣ دالة تسجيل الدخول المباشر الموثق
  async login(loginDto: LoginDto) {
    const { phone, password } = loginDto;
    const cleanPhone = phone.replace(/[^0-9]/g, '');

    const user = await this.userRepository.findOne({
      where: { phone: cleanPhone },
    });

    if (!user) {
      throw new UnauthorizedException('رقم الهاتف أو كلمة المرور غير صحيحة');
    }

    const isValidPassword = await bcrypt.compare(password, user.passwordHash);
    if (!isValidPassword) {
      throw new UnauthorizedException('رقم الهاتف أو كلمة المرور غير صحيحة');
    }

    if (user.status === AccountStatus.SUSPENDED) {
      throw new BadRequestException(
        'عفواً، الحساب محظور حالياً، يرجى مراجعة الإدارة',
      );
    }

    const token = this.generateToken(user);

    return {
      message: 'تم تسجيل الدخول بنجاح 🚀',
      token,
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        role: user.role,
        status: user.status,
        email: user.email || '',
        firebaseUid: user.firebaseUid || '',
        adminNotes: user.admin_notes || '',
      },
    };
  }

  // 🎯 3️⃣ دالة فحص الحساب الاجتماعي بالبريد أو الـ UID لصالح الـ Controller
  async findOneByEmailOrUid(
    email: string,
    firebaseUid: string,
  ): Promise<User | null> {
    if (!email && !firebaseUid) return null;

    return await this.userRepository.findOne({
      where: [{ firebaseUid: firebaseUid }, { email: email }],
    });
  }

  // 🎯 4️⃣ [تم الإصلاح ومسح async] دالة جسرية لتوليد توكن الـ JWT لصالح الـ Controller الاجتماعي
  generateJwtToken(user: User): string {
    return this.generateToken(user);
  }

  // 🎯 5️⃣ دالة حذف الحساب بكل متعلقاته اللوجستية من السيرفر
  async deleteAccountByPhone(
    phone: string,
  ): Promise<{ success: boolean; message: string }> {
    const cleanPhone = phone.replace(/[^0-9]/g, '');
    const phoneSuffix =
      cleanPhone.length > 9
        ? cleanPhone.substring(cleanPhone.length - 9)
        : cleanPhone;

    const user = await this.userRepository.findOne({
      where: { phone: Like(`%${phoneSuffix}`) },
    });

    if (!user) {
      throw new NotFoundException('عفواً، الحساب غير موجود في المنظومة');
    }

    if (user.role === UserRole.DELIVERY) {
      await this.deliveryRepository.delete({ userId: user.id });
    } else if (user.role === UserRole.MERCHANT) {
      await this.merchantRepository.delete({ ownerId: user.id });
    }

    await this.userRepository.delete({ id: user.id });

    return {
      success: true,
      message:
        'تم حذف الحساب وكافة البيانات اللوجستية التابعة له من السيرفر بنجاح.',
    };
  }

  private generateToken(user: User): string {
    return this.jwtService.sign({ sub: user.id, role: user.role });
  }
}
