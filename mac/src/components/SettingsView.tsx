interface SettingsViewProps {
  onLogout: () => void;
}

export default function SettingsView({ onLogout }: SettingsViewProps) {
  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        height: '100%',
        gap: '16px',
      }}
    >
      <p style={{ fontSize: '13px', color: 'var(--color-text-secondary)' }}>
        Settings placeholder
      </p>
      <button
        onClick={onLogout}
        style={{
          background: 'none',
          border: '1px solid var(--color-destructive)',
          color: 'var(--color-destructive)',
          borderRadius: '8px',
          padding: '8px 24px',
          fontSize: '13px',
          cursor: 'pointer',
        }}
      >
        Log Out
      </button>
    </div>
  );
}
