import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  formatBlockTitle,
  formatHeaderDate,
  formatProgramDay,
  formatRemaining,
  getBlocksForDate,
  getCurrentBlock,
  getDayNumber,
  getLearningStreak,
  getNextBlock,
  getProgramStatus,
  toDateKey,
} from '../src/time';
import { EXTENDED_TITLE } from '../src/schedule';

// Minimal Node global so the build type-check passes without @types/node.
declare const process: { env: Record<string, string | undefined> };

/** Runs a group of tests with the process timezone switched. Node re-reads TZ on assignment. */
function inZone(tz: string, fn: () => void): void {
  describe(`in ${tz}`, () => {
    let previous: string | undefined;
    beforeAll(() => {
      previous = process.env.TZ;
      process.env.TZ = tz;
    });
    afterAll(() => {
      if (previous === undefined) delete process.env.TZ;
      else process.env.TZ = previous;
    });
    fn();
  });
}

const local = (y: number, m: number, d: number, hh = 0, mm = 0, ss = 0): Date =>
  new Date(y, m - 1, d, hh, mm, ss, 0);

const numbers = (date: Date): number[] => getBlocksForDate(date).map((b) => b.number);

// ---------------------------------------------------------------------------

inZone('Europe/Dublin', () => {
  it('the clocks go back on 25 October 2026 (sanity check that TZ applies)', () => {
    const hours = (local(2026, 10, 26).getTime() - local(2026, 10, 25).getTime()) / 3_600_000;
    expect(hours).toBe(25);
  });

  it('counts day numbers by calendar date across the clock change', () => {
    expect(getDayNumber(local(2026, 10, 5))).toBe(1);
    expect(getDayNumber(local(2026, 10, 24, 23, 59, 59))).toBe(20);
    expect(getDayNumber(local(2026, 10, 25, 0, 30))).toBe(21);
    expect(getDayNumber(local(2026, 10, 25, 12))).toBe(21);
    expect(getDayNumber(local(2026, 10, 25, 23, 59, 59))).toBe(21);
    expect(getDayNumber(local(2026, 10, 26, 0, 0, 0))).toBe(22);
    expect(getDayNumber(local(2026, 10, 26, 12))).toBe(22);
    expect(getDayNumber(local(2026, 12, 31))).toBe(88);
    expect(getDayNumber(local(2027, 1, 12, 23, 59, 59))).toBe(100);
  });

  it('keeps the odd/even rule intact around the clock change', () => {
    expect(numbers(local(2026, 10, 25, 12))).toContain(10); // day 21, odd
    expect(numbers(local(2026, 10, 26, 12))).not.toContain(10); // day 22, even
    expect(numbers(local(2026, 10, 27, 12))).toContain(10); // day 23, odd
  });

  it('blocks on the clock-change day still start at local wall-clock time', () => {
    const blocks = getBlocksForDate(local(2026, 10, 25, 12));
    expect(blocks[0].start.getHours()).toBe(5);
    expect(blocks[0].start.getMinutes()).toBe(0);
    expect(blocks[blocks.length - 1].end.getHours()).toBe(22);
    const crossfit = blocks.find((b) => b.number === 6)!;
    expect(crossfit.start.getHours()).toBe(10);
    expect(crossfit.start.getMinutes()).toBe(30);
  });
});

inZone('America/Toronto', () => {
  it('the clocks go back on 1 November 2026 (sanity check that TZ applies)', () => {
    const hours = (local(2026, 11, 2).getTime() - local(2026, 11, 1).getTime()) / 3_600_000;
    expect(hours).toBe(25);
  });

  it('counts day numbers by calendar date across the clock change', () => {
    expect(getDayNumber(local(2026, 10, 31, 23, 59, 59))).toBe(27);
    expect(getDayNumber(local(2026, 11, 1, 0, 0, 0))).toBe(28);
    expect(getDayNumber(local(2026, 11, 1, 1, 30))).toBe(28);
    expect(getDayNumber(local(2026, 11, 1, 23, 59, 59))).toBe(28);
    expect(getDayNumber(local(2026, 11, 2, 0, 0, 0))).toBe(29);
    expect(getDayNumber(local(2026, 11, 2, 12))).toBe(29);
    expect(getDayNumber(local(2026, 12, 31, 23, 59, 59))).toBe(88);
    expect(getDayNumber(local(2027, 1, 12, 12))).toBe(100);
  });

  it('keeps the odd/even rule intact around the clock change', () => {
    expect(numbers(local(2026, 10, 31, 12))).toContain(10); // day 27
    expect(numbers(local(2026, 11, 1, 12))).not.toContain(10); // day 28
    expect(numbers(local(2026, 11, 2, 12))).toContain(10); // day 29
  });
});

inZone('Asia/Bangkok', () => {
  it('has no clock change and the same day numbers', () => {
    const hours = (local(2026, 10, 26).getTime() - local(2026, 10, 25).getTime()) / 3_600_000;
    expect(hours).toBe(24);
    expect(getDayNumber(local(2026, 10, 25))).toBe(21);
    expect(getDayNumber(local(2026, 11, 1))).toBe(28);
  });
});

// ---------------------------------------------------------------------------

inZone('Europe/Dublin', () => {
  describe('program window', () => {
    it('reports before / active / after', () => {
      expect(getProgramStatus(local(2026, 10, 4, 23, 59, 59))).toBe('before');
      expect(getProgramStatus(local(2026, 10, 5))).toBe('active');
      expect(getProgramStatus(local(2027, 1, 12, 23, 59, 59))).toBe('active');
      expect(getProgramStatus(local(2027, 1, 13))).toBe('after');
    });

    it('formats the header', () => {
      expect(formatHeaderDate(local(2026, 10, 5))).toBe('Mon 5 Oct');
      expect(formatHeaderDate(local(2027, 1, 12))).toBe('Tue 12 Jan');
      expect(formatProgramDay(local(2026, 10, 5))).toBe('Day 1 of 100');
      expect(formatProgramDay(local(2027, 1, 12))).toBe('Day 100 of 100');
      expect(formatProgramDay(local(2026, 10, 4))).toBe('Program starts 5 Oct');
      expect(formatProgramDay(local(2027, 1, 13))).toBe('Program complete');
    });

    it('still builds a routine outside the program window', () => {
      expect(getBlocksForDate(local(2026, 10, 4)).length).toBeGreaterThan(0);
      expect(getBlocksForDate(local(2027, 1, 13)).length).toBeGreaterThan(0);
    });
  });

  describe('odd and even days', () => {
    it('day 1 (odd) has all 14 blocks including Ironman prep', () => {
      expect(numbers(local(2026, 10, 5))).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]);
      const b9 = getBlocksForDate(local(2026, 10, 5)).find((b) => b.number === 9)!;
      expect(b9.title).toBe('Deep work 3 - Sink as the operator');
      expect(b9.endLabel).toBe('17:15');
    });

    it('day 2 (even) drops block 10 and extends block 9 to 18:30', () => {
      const blocks = getBlocksForDate(local(2026, 10, 6));
      expect(blocks.map((b) => b.number)).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14]);
      const b9 = blocks.find((b) => b.number === 9)!;
      expect(b9.title).toBe(EXTENDED_TITLE);
      expect(b9.startLabel).toBe('15:30');
      expect(b9.endLabel).toBe('18:30');
      expect(b9.end.getHours()).toBe(18);
      expect(b9.end.getMinutes()).toBe(30);
      const b11 = blocks.find((b) => b.number === 11)!;
      expect(b11.startLabel).toBe('18:30');
    });

    it('counts by program day, not by odd calendar date', () => {
      expect(numbers(local(2026, 10, 5))).toContain(10); // day 1
      expect(numbers(local(2026, 10, 6))).not.toContain(10); // day 2
      expect(numbers(local(2026, 11, 1))).not.toContain(10); // 1 Nov is day 28
      expect(numbers(local(2026, 11, 2))).toContain(10); // 2 Nov is day 29
      expect(numbers(local(2027, 1, 12))).not.toContain(10); // day 100
    });

    it('block 9 is the current block at 18:00 on an even day', () => {
      const now = local(2026, 10, 6, 18, 0, 0);
      const cur = getCurrentBlock(getBlocksForDate(now), now);
      expect(cur.number).toBe(9);
      expect(cur.title).toBe(EXTENDED_TITLE);
    });

    it('block 10 is the current block at 18:00 on an odd day', () => {
      const now = local(2026, 10, 7, 18, 0, 0);
      expect(getCurrentBlock(getBlocksForDate(now), now).number).toBe(10);
    });
  });

  describe('sleep state', () => {
    const at = (hh: number, mm: number, ss: number, day = 10) => {
      const now = local(2026, 10, day, hh, mm, ss);
      return getCurrentBlock(getBlocksForDate(now), now);
    };

    it('is Sleep from 22:00:00', () => {
      const b = at(22, 0, 0);
      expect(b.isSleep).toBe(true);
      expect(b.title).toBe('Sleep');
      expect(b.number).toBe(0);
      expect(b.end.getTime()).toBe(local(2026, 10, 11, 5, 0, 0).getTime());
    });

    it('is Sleep at 23:59:59 counting down to 05:00 tomorrow', () => {
      const b = at(23, 59, 59);
      expect(b.isSleep).toBe(true);
      expect(b.endLabel).toBe('05:00');
      expect(b.end.getTime()).toBe(local(2026, 10, 11, 5, 0, 0).getTime());
    });

    it('is Sleep at 00:00:00 counting down to 05:00 today', () => {
      const b = at(0, 0, 0, 11);
      expect(b.isSleep).toBe(true);
      expect(b.end.getTime()).toBe(local(2026, 10, 11, 5, 0, 0).getTime());
      expect(b.start.getTime()).toBe(local(2026, 10, 10, 22, 0, 0).getTime());
    });

    it('is Sleep at 04:59:59 and block 1 at 05:00:00', () => {
      expect(at(4, 59, 59).isSleep).toBe(true);
      const wake = at(5, 0, 0);
      expect(wake.isSleep).toBe(false);
      expect(wake.number).toBe(1);
    });

    it('is block 14 at 21:59:59', () => {
      const b = at(21, 59, 59);
      expect(b.number).toBe(14);
      expect(b.isSleep).toBe(false);
    });

    it('formats the Sleep title without a number', () => {
      expect(formatBlockTitle(at(23, 0, 0))).toBe('Sleep');
      expect(formatBlockTitle(at(11, 0, 0))).toBe('06 · CrossFit');
    });
  });

  describe('exact boundaries', () => {
    const at = (hh: number, mm: number, ss: number) => {
      const now = local(2026, 10, 1, hh, mm, ss);
      return getCurrentBlock(getBlocksForDate(now), now).number;
    };

    it('10:29:59 is block 5, 10:30:00 is block 6', () => {
      expect(at(10, 29, 59)).toBe(5);
      expect(at(10, 30, 0)).toBe(6);
    });

    it('19:14:59 is block 11, 19:15:00 is block 12', () => {
      expect(at(19, 14, 59)).toBe(11);
      expect(at(19, 15, 0)).toBe(12);
    });

    it('19:59:59 is block 12, 20:00:00 is block 13', () => {
      expect(at(19, 59, 59)).toBe(12);
      expect(at(20, 0, 0)).toBe(13);
    });

    it('a block with 999ms left is still that block', () => {
      const now = new Date(local(2026, 10, 1, 10, 29, 59).getTime() + 999);
      expect(getCurrentBlock(getBlocksForDate(now), now).number).toBe(5);
    });
  });

  describe('next block', () => {
    const nextAt = (hh: number, mm: number, day = 1) => {
      const now = local(2026, 10, day, hh, mm, 0);
      return getNextBlock(getBlocksForDate(now), now);
    };

    it('is the following block during the day', () => {
      const n = nextAt(12, 0);
      expect(n.number).toBe(7);
      expect(n.startLabel).toBe('12:30');
      expect(n.title).toBe('Calls + partners');
    });

    it('is Sleep at 22:00 during wind down', () => {
      const n = nextAt(21, 30);
      expect(n.isSleep).toBe(true);
      expect(n.startLabel).toBe('22:00');
    });

    it("is tomorrow's block 1 after lights out", () => {
      const n = nextAt(23, 0);
      expect(n.number).toBe(1);
      expect(n.start.getTime()).toBe(local(2026, 10, 2, 5, 0, 0).getTime());
    });

    it("is today's block 1 before wake", () => {
      const n = nextAt(3, 0, 2);
      expect(n.number).toBe(1);
      expect(n.start.getTime()).toBe(local(2026, 10, 2, 5, 0, 0).getTime());
    });
  });

  describe('formatRemaining', () => {
    it('shows h:mm:ss at one hour and above', () => {
      expect(formatRemaining(3_600_000)).toBe('1:00:00');
      expect(formatRemaining(5_025_000)).toBe('1:23:45');
      expect(formatRemaining(2 * 3_600_000 + 45 * 60_000)).toBe('2:45:00');
    });

    it('shows mm:ss under an hour', () => {
      expect(formatRemaining(3_599_000)).toBe('59:59');
      expect(formatRemaining(1_425_000)).toBe('23:45');
    });

    it('shows mm:ss under a minute', () => {
      expect(formatRemaining(45_000)).toBe('00:45');
      expect(formatRemaining(1_000)).toBe('00:01');
    });

    it('rounds up partial seconds and never goes negative', () => {
      expect(formatRemaining(500)).toBe('00:01');
      expect(formatRemaining(0)).toBe('00:00');
      expect(formatRemaining(-5_000)).toBe('00:00');
    });
  });

  describe('learning streak', () => {
    const today = local(2026, 10, 20, 19, 30);
    const key = (daysAgo: number) => toDateKey(local(2026, 10, 20 - daysAgo));
    const streakWith = (...daysAgo: number[]) => {
      const set = new Set(daysAgo.map(key));
      return getLearningStreak((k) => set.has(k), today);
    };

    it('is 0 with no entries', () => {
      expect(streakWith()).toBe(0);
    });

    it('counts consecutive days ending today', () => {
      expect(streakWith(0)).toBe(1);
      expect(streakWith(0, 1, 2)).toBe(3);
    });

    it('counts consecutive days ending yesterday (today not yet logged)', () => {
      expect(streakWith(1, 2)).toBe(2);
      expect(streakWith(1, 2, 3, 4)).toBe(4);
    });

    it('is 0 when the last entry was two days ago', () => {
      expect(streakWith(2, 3)).toBe(0);
    });

    it('stops at the first gap', () => {
      expect(streakWith(0, 2, 3)).toBe(1);
      expect(streakWith(0, 1, 3)).toBe(2);
    });

    it('counts across the clock change', () => {
      const changeDay = local(2026, 10, 26, 12);
      const set = new Set([toDateKey(local(2026, 10, 26)), toDateKey(local(2026, 10, 25)), toDateKey(local(2026, 10, 24))]);
      expect(getLearningStreak((k) => set.has(k), changeDay)).toBe(3);
    });
  });
});
