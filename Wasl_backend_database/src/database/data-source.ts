// import { DataSource, DataSourceOptions } from 'typeorm';

// import { User } from '../users/entities/user.entity';
// import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
// import { Merchant } from '../merchant/entities/merchant.entity';
// import { Order, OrderOffer } from '../orders/entities/order.entity';
// import { InAppNotification } from '../orders/entities/notification.entity';
// import { AppSetting } from '../settings/entities/app-setting.entity';
// import { OtpVerification } from '../otp/entities/otp-verification.entity';
// import { WalletTopUpRequest } from '../payments/entities/wallet-topup-request.entity';
// import { WalletTransaction } from '../payments/entities/wallet-transaction.entity';

// /**
//  * Every entity that maps to a table. The migration CLI and the running app
//  * both read this list, so a table can't exist in one and be missing from the
//  * other. (`Category` and `Store` are plain classes with no @Entity decorator —
//  * they are not tables and deliberately absent.)
//  */
// export const ENTITIES = [
//   User,
//   DeliveryPartner,
//   Merchant,
//   Order,
//   OrderOffer,
//   InAppNotification,
//   AppSetting,
//   OtpVerification,
//   WalletTopUpRequest,
//   WalletTransaction,
// ];

// /**
//  * Connection settings shared by the NestJS app (app.module.ts) and the TypeORM
//  * CLI used to generate/run migrations. Kept in one place so `migration:generate`
//  * always diffs against the same database the app will actually talk to.
//  *
//  * - Cloud (Render/Railway/Neon): DATABASE_URL, over SSL.
//  * - Local dev: individual DB_* vars.
//  */
// export function buildDataSourceOptions(): DataSourceOptions {
//   const url = process.env.DATABASE_URL;

//   return {
//     type: 'postgres',
//     ...(url
//       ? { url, ssl: { rejectUnauthorized: false } }
//       : {
//           host: process.env.DB_HOST || 'localhost',
//           port: Number(process.env.DB_PORT || 5432),
//           username: process.env.DB_USERNAME || 'postgres',
//           password: process.env.DB_PASSWORD || 'postgres',
//           database: process.env.DB_NAME || 'wasl_delivery_db',
//         }),
//     entities: ENTITIES,
//     migrations: [__dirname + '/migrations/*{.ts,.js}'],
//     // Optional pool ceiling (defaults to node-postgres' own default of 10).
//     // Managed Postgres tiers cap connections low; set DB_POOL_MAX to stay under.
//     ...(process.env.DB_POOL_MAX
//       ? { extra: { max: Number(process.env.DB_POOL_MAX) } }
//       : {}),
//     // 🔴 Never re-enable. `synchronize` silently ALTERs/DROPs production
//     // columns to match the entities — it is how schema drift turns into data
//     // loss. Schema changes go through a migration from now on.
//     synchronize: false,
//   };
// }

// /** Default export is what the TypeORM CLI looks for. */
// export default new DataSource(buildDataSourceOptions());

import 'dotenv/config'; // 🎯 حاسم جداً: يجبر Node.js على قراءة ملف .env قبل بناء الاتصال
import { DataSource, DataSourceOptions } from 'typeorm';

import { User } from '../users/entities/user.entity';
import { DeliveryPartner } from '../delivery/entities/delivery-partner.entity';
import { Merchant } from '../merchant/entities/merchant.entity';
import { Order } from '../orders/entities/order.entity';
import { InAppNotification } from '../orders/entities/notification.entity';
import { AppSetting } from '../settings/entities/app-setting.entity';
import { OtpVerification } from '../otp/entities/otp-verification.entity';
import { WalletTopUpRequest } from '../payments/entities/wallet-topup-request.entity';
import { WalletTransaction } from '../payments/entities/wallet-transaction.entity';
import { DeliveryZone } from '../zones/entities/delivery-zone.entity';
import { DeliveryZoneRate } from '../zones/entities/delivery-zone-rate.entity';
import { MenuCategory } from '../catalog/entities/menu-category.entity';
import { Product } from '../catalog/entities/product.entity';
import {
  ProductAddon,
  ProductSize,
} from '../catalog/entities/product-option.entity';
import { OrderItem } from '../orders/entities/order-item.entity';
import { OrderMessage } from '../orders/entities/order-message.entity';
import { OrderPriceProposal } from '../orders/entities/order-price-proposal.entity';
import { OrderCancellationRequest } from '../orders/entities/order-cancellation-request.entity';

/**
 * Every entity that maps to a table.
 */
export const ENTITIES = [
  User,
  DeliveryPartner,
  Merchant,
  Order,
  InAppNotification,
  AppSetting,
  OtpVerification,
  WalletTopUpRequest,
  WalletTransaction,
  DeliveryZone,
  DeliveryZoneRate,
  MenuCategory,
  Product,
  ProductSize,
  ProductAddon,
  OrderItem,
  OrderMessage,
  OrderPriceProposal,
  OrderCancellationRequest,
];

export function buildDataSourceOptions(): DataSourceOptions {
  const url = process.env.DATABASE_URL;

  return {
    type: 'postgres',
    ...(url
      ? { url, ssl: { rejectUnauthorized: false } }
      : {
          host: process.env.DB_HOST || 'localhost',
          port: Number(process.env.DB_PORT || 5432),
          username: process.env.DB_USERNAME || 'postgres',
          password: process.env.DB_PASSWORD || '',
          database: process.env.DB_NAME || 'wasl_delivery_db',
        }),
    entities: ENTITIES,
    migrations: [__dirname + '/migrations/*{.ts,.js}'],
    ...(process.env.DB_POOL_MAX
      ? { extra: { max: Number(process.env.DB_POOL_MAX) } }
      : {}),
    synchronize: false,
  };
}

export default new DataSource(buildDataSourceOptions());
