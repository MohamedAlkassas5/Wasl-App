import { Entity, PrimaryColumn, Column, UpdateDateColumn } from 'typeorm';

/**
 * Key/value store for runtime-configurable business rules
 * (delivery pricing tiers, platform commission %, driver search radius…).
 *
 * Values are stored as text and parsed by SettingsService, so a single table
 * can hold numbers, booleans or strings without schema changes.
 */
@Entity('app_settings')
export class AppSetting {
  @PrimaryColumn({ type: 'varchar', length: 100 })
  key!: string;

  @Column({ type: 'text' })
  value!: string;

  @Column({ type: 'text', nullable: true })
  description?: string;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;
}
