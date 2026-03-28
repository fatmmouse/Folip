import { useState, createContext, useContext, useEffect } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { getCurrentWebviewWindow } from '@tauri-apps/api/webviewWindow';
import { Settings } from 'lucide-react';
import { useAuth } from './hooks/useAuth';
import LoginView from './components/LoginView';
import RegisterView from './components/RegisterView';
import SendView from './components/SendView';
import InboxView from './components/InboxView';
import SettingsView from './components/SettingsView';

// --- App Context for cross-view communication ---
interface AppContextType {
  pendingCount: number;
  setPendingCount: (n: number) => void;
}

const AppContext = createContext<AppContextType>({
  pendingCount: 0,
  setPendingCount: () => {},
});

export function useAppContext() {
  return useContext(AppContext);
}

// --- Login App (rendered in the login window) ---
function LoginApp() {
  const auth = useAuth();
  const [showRegister, setShowRegister] = useState(false);

  const handleLoginSuccess = async (email: string, password: string) => {
    await auth.login(email, password);
    await invoke('show_main_hide_login');
  };

  const handleRegisterSuccess = async (email: string, password: string) => {
    await auth.register(email, password);
    await invoke('show_main_hide_login');
  };

  if (showRegister) {
    return (
      <RegisterView
        onRegister={handleRegisterSuccess}
        onSwitchToLogin={() => { setShowRegister(false); auth.clearError(); }}
        error={auth.error}
      />
    );
  }

  return (
    <LoginView
      onLogin={handleLoginSuccess}
      onSwitchToRegister={() => { setShowRegister(true); auth.clearError(); }}
      error={auth.error}
    />
  );
}

// --- Tab Bar ---
type TabId = 'send' | 'inbox' | 'settings';

interface TabBarProps {
  activeTab: TabId;
  onTabChange: (tab: TabId) => void;
  pendingCount: number;
}

function TabBar({ activeTab, onTabChange, pendingCount }: TabBarProps) {
  const tabStyle = (tab: TabId): React.CSSProperties => ({
    background: 'none',
    border: 'none',
    borderBottom: activeTab === tab ? '2px solid var(--color-accent)' : '2px solid transparent',
    color: activeTab === tab ? 'var(--color-text-primary)' : 'var(--color-text-secondary)',
    fontFamily: 'var(--font-heading)',
    fontSize: '14px',
    fontWeight: 600,
    padding: '0 16px',
    height: '100%',
    cursor: 'pointer',
    lineHeight: '40px',
  });

  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        height: '40px',
        borderBottom: '1px solid var(--color-secondary)',
        flexShrink: 0,
      }}
    >
      <button style={tabStyle('send')} onClick={() => onTabChange('send')}>
        Send
      </button>
      <button style={tabStyle('inbox')} onClick={() => onTabChange('inbox')}>
        {pendingCount > 0 ? (
          <>
            Inbox{' '}
            <span style={{ fontSize: '10px', lineHeight: 1.4 }}>({pendingCount})</span>
          </>
        ) : (
          'Inbox'
        )}
      </button>
      <div style={{ flex: 1 }} />
      <button
        onClick={() => onTabChange('settings')}
        title="Settings"
        aria-label="Settings"
        style={{
          background: 'none',
          border: 'none',
          padding: '0 12px',
          height: '100%',
          cursor: 'pointer',
          display: 'flex',
          alignItems: 'center',
          color: activeTab === 'settings' ? 'var(--color-text-primary)' : 'var(--color-text-secondary)',
        }}
      >
        <Settings size={16} />
      </button>
    </div>
  );
}

// --- Main App (rendered in the tray popover) ---
function MainApp() {
  const auth = useAuth();
  const [activeTab, setActiveTab] = useState<TabId>('send');
  const [pendingCount, setPendingCount] = useState(0);

  // If not authenticated, show login window
  useEffect(() => {
    if (auth.isAuthenticated === false) {
      invoke('show_login').catch(() => {});
    }
  }, [auth.isAuthenticated]);

  // Update tray badge when pending count changes
  useEffect(() => {
    invoke('update_tray_badge', { hasPending: pendingCount > 0 }).catch(() => {});
  }, [pendingCount]);

  // Loading state
  if (auth.isAuthenticated === null) {
    return (
      <div
        style={{
          width: '100%',
          height: '100vh',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: 'var(--color-dominant)',
          borderRadius: '12px',
          boxShadow: '0 8px 32px rgba(20, 20, 19, 0.15)',
        }}
      >
        <span style={{ fontSize: '13px', color: 'var(--color-text-secondary)' }}>Loading...</span>
      </div>
    );
  }

  // Not authenticated — login window should be showing
  if (auth.isAuthenticated === false) {
    return (
      <div
        style={{
          width: '100%',
          height: '100vh',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: 'var(--color-dominant)',
          borderRadius: '12px',
          boxShadow: '0 8px 32px rgba(20, 20, 19, 0.15)',
        }}
      >
        <span style={{ fontSize: '13px', color: 'var(--color-text-secondary)' }}>
          Please log in to continue.
        </span>
      </div>
    );
  }

  // Authenticated — show main panel with tab bar
  return (
    <AppContext.Provider value={{ pendingCount, setPendingCount }}>
      <div
        style={{
          width: '100%',
          height: '100vh',
          display: 'flex',
          flexDirection: 'column',
          background: 'var(--color-dominant)',
          borderRadius: '12px',
          boxShadow: '0 8px 32px rgba(20, 20, 19, 0.15)',
          overflow: 'hidden',
        }}
      >
        <TabBar activeTab={activeTab} onTabChange={setActiveTab} pendingCount={pendingCount} />

        <div style={{ flex: 1, overflow: 'hidden', position: 'relative' }}>
          <div style={{ position: 'absolute', inset: 0, display: activeTab === 'send' ? 'block' : 'none' }}>
            <SendView />
          </div>
          <div style={{ position: 'absolute', inset: 0, display: activeTab === 'inbox' ? 'block' : 'none' }}>
            <InboxView />
          </div>
          <div style={{ position: 'absolute', inset: 0, display: activeTab === 'settings' ? 'block' : 'none' }}>
            <SettingsView onLogout={auth.logout} />
          </div>
        </div>
      </div>
    </AppContext.Provider>
  );
}

// --- Root App: routes based on Tauri window label ---
function App() {
  const windowLabel = getCurrentWebviewWindow().label;

  if (windowLabel === 'login') {
    return <LoginApp />;
  }

  return <MainApp />;
}

export default App;
