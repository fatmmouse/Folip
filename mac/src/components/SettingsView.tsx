import { useState, useEffect, useCallback, useRef } from 'react';
import { listen } from '@tauri-apps/api/event';
import { Trash2, Pencil, Check, X } from 'lucide-react';
import * as api from '../lib/api';

interface Device {
  device_id: string;
  device_name: string;
  registered_at: number;
}

interface SettingsViewProps {
  onLogout: () => void;
}

function formatDate(timestamp: number): string {
  // Backend stores milliseconds; detect and handle both ms and seconds
  const ms = timestamp > 1e12 ? timestamp : timestamp * 1000;
  const date = new Date(ms);
  return date.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
}

export default function SettingsView({ onLogout }: SettingsViewProps) {
  const [devices, setDevices] = useState<Device[]>([]);
  const [loading, setLoading] = useState(true);
  const [confirmRemove, setConfirmRemove] = useState<string | null>(null);
  const [confirmLogout, setConfirmLogout] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [currentDeviceId, setCurrentDeviceId] = useState<string | null>(null);

  const fetchDevices = useCallback(async () => {
    try {
      const [result, deviceId] = await Promise.all([
        api.getDevices(),
        api.getCurrentDeviceId(),
      ]);
      setDevices(result.devices);
      setCurrentDeviceId(deviceId);
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

  // Re-fetch when tab switches (catches remote renames from other devices)
  useEffect(() => {
    const handler = () => { fetchDevices(); };
    window.addEventListener('devices-changed', handler);
    return () => window.removeEventListener('devices-changed', handler);
  }, [fetchDevices]);

  // Re-fetch when panel is opened via tray icon click
  useEffect(() => {
    const unlisten = listen('panel-opened', () => { fetchDevices(); });
    return () => { unlisten.then(fn => fn()); };
  }, [fetchDevices]);

  const handleRemoveDevice = async (deviceId: string) => {
    try {
      await api.removeDevice(deviceId);
      setConfirmRemove(null);
      fetchDevices();
      window.dispatchEvent(new Event('devices-changed'));
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
                isCurrent={device.device_id === currentDeviceId}
                isConfirming={confirmRemove === device.device_id}
                onRequestRemove={() => setConfirmRemove(device.device_id)}
                onCancelRemove={() => setConfirmRemove(null)}
                onConfirmRemove={() => handleRemoveDevice(device.device_id)}
                onRename={fetchDevices}
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
  isCurrent: boolean;
  isConfirming: boolean;
  onRequestRemove: () => void;
  onCancelRemove: () => void;
  onConfirmRemove: () => void;
  onRename: () => void;
}

function DeviceItem({
  device,
  isCurrent,
  isConfirming,
  onRequestRemove,
  onCancelRemove,
  onConfirmRemove,
  onRename,
}: DeviceItemProps) {
  const [hovered, setHovered] = useState(false);
  const [editing, setEditing] = useState(false);
  const [editName, setEditName] = useState(device.device_name);
  const inputRef = useRef<HTMLInputElement>(null);

  const handleRename = async () => {
    const trimmed = editName.trim();
    if (!trimmed || trimmed === device.device_name) {
      setEditing(false);
      setEditName(device.device_name);
      return;
    }
    try {
      await api.renameDevice(device.device_id, trimmed);
      setEditing(false);
      onRename();
      window.dispatchEvent(new Event('devices-changed'));
    } catch (_e) {
      setEditName(device.device_name);
      setEditing(false);
    }
  };

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
        {editing ? (
          <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
            <input
              ref={inputRef}
              value={editName}
              onChange={(e) => setEditName(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter') handleRename(); if (e.key === 'Escape') { setEditing(false); setEditName(device.device_name); } }}
              autoFocus
              style={{
                flex: 1,
                fontSize: '13px',
                padding: '2px 4px',
                border: '1px solid var(--color-secondary)',
                borderRadius: '4px',
                background: 'var(--color-bg)',
                color: 'var(--color-text-primary)',
                outline: 'none',
              }}
            />
            <button onClick={handleRename} title="Save" style={{ background: 'none', border: 'none', padding: '2px', cursor: 'pointer', color: 'var(--color-accent)', display: 'flex' }}>
              <Check size={14} />
            </button>
            <button onClick={() => { setEditing(false); setEditName(device.device_name); }} title="Cancel" style={{ background: 'none', border: 'none', padding: '2px', cursor: 'pointer', color: 'var(--color-text-secondary)', display: 'flex' }}>
              <X size={14} />
            </button>
          </div>
        ) : (
          <div style={{ fontSize: '13px', color: 'var(--color-text-primary)', display: 'flex', alignItems: 'center', gap: '6px' }}>
            {device.device_name}
            {isCurrent && (
              <span style={{ fontSize: '10px', color: 'var(--color-accent)', fontWeight: 600 }}>This device</span>
            )}
          </div>
        )}
        <div style={{ fontSize: '11px', color: 'var(--color-text-secondary)', lineHeight: 1.4 }}>
          Registered {formatDate(device.registered_at)}
        </div>
      </div>
      {hovered && !editing && (
        <div style={{ display: 'flex', gap: '2px' }}>
          <button
            onClick={() => { setEditing(true); setEditName(device.device_name); }}
            title="Rename device"
            style={{
              background: 'none',
              border: 'none',
              padding: '4px',
              cursor: 'pointer',
              color: 'var(--color-text-secondary)',
              display: 'flex',
              alignItems: 'center',
            }}
            onMouseEnter={(e) => { e.currentTarget.style.color = 'var(--color-accent)'; }}
            onMouseLeave={(e) => { e.currentTarget.style.color = 'var(--color-text-secondary)'; }}
          >
            <Pencil size={14} />
          </button>
          {!isCurrent && <button
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
          </button>}
        </div>
      )}
    </div>
  );
}
