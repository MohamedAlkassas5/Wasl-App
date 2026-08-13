import { BadRequestException } from '@nestjs/common';
import { OrderItemDto } from './dto/create-order.dto';
import { OrderItem } from './entities/order-item.entity';
import { Product } from '../catalog/entities/product.entity';
import {
  ProductAddon,
  ProductSize,
} from '../catalog/entities/product-option.entity';

export interface SellableProduct {
  product: Product;
  sizes: ProductSize[];
  addons: ProductAddon[];
}

const round2 = (n: number) => Math.round(n * 100) / 100;

/**
 * Turns the cart the app sent into priced order lines.
 *
 * The client sends identifiers only — which product, which size, which
 * add-ons — and every figure is looked up here. That is the whole point: the
 * previous flow serialised the cart into a text blob and stored whatever
 * `itemsPrice` the app claimed, so the customer's device decided the bill.
 *
 * Each line is then copied, not referenced, so a merchant editing the menu
 * tomorrow cannot change what this order cost.
 */
export function buildOrderItems(
  lines: OrderItemDto[],
  catalog: SellableProduct[],
): { items: Partial<OrderItem>[]; itemsTotal: number; description: string } {
  if (lines.length === 0) {
    throw new BadRequestException('لا يمكن إنشاء طلب بدون أصناف');
  }

  const byId = new Map(catalog.map((entry) => [entry.product.id, entry]));
  const items: Partial<OrderItem>[] = [];
  const descriptions: string[] = [];
  let itemsTotal = 0;

  for (const line of lines) {
    const entry = byId.get(line.productId);
    if (!entry) {
      // Either the item was delisted between browsing and checkout, or it
      // belongs to a different merchant. Both are refusals, not guesses.
      throw new BadRequestException(
        'أحد الأصناف لم يعد متاحاً، حدّث السلة وحاول مرة أخرى',
      );
    }

    const { product, sizes, addons } = entry;

    let unitPrice: number;
    let sizeName: string | null = null;
    if (sizes.length > 0) {
      if (!line.sizeId) {
        throw new BadRequestException(
          `اختر الحجم المطلوب لصنف ${product.name}`,
        );
      }
      const size = sizes.find((s) => s.id === line.sizeId);
      if (!size || !size.isAvailable) {
        throw new BadRequestException(
          `الحجم المختار لصنف ${product.name} لم يعد متاحاً`,
        );
      }
      unitPrice = Number(size.price);
      sizeName = size.name;
    } else {
      if (line.sizeId) {
        throw new BadRequestException(`صنف ${product.name} ليس له أحجام`);
      }
      unitPrice = Number(product.price);
    }

    const chosenAddons = (line.addonIds ?? []).map((addonId) => {
      const addon = addons.find((a) => a.id === addonId);
      if (!addon || !addon.isAvailable) {
        throw new BadRequestException(
          `إحدى الإضافات على صنف ${product.name} لم تعد متاحة`,
        );
      }
      return { name: addon.name, price: Number(addon.price) };
    });

    unitPrice = round2(
      unitPrice + chosenAddons.reduce((sum, a) => sum + a.price, 0),
    );
    const lineTotal = round2(unitPrice * line.quantity);
    itemsTotal = round2(itemsTotal + lineTotal);

    items.push({
      productId: product.id,
      name: product.name,
      sizeName,
      unitPrice,
      quantity: line.quantity,
      lineTotal,
      addons: chosenAddons.length ? chosenAddons : null,
      note: line.note?.trim() || null,
    });

    descriptions.push(
      describe(product.name, sizeName, chosenAddons, line, lineTotal),
    );
  }

  return { items, itemsTotal, description: descriptions.join('\n') };
}

/**
 * A readable one-line summary, kept because the driver's screens still show
 * `itemsDescription` as plain text. It is now derived from the priced lines
 * rather than being the only record of them.
 */
function describe(
  name: string,
  sizeName: string | null,
  addons: { name: string }[],
  line: OrderItemDto,
  lineTotal: number,
): string {
  let text = `${line.quantity}× ${name}`;
  if (sizeName) text += ` (${sizeName})`;
  if (addons.length) text += ` + ${addons.map((a) => a.name).join(' + ')}`;
  if (line.note?.trim()) text += ` — ملاحظة: ${line.note.trim()}`;
  return `${text} = ${lineTotal.toFixed(2)} ج.م`;
}
