// 在项目中的位置：src/app.ts
// devDependencies：vitest、supertest、@types/supertest；现有测试在 tests/ 下，用 describe + 中文 it 描述。
import express, { Request, Response } from 'express';

export interface Order {
  id: string;
  skuId: string;
  quantity: number;
  status: 'CREATED' | 'PAID' | 'CANCELLED';
}

export interface OrderStore {
  create(skuId: string, quantity: number): Promise<Order>;
  find(id: string): Promise<Order | undefined>;
}

export function createApp(store: OrderStore) {
  const app = express();
  app.use(express.json());

  app.post('/orders', async (req: Request, res: Response) => {
    const { skuId, quantity } = req.body ?? {};
    if (typeof skuId !== 'string' || skuId.length === 0) {
      return res.status(400).json({ code: 'INVALID_SKU', message: 'skuId 必填' });
    }
    if (!Number.isInteger(quantity) || quantity < 0 || quantity > 99) {
      return res.status(400).json({ code: 'INVALID_QUANTITY', message: 'quantity 须为 1 到 99 的整数' });
    }
    const order = await store.create(skuId, quantity);
    return res.status(200).json(order);
  });

  app.get('/orders/:id', async (req: Request, res: Response) => {
    const order = await store.find(req.params.id);
    if (!order) {
      return res.status(404).json({ code: 'ORDER_NOT_FOUND', message: '订单不存在' });
    }
    return res.json(order);
  });

  return app;
}
