/**
 * The routine. Edit this file to change blocks, times, titles or notes.
 * All logic lives in time.ts and reads from here.
 */

export type Category = 'deep' | 'train' | 'learn' | 'fuel' | 'light' | 'rest';

export interface BlockDef {
  /** Block number as shown on screen. Never renumbered, even when block 10 is skipped. */
  number: number;
  /** Local wall-clock start, "HH:MM". */
  start: string;
  /** Local wall-clock end, "HH:MM". */
  end: string;
  title: string;
  category: Category;
  note: string;
}

/** First day of the program (local calendar date). Day 1. */
export const PROGRAM_START = { year: 2026, month: 10, day: 5 };
/** Number of consecutive days in the program. Last day is Tuesday 12 January 2027. */
export const PROGRAM_DAYS = 100;

/** Wake time. Sleep state ends here. */
export const WAKE = '05:00';
/** Lights out. Sleep state starts here. */
export const LIGHTS_OUT = '22:00';

/** Block that only happens on odd program days (day 1, 3, 5, ...). */
export const EVERY_SECOND_DAY_BLOCK = 10;
/** Block that extends to fill the gap on even days. */
export const EXTENDED_BLOCK = 9;
export const EXTENDED_TITLE = 'Deep work 3 - Sink as the operator (extended)';

/** Block during which "Tomorrow's top 3" inputs are shown. */
export const TOMORROW_TOP3_BLOCK = 13;
/** Block during which the learning log input is shown. */
export const LEARNING_LOG_BLOCK = 12;

export const BLOCKS: readonly BlockDef[] = [
  {
    number: 1, start: '05:00', end: '05:30', title: 'Wake, no screens', category: 'rest',
    note: "Water, daylight, 10 min mobility. Read tomorrow's top 3 from last night.",
  },
  {
    number: 2, start: '05:30', end: '06:15', title: 'Deep work 1 - The ONE thing', category: 'deep',
    note: 'Most important Sink / farm task of the day. Offline, phone in another room.',
  },
  {
    number: 3, start: '06:15', end: '07:30', title: 'Swim / cardio', category: 'train',
    note: 'Swim 6:30 - 7:30. Includes travel and shower. Breakfast on the go.',
  },
  {
    number: 4, start: '07:30', end: '10:00', title: 'Deep work 2 - Build the farm plan', category: 'deep',
    note: 'Robin and Sarge site plan, business model, design brief, costings.',
  },
  {
    number: 5, start: '10:00', end: '10:30', title: 'Admin + travel', category: 'light',
    note: 'Clear messages once. Travel to CrossFit.',
  },
  {
    number: 6, start: '10:30', end: '12:30', title: 'CrossFit', category: 'train',
    note: 'Full effort, includes shower. Lunch on the go straight after.',
  },
  {
    number: 7, start: '12:30', end: '15:15', title: 'Calls + partners', category: 'light',
    note: 'All meetings batched here: family partners, planners, architects, suppliers.',
  },
  {
    number: 8, start: '15:15', end: '15:30', title: 'Walk reset', category: 'rest',
    note: 'Outside, no phone. Resets focus for the afternoon.',
  },
  {
    number: 9, start: '15:30', end: '17:15', title: 'Deep work 3 - Sink as the operator', category: 'deep',
    note: 'Management model, brand, systems and SOPs that let Sink run the farm and padel.',
  },
  {
    number: 10, start: '17:15', end: '18:30', title: 'Bike / row', category: 'train',
    note: 'Ride 17:30 - 18:30, easy zone 2, includes shower.',
  },
  {
    number: 11, start: '18:30', end: '19:15', title: 'Dinner', category: 'fuel',
    note: 'Sit-down meal, finished by 19:15 to protect sleep.',
  },
  {
    number: 12, start: '19:15', end: '20:00', title: 'Deep skill learning', category: 'learn',
    note: 'One skill, one course or book, 45 min. No inbox. Log what you learned in one line.',
  },
  {
    number: 13, start: '20:00', end: '21:00', title: 'Light work + shutdown', category: 'light',
    note: "Inbox, progress log, write tomorrow's top 3. Workday ends at 21:00.",
  },
  {
    number: 14, start: '21:00', end: '22:00', title: 'Wind down', category: 'rest',
    note: 'Screens off, lights low, stretch or read. Lights out 22:00.',
  },
];

export interface CategoryStyle {
  label: string;
  light: { fill: string; text: string };
  dark: { fill: string; text: string };
}

export const CATEGORIES: Record<Category, CategoryStyle> = {
  deep: {
    label: 'Deep work - Sink / farm',
    light: { fill: '#E6F1FB', text: '#185FA5' },
    dark: { fill: '#0C447C', text: '#B5D4F4' },
  },
  train: {
    label: 'Training',
    light: { fill: '#E1F5EE', text: '#0F6E56' },
    dark: { fill: '#0B4A3B', text: '#A3E4CF' },
  },
  learn: {
    label: 'Skill learning',
    light: { fill: '#FBEAF0', text: '#993556' },
    dark: { fill: '#5E1F37', text: '#F4B9CD' },
  },
  fuel: {
    label: 'Dinner',
    light: { fill: '#FAEEDA', text: '#854F0B' },
    dark: { fill: '#553308', text: '#F5D08E' },
  },
  light: {
    label: 'Light work',
    light: { fill: '#F1EFE8', text: '#5F5E5A' },
    dark: { fill: '#3A3936', text: '#D6D4CE' },
  },
  rest: {
    label: 'Rest / recovery',
    light: { fill: '#EEEDFE', text: '#534AB7' },
    dark: { fill: '#2C2775', text: '#C7C2F6' },
  },
};
