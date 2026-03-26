import { useState, useRef, useEffect } from 'react';
import { ChevronDown, Check } from 'lucide-react';
import type { Device } from '../hooks/useDevices';

interface DeviceSelectorProps {
  devices: Device[];
  selectedDeviceId: string | null;
  onSelect: (id: string) => void;
  disabled: boolean;
}

export default function DeviceSelector({ devices, selectedDeviceId, onSelect, disabled }: DeviceSelectorProps) {
  const [isOpen, setIsOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  // Close dropdown on click outside
  useEffect(() => {
    if (!isOpen) return;

    function handleClickOutside(e: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setIsOpen(false);
      }
    }

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [isOpen]);

  // Empty state
  if (devices.length === 0) {
    return (
      <div
        style={{
          background: 'var(--color-secondary)',
          borderRadius: '8px',
          display: 'flex',
          alignItems: 'center',
          flexDirection: 'column',
          justifyContent: 'center',
          padding: '8px 12px',
        }}
      >
        <span style={{ fontSize: '13px', color: 'var(--color-text-secondary)' }}>
          No other devices
        </span>
        <span style={{ fontSize: '11px', color: 'var(--color-text-secondary)', marginTop: '2px' }}>
          Log in on another device to start sending files.
        </span>
      </div>
    );
  }

  const selectedDevice = devices.find((d) => d.device_id === selectedDeviceId);
  const displayName = selectedDevice?.device_name ?? 'Select device';

  return (
    <div ref={containerRef} style={{ position: 'relative' }}>
      {/* Trigger button */}
      <button
        onClick={() => !disabled && setIsOpen(!isOpen)}
        disabled={disabled}
        style={{
          width: '100%',
          height: '36px',
          background: 'var(--color-secondary)',
          borderRadius: '8px',
          border: 'none',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '0 12px',
          fontSize: '13px',
          color: 'var(--color-text-primary)',
          cursor: disabled ? 'not-allowed' : 'pointer',
          opacity: disabled ? 0.5 : 1,
        }}
      >
        <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {displayName}
        </span>
        <ChevronDown size={12} color="var(--color-text-secondary)" />
      </button>

      {/* Dropdown list */}
      {isOpen && !disabled && (
        <div
          style={{
            position: 'absolute',
            top: '40px',
            left: 0,
            right: 0,
            background: 'var(--color-dominant)',
            border: '1px solid var(--color-secondary)',
            borderRadius: '8px',
            boxShadow: '0 4px 16px rgba(20, 20, 19, 0.12)',
            zIndex: 10,
            overflow: 'hidden',
          }}
        >
          {devices.map((device) => (
            <button
              key={device.device_id}
              onClick={() => {
                onSelect(device.device_id);
                setIsOpen(false);
              }}
              style={{
                width: '100%',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '8px 12px',
                border: 'none',
                background: 'transparent',
                fontSize: '13px',
                color: 'var(--color-text-primary)',
                cursor: 'pointer',
                textAlign: 'left',
              }}
              onMouseEnter={(e) => {
                (e.currentTarget as HTMLElement).style.background = 'var(--color-secondary)';
              }}
              onMouseLeave={(e) => {
                (e.currentTarget as HTMLElement).style.background = 'transparent';
              }}
            >
              <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {device.device_name}
              </span>
              {device.device_id === selectedDeviceId && (
                <Check size={14} color="var(--color-accent)" />
              )}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
