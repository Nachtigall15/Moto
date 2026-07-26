export function formatMatchDate(iso: string): string {
  const date = new Date(iso);
  return date.toLocaleString('de-DE', {
    weekday: 'short',
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function formatEuro(amount: number): string {
  return amount.toLocaleString('de-DE', { style: 'currency', currency: 'EUR' });
}

/** Parses a decimal input that may use a comma as separator ("12,50" -> 12.5). */
export function parseDecimal(input: string): number {
  const normalized = input.replace(',', '.').trim();
  const value = parseFloat(normalized);
  return Number.isFinite(value) ? value : 0;
}
