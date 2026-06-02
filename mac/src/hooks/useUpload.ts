import { useState, useCallback, useRef } from 'react';
import { listen, type UnlistenFn } from '@tauri-apps/api/event';
import { prepareUpload, uploadFile } from '../lib/api';

export type UploadStatus = 'idle' | 'uploading' | 'complete' | 'error';

function basename(filePath: string): string {
  const parts = filePath.split(/[/\\]/);
  return parts[parts.length - 1] || filePath;
}

export function useUpload() {
  const [status, setStatus] = useState<UploadStatus>('idle');
  const [progress, setProgress] = useState(0);
  const [fileName, setFileName] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [totalFiles, setTotalFiles] = useState(0);
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

  const startUpload = useCallback(async (filePaths: string[], targetDeviceId: string) => {
    if (filePaths.length === 0) return;

    cleanup();

    setStatus('uploading');
    setError(null);
    setTotalFiles(filePaths.length);

    try {
      // One progress listener for the whole batch — Rust re-emits per upload.
      unlistenRef.current = await listen<{ percent: number }>('upload-progress', (event) => {
        const percent = typeof event.payload === 'number'
          ? event.payload
          : (event.payload as { percent: number }).percent ?? 0;
        setProgress(Math.min(100, Math.max(0, percent)));
      });

      for (let i = 0; i < filePaths.length; i++) {
        const filePath = filePaths[i];
        setCurrentIndex(i + 1);
        setFileName(basename(filePath));
        setProgress(0);

        const { transfer_id, upload_url } = await prepareUpload(filePath, targetDeviceId);
        await uploadFile(filePath, upload_url, transfer_id, targetDeviceId);
      }

      setStatus('complete');
      setProgress(100);

      resetTimerRef.current = setTimeout(() => {
        setStatus('idle');
        setProgress(0);
        setFileName(null);
        setError(null);
        setCurrentIndex(0);
        setTotalFiles(0);
      }, 900);
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
    setCurrentIndex(0);
    setTotalFiles(0);
  }, [cleanup]);

  return {
    status,
    progress,
    fileName,
    error,
    currentIndex,
    totalFiles,
    startUpload,
    reset,
  };
}
