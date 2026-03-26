interface ProgressBarProps {
  progress: number;
  height?: number;
  className?: string;
}

export default function ProgressBar({ progress, height = 6, className }: ProgressBarProps) {
  const cornerRadius = height >= 6 ? 3 : 1;

  return (
    <div
      className={className}
      style={{
        width: '100%',
        height: `${height}px`,
        background: 'var(--color-secondary)',
        borderRadius: `${cornerRadius}px`,
        overflow: 'hidden',
      }}
    >
      <div
        style={{
          width: `${Math.min(100, Math.max(0, progress))}%`,
          height: '100%',
          background: 'var(--color-accent)',
          borderRadius: `${cornerRadius}px`,
          transition: 'width 200ms linear',
        }}
      />
    </div>
  );
}
