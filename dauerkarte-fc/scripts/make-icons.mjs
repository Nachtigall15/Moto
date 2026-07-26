// Generates simple placeholder PNG icons (solid FC-red background, white "FC" monogram
// drawn from rectangles) for the PWA manifest. Run once with `node scripts/make-icons.mjs`.
import { deflateSync } from 'node:zlib';
import { writeFileSync } from 'node:fs';

const RED = [0xe3, 0x06, 0x13];
const WHITE = [0xff, 0xff, 0xff];

function crc32(buf) {
  let c;
  const table = crc32.table || (crc32.table = (() => {
    const t = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
      c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      t[n] = c;
    }
    return t;
  })());
  let crc = 0xffffffff;
  for (let i = 0; i < buf.length; i++) crc = table[(crc ^ buf[i]) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, 'ascii');
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([len, typeBuf, data, crcBuf]);
}

function makePng(size, drawPixel) {
  const width = size;
  const height = size;
  const raw = Buffer.alloc((width * 3 + 1) * height);
  let offset = 0;
  for (let y = 0; y < height; y++) {
    raw[offset++] = 0; // filter type: none
    for (let x = 0; x < width; x++) {
      const [r, g, b] = drawPixel(x, y);
      raw[offset++] = r;
      raw[offset++] = g;
      raw[offset++] = b;
    }
  }
  const idat = deflateSync(raw);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 2; // color type: RGB
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;

  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  return Buffer.concat([
    signature,
    chunk('IHDR', ihdr),
    chunk('IDAT', idat),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

// Simple "FC" monogram built from block letters on a red field, with safe padding
// for maskable icons (content kept within the inner ~80% circle).
function pixelFor(size, maskable) {
  const pad = maskable ? size * 0.12 : size * 0.08;
  return (x, y) => {
    const cx = size / 2;
    const cy = size / 2;
    const s = size - pad * 2;
    const left = pad;
    const top = pad;

    // letter grid: 5 cols x 7 rows per letter, two letters "F" "C"
    const cell = s / 12;
    const gx = (x - left) / cell;
    const gy = (y - top) / cell;

    if (gx < 0 || gy < 0 || gx >= 12 || gy >= 7) return RED;

    const col = Math.floor(gx);
    const row = Math.floor(gy);

    // "F" occupies cols 0-4, "C" occupies cols 6-11 (col 5 = gap)
    const F = [
      [1, 1, 1, 1, 1],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 1, 1, 1, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
    ];
    const C = [
      [0, 1, 1, 1, 1, 1],
      [1, 0, 0, 0, 0, 0],
      [1, 0, 0, 0, 0, 0],
      [1, 0, 0, 0, 0, 0],
      [1, 0, 0, 0, 0, 0],
      [1, 0, 0, 0, 0, 0],
      [0, 1, 1, 1, 1, 1],
    ];

    if (col < 5) {
      if (F[row][col]) return WHITE;
    } else if (col >= 6 && col < 12) {
      if (C[row][col - 6]) return WHITE;
    }
    void cx;
    void cy;
    return RED;
  };
}

const outDir = new URL('../public/icons/', import.meta.url);

for (const size of [192, 512]) {
  writeFileSync(new URL(`icon-${size}.png`, outDir), makePng(size, pixelFor(size, false)));
  writeFileSync(new URL(`icon-${size}-maskable.png`, outDir), makePng(size, pixelFor(size, true)));
}

console.log('Icons generated.');
