import './styles.css';
import { registerSW } from 'virtual:pwa-register';
import { CATEGORIES, LEARNING_LOG_BLOCK, TOMORROW_TOP3_BLOCK } from './schedule';
import {
  addDays,
  formatBlockTitle,
  formatHeaderDate,
  formatProgramDay,
  formatRemaining,
  getBlocksForDate,
  getCurrentBlock,
  getLearningStreak,
  getNextBlock,
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
const nowCard = $('now');
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
const wakeWrap = $('wake-wrap');
const wakeToggle = $<HTMLInputElement>('wake-toggle');
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
    renderStreak(now);
  }

  const header = `${formatHeaderDate(now)}|${formatProgramDay(now)}`;
  if (header !== lastHeader) {
    lastHeader = header;
    hdrDate.textContent = formatHeaderDate(now);
    hdrDay.textContent = formatProgramDay(now);
  }

  const blockKey = `${dateKey}:${live.number}:${live.start.getTime()}`;
  if (blockKey !== lastBlockKey) {
    lastBlockKey = blockKey;
    onBlockChange(blocks, live, now);
  }

  renderNow(previewBlock ?? live, live, now);
  renderNext(next);
  updateDayList(live, now);
}

function renderNow(shown: Block, live: Block, now: Date): void {
  const isPreview = shown !== live;
  nowCard.dataset.category = shown.category;
  nowTag.hidden = !isPreview;

  const title = formatBlockTitle(shown);
  if (nowTitle.textContent !== title) nowTitle.textContent = title;
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
      row.scrollIntoView({ block: 'nearest' });
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

    li.append(cb, main);
    dayList.append(li);
    dayRows.set(block.number, li);
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
    wakeToggle.checked = false;
    setSetting('wakelock', null);
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

if ('wakeLock' in navigator) {
  wakeWrap.hidden = false;
  wakeToggle.checked = getSetting('wakelock') === '1';
  wakeToggle.addEventListener('change', () => {
    setSetting('wakelock', wakeToggle.checked ? '1' : null);
    if (wakeToggle.checked) void acquireWakeLock();
    else void releaseWakeLock();
  });
  if (wakeToggle.checked) void acquireWakeLock();
}

// ---------- Footer: alerts ----------
function updateAlertsButton(): void {
  const p = getPermission();
  if (p === 'unsupported') {
    alertsBtn.hidden = true;
    return;
  }
  alertsBtn.hidden = false;
  if (p === 'granted') {
    alertsBtn.textContent = 'Block alerts on';
    alertsBtn.disabled = true;
  } else if (p === 'denied') {
    alertsBtn.textContent = 'Alerts blocked';
    alertsBtn.disabled = true;
  } else {
    alertsBtn.textContent = 'Enable block alerts';
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
  render();
});

// ---------- Clock ----------
function resync(): void {
  render();
  if (document.visibilityState === 'visible') {
    if (wakeToggle.checked) void acquireWakeLock();
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
