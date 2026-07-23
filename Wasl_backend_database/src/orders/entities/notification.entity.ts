import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

@Entity('notifications')
export class InAppNotification {
  @PrimaryGeneratedColumn()
  id!: number; // 🎯 أضفنا علامة التعجب لإسكات خطأ الـ initializer

  @Column()
  userId!: number; // يمكن أن يكون ID العميل أو الكابتن

  @Column()
  title!: string;

  @Column()
  message!: string;

  @Column({ default: false })
  isRead!: boolean;

  @CreateDateColumn({ type: 'timestamp' })
  createdAt!: Date;
}
