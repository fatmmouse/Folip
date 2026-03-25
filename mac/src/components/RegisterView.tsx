import { useState } from 'react';

interface RegisterViewProps {
  onRegister: (email: string, password: string) => Promise<void>;
  onSwitchToLogin: () => void;
  error: string | null;
}

export default function RegisterView({ onRegister, onSwitchToLogin, error }: RegisterViewProps) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password || loading) return;
    setLoading(true);
    try {
      await onRegister(email, password);
    } catch {
      // error is handled by useAuth hook
    } finally {
      setLoading(false);
    }
  };

  return (
    <div
      data-tauri-drag-region
      style={{
        width: '100%',
        height: '100vh',
        background: 'var(--color-login-bg)',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '32px 48px',
        boxSizing: 'border-box',
        borderRadius: '12px',
      }}
    >
      <h1
        style={{
          fontSize: '15px',
          fontWeight: 600,
          color: 'var(--color-login-text)',
          marginBottom: '32px',
          lineHeight: 1.3,
        }}
      >
        Folip
      </h1>

      <form onSubmit={handleSubmit} style={{ width: '100%', maxWidth: '320px' }}>
        <label
          style={{
            display: 'block',
            fontSize: '13px',
            color: 'var(--color-login-text)',
            marginBottom: '4px',
          }}
        >
          Email
        </label>
        <input
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          autoFocus
          style={{
            width: '100%',
            height: '36px',
            background: 'var(--color-login-input-bg)',
            border: '1px solid rgba(176, 174, 165, 0.3)',
            borderRadius: '8px',
            color: 'var(--color-login-text)',
            fontSize: '13px',
            padding: '0 12px',
            boxSizing: 'border-box',
            outline: 'none',
            marginBottom: '16px',
          }}
        />

        <label
          style={{
            display: 'block',
            fontSize: '13px',
            color: 'var(--color-login-text)',
            marginBottom: '4px',
          }}
        >
          Password
        </label>
        <input
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          style={{
            width: '100%',
            height: '36px',
            background: 'var(--color-login-input-bg)',
            border: '1px solid rgba(176, 174, 165, 0.3)',
            borderRadius: '8px',
            color: 'var(--color-login-text)',
            fontSize: '13px',
            padding: '0 12px',
            boxSizing: 'border-box',
            outline: 'none',
            marginBottom: '16px',
          }}
        />

        {error && (
          <p
            style={{
              fontSize: '11px',
              color: 'var(--color-destructive)',
              margin: '0 0 8px 0',
            }}
          >
            {error}
          </p>
        )}

        <button
          type="submit"
          disabled={loading || !email || !password}
          style={{
            width: '100%',
            height: '36px',
            background: 'var(--color-accent)',
            color: '#ffffff',
            border: 'none',
            borderRadius: '8px',
            fontSize: '13px',
            fontWeight: 600,
            cursor: loading ? 'wait' : 'pointer',
            opacity: loading || !email || !password ? 0.6 : 1,
          }}
        >
          {loading ? 'Creating account...' : 'Create Account'}
        </button>
      </form>

      <p
        style={{
          fontSize: '13px',
          color: 'var(--color-login-text)',
          marginTop: '24px',
        }}
      >
        Have an account?{' '}
        <span
          onClick={onSwitchToLogin}
          style={{
            color: 'var(--color-accent)',
            cursor: 'pointer',
          }}
        >
          Log In
        </span>
      </p>
    </div>
  );
}
