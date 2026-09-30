/**
 * Best-effort local block alerts.
 *
 * While the page is open, one timer per remaining block fires a notification
 * at the block start. Timers are rebuilt whenever the app becomes visible
 * again, because browsers pause timers while the page is hidden.
 * Permission is only ever requested from a user tap (see main.ts).
 */
import type { Block } from './time';

const pad2 = (n: number): string => String(n).padStart(2, '0');

let timers: number[] = [];

export function isSupported(): boolean {
  return typeof window !== 'undefined' && 'Notification' in window;
}

export function getPermission(): NotificationPermission | 'unsupported' {
  if (!isSupported()) return 'unsupported';
  return Notification.permission;
}

export async function requestPermission(): Promise<NotificationPermission | 'unsupported'> {
  if (!isSupported()) return 'unsupported';
  try {
    return await Notification.requestPermission();
  } catch {
    return Notification.permission;
  }
}

export function alertTitle(block: Block): string {
  return `Block ${pad2(block.number)} · ${block.title}`;
}

export function alertBody(block: Block): string {
  return `until ${block.endLabel}`;
}

async function show(title: string, body: string, tag: string): Promise<void> {
  try {
    const reg = 'serviceWorker' in navigator ? await navigator.serviceWorker.getRegistration() : undefined;
    if (reg && typeof reg.showNotification === 'function') {
      await reg.showNotification(title, { body, tag, silent: false });
      return;
    }
  } catch {
    /* fall through */
  }
  try {
    new Notification(title, { body, tag });
  } catch {
    /* ignore */
  }
}

export function clearBlockAlerts(): void {
  for (const id of timers) window.clearTimeout(id);
  timers = [];
}

/**
 * Schedule a notification for the start of every block that begins after `now`.
 * Returns the number of alerts scheduled.
 */
export function scheduleBlockAlerts(blocks: Block[], now: Date): number {
  clearBlockAlerts();
  if (getPermission() !== 'granted') return 0;

  const t = now.getTime();
  for (const block of blocks) {
    if (block.isSleep) continue;
    const delay = block.start.getTime() - t;
    if (delay <= 0) continue;
    const id = window.setTimeout(() => {
      void show(alertTitle(block), alertBody(block), `block-${block.number}-${block.start.getTime()}`);
    }, delay);
    timers.push(id);
  }
  return timers.length;
}
