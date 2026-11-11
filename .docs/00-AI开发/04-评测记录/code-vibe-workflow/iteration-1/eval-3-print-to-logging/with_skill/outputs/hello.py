import logging
from pathlib import Path

# 用文件名（不含扩展名）作为 logger 名，满足"logger 名用文件名"的要求
logger = logging.getLogger(Path(__file__).stem)
# 配置 INFO 级别输出，确保 INFO 日志可见
logging.basicConfig(level=logging.INFO)

logger.info('hello world')
