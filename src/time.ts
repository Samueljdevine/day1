/**
 * Pure time logic. No DOM, no storage, no side effects.
 * Everything works on the device's local wall clock via the local Date getters.
 */
import {
  BLOCKS,
  EVERY_SECOND_DAY_BLOCK,
  EXTENDED_BLOCK,
  EXTENDED_TITLE,
  LIGHTS_OUT,
  PROGRAM_DAYS,
  PROGRAM_START,
  WAKE,
  type Category,
} from './schedule';

export interface Block {
  /** Block number from the schedule table. 0 for the Sleep state. */
  number: number;
  title: string;
  category: Category;
  note: string;
  /** Local start instant. */
  start: Date;
  /** Local end instant (exclusive). */
  end: Date;
  /** "HH:MM" */
  startLabel: string;
  /** "HH:MM" */
  endLabel: string;
  isSleep: boolean;
}

export type ProgramStatus = 'before' | 'active' | 'after';

const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTH_NAMES = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

const pad2 = (n: number): string => String(n).padStart(2, '0');

/** Parse "HH:MM" into hours and minutes. */
export function parseHM(hm: string): { h: number; m: number } {
  const [h, m] = hm.split(':').map(Number);
  return { h, m };
}

/** Local midnight of the given date. */
export function startOfDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate(), 0, 0, 0, 0);
}

/** Local midnight, n calendar days away. Safe across clock changes. */
export function addDays(date: Date, n: number): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() + n, 0, 0, 0, 0);
}

/** The instant "HH:MM" on the same local calendar date as `date`. */
export function atTime(date: Date, hm: string): Date {
  const { h, m } = parseHM(hm);
  return new Date(date.getFullYear(), date.getMonth(), date.getDate(), h, m, 0, 0);
}

/** "YYYY-MM-DD" using the local calendar date. Used for storage keys. */
export function toDateKey(date: Date): string {
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
}

/** "HH:MM" local. */
export function formatHM(date: Date): string {
  return `${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
}

/**
 * Whole calendar days from `a` to `b`, comparing year/month/day only.
 * Uses Date.UTC on the local components so DST days (23 or 25 hours) count as exactly one day.
 */
export function daysBetween(a: Date, b: Date): number {
  const ua = Date.UTC(a.getFullYear(), a.getMonth(), a.getDate());
  const ub = Date.UTC(b.getFullYear(), b.getMonth(), b.getDate());
  return Math.round((ub - ua) / 86_400_000);
}

function programStartDate(): Date {
  return new Date(PROGRAM_START.year, PROGRAM_START.month - 1, PROGRAM_START.day);
}

/** 1 on the first program day. 0 the day before, 93 the day after the last day. */
export function getDayNumber(date: Date): number {
  return daysBetween(programStartDate(), date) + 1;
}

export function getProgramStatus(date: Date): ProgramStatus {
  const n = getDayNumber(date);
  if (n < 1) return 'before';
  if (n > PROGRAM_DAYS) return 'after';
  return 'active';
}

/** Block 10 (Ironman prep) is active on odd program days: 1, 3, 5, ... */
export function isEverySecondDayBlockActive(date: Date): boolean {
  return getDayNumber(date) % 2 !== 0;
}

/** All blocks for the local calendar date of `date`, in order, with real start/end instants. */
export function getBlocksForDate(date: Date): Block[] {
  const includeAlternate = isEverySecondDayBlockActive(date);
  const alternateDef = BLOCKS.find((b) => b.number === EVERY_SECOND_DAY_BLOCK);
  const blocks: Block[] = [];

  for (const def of BLOCKS) {
    if (def.number === EVERY_SECOND_DAY_BLOCK && !includeAlternate) continue;

    let title = def.title;
    let end = def.end;
    if (def.number === EXTENDED_BLOCK && !includeAlternate && alternateDef) {
      title = EXTENDED_TITLE;
      end = alternateDef.end;
    }

    blocks.push({
      number: def.number,
      title,
      category: def.category,
      note: def.note,
      start: atTime(date, def.start),
      end: atTime(date, end),
      startLabel: def.start,
      endLabel: end,
      isSleep: false,
    });
  }
  return blocks;
}

/** The Sleep pseudo-block that contains (or follows) `now`. */
export function getSleepBlock(now: Date): Block {
  const wakeToday = atTime(now, WAKE);
  let start: Date;
  let end: Date;
  if (now.getTime() < wakeToday.getTime()) {
    start = atTime(addDays(now, -1), LIGHTS_OUT);
    end = wakeToday;
  } else {
    start = atTime(now, LIGHTS_OUT);
    end = atTime(addDays(now, 1), WAKE);
  }
  return {
    number: 0,
    title: 'Sleep',
    category: 'rest',
    note: `Lights out ${LIGHTS_OUT}. Wake ${WAKE}.`,
    start,
    end,
    startLabel: LIGHTS_OUT,
    endLabel: WAKE,
    isSleep: true,
  };
}

/**
 * The block containing `now` (start <= now < end), or the Sleep block when
 * `now` is outside every block for the day.
 */
export function getCurrentBlock(blocks: Block[], now: Date): Block {
  const t = now.getTime();
  const found = blocks.find((b) => b.start.getTime() <= t && t < b.end.getTime());
  return found ?? getSleepBlock(now);
}

/**
 * The next block that starts after `now`. After the last block it is Sleep;
 * after lights out it is the first block of the following day.
 */
export function getNextBlock(blocks: Block[], now: Date): Block {
  const t = now.getTime();
  const found = blocks.find((b) => b.start.getTime() > t);
  if (found) return found;

  const last = blocks[blocks.length - 1];
  if (last && t < last.end.getTime()) return getSleepBlock(now);

  const tomorrow = getBlocksForDate(addDays(now, 1));
  return tomorrow[0] ?? getSleepBlock(now);
}

export function getRemainingMs(block: Block, now: Date): number {
  return Math.max(0, block.end.getTime() - now.getTime());
}

/** Elapsed fraction 0..1 of the block at `now`. */
export function getProgress(block: Block, now: Date): number {
  const total = block.end.getTime() - block.start.getTime();
  if (total <= 0) return 1;
  const elapsed = now.getTime() - block.start.getTime();
  return Math.min(1, Math.max(0, elapsed / total));
}

/** "1:23:45" at or over one hour, "23:45" under. Rounds up to the next whole second. */
export function formatRemaining(ms: number): string {
  const total = Math.max(0, Math.ceil(ms / 1000));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  return h > 0 ? `${h}:${pad2(m)}:${pad2(s)}` : `${pad2(m)}:${pad2(s)}`;
}

/**
 * Consecutive calendar days with a learning entry, ending today or yesterday.
 * `hasEntry` is called with "YYYY-MM-DD" keys.
 */
export function getLearningStreak(hasEntry: (dateKey: string) => boolean, today: Date): number {
  let day = startOfDay(today);
  if (!hasEntry(toDateKey(day))) {
    day = addDays(day, -1);
    if (!hasEntry(toDateKey(day))) return 0;
  }
  let streak = 0;
  while (hasEntry(toDateKey(day)) && streak < 10_000) {
    streak += 1;
    day = addDays(day, -1);
  }
  return streak;
}

/** "Thu 1 Oct" */
export function formatHeaderDate(date: Date): string {
  return `${DAY_NAMES[date.getDay()]} ${date.getDate()} ${MONTH_NAMES[date.getMonth()]}`;
}

/** "Day 12 of 92", "Program starts 1 Oct" or "Program complete". */
export function formatProgramDay(date: Date): string {
  const status = getProgramStatus(date);
  if (status === 'before') {
    return `Program starts ${PROGRAM_START.day} ${MONTH_NAMES[PROGRAM_START.month - 1]}`;
  }
  if (status === 'after') return 'Program complete';
  return `Day ${getDayNumber(date)} of ${PROGRAM_DAYS}`;
}

/** "06 · CrossFit" */
export function formatBlockTitle(block: Block): string {
  return block.isSleep ? block.title : `${pad2(block.number)} · ${block.title}`;
}
