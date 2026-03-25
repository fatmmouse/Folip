import { useState, useEffect, useCallback } from 'react';
import * as api from '../lib/api';

export function useAuth() {
  const [isAuthenticated, setIsAuthenticated] = useState<boolean | null>(null); // null = checking
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.checkAuth().then(setIsAuthenticated).catch(() => setIsAuthenticated(false));
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    setError(null);
    try {
      await api.login(email, password);
      setIsAuthenticated(true);
    } catch (e) {
      setError(typeof e === 'string' ? e : 'Incorrect email or password.');
      throw e;
    }
  }, []);

  const register = useCallback(async (email: string, password: string) => {
    setError(null);
    try {
      await api.register(email, password);
      setIsAuthenticated(true);
    } catch (e) {
      setError(typeof e === 'string' ? e : 'Registration failed.');
      throw e;
    }
  }, []);

  const logout = useCallback(async () => {
    try { await api.logout(); } catch (_) { /* ignore */ }
    setIsAuthenticated(false);
  }, []);

  return { isAuthenticated, error, login, register, logout, clearError: () => setError(null) };
}
