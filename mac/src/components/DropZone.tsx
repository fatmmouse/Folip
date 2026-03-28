import { useState, useEffect } from 'react';
import { getCurrentWebviewWindow } from '@tauri-apps/api/webviewWindow';
import { open } from '@tauri-apps/plugin-dialog';
import { Upload, CheckCircle } from 'lucide-react';
import type { UploadStatus } from '../hooks/useUpload';
import ProgressBar from './ProgressBar';

interface DropZoneProps {
  onFileDrop: (filePath: string) => void;
  uploadStatus: UploadStatus;
  progress: number;
  fileName: string | null;
  error: string | null;
}

export default function DropZone({ onFileDrop, uploadStatus, progress, fileName, error }: DropZoneProps) {
  const [dragOver, setDragOver] = useState(false);

  // Set up Tauri drag-drop event listener
  useEffect(() => {
    let unlisten: (() => void) | undefined;

    getCurrentWebviewWindow().onDragDropEvent((event) => {
      if (event.payload.type === 'enter') {
        setDragOver(true);
      } else if (event.payload.type === 'leave') {
        setDragOver(false);
      } else if (event.payload.type === 'drop') {
        setDragOver(false);
        const paths = event.payload.paths;
        if (paths && paths.length > 0) {
          onFileDrop(paths[0]);
        }
      }
    }).then((fn) => {
      unlisten = fn;
    });

    return () => {
      if (unlisten) unlisten();
    };
  }, [onFileDrop]);

  // Click to select file
  const handleClick = async () => {
    if (uploadStatus === 'uploading' || uploadStatus === 'complete') return;
    try {
      const filePath = await open({ multiple: false });
      if (typeof filePath === 'string') {
        onFileDrop(filePath);
      }
    } catch {
      // User cancelled or dialog error — ignore
    }
  };

  // --- Uploading state ---
  if (uploadStatus === 'uploading') {
    return (
      <div
        style={{
          minHeight: '120px',
          borderRadius: '8px',
          background: 'var(--color-secondary)',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'center',
          padding: '16px',
        }}
      >
        <span
          style={{
            fontSize: '13px',
            color: 'var(--color-text-primary)',
            marginBottom: '8px',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
        >
          {fileName}
        </span>
        <ProgressBar progress={progress} />
        <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '4px' }}>
          <span style={{ fontSize: '10px', color: 'var(--color-text-secondary)', lineHeight: 1.4 }}>
            {Math.round(progress)}%
          </span>
        </div>
      </div>
    );
  }

  // --- Complete state ---
  if (uploadStatus === 'complete') {
    return (
      <div
        style={{
          minHeight: '120px',
          borderRadius: '8px',
          background: 'var(--color-secondary)',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: '8px',
          animation: 'fadeIn 200ms ease',
        }}
      >
        <CheckCircle size={24} color="var(--color-success)" />
        <span style={{ fontSize: '13px', color: 'var(--color-success)', fontWeight: 600 }}>
          Sent
        </span>
      </div>
    );
  }

  // --- Error state ---
  if (uploadStatus === 'error') {
    return (
      <div
        onClick={handleClick}
        style={{
          minHeight: '120px',
          border: '2px dashed var(--color-destructive)',
          borderRadius: '8px',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          cursor: 'pointer',
          gap: '4px',
          padding: '16px',
        }}
      >
        <span style={{ fontSize: '11px', color: 'var(--color-destructive)', textAlign: 'center' }}>
          {error}
        </span>
        <span style={{ fontSize: '11px', color: 'var(--color-text-secondary)', marginTop: '4px' }}>
          Click or drag to try again
        </span>
      </div>
    );
  }

  // --- Default / drag-hover state ---
  return (
    <div
      onClick={handleClick}
      style={{
        minHeight: '120px',
        border: `2px dashed ${dragOver ? 'var(--color-accent)' : 'var(--color-text-secondary)'}`,
        borderRadius: '8px',
        background: dragOver ? 'rgba(217, 119, 87, 0.08)' : 'transparent',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        cursor: 'pointer',
        gap: '8px',
        transition: 'border-color 150ms ease, background-color 150ms ease',
      }}
    >
      <Upload size={20} color={dragOver ? 'var(--color-accent)' : 'var(--color-text-secondary)'} />
      <span
        style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '13px',
          color: dragOver ? 'var(--color-accent)' : 'var(--color-text-secondary)',
          transition: 'color 150ms ease',
        }}
      >
        {dragOver ? 'Drop to send' : 'Drag file here or click to select'}
      </span>
    </div>
  );
}
