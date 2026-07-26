import { MigrationInterface, QueryRunner } from "typeorm";

export class InitialSchema1785039931464 implements MigrationInterface {
    name = 'InitialSchema1785039931464'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TYPE "public"."delivery_partners_vehicletype_enum" AS ENUM('motorcycle', 'scooter', 'car', 'bicycle')`);
        await queryRunner.query(`CREATE TYPE "public"."delivery_partners_verificationstatus_enum" AS ENUM('pending', 'approved', 'rejected')`);
        await queryRunner.query(`CREATE TABLE "delivery_partners" ("user_id" integer NOT NULL, "national_id_front" character varying NOT NULL, "national_id_back" character varying NOT NULL, "selfie" character varying NOT NULL, "vehicle_image" character varying NOT NULL, "vehicleType" "public"."delivery_partners_vehicletype_enum" NOT NULL, "license_number" character varying, "verificationStatus" "public"."delivery_partners_verificationstatus_enum" NOT NULL DEFAULT 'pending', "admin_notes" text, "balance" numeric(10,2) NOT NULL DEFAULT '0', "is_online" boolean NOT NULL DEFAULT false, "current_latitude" double precision, "current_longitude" double precision, "last_location_update" TIMESTAMP, "availability_radius_km" double precision NOT NULL DEFAULT '5', "rating" numeric(3,2) NOT NULL DEFAULT '5', "created_at" TIMESTAMP NOT NULL DEFAULT now(), "updated_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_6263f85f19ca48264691b74aecc" PRIMARY KEY ("user_id"))`);
        await queryRunner.query(`CREATE TYPE "public"."merchants_status_enum" AS ENUM('pending', 'approved', 'rejected', 'suspended')`);
        await queryRunner.query(`CREATE TABLE "merchants" ("id" SERIAL NOT NULL, "owner_id" integer NOT NULL, "store_name" character varying(150) NOT NULL, "store_type" character varying(100) NOT NULL, "logo" character varying, "cover_image" character varying, "latitude" double precision, "longitude" double precision, "address_details" text, "status" "public"."merchants_status_enum" NOT NULL DEFAULT 'pending', "admin_notes" text, "created_at" TIMESTAMP NOT NULL DEFAULT now(), "updated_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "UQ_932ac199ae3be47144903de1c10" UNIQUE ("owner_id"), CONSTRAINT "REL_932ac199ae3be47144903de1c1" UNIQUE ("owner_id"), CONSTRAINT "PK_4fd312ef25f8e05ad47bfe7ed25" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TYPE "public"."users_role_enum" AS ENUM('customer', 'delivery', 'merchant', 'admin')`);
        await queryRunner.query(`CREATE TYPE "public"."users_status_enum" AS ENUM('active', 'pending', 'rejected', 'suspended')`);
        await queryRunner.query(`CREATE TABLE "users" ("id" SERIAL NOT NULL, "name" character varying(100) NOT NULL, "phone" character varying(20) NOT NULL, "passwordHash" character varying NOT NULL, "role" "public"."users_role_enum" NOT NULL DEFAULT 'customer', "status" "public"."users_status_enum" NOT NULL DEFAULT 'active', "admin_notes" text, "email" character varying(150), "firebase_uid" character varying(255), "created_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "UQ_a000cca60bcf04454e727699490" UNIQUE ("phone"), CONSTRAINT "UQ_97672ac88f789774dd47f7c8be3" UNIQUE ("email"), CONSTRAINT "UQ_0fd54ced5cc75f7cb92925dd803" UNIQUE ("firebase_uid"), CONSTRAINT "PK_a3ffb1c0c8416b9fc6f907b7433" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TYPE "public"."orders_status_enum" AS ENUM('pending_offers', 'accepted', 'at_store', 'items_bought', 'delivering', 'completed', 'cancelled')`);
        await queryRunner.query(`CREATE TABLE "orders" ("id" SERIAL NOT NULL, "customerId" integer NOT NULL, "customerName" character varying, "customerPhone" character varying, "categoryType" character varying NOT NULL, "storeName" character varying, "itemsDescription" text NOT NULL, "voiceNoteUrl" character varying, "itemsImageUrl" character varying, "itemsPrice" numeric(10,2) NOT NULL DEFAULT '0', "invoiceImageUrl" character varying, "deliveryAddressText" text NOT NULL, "latitude" numeric(10,7), "longitude" numeric(10,7), "pickup_address_text" text, "pickup_latitude" numeric(10,7), "pickup_longitude" numeric(10,7), "distance_km" numeric(8,2), "estimated_delivery_fee" numeric(10,2) NOT NULL DEFAULT '0', "status" "public"."orders_status_enum" NOT NULL DEFAULT 'pending_offers', "finalDeliveryFee" numeric(10,2) NOT NULL DEFAULT '0', "acceptedDriverId" integer, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_710e2d4957aa5878dfe94e4ac2f" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "order_offers" ("id" SERIAL NOT NULL, "orderId" integer NOT NULL, "driverId" integer NOT NULL, "deliveryFee" numeric(10,2) NOT NULL, "estimatedTime" integer NOT NULL, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "itemsPrice" numeric(10,2) DEFAULT '0', CONSTRAINT "PK_1bffc1972713d7342168ba014a3" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "notifications" ("id" SERIAL NOT NULL, "userId" integer NOT NULL, "title" character varying NOT NULL, "message" character varying NOT NULL, "isRead" boolean NOT NULL DEFAULT false, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_6a72c3c0f683f6462415e653c3a" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "app_settings" ("key" character varying(100) NOT NULL, "value" text NOT NULL, "description" text, "updated_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_975c2db59c65c05fd9c6b63a2ab" PRIMARY KEY ("key"))`);
        await queryRunner.query(`CREATE TABLE "otp_verifications" ("id" SERIAL NOT NULL, "phone" character varying(20) NOT NULL, "otp_hash" character varying NOT NULL, "expires_at" TIMESTAMP NOT NULL, "attempts" integer NOT NULL DEFAULT '0', "sends_in_window" integer NOT NULL DEFAULT '0', "window_started_at" TIMESTAMP, "last_sent_at" TIMESTAMP, "verified" boolean NOT NULL DEFAULT false, "verified_at" TIMESTAMP, "created_at" TIMESTAMP NOT NULL DEFAULT now(), "updated_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "UQ_5121c67380278afb68a84537266" UNIQUE ("phone"), CONSTRAINT "PK_91d17e75ac3182dba6701869b39" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TYPE "public"."wallet_topup_requests_method_enum" AS ENUM('vodafone_cash', 'instapay')`);
        await queryRunner.query(`CREATE TYPE "public"."wallet_topup_requests_status_enum" AS ENUM('pending', 'approved', 'rejected')`);
        await queryRunner.query(`CREATE TABLE "wallet_topup_requests" ("id" SERIAL NOT NULL, "driver_id" integer NOT NULL, "amount" numeric(10,2) NOT NULL, "method" "public"."wallet_topup_requests_method_enum" NOT NULL, "sender_reference" character varying, "proof_image_url" character varying, "status" "public"."wallet_topup_requests_status_enum" NOT NULL DEFAULT 'pending', "admin_note" text, "reviewed_by_admin_id" integer, "reviewed_at" TIMESTAMP, "created_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_92d7915efe88d67f8f70d3ce56f" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TYPE "public"."wallet_transactions_type_enum" AS ENUM('topup', 'commission', 'adjustment')`);
        await queryRunner.query(`CREATE TABLE "wallet_transactions" ("id" SERIAL NOT NULL, "driver_id" integer NOT NULL, "amount" numeric(10,2) NOT NULL, "type" "public"."wallet_transactions_type_enum" NOT NULL, "balance_after" numeric(10,2) NOT NULL, "note" text, "created_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_5120f131bde2cda940ec1a621db" PRIMARY KEY ("id"))`);
        await queryRunner.query(`ALTER TABLE "delivery_partners" ADD CONSTRAINT "FK_6263f85f19ca48264691b74aecc" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "merchants" ADD CONSTRAINT "FK_932ac199ae3be47144903de1c10" FOREIGN KEY ("owner_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "orders" ADD CONSTRAINT "FK_e5de51ca888d8b1f5ac25799dd1" FOREIGN KEY ("customerId") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "orders" ADD CONSTRAINT "FK_d0e2fead24f037c9c6e2f08b1ff" FOREIGN KEY ("acceptedDriverId") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "order_offers" ADD CONSTRAINT "FK_442420865429b5f394b72188d4f" FOREIGN KEY ("orderId") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "order_offers" ADD CONSTRAINT "FK_4d19b64af866b76b977a4e02757" FOREIGN KEY ("driverId") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "order_offers" DROP CONSTRAINT "FK_4d19b64af866b76b977a4e02757"`);
        await queryRunner.query(`ALTER TABLE "order_offers" DROP CONSTRAINT "FK_442420865429b5f394b72188d4f"`);
        await queryRunner.query(`ALTER TABLE "orders" DROP CONSTRAINT "FK_d0e2fead24f037c9c6e2f08b1ff"`);
        await queryRunner.query(`ALTER TABLE "orders" DROP CONSTRAINT "FK_e5de51ca888d8b1f5ac25799dd1"`);
        await queryRunner.query(`ALTER TABLE "merchants" DROP CONSTRAINT "FK_932ac199ae3be47144903de1c10"`);
        await queryRunner.query(`ALTER TABLE "delivery_partners" DROP CONSTRAINT "FK_6263f85f19ca48264691b74aecc"`);
        await queryRunner.query(`DROP TABLE "wallet_transactions"`);
        await queryRunner.query(`DROP TYPE "public"."wallet_transactions_type_enum"`);
        await queryRunner.query(`DROP TABLE "wallet_topup_requests"`);
        await queryRunner.query(`DROP TYPE "public"."wallet_topup_requests_status_enum"`);
        await queryRunner.query(`DROP TYPE "public"."wallet_topup_requests_method_enum"`);
        await queryRunner.query(`DROP TABLE "otp_verifications"`);
        await queryRunner.query(`DROP TABLE "app_settings"`);
        await queryRunner.query(`DROP TABLE "notifications"`);
        await queryRunner.query(`DROP TABLE "order_offers"`);
        await queryRunner.query(`DROP TABLE "orders"`);
        await queryRunner.query(`DROP TYPE "public"."orders_status_enum"`);
        await queryRunner.query(`DROP TABLE "users"`);
        await queryRunner.query(`DROP TYPE "public"."users_status_enum"`);
        await queryRunner.query(`DROP TYPE "public"."users_role_enum"`);
        await queryRunner.query(`DROP TABLE "merchants"`);
        await queryRunner.query(`DROP TYPE "public"."merchants_status_enum"`);
        await queryRunner.query(`DROP TABLE "delivery_partners"`);
        await queryRunner.query(`DROP TYPE "public"."delivery_partners_verificationstatus_enum"`);
        await queryRunner.query(`DROP TYPE "public"."delivery_partners_vehicletype_enum"`);
    }

}
