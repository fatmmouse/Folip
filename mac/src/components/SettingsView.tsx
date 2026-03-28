import { useState, useEffect, useCallback } from 'react';
import { Trash2 } from 'lucide-react';
import * as api from '../lib/api';

interface Device {
  device_id: string;
  device_name: string;
  registered_at: number;
}

interface SettingsViewProps {
  onLogout: () => void;
}

function formatDate(epochSeconds: number): string {
  const date = new Date(epochSeconds * 1000);
  return date.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
}

export default function SettingsView({ onLogout }: SettingsViewProps) {
  const [devices, setDevices] = useState<Device[]>([]);
  const [loading, setLoading] = useState(true);
  const [confirmRemove, setConfirmRemove] = useState<string | null>(null);
  const [confirmLogout, setConfirmLogout] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchDevices = useCallback(async () => {
    try {
      const result = await api.getDevices();
      setDevices(result.devices);
      setError(null);
    } catch (_e) {
      setError('Cannot reach server -- check your internet connection.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchDevices();
  }, [fetchDevices]);

  const handleRemoveDevice = async (deviceId: string) => {
    try {
      await api.removeDevice(deviceId);
      setConfirmRemove(null);
      fetchDevices();
    } catch (_e) {
      setError('Failed to remove device.');
    }
  };

  const handleLogout = () => {
    onLogout();
  };

  return (
    <div
      style={{
        height: '100%',
        overflowY: 'auto',
        padding: '16px 12px',
        display: 'flex',
        flexDirection: 'column',
        gap: '24px',
      }}
    >
      {/* Title */}
      <h2
        style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '16px',
          fontWeight: 600,
          lineHeight: 1.3,
          color: 'var(--color-text-primary)',
          margin: 0,
        }}
      >
        Account
      </h2>

      {/* Error banner */}
      {error && (
        <div
          style={{
            padding: '8px 12px',
            fontSize: '11px',
            color: 'var(--color-destructive)',
            background: 'rgba(197, 48, 48, 0.08)',
            borderRadius: '6px',
          }}
        >
          {error}
        </div>
      )}

      {/* Devices section */}
      <div>
        <h3
          style={{
            fontFamily: 'var(--font-heading)',
            fontSize: '14px',
            fontWeight: 600,
            color: 'var(--color-text-primary)',
            margin: '0 0 8px 0',
          }}
        >
          Devices
        </h3>

        {loading ? (
          <span style={{ fontSize: '11px', color: 'var(--color-text-secondary)' }}>
            Loading...
          </span>
        ) : devices.length === 0 ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
            <span style={{ fontSize: '13px', color: 'var(--color-text-primary)' }}>
              No other devices
            </span>
            <span style={{ fontSize: '11px', color: 'var(--color-text-secondary)' }}>
              Log in on another device to start sending files.
            </span>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0' }}>
            {devices.map(device => (
              <DeviceItem
                key={device.device_id}
                device={device}
                isConfirming={confirmRemove === device.device_id}
                onRequestRemove={() => setConfirmRemove(device.device_id)}
                onCancelRemove={() => setConfirmRemove(null)}
                onConfirmRemove={() => handleRemoveDevice(device.device_id)}
              />
            ))}
          </div>
        )}
      </div>

      {/* Spacer */}
      <div style={{ flex: 1 }} />

      {/* Logout section */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
        {confirmLogout ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
            <span style={{ fontSize: '13px', color: 'var(--color-text-primary)' }}>
              Log out of this device?
            </span>
            <div style={{ display: 'flex', gap: '8px' }}>
              <button
                onClick={handleLogout}
                style={{
                  flex: 1,
                  padding: '8px',
                  fontSize: '13px',
                  fontWeight: 600,
                  cursor: 'pointer',
                  border: 'none',
                  borderRadius: '8px',
                  background: 'var(--color-destructive)',
                  color: '#fff',
                }}
              >
                Log Out
              </button>
              <button
                onClick={() => setConfirmLogout(false)}
                style={{
                  flex: 1,
                  padding: '8px',
                  fontSize: '13px',
                  cursor: 'pointer',
                  border: '1px solid var(--color-secondary)',
                  borderRadius: '8px',
                  background: 'none',
                  color: 'var(--color-text-primary)',
                }}
              >
                Cancel
              </button>
            </div>
          </div>
        ) : (
          <button
            onClick={() => setConfirmLogout(true)}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = 'var(--color-destructive)';
              e.currentTarget.style.color = '#fff';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'transparent';
              e.currentTarget.style.color = 'var(--color-destructive)';
            }}
            style={{
              width: '100%',
              padding: '8px',
              fontSize: '13px',
              fontWeight: 600,
              cursor: 'pointer',
              border: '1px solid var(--color-destructive)',
              borderRadius: '8px',
              background: 'transparent',
              color: 'var(--color-destructive)',
              transition: 'background-color 100ms ease, color 100ms ease',
            }}
          >
            Log Out
          </button>
        )}
      </div>
    </div>
  );
}

// --- Device list item ---

interface DeviceItemProps {
  device: Device;
  isConfirming: boolean;
  onRequestRemove: () => void;
  onCancelRemove: () => void;
  onConfirmRemove: () => void;
}

function DeviceItem({
  device,
  isConfirming,
  onRequestRemove,
  onCancelRemove,
  onConfirmRemove,
}: DeviceItemProps) {
  const [hovered, setHovered] = useState(false);

  if (isConfirming) {
    return (
      <div
        style={{
          padding: '8px 0',
          borderBottom: '1px solid var(--color-secondary)',
          display: 'flex',
          flexDirection: 'column',
          gap: '6px',
        }}
      >
        <span style={{ fontSize: '13px', color: 'var(--color-text-primary)' }}>
          Remove {device.device_name}? This device will need to log in again.
        </span>
        <div style={{ display: 'flex', gap: '8px' }}>
          <button
            onClick={onConfirmRemove}
            style={{
              padding: '4px 12px',
              fontSize: '11px',
              fontWeight: 600,
              cursor: 'pointer',
              border: 'none',
              borderRadius: '6px',
              background: 'var(--color-destructive)',
              color: '#fff',
            }}
          >
            Remove Device
          </button>
          <button
            onClick={onCancelRemove}
            style={{
              padding: '4px 12px',
              fontSize: '11px',
              cursor: 'pointer',
              border: '1px solid var(--color-secondary)',
              borderRadius: '6px',
              background: 'none',
              color: 'var(--color-text-secondary)',
            }}
          >
            Cancel
          </button>
        </div>
      </div>
    );
  }

  return (
    <div
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        display: 'flex',
        alignItems: 'center',
        padding: '8px 0',
        borderBottom: '1px solid var(--color-secondary)',
      }}
    >
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: '13px', color: 'var(--color-text-primary)' }}>
          {device.device_name}
        </div>
        <div style={{ fontSize: '11px', color: 'var(--color-text-secondary)', lineHeight: 1.4 }}>
          Registered {formatDate(device.registered_at)}
        </div>
      </div>
      {hovered && (
        <button
          onClick={onRequestRemove}
          title="Remove device"
          style={{
            background: 'none',
            border: 'none',
            padding: '4px',
            cursor: 'pointer',
            color: 'var(--color-text-secondary)',
            display: 'flex',
            alignItems: 'center',
          }}
          onMouseEnter={(e) => { e.currentTarget.style.color = 'var(--color-destructive)'; }}
          onMouseLeave={(e) => { e.currentTarget.style.color = 'var(--color-text-secondary)'; }}
        >
          <Trash2 size={14} />
        </button>
      )}
    </div>
  );
}
