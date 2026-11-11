// read-dsh-session.mjs
// 用途：把 DeepSeek Harness 的 zstd 会话记录（session.vN.jsonl.zstd）解成明文 JSONL，供 Sync-Chat.ps1 读取。
// 输入：node read-dsh-session.mjs <压缩记录路径> <明文输出路径>
// 输出：只写输出文件，成功时 stdout 不输出任何内容；出错信息写 stderr。
// 退出码：0 成功；1 参数有误；2 读不了、不是 zstd 记录，或当前 Node 不支持 zstd（需要 22.15 或更新版本）。
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import zlib from 'node:zlib';

function fail(code, message) {
    process.stderr.write(`read-dsh-session: ${message}\n`);
    process.exit(code);
}

const [input, output] = process.argv.slice(2);
if (!input || !output) fail(1, '用法：node read-dsh-session.mjs <session.vN.jsonl.zstd> <输出.jsonl>');
if (typeof zlib.zstdDecompressSync !== 'function') fail(2, `当前 Node ${process.version} 不支持 zstd，需要 22.15 或更新版本`);

const ZSTD_MAGIC = 0xfd2fb528;

// dsh 每批事件追加一个独立的 zstd 帧。宿主可能正在写最后一帧，这里只按帧头和块头
// 找出完整的帧（与 dsh 自己的修复逻辑一致），不完整的尾帧丢掉，下次同步再读。
function completeFrames(buffer) {
    const frames = [];
    let offset = 0;
    while (offset < buffer.length) {
        const start = offset;
        if (buffer.length - offset < 5) break;
        if (buffer.readUInt32LE(offset) !== ZSTD_MAGIC) throw new Error(`第 ${offset} 字节处不是 zstd 帧`);
        offset += 4;
        const descriptor = buffer.readUInt8(offset);
        offset += 1;
        const contentSizeFlag = descriptor >>> 6;
        const singleSegment = (descriptor & 32) !== 0;
        const checksum = (descriptor & 4) !== 0;
        const dictionaryFlag = descriptor & 3;
        const dictionaryBytes = dictionaryFlag === 3 ? 4 : dictionaryFlag;
        const contentSizeBytes = contentSizeFlag === 0 ? (singleSegment ? 1 : 0) : 1 << contentSizeFlag;
        offset += (singleSegment ? 0 : 1) + dictionaryBytes + contentSizeBytes;
        let complete = false;
        while (offset + 3 <= buffer.length) {
            const blockHeader = buffer.readUIntLE(offset, 3);
            offset += 3;
            const blockType = (blockHeader >>> 1) & 3;
            if (blockType === 3) throw new Error(`第 ${offset - 3} 字节处的 zstd 块类型无效`);
            offset += blockType === 1 ? 1 : blockHeader >>> 3;
            if (offset > buffer.length) break;
            if (blockHeader & 1) {
                complete = true;
                break;
            }
        }
        if (complete && checksum) offset += 4;
        if (!complete || offset > buffer.length) break;
        frames.push(buffer.subarray(start, offset));
    }
    return frames;
}

let buffer;
try {
    buffer = readFileSync(input);
} catch (error) {
    fail(2, `读不了 ${input}：${error.message}`);
}

let text;
try {
    text = Buffer.concat(completeFrames(buffer).map((frame) => zlib.zstdDecompressSync(frame)));
} catch (error) {
    fail(2, `解不开 ${input}：${error.message}`);
}

try {
    mkdirSync(dirname(output), { recursive: true });
    writeFileSync(output, text);
} catch (error) {
    fail(2, `写不了 ${output}：${error.message}`);
}
