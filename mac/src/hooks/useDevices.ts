import { useState, useEffect, useCallback } from 'react';
import { getDevices } from '../lib/api';

export interface Device {
  device_id: string;
  device_name: string;
  registered_at: number;
}

const LAST_DEVICE_KEY = 'folip_last_device';

export function useDevices() {
  const [devices, setDevices] = useState<Device[]>([]);
  const [selectedDeviceId, setSelectedDeviceId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchDevices = useCallback(async () => {
    setLoading(true);
    try {
      const result = await getDevices();
      const deviceList = result.devices ?? [];
      setDevices(deviceList);

      // Select last-used device if it exists in the list, otherwise first device
      const lastUsed = localStorage.getItem(LAST_DEVICE_KEY);
      if (lastUsed && deviceList.some((d) => d.device_id === lastUsed)) {
        setSelectedDeviceId(lastUsed);
      } else if (deviceList.length > 0) {
        setSelectedDeviceId(deviceList[0].device_id);
      } else {
        setSelectedDeviceId(null);
      }
    } catch {
      // Silently fail — devices list will be empty
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchDevices();
  }, [fetchDevices]);

  const selectDevice = useCallback((deviceId: string) => {
    setSelectedDeviceId(deviceId);
    localStorage.setItem(LAST_DEVICE_KEY, deviceId);
  }, []);

  const refreshDevices = useCallback(() => {
    return fetchDevices();
  }, [fetchDevices]);

  return {
    devices,
    selectedDeviceId,
    loading,
    selectDevice,
    refreshDevices,
  };
}
