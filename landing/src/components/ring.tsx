/** Ring Spark mark (design option 1a) rendered in terminal-green. */
export function Ring({ size = 24, stroke = 5.5 }: { size?: number; stroke?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 40 40" aria-hidden>
      <circle cx="20" cy="20" r="15" fill="none" stroke="rgba(255,255,255,.14)" strokeWidth={stroke} />
      <circle cx="20" cy="20" r="15" fill="none" stroke="var(--color-green)" strokeWidth={stroke}
        strokeLinecap="round" strokeDasharray="94.2" strokeDashoffset="28" transform="rotate(-90 20 20)" />
      <circle cx="20" cy="20" r="4" fill="var(--color-green)" />
    </svg>
  );
}
