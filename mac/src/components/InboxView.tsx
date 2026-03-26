import { useState, useEffect } from 'react';
import { ChevronRight, ChevronDown } from 'lucide-react';
import { useInbox } from '../hooks/useInbox';
import { useAppContext } from '../App';
import FileItem from './FileItem';

export default function InboxView() {
  const {
    pendingTransfers,
    downloadedTransfers,
    pendingCount,
    loading,
    error,
    downloadTransfer,
    redownloadTransfer,
    downloadingIds,
    downloadProgress,
    downloadErrors,
  } = useInbox();

  const { setPendingCount } = useAppContext();
  const [receivedExpanded, setReceivedExpanded] = useState(false);

  // Connect pendingCount to AppContext for tab badge + tray badge
  useEffect(() => {
    setPendingCount(pendingCount);
  }, [pendingCount, setPendingCount]);

  // Loading state (first load only)
  if (loading) {
    return (
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          height: '100%',
          color: 'var(--color-text-secondary)',
          fontSize: '13px',
        }}
      >
        Loading...
      </div>
    );
  }

  // Error state
  if (error && pendingTransfers.length === 0 && downloadedTransfers.length === 0) {
    return (
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          height: '100%',
          padding: '0 12px',
        }}
      >
        <span style={{ fontSize: '13px', color: 'var(--color-destructive)', textAlign: 'center' }}>
          {error}
        </span>
      </div>
    );
  }

  // Empty state
  if (pendingTransfers.length === 0 && downloadedTransfers.length === 0) {
    return (
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          height: '100%',
          gap: '4px',
        }}
      >
        <span style={{ fontSize: '13px', color: 'var(--color-text-primary)' }}>
          No files waiting
        </span>
        <span style={{ fontSize: '11px', color: 'var(--color-text-secondary)' }}>
          Files sent to this device will appear here.
        </span>
      </div>
    );
  }

  return (
    <div style={{ height: '100%', overflowY: 'auto', padding: '0' }}>
      {/* Error banner */}
      {error && (
        <div
          style={{
            padding: '8px 12px',
            fontSize: '11px',
            color: 'var(--color-destructive)',
            background: 'rgba(197, 48, 48, 0.08)',
          }}
        >
          {error}
        </div>
      )}

      {/* Pending transfers */}
      {pendingTransfers.map(transfer => (
        <FileItem
          key={transfer.transfer_id}
          transfer={transfer}
          isPending={true}
          onDownload={() => downloadTransfer(transfer)}
          isDownloading={downloadingIds.has(transfer.transfer_id)}
          downloadProgress={downloadProgress[transfer.transfer_id]}
          error={downloadErrors[transfer.transfer_id]}
        />
      ))}

      {/* Already received section */}
      {downloadedTransfers.length > 0 && (
        <>
          <button
            onClick={() => setReceivedExpanded(!receivedExpanded)}
            style={{
              display: 'flex',
              alignItems: 'center',
              width: '100%',
              padding: '8px 12px',
              background: 'none',
              border: 'none',
              borderBottom: '1px solid var(--color-secondary)',
              cursor: 'pointer',
              gap: '4px',
              color: 'var(--color-text-secondary)',
              fontSize: '11px',
              lineHeight: 1.4,
            }}
          >
            {receivedExpanded ? <ChevronDown size={12} /> : <ChevronRight size={12} />}
            Already received ({downloadedTransfers.length})
          </button>

          <div
            style={{
              overflow: 'hidden',
              maxHeight: receivedExpanded ? `${downloadedTransfers.length * 49}px` : '0px',
              opacity: receivedExpanded ? 1 : 0,
              transition: 'max-height 200ms ease, opacity 200ms ease',
            }}
          >
            {downloadedTransfers.map(transfer => (
              <FileItem
                key={transfer.transfer_id}
                transfer={transfer}
                isPending={false}
                onDownload={() => {}}
                onRedownload={() => redownloadTransfer(transfer)}
                isDownloading={downloadingIds.has(transfer.transfer_id)}
                downloadProgress={downloadProgress[transfer.transfer_id]}
                error={downloadErrors[transfer.transfer_id]}
              />
            ))}
          </div>
        </>
      )}
    </div>
  );
}
