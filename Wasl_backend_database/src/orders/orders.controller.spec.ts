import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { Test, TestingModule } from '@nestjs/testing';

import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';
import { AuthUser } from '../auth/current-user';
import { UserRole } from '../users/entities/user.entity';
import { CreateOrderDto } from './dto/create-order.dto';
import { AccountAccessService } from '../auth/account-access.service';
import { UploadService } from '../storage/upload.service';

/**
 * These cover the broken-access-control fix: the caller's identity comes from
 * the JWT, and ids in the URL or body are checked against it rather than
 * trusted. The service is mocked — what's under test is the controller's
 * authorization, not the database.
 */
describe('OrdersController (authorization)', () => {
  const CUSTOMER: AuthUser = { sub: 10, role: UserRole.CUSTOMER };
  const DRIVER: AuthUser = { sub: 20, role: UserRole.DELIVERY };
  const ADMIN: AuthUser = { sub: 1, role: UserRole.ADMIN };

  let controller: OrdersController;
  let service: jest.Mocked<
    Pick<
      OrdersService,
      | 'createOrder'
      | 'getCustomerOrders'
      | 'deleteDriverProfile'
      | 'acceptAvailableOrder'
    >
  >;

  beforeEach(async () => {
    service = {
      createOrder: jest.fn().mockResolvedValue({ success: true }),
      getCustomerOrders: jest.fn().mockResolvedValue([]),
      deleteDriverProfile: jest.fn().mockResolvedValue(undefined),
      acceptAvailableOrder: jest.fn().mockResolvedValue({ success: true }),
    };

    const module: TestingModule = await Test.createTestingModule({
      // JwtAuthGuard is attached to the controller, so Nest instantiates it —
      // it never runs here, we call the handlers directly.
      imports: [JwtModule.register({ secret: 'test-secret' })],
      controllers: [OrdersController],
      providers: [
        { provide: OrdersService, useValue: service },
        // Uploads go through the storage backend now; no file is sent in these
        // handler-level tests, so this only has to exist.
        {
          provide: UploadService,
          useValue: { persistImage: jest.fn().mockResolvedValue(undefined) },
        },
        // The guard now also rejects closed accounts, so it needs the account
        // lookup even though it never runs in these handler-level tests.
        { provide: AccountAccessService, useValue: { isClosed: () => false } },
      ],
    }).compile();

    controller = module.get(OrdersController);
  });

  it('is defined', () => {
    expect(controller).toBeDefined();
  });

  it('ignores a client-supplied customerId and books the order for the token owner', async () => {
    const dto = { customerId: 999, items: [] } as unknown as CreateOrderDto;

    await controller.create(
      CUSTOMER,
      undefined as unknown as Express.Multer.File,
      dto,
    );

    expect(dto.customerId).toBe(CUSTOMER.sub);
    expect(service.createOrder).toHaveBeenCalledWith(CUSTOMER.sub, dto);
  });

  it("refuses to list another customer's orders", () => {
    expect(() => controller.getCustomerOrders(CUSTOMER, 11)).toThrow(
      ForbiddenException,
    );
    expect(service.getCustomerOrders).not.toHaveBeenCalled();
  });

  it('lets a customer list their own orders', () => {
    controller.getCustomerOrders(CUSTOMER, CUSTOMER.sub);
    expect(service.getCustomerOrders).toHaveBeenCalledWith(CUSTOMER.sub);
  });

  it('lets an admin list anyone’s orders', () => {
    controller.getCustomerOrders(ADMIN, CUSTOMER.sub);
    expect(service.getCustomerOrders).toHaveBeenCalledWith(CUSTOMER.sub);
  });

  it('refuses to delete another driver’s account', async () => {
    await expect(controller.deleteDriverAccount(DRIVER, 21)).rejects.toThrow(
      ForbiddenException,
    );
    expect(service.deleteDriverProfile).not.toHaveBeenCalled();
  });

  it('accepts an order as the authenticated driver, not as an id in the request', () => {
    controller.acceptAvailableOrder(DRIVER, 5);

    expect(service.acceptAvailableOrder).toHaveBeenCalledWith(5, DRIVER.sub);
  });

  it('refuses acceptance from anyone who is not a driver', () => {
    // There is no delivery fee in this request to argue about any more — the
    // only thing acceptance decides is who gets the order, so the one check
    // that matters is that the caller is a captain.
    expect(() => controller.acceptAvailableOrder(CUSTOMER, 5)).toThrow(
      BadRequestException,
    );
    expect(service.acceptAvailableOrder).not.toHaveBeenCalled();
  });
});
