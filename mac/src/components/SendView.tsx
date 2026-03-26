import { useCallback, useState } from 'react';
import { useDevices } from '../hooks/useDevices';
import { useUpload } from '../hooks/useUpload';
import DeviceSelector from './DeviceSelector';
import DropZone from './DropZone';

export default function SendView() {
  const { devices, selectedDeviceId, selectDevice } = useDevices();
  const upload = useUpload();
  const [noDeviceError, setNoDeviceError] = useState(false);

  const isUploading = upload.status === 'uploading';

  const handleFileDrop = useCallback(
    (filePath: string) => {
      if (!selectedDeviceId) {
        setNoDeviceError(true);
        return;
      }
      setNoDeviceError(false);
      upload.startUpload(filePath, selectedDeviceId);
    },
    [selectedDeviceId, upload],
  );

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        height: '100%',
        padding: '12px',
        gap: '16px',
      }}
    >
      {/* Device selector */}
      <DeviceSelector
        devices={devices}
        selectedDeviceId={selectedDeviceId}
        onSelect={selectDevice}
        disabled={isUploading}
      />

      {/* No-device inline error */}
      {noDeviceError && devices.length > 0 && (
        <span style={{ fontSize: '11px', color: 'var(--color-destructive)', marginTop: '-12px' }}>
          Select a device first
        </span>
      )}

      {/* Drop zone */}
      <DropZone
        onFileDrop={handleFileDrop}
        uploadStatus={upload.status}
        progress={upload.progress}
        fileName={upload.fileName}
        error={upload.error}
      />
    </div>
  );
}
