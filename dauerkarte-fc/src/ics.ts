import type { Match } from './types';

const MATCH_DURATION_HOURS = 2;

function pad(n: number): string {
  return n.toString().padStart(2, '0');
}

/** Formats a Date as UTC floating timestamp for ICS (YYYYMMDDTHHMMSSZ). */
function formatIcsDate(date: Date): string {
  return (
    `${date.getUTCFullYear()}${pad(date.getUTCMonth() + 1)}${pad(date.getUTCDate())}` +
    `T${pad(date.getUTCHours())}${pad(date.getUTCMinutes())}${pad(date.getUTCSeconds())}Z`
  );
}

function escapeIcsText(text: string): string {
  return text.replace(/([,;])/g, '\\$1').replace(/\n/g, '\\n');
}

function buildEvent(match: Match): string {
  const start = new Date(match.date);
  const end = new Date(start.getTime() + MATCH_DURATION_HOURS * 60 * 60 * 1000);
  const summary = escapeIcsText(`1. FC Köln – ${match.opponent} (Dauerkarte klären)`);

  return [
    'BEGIN:VEVENT',
    `UID:fc-koeln-dauerkarte-${match.matchID}@local`,
    `DTSTAMP:${formatIcsDate(new Date())}`,
    `DTSTART:${formatIcsDate(start)}`,
    `DTEND:${formatIcsDate(end)}`,
    `SUMMARY:${summary}`,
    `DESCRIPTION:Spieltag ${match.matchday} – 1. FC Köln gegen ${escapeIcsText(match.opponent)}`,
    'BEGIN:VALARM',
    'ACTION:DISPLAY',
    'DESCRIPTION:Dauerkarte klären',
    'TRIGGER:-P3D',
    'END:VALARM',
    'END:VEVENT',
  ].join('\r\n');
}

function buildCalendar(events: string[]): string {
  return [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Dauerkarte FC Köln//DE',
    'CALSCALE:GREGORIAN',
    ...events,
    'END:VCALENDAR',
  ].join('\r\n');
}

function downloadIcs(filename: string, content: string): void {
  const blob = new Blob([content], { type: 'text/calendar;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

export function downloadMatchIcs(match: Match): void {
  const calendar = buildCalendar([buildEvent(match)]);
  downloadIcs(`fc-koeln-spieltag-${match.matchday}.ics`, calendar);
}

export function downloadAllMatchesIcs(matches: Match[]): void {
  const now = Date.now();
  const upcoming = matches.filter((m) => new Date(m.date).getTime() >= now);
  const calendar = buildCalendar(upcoming.map(buildEvent));
  downloadIcs('fc-koeln-heimspiele.ics', calendar);
}
