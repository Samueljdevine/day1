// Generates flat PNG icons (a white "1" on the dark theme background) with no
// dependencies: raw RGBA -> zlib -> PNG. Run with `npm run icons`.
import { deflateSync } from 'node:zlib';
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const BG = [0x0f, 0x11, 0x15];
const FG = [0xff, 0xff, 0xff];
const SUPERSAMPLE = 4;

// Numeral "1" as a polygon in unit coordinates (x right, y down).
const ONE = [
  [0.47, 0.20], [0.61, 0.20], [0.61, 0.80], [0.47, 0.80],
  [0.47, 0.35], [0.36, 0.44], [0.285, 0.35],
];

function pointInPolygon(x, y, poly) {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, yi] = poly[i];
    const [xj, yj] = poly[j];
    if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}

const CRC_TABLE = new Uint32Array(256).map((_, n) => {
  let c = n;
  for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});

function crc32(buf) {
  let c = 0xffffffff;
  for (const b of buf) c = CRC_TABLE[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const typeBuf = Buffer.from(type, 'ascii');
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])));
  return Buffer.concat([len, typeBuf, data, crc]);
}

function encodePng(width, height, rgb) {
  const raw = Buffer.alloc((width * 3 + 1) * height);
  for (let y = 0; y < height; y += 1) {
    raw[y * (width * 3 + 1)] = 0; // filter: none
    rgb.copy(raw, y * (width * 3 + 1) + 1, y * width * 3, (y + 1) * width * 3);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 2; // colour type RGB
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

function renderIcon(size, scale = 1) {
  const rgb = Buffer.alloc(size * size * 3);
  const ss = SUPERSAMPLE;
  for (let y = 0; y < size; y += 1) {
    for (let x = 0; x < size; x += 1) {
      let hits = 0;
      for (let sy = 0; sy < ss; sy += 1) {
        for (let sx = 0; sx < ss; sx += 1) {
          // Map pixel sample to unit square, then shrink the glyph around the centre by `scale`.
          const ux = (x + (sx + 0.5) / ss) / size;
          const uy = (y + (sy + 0.5) / ss) / size;
          const gx = (ux - 0.5) / scale + 0.5;
          const gy = (uy - 0.5) / scale + 0.5;
          if (pointInPolygon(gx, gy, ONE)) hits += 1;
        }
      }
      const a = hits / (ss * ss);
      const i = (y * size + x) * 3;
      for (let c = 0; c < 3; c += 1) rgb[i + c] = Math.round(BG[c] + (FG[c] - BG[c]) * a);
    }
  }
  return encodePng(size, size, rgb);
}

const out = join(dirname(fileURLToPath(import.meta.url)), '..', 'public');
mkdirSync(out, { recursive: true });

const files = [
  ['icon-192.png', 192, 1],
  ['icon-512.png', 512, 1],
  ['icon-512-maskable.png', 512, 0.8], // keep the glyph inside the maskable safe zone
  ['apple-touch-icon.png', 180, 1],
  // Native iOS app icon (single 1024px image, iOS 17+ asset catalog).
  ['../ios/Day1/Assets.xcassets/AppIcon.appiconset/AppIcon.png', 1024, 1],
];
for (const [name, size, scale] of files) {
  const png = renderIcon(size, scale);
  writeFileSync(join(out, name), png);
  console.log(`${name}  ${size}x${size}  ${png.length} bytes`);
}

const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
<rect width="100" height="100" fill="#0f1115"/>
<polygon fill="#fff" points="${ONE.map(([x, y]) => `${(x * 100).toFixed(1)},${(y * 100).toFixed(1)}`).join(' ')}"/>
</svg>
`;
writeFileSync(join(out, 'icon.svg'), svg);
console.log('icon.svg');
