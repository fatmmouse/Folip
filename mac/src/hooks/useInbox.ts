import { useState, useEffect, useCallback, useRef } from 'react';
import { listen } from '@tauri-apps/api/event';
import { getCurrentWebviewWindow } from '@tauri-apps/api/webviewWindow';
import * as api from '../lib/api';

export interface Transfer {
  transfer_id: string;
  file_name: string;
  file_size: number;
  sender_device_id: string;
  created_at: number;
  status: 'pending' | 'downloaded' | 'uploading';
  download_url: string;
}

interface DownloadProgress {
  transfer_id: string;
  percent: number;
  bytes_received: number;
  total_bytes: number;
}

export function useInbox() {
  const [transfers, setTransfers] = useState<Transfer[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [downloadingIds, setDownloadingIds] = useState<Set<string>>(new Set());
  const [downloadProgress, setDownloadProgress] = useState<Record<string, number>>({});
  const [downloadErrors, setDownloadErrors] = useState<Record<string, string>>({});
  const initialLoadDone = useRef(false);

  const pendingTransfers = transfers.filter(t => t.status === 'pending');
  const downloadedTransfers = transfers.filter(t => t.status === 'downloaded');
  const pendingCount = pendingTransfers.length;

  const refresh = useCallback(async () => {
    try {
      const result = await api.getInbox();
      setTransfers(result.transfers as Transfer[]);
      if (!initialLoadDone.current) {
        initialLoadDone.current = true;
        setLoading(false);
      }
      setError(null);
    } catch (e) {
      if (!initialLoadDone.current) {
        initialLoadDone.current = true;
        setLoading(false);
        setError('Cannot reach server -- check your internet connection.');
      }
    }
  }, []);

  // Auto-refresh: on mount, every 30s, and on window focus
  useEffect(() => {
    refresh();

    const interval = setInterval(refresh, 30000);

    let unlisten: (() => void) | undefined;
    getCurrentWebviewWindow()
      .onFocusChanged(({ payload: focused }) => {
        if (focused) refresh();
      })
      .then(fn => { unlisten = fn; });

    return () => {
      clearInterval(interval);
      if (unlisten) unlisten();
    };
  }, [refresh]);

  // Listen for download-progress events
  useEffect(() => {
    let unlisten: (() => void) | undefined;
    listen<DownloadProgress>('download-progress', (event) => {
      const { transfer_id, percent } = event.payload;
      setDownloadProgress(prev => ({ ...prev, [transfer_id]: percent }));
    }).then(fn => { unlisten = fn; });

    return () => {
      if (unlisten) unlisten();
    };
  }, []);

  const downloadTransfer = useCallback(async (transfer: Transfer) => {
    setDownloadingIds(prev => new Set(prev).add(transfer.transfer_id));
    setDownloadProgress(prev => ({ ...prev, [transfer.transfer_id]: 0 }));
    setDownloadErrors(prev => {
      const next = { ...prev };
      delete next[transfer.transfer_id];
      return next;
    });

    try {
      await api.downloadFile(transfer.download_url, transfer.file_name, transfer.transfer_id);
      // Move to downloaded in local state
      setTransfers(prev =>
        prev.map(t =>
          t.transfer_id === transfer.transfer_id ? { ...t, status: 'downloaded' as const } : t
        )
      );
    } catch (_e) {
      setDownloadErrors(prev => ({
        ...prev,
        [transfer.transfer_id]: 'Download failed -- check your connection and try again.',
      }));
    } finally {
      setDownloadingIds(prev => {
        const next = new Set(prev);
        next.delete(transfer.transfer_id);
        return next;
      });
      setDownloadProgress(prev => {
        const next = { ...prev };
        delete next[transfer.transfer_id];
        return next;
      });
    }
  }, []);

  const redownloadTransfer = useCallback(async (transfer: Transfer) => {
    setDownloadingIds(prev => new Set(prev).add(transfer.transfer_id));
    setDownloadProgress(prev => ({ ...prev, [transfer.transfer_id]: 0 }));

    try {
      await api.redownloadFile(transfer.download_url, transfer.file_name, transfer.transfer_id);
    } catch (_e) {
      setDownloadErrors(prev => ({
        ...prev,
        [transfer.transfer_id]: 'Download failed -- check your connection and try again.',
      }));
    } finally {
      setDownloadingIds(prev => {
        const next = new Set(prev);
        next.delete(transfer.transfer_id);
        return next;
      });
      setDownloadProgress(prev => {
        const next = { ...prev };
        delete next[transfer.transfer_id];
        return next;
      });
    }
  }, []);

  return {
    pendingTransfers,
    downloadedTransfers,
    pendingCount,
    loading,
    error,
    refresh,
    downloadTransfer,
    redownloadTransfer,
    downloadingIds,
    downloadProgress,
    downloadErrors,
  };
}
