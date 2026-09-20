import { AsyncLocalStorage } from 'node:async_hooks';
import pino from 'pino';
import axios from 'axios';
import { Queue } from 'bullmq';

export const als = new AsyncLocalStorage<{ traceId: string }>();

// The mixin is already wired: every line picks traceId out of ALS.
export const logger = pino({
  mixin: () => ({ traceId: als.getStore()?.traceId }),
});

const auditLogger = logger.child({ channel: 'audit' });
const pushQueue = new Queue('order-push');

export async function createOrder(req: OrderRequest): Promise<OrderResult> {
  logger.info('进入 createOrder');

  if (!req.orderNo) {
    logger.error(`参数不合法: ${JSON.stringify(req)}`);
    throw new Error('orderNo required');
  }

  const user = await userClient.get(req.userId);
  logger.info({ user }, '用户信息');

  const resp = await payGateway.pay(req.orderNo, req.amount);

  if (resp.success) {
    logger.info('ok');
    auditLogger.info(
      { orderNo: req.orderNo, userId: req.userId, amount: req.amount },
      'ORDER_CREATED',
    );
  }

  req.items.forEach((item) => {
    logger.info(`处理商品 ${item.skuId}`);
  });
  await stockClient.deductAll(req.items);

  logger.info('订单创建完成', { orderNo: req.orderNo, tradeNo: resp.tradeNo });

  return { orderNo: req.orderNo, tradeNo: resp.tradeNo };
}

export async function refund(orderNo: string): Promise<void> {
  try {
    await payGateway.refund(orderNo);
  } catch (e) {
    logger.error({ err: e, orderNo }, '退款失败');
    throw e;
  }
}

export async function syncStatus(orderNo: string): Promise<void> {
  try {
    const remote = await payGateway.queryStatus(orderNo);
    await cache.set(orderNo, remote);
  } catch (e) {
    logger.error({ error: e }, '同步状态失败');
  }
}

export async function cleanupExpired(): Promise<void> {
  try {
    await cache.evictExpired();
  } catch (e) {
    console.error('cleanup failed', e);
  }
}

// Enqueued to BullMQ — AsyncLocalStorage does not reach the worker process.
export async function pushDownstream(orderNo: string): Promise<void> {
  await pushQueue.add('push', { orderNo });
}

export async function handlePushJob(job: { data: { orderNo: string } }): Promise<void> {
  logger.info({ orderNo: job.data.orderNo }, '下游推送开始');
  await downstream.push(job.data.orderNo);
}

// Builds its own axios call; no trace header goes out.
export async function callPartner(orderNo: string): Promise<void> {
  await axios.get(`https://partner.internal/orders/${orderNo}`);
}

export async function reconcileDaily(): Promise<void> {
  const pending = await payGateway.listPending();
  for (const orderNo of pending) {
    await payGateway.reconcile(orderNo);
  }
}

export function onLogin(userId: string, token: string): void {
  logger.debug({ userId, token }, '登录成功');
}

// Registered at module load; it runs in the registration context, not the emitter's.
orderEmitter.on('paid', (orderNo: string) => {
  logger.info({ orderNo }, '收到支付完成事件');
});
