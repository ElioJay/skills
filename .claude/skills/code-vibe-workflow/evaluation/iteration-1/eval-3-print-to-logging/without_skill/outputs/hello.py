import logging
from pathlib import Path

# 使用文件名（不含扩展名）作为 logger 名称
logger = logging.getLogger(Path(__file__).stem)

# 配置日志输出级别为 INFO
logging.basicConfig(level=logging.INFO)

# 使用 logger 输出 INFO 级别日志，替代原来的 print
logger.info('hello world')
