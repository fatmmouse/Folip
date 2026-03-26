import { useState, useCallback, useRef } from 'react';
import { listen, type UnlistenFn } from '@tauri-apps/api/event';
import { prepareUpload, uploadFile } from '../lib/api';

export type UploadStatus = 'idle' | 'uploading' | 'complete' | 'error';

export function useUpload() {
  const [status, setStatus] = useState<UploadStatus>('idle');
  const [progress, setProgress] = useState(0);
  const [fileName, setFileName] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const unlistenRef = useRef<UnlistenFn | null>(null);
  const resetTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const cleanup = useCallback(() => {
    if (unlistenRef.current) {
      unlistenRef.current();
      unlistenRef.current = null;
    }
    if (resetTimerRef.current) {
      clearTimeout(resetTimerRef.current);
      resetTimerRef.current = null;
    }
  }, []);

  const startUpload = useCallback(async (filePath: string, targetDeviceId: string) => {
    cleanup();

    // Extract file name from path
    const parts = filePath.split(/[/\\]/);
    const name = parts[parts.length - 1] || filePath;
    setFileName(name);
    setStatus('uploading');
    setProgress(0);
    setError(null);

    try {
      // Listen for progress events from Rust
      unlistenRef.current = await listen<{ percent: number }>('upload-progress', (event) => {
        const percent = typeof event.payload === 'number'
          ? event.payload
          : (event.payload as { percent: number }).percent ?? 0;
        setProgress(Math.min(100, Math.max(0, percent)));
      });

      // Prepare upload (get presigned URL)
      const { transfer_id, upload_url } = await prepareUpload(filePath, targetDeviceId);

      // Upload file
      await uploadFile(filePath, upload_url, transfer_id, targetDeviceId);

      // Success
      setStatus('complete');
      setProgress(100);

      // Auto-reset to idle after 2 seconds
      resetTimerRef.current = setTimeout(() => {
        setStatus('idle');
        setProgress(0);
        setFileName(null);
        setError(null);
      }, 2000);
    } catch (err) {
      setStatus('error');
      setError('Upload failed -- check your connection and try again.');
    } finally {
      if (unlistenRef.current) {
        unlistenRef.current();
        unlistenRef.current = null;
      }
    }
  }, [cleanup]);

  const reset = useCallback(() => {
    cleanup();
    setStatus('idle');
    setProgress(0);
    setFileName(null);
    setError(null);
  }, [cleanup]);

  return {
    status,
    progress,
    fileName,
    error,
    startUpload,
    reset,
  };
}
