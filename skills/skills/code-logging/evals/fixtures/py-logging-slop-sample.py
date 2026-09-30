"""Order service — logging fixture."""

import asyncio
import contextvars
import json
import logging
from concurrent.futures import ThreadPoolExecutor

import httpx

logger = logging.getLogger(__name__)
audit_logger = logging.getLogger("audit")

trace_id_var: contextvars.ContextVar[str] = contextvars.ContextVar("trace_id", default="-")


class TraceFilter(logging.Filter):
    """Already wired into the root handler; the formatter emits %(trace_id)s."""

    def filter(self, record):
        record.trace_id = trace_id_var.get()
        return True


executor = ThreadPoolExecutor(max_workers=8)


def create_order(req):
    logger.info("进入 create_order")

    if not req.get("order_no"):
        logger.error(f"参数不合法: {req}")
        raise ValueError("order_no required")

    user = user_client.get(req["user_id"])
    logger.info("用户信息 user=%s", user)
    logger.info(f"手机号 {user.mobile} 校验通过")

    resp = pay_gateway.pay(req["order_no"], req["amount"])

    if resp.success:
        logger.info("done")
        audit_logger.info("ORDER_CREATED|%s|%s|%s", req["order_no"], req["user_id"], req["amount"])

    for item in req["items"]:
        logger.info(f"处理商品 {item['sku_id']}")
        stock_client.deduct(item["sku_id"], item["quantity"])

    logger.debug("订单请求体 payload=%s", json.dumps(req))

    return {"order_no": req["order_no"], "trade_no": resp.trade_no}


def refund(order_no):
    try:
        pay_gateway.refund(order_no)
    except PayError as e:
        logger.error("退款失败 order_no=%s", order_no, exc_info=True)
        raise
    except Exception as e:
        logger.error(f"退款异常: {e}")


def sync_status(order_no):
    try:
        remote = pay_gateway.query_status(order_no)
        cache.set(order_no, remote)
    except Exception:
        pass


def cleanup_expired():
    try:
        cache.evict_expired()
    except Exception as e:
        print("cleanup failed", e)


def push_downstream(order_no):
    """Submitted to a thread pool — the trace_id contextvar does not cross the handoff."""
    executor.submit(_do_push, order_no)


def _do_push(order_no):
    logger.info("下游推送开始 order_no=%s", order_no)
    downstream.push(order_no)


async def refresh_quotes(order_nos):
    """asyncio tasks DO inherit contextvars — this one is fine as-is."""
    tasks = [asyncio.create_task(_refresh_one(n)) for n in order_nos]
    await asyncio.gather(*tasks)


async def _refresh_one(order_no):
    logger.info("行情刷新 order_no=%s", order_no)
    async with httpx.AsyncClient() as client:
        await client.get(f"https://quotes.internal/{order_no}")


def reconcile_daily():
    pending = pay_gateway.list_pending()
    for order_no in pending:
        pay_gateway.reconcile(order_no)


def on_login(user_id, token):
    logger.debug("登录成功 user_id=%s token=%s", user_id, token)
