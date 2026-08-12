import { ForbiddenException } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { Test, TestingModule } from '@nestjs/testing';

import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';
import { AuthUser } from '../auth/current-user';
import { UserRole } from '../users/entities/user.entity';
import { CreateOrderDto } from './dto/create-order.dto';

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
      | 'submitOffer'
    >
  >;

  beforeEach(async () => {
    service = {
      createOrder: jest.fn().mockResolvedValue({ success: true }),
      getCustomerOrders: jest.fn().mockResolvedValue([]),
      deleteDriverProfile: jest.fn().mockResolvedValue(undefined),
      submitOffer: jest.fn().mockResolvedValue({ success: true }),
    };

    const module: TestingModule = await Test.createTestingModule({
      // JwtAuthGuard is attached to the controller, so Nest instantiates it —
      // it never runs here, we call the handlers directly.
      imports: [JwtModule.register({ secret: 'test-secret' })],
      controllers: [OrdersController],
      providers: [{ provide: OrdersService, useValue: service }],
    }).compile();

    controller = module.get(OrdersController);
  });

  it('is defined', () => {
    expect(controller).toBeDefined();
  });

  it('ignores a client-supplied customerId and books the order for the token owner', () => {
    const dto = { customerId: 999, items: [] } as unknown as CreateOrderDto;

    controller.create(
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

  it('submits an offer as the authenticated driver, not as the id in the body', () => {
    controller.submitOffer(DRIVER, 5, {
      deliveryFee: 30,
      estimatedTime: 15,
    });

    expect(service.submitOffer).toHaveBeenCalledWith(DRIVER.sub, 5, 30, 15);
  });
});
