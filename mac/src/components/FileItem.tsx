import { useState } from 'react';
import { Download } from 'lucide-react';
import type { Transfer } from '../hooks/useInbox';

interface FileItemProps {
  transfer: Transfer;
  onDownload: () => void;
  onRedownload?: () => void;
  downloadProgress?: number;
  isDownloading?: boolean;
  isPending: boolean;
  error?: string;
}

function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`;
}

function formatRelativeTime(epochSeconds: number): string {
  const now = Date.now() / 1000;
  const diff = Math.max(0, now - epochSeconds);

  if (diff < 60) return 'just now';
  if (diff < 3600) {
    const mins = Math.floor(diff / 60);
    return `${mins} min ago`;
  }
  if (diff < 86400) {
    const hours = Math.floor(diff / 3600);
    return `${hours} hour${hours > 1 ? 's' : ''} ago`;
  }
  if (diff < 172800) return 'yesterday';
  const days = Math.floor(diff / 86400);
  return `${days} days ago`;
}

export default function FileItem({
  transfer,
  onDownload,
  onRedownload,
  downloadProgress,
  isDownloading,
  isPending,
  error,
}: FileItemProps) {
  const [hovered, setHovered] = useState(false);

  const handleClick = () => {
    if (isPending && !isDownloading) {
      onDownload();
    }
  };

  return (
    <div
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onClick={handleClick}
      style={{
        height: '48px',
        padding: '0 12px',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
        background: hovered ? 'var(--color-secondary)' : 'var(--color-dominant)',
        cursor: isPending && !isDownloading ? 'pointer' : 'default',
        transition: 'background-color 100ms ease',
        borderBottom: '1px solid var(--color-secondary)',
        position: 'relative',
      }}
    >
      {/* Row 1: file name + file size */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
        <span
          style={{
            fontSize: '13px',
            color: 'var(--color-text-primary)',
            flex: 1,
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
        >
          {transfer.file_name}
        </span>
        {!isPending && hovered && onRedownload ? (
          <button
            onClick={(e) => {
              e.stopPropagation();
              onRedownload();
            }}
            title="Re-download"
            style={{
              background: 'none',
              border: 'none',
              padding: '2px',
              cursor: 'pointer',
              color: 'var(--color-text-secondary)',
              display: 'flex',
              alignItems: 'center',
            }}
          >
            <Download size={14} />
          </button>
        ) : (
          <span
            style={{
              fontSize: '11px',
              lineHeight: 1.4,
              color: 'var(--color-text-secondary)',
              whiteSpace: 'nowrap',
              flexShrink: 0,
            }}
          >
            {formatFileSize(transfer.file_size)}
          </span>
        )}
      </div>

      {/* Row 2: sender device + time */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
        <span
          style={{
            fontSize: '11px',
            lineHeight: 1.4,
            color: 'var(--color-text-secondary)',
            flex: 1,
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
        >
          {error || `From ${transfer.sender_device_id}`}
        </span>
        <span
          style={{
            fontSize: '11px',
            lineHeight: 1.4,
            color: error ? 'var(--color-destructive)' : 'var(--color-text-secondary)',
            whiteSpace: 'nowrap',
            flexShrink: 0,
          }}
        >
          {formatRelativeTime(transfer.created_at)}
        </span>
      </div>

      {/* Download progress bar */}
      {isDownloading && downloadProgress !== undefined && (
        <div
          style={{
            position: 'absolute',
            bottom: 0,
            left: '12px',
            right: '12px',
            height: '2px',
            background: 'var(--color-secondary)',
            borderRadius: '1px',
            overflow: 'hidden',
          }}
        >
          <div
            style={{
              width: `${downloadProgress}%`,
              height: '100%',
              background: 'var(--color-accent)',
              borderRadius: '1px',
              transition: 'width 200ms linear',
            }}
          />
        </div>
      )}
    </div>
  );
}
