/**
 * localStorage persistence. Every read and write is guarded so a blocked or
 * full storage (private browsing) never breaks the clock display.
 *
 * Keys:
 *   top3:<YYYY-MM-DD>            JSON [{ text, done } x3]
 *   learn:<YYYY-MM-DD>           string
 *   done:<YYYY-MM-DD>:<block>    "1"
 *   setting:<name>               string
 */

export interface Top3Item {
  text: string;
  done: boolean;
}

function read(key: string): string | null {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

function write(key: string, value: string): void {
  try {
    localStorage.setItem(key, value);
  } catch {
    /* ignore */
  }
}

function remove(key: string): void {
  try {
    localStorage.removeItem(key);
  } catch {
    /* ignore */
  }
}

function allKeys(): string[] {
  try {
    const keys: string[] = [];
    for (let i = 0; i < localStorage.length; i += 1) {
      const k = localStorage.key(i);
      if (k) keys.push(k);
    }
    return keys;
  } catch {
    return [];
  }
}

const emptyTop3 = (): Top3Item[] => [
  { text: '', done: false },
  { text: '', done: false },
  { text: '', done: false },
];

export function getTop3(dateKey: string): Top3Item[] {
  const raw = read(`top3:${dateKey}`);
  if (!raw) return emptyTop3();
  try {
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) return emptyTop3();
    const items = emptyTop3();
    for (let i = 0; i < 3; i += 1) {
      const p = parsed[i] as Partial<Top3Item> | undefined;
      if (p && typeof p === 'object') {
        items[i] = { text: typeof p.text === 'string' ? p.text : '', done: p.done === true };
      }
    }
    return items;
  } catch {
    return emptyTop3();
  }
}

export function setTop3(dateKey: string, items: Top3Item[]): void {
  write(`top3:${dateKey}`, JSON.stringify(items.slice(0, 3)));
}

export function getLearn(dateKey: string): string {
  return read(`learn:${dateKey}`) ?? '';
}

export function setLearn(dateKey: string, text: string): void {
  if (text.trim() === '') remove(`learn:${dateKey}`);
  else write(`learn:${dateKey}`, text);
}

export function hasLearnEntry(dateKey: string): boolean {
  return getLearn(dateKey).trim() !== '';
}

export function isBlockDone(dateKey: string, blockNumber: number): boolean {
  return read(`done:${dateKey}:${blockNumber}`) === '1';
}

export function setBlockDone(dateKey: string, blockNumber: number, done: boolean): void {
  const key = `done:${dateKey}:${blockNumber}`;
  if (done) write(key, '1');
  else remove(key);
}

/** Clears the block checkboxes and the top-3 done ticks for the day. Keeps the text. */
export function resetDay(dateKey: string): void {
  for (const key of allKeys()) {
    if (key.startsWith(`done:${dateKey}:`)) remove(key);
  }
  const top3 = getTop3(dateKey);
  if (top3.some((t) => t.done)) {
    setTop3(
      dateKey,
      top3.map((t) => ({ ...t, done: false })),
    );
  }
}

export function getSetting(name: string): string | null {
  return read(`setting:${name}`);
}

export function setSetting(name: string, value: string | null): void {
  if (value === null) remove(`setting:${name}`);
  else write(`setting:${name}`, value);
}
