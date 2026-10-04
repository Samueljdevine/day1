import './styles.css';
import { registerSW } from 'virtual:pwa-register';
import { CATEGORIES, LEARNING_LOG_BLOCK, PROGRAM_DAYS, TOMORROW_TOP3_BLOCK } from './schedule';
import {
  addDays,
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
  getProgress,
  getRemainingMs,
  toDateKey,
  type Block,
} from './time';
import {
  getLearn,
  getSetting,
  getTop3,
  hasLearnEntry,
  isBlockDone,
  resetDay,
  setBlockDone,
  setLearn,
  setSetting,
  setTop3,
} from './storage';
import { getPermission, isSupported as notifySupported, requestPermission, scheduleBlockAlerts } from './notify';

registerSW({ immediate: true });

const URGENT_MS = 5 * 60 * 1000;
const PREVIEW_MS = 5000;

// ---------- DOM ----------
const $ = <T extends HTMLElement = HTMLElement>(id: string): T => {
  const el = document.getElementById(id);
  if (!el) throw new Error(`Missing #${id}`);
  return el as T;
};

const hdrDate = $('hdr-date');
const hdrDay = $('hdr-day');
const programBar = $('program-bar');
const programFill = $('program-fill');
const nowCard = $('now');
const nowCat = $('now-cat');
const nowRange = $('now-range');
const strip = $('strip');
const dayCount = $('day-count');
const nowTitle = $('now-title');
const nowTag = $('now-tag');
const nowCountdown = $('now-countdown');
const nowUntil = $('now-until');
const nowNote = $('now-note');
const nowBar = $('now-bar');
const nextRow = $('next');
const top3Today = $('top3-today');
const top3TomorrowWrap = $('top3-tomorrow-wrap');
const top3Tomorrow = $('top3-tomorrow');
const learnWrap = $('learn-wrap');
const learnInput = $<HTMLInputElement>('learn-input');
const learnStreak = $('learn-streak');
const dayList = $('day-list');
const wakeBtn = $<HTMLButtonElement>('wake-btn');
const alertsBtn = $<HTMLButtonElement>('alerts-btn');
const resetLink = $('reset-link');

// ---------- State ----------
let builtDateKey = '';
let builtTomorrowKey = '';
let builtLearnKey = '';
let lastBlockKey = '';
let lastCountdown = '';
let lastHeader = '';
let previewBlock: Block | null = null;
let previewTimer = 0;
let dayRows = new Map<number, HTMLLIElement>();
let stripSegs: { el: HTMLElement; block: Block }[] = [];
let stripMarker: HTMLElement | null = null;
let stripRange: { start: number; end: number } = { start: 0, end: 1 };
let wakeOn = false;
let wakeLock: WakeLockSentinel | null = null;

// ---------- Render ----------
function render(): void {
  const now = new Date();
  const dateKey = toDateKey(now);
  const blocks = getBlocksForDate(now);
  const live = getCurrentBlock(blocks, now);
  const next = getNextBlock(blocks, now);

  if (dateKey !== builtDateKey) {
    builtDateKey = dateKey;
    buildTop3(top3Today, dateKey);
    buildLearn(dateKey);
    buildDayList(blocks, dateKey);
    buildStrip(blocks);
    renderStreak(now);
  }

  const header = `${formatHeaderDate(now)}|${formatProgramDay(now)}`;
  if (header !== lastHeader) {
    lastHeader = header;
    hdrDate.textContent = formatHeaderDate(now);
    hdrDay.textContent = formatProgramDay(now);
    const active = getProgramStatus(now) === 'active';
    programBar.hidden = !active;
    if (active) programFill.style.width = `${((getDayNumber(now) / PROGRAM_DAYS) * 100).toFixed(1)}%`;
  }

  const blockKey = `${dateKey}:${live.number}:${live.start.getTime()}`;
  if (blockKey !== lastBlockKey) {
    lastBlockKey = blockKey;
    onBlockChange(blocks, live, now);
  }

  renderNow(previewBlock ?? live, live, now);
  renderNext(next);
  updateDayList(live, now);
  updateStrip(live, now);
}

function renderNow(shown: Block, live: Block, now: Date): void {
  const isPreview = shown !== live;
  nowCard.dataset.category = shown.category;
  nowTag.hidden = !isPreview;

  const title = formatBlockTitle(shown);
  if (nowTitle.textContent !== title) nowTitle.textContent = title;
  const cat = shown.isSleep ? 'Sleep' : CATEGORIES[shown.category].label;
  if (nowCat.textContent !== cat) nowCat.textContent = cat;
  const range = `${shown.startLabel}–${shown.endLabel}`;
  if (nowRange.textContent !== range) nowRange.textContent = range;
  if (nowNote.textContent !== shown.note) nowNote.textContent = shown.note;

  let countdown: string;
  let until: string;
  let progress: number;
  let urgent = false;

  if (isPreview) {
    const duration = shown.end.getTime() - shown.start.getTime();
    countdown = formatRemaining(duration);
    until = `${shown.startLabel} – ${shown.endLabel}`;
    progress = now.getTime() >= shown.end.getTime() ? 1 : 0;
  } else {
    const remaining = getRemainingMs(shown, now);
    countdown = formatRemaining(remaining);
    until = `until ${shown.endLabel}`;
    progress = getProgress(shown, now);
    urgent = remaining > 0 && remaining < URGENT_MS;
  }

  if (countdown !== lastCountdown) {
    lastCountdown = countdown;
    nowCountdown.textContent = countdown;
  }
  if (nowUntil.textContent !== until) nowUntil.textContent = until;
  nowBar.style.width = `${(progress * 100).toFixed(2)}%`;
  nowCard.classList.toggle('urgent', urgent);
  nowCard.setAttribute('aria-label', `${title}, ${countdown} ${until}`);
}

function renderNext(next: Block): void {
  const label = next.isSleep ? 'Sleep' : next.title;
  const text = `Next · ${next.startLabel} ${label}`;
  if (nextRow.dataset.text !== text) {
    nextRow.dataset.text = text;
    nextRow.innerHTML = '';
    nextRow.append('Next · ');
    const strong = document.createElement('strong');
    strong.textContent = `${next.startLabel} ${label}`;
    nextRow.append(strong);
  }
}

function onBlockChange(blocks: Block[], live: Block, now: Date): void {
  document.body.classList.toggle('sleep', live.isSleep);

  const showTomorrow = live.number === TOMORROW_TOP3_BLOCK;
  top3TomorrowWrap.hidden = !showTomorrow;
  // Six inputs on screen: tighten the card so everything still fits without page scroll.
  $('app').classList.toggle('tight', showTomorrow);
  if (showTomorrow) {
    const tomorrowKey = toDateKey(addDays(now, 1));
    if (tomorrowKey !== builtTomorrowKey) {
      builtTomorrowKey = tomorrowKey;
      buildTop3(top3Tomorrow, tomorrowKey);
    }
  }

  learnWrap.hidden = live.number !== LEARNING_LOG_BLOCK;

  if (getPermission() === 'granted') scheduleBlockAlerts(blocks, now);

  if (!previewBlock) {
    const row = dayRows.get(live.number);
    if (row && typeof row.scrollIntoView === 'function') {
      row.scrollIntoView({ block: 'start' });
    }
  }
}

// ---------- Top 3 ----------
function buildTop3(container: HTMLElement, dateKey: string): void {
  container.innerHTML = '';
  const items = getTop3(dateKey);
  items.forEach((item, i) => {
    const row = document.createElement('div');
    row.className = 'top3-row';
    row.classList.toggle('done', item.done);

    const num = document.createElement('span');
    num.className = 'num';
    num.textContent = String(i + 1);

    const input = document.createElement('input');
    input.type = 'text';
    input.value = item.text;
    input.placeholder = `Top ${i + 1}`;
    input.autocomplete = 'off';
    input.setAttribute('autocapitalize', 'sentences');
    input.setAttribute('enterkeyhint', 'done');
    input.setAttribute('aria-label', `Top 3 item ${i + 1}`);
    input.addEventListener('input', () => {
      items[i].text = input.value;
      setTop3(dateKey, items);
    });
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') input.blur();
    });

    const cb = document.createElement('input');
    cb.type = 'checkbox';
    cb.checked = item.done;
    cb.setAttribute('aria-label', `Item ${i + 1} done`);
    cb.addEventListener('change', () => {
      items[i].done = cb.checked;
      row.classList.toggle('done', cb.checked);
      setTop3(dateKey, items);
    });

    row.append(num, input, cb);
    container.append(row);
  });
}

// ---------- Learning ----------
function buildLearn(dateKey: string): void {
  if (builtLearnKey === dateKey) return;
  builtLearnKey = dateKey;
  learnInput.value = getLearn(dateKey);
}

learnInput.addEventListener('input', () => {
  setLearn(builtLearnKey, learnInput.value);
  renderStreak(new Date());
});
learnInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') learnInput.blur();
});

function renderStreak(now: Date): void {
  const n = getLearningStreak(hasLearnEntry, now);
  learnStreak.textContent = `Learning streak: ${n} ${n === 1 ? 'day' : 'days'}`;
}

// ---------- Full day list ----------
function buildDayList(blocks: Block[], dateKey: string): void {
  dayList.innerHTML = '';
  dayRows = new Map();
  for (const block of blocks) {
    const li = document.createElement('li');
    li.className = 'day-row';
    li.dataset.category = block.category;
    li.dataset.number = String(block.number);
    li.dataset.end = String(block.end.getTime());
    li.classList.toggle('done', isBlockDone(dateKey, block.number));

    const cb = document.createElement('input');
    cb.type = 'checkbox';
    cb.className = 'day-done';
    cb.checked = isBlockDone(dateKey, block.number);
    cb.setAttribute('aria-label', `Block ${block.number} done`);
    cb.addEventListener('change', () => {
      setBlockDone(dateKey, block.number, cb.checked);
      li.classList.toggle('done', cb.checked);
      renderDayCount();
    });

    const main = document.createElement('button');
    main.type = 'button';
    main.className = 'day-main';
    main.title = CATEGORIES[block.category].label;
    const time = document.createElement('span');
    time.className = 'day-time';
    time.textContent = `${block.startLabel}–${block.endLabel}`;
    const title = document.createElement('span');
    title.className = 'day-title';
    title.textContent = formatBlockTitle(block);
    main.append(time, title);
    main.addEventListener('click', () => startPreview(block));

    const dur = document.createElement('span');
    dur.className = 'day-dur';
    dur.textContent = formatDuration(block.end.getTime() - block.start.getTime());

    li.append(cb, main, dur);
    dayList.append(li);
    dayRows.set(block.number, li);
  }
  renderDayCount();
}

function renderDayCount(): void {
  let done = 0;
  for (const [, li] of dayRows) if (li.classList.contains('done')) done += 1;
  dayCount.textContent = `${done} of ${dayRows.size} done`;
}

/** "45m", "2h", "2h 45m" */
function formatDuration(ms: number): string {
  const mins = Math.round(ms / 60000);
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  if (h === 0) return `${m}m`;
  return m === 0 ? `${h}h` : `${h}h ${m}m`;
}

// ---------- Day strip: every block as a coloured segment, sized by duration ----------
function buildStrip(blocks: Block[]): void {
  strip.innerHTML = '';
  stripSegs = [];
  if (blocks.length === 0) return;
  stripRange = { start: blocks[0].start.getTime(), end: blocks[blocks.length - 1].end.getTime() };
  for (const block of blocks) {
    const seg = document.createElement('button');
    seg.type = 'button';
    seg.className = 'strip-seg';
    seg.dataset.category = block.category;
    seg.style.flexGrow = String(Math.max(1, (block.end.getTime() - block.start.getTime()) / 60000));
    seg.setAttribute('aria-label', `${formatBlockTitle(block)}, ${block.startLabel} to ${block.endLabel}`);
    seg.addEventListener('click', () => startPreview(block));
    strip.append(seg);
    stripSegs.push({ el: seg, block });
  }
  stripMarker = document.createElement('div');
  stripMarker.className = 'strip-marker';
  strip.append(stripMarker);
}

function updateStrip(live: Block, now: Date): void {
  const t = now.getTime();
  for (const { el, block } of stripSegs) {
    const isCurrent = !live.isSleep && block.number === live.number;
    el.classList.toggle('current', isCurrent);
    el.classList.toggle('past', !isCurrent && t >= block.end.getTime());
    el.classList.toggle('previewed', previewBlock !== null && previewBlock.number === block.number);
  }
  if (stripMarker) {
    const span = stripRange.end - stripRange.start;
    const frac = span > 0 ? (t - stripRange.start) / span : 0;
    stripMarker.hidden = live.isSleep || frac < 0 || frac > 1;
    stripMarker.style.left = `${(Math.min(1, Math.max(0, frac)) * 100).toFixed(2)}%`;
  }
}

function updateDayList(live: Block, now: Date): void {
  const t = now.getTime();
  for (const [, li] of dayRows) {
    const n = Number(li.dataset.number);
    const isCurrent = !live.isSleep && n === live.number;
    li.classList.toggle('current', isCurrent);
    // Past when its end has been reached today.
    const end = li.dataset.end ? Number(li.dataset.end) : NaN;
    li.classList.toggle('past', !isCurrent && !Number.isNaN(end) && t >= end);
  }
}

function startPreview(block: Block): void {
  previewBlock = block;
  window.clearTimeout(previewTimer);
  previewTimer = window.setTimeout(() => {
    previewBlock = null;
    render();
  }, PREVIEW_MS);
  render();
}

// ---------- Footer: wake lock ----------
async function acquireWakeLock(): Promise<void> {
  if (!('wakeLock' in navigator) || wakeLock || document.visibilityState !== 'visible') return;
  try {
    wakeLock = await navigator.wakeLock.request('screen');
    wakeLock.addEventListener('release', () => {
      wakeLock = null;
    });
  } catch {
    wakeLock = null;
    setWake(false);
  }
}

async function releaseWakeLock(): Promise<void> {
  if (wakeLock) {
    try {
      await wakeLock.release();
    } catch {
      /* ignore */
    }
    wakeLock = null;
  }
}

function setWake(on: boolean): void {
  wakeOn = on;
  wakeBtn.setAttribute('aria-pressed', String(on));
  wakeBtn.textContent = on ? 'Staying awake' : 'Keep awake';
  setSetting('wakelock', on ? '1' : null);
}

if ('wakeLock' in navigator) {
  wakeBtn.hidden = false;
  setWake(getSetting('wakelock') === '1');
  wakeBtn.addEventListener('click', () => {
    setWake(!wakeOn);
    if (wakeOn) void acquireWakeLock();
    else void releaseWakeLock();
  });
  if (wakeOn) void acquireWakeLock();
}

// ---------- Footer: alerts ----------
function updateAlertsButton(): void {
  const p = getPermission();
  if (p === 'unsupported') {
    alertsBtn.hidden = true;
    return;
  }
  alertsBtn.hidden = false;
  alertsBtn.setAttribute('aria-pressed', String(p === 'granted'));
  if (p === 'granted') {
    alertsBtn.textContent = 'Alerts on';
    alertsBtn.disabled = true;
  } else if (p === 'denied') {
    alertsBtn.textContent = 'Alerts blocked';
    alertsBtn.disabled = true;
  } else {
    alertsBtn.textContent = 'Block alerts';
    alertsBtn.disabled = false;
  }
}

alertsBtn.addEventListener('click', async () => {
  const result = await requestPermission();
  updateAlertsButton();
  if (result === 'granted') {
    const now = new Date();
    scheduleBlockAlerts(getBlocksForDate(now), now);
  }
});

if (!notifySupported()) alertsBtn.hidden = true;
else updateAlertsButton();

// ---------- Footer: reset ----------
resetLink.addEventListener('click', (e) => {
  e.preventDefault();
  if (!window.confirm("Clear today's checkboxes?")) return;
  const now = new Date();
  const dateKey = toDateKey(now);
  resetDay(dateKey);
  buildTop3(top3Today, dateKey);
  for (const [n, li] of dayRows) {
    const cb = li.querySelector<HTMLInputElement>('input.day-done');
    if (cb) cb.checked = isBlockDone(dateKey, n);
    li.classList.remove('done');
  }
  renderDayCount();
  render();
});

// ---------- Clock ----------
function resync(): void {
  render();
  if (document.visibilityState === 'visible') {
    if (wakeOn) void acquireWakeLock();
    if (getPermission() === 'granted') {
      const now = new Date();
      scheduleBlockAlerts(getBlocksForDate(now), now);
    }
  }
}

document.addEventListener('visibilitychange', resync);
window.addEventListener('focus', resync);
window.addEventListener('pageshow', resync);

function tick(): void {
  render();
  // Align the next render to the top of the next second so the digits flip cleanly.
  window.setTimeout(tick, 1000 - (Date.now() % 1000) + 2);
}

tick();
