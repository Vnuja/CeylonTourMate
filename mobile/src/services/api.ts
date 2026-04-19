import axios, { AxiosInstance, AxiosError, InternalAxiosRequestConfig } from 'axios';
import { useUIStore } from '../store/uiStore';

let authToken: string | null = null;
let logoutCallback: (() => void) | null = null;

export const setAuthToken = (token: string | null) => {
  authToken = token;
};

export const setLogoutCallback = (cb: () => void) => {
  logoutCallback = cb;
};

const API_BASE_URL = process.env.EXPO_PUBLIC_API_URL || 'http://localhost:3001/api';

// Create axios instance
export const apiClient: AxiosInstance = axios.create({
  baseURL: API_BASE_URL,
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor — attach JWT token
apiClient.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    if (authToken && config.headers) {
      config.headers.Authorization = `Bearer ${authToken}`;
    }
    return config;
  },
  (error: AxiosError) => {
    return Promise.reject(error);
  }
);

// Response interceptor — handle errors + token refresh
apiClient.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const originalRequest = error.config as InternalAxiosRequestConfig & { _retry?: boolean };

    // Handle 401 — token expired
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;

      try {
        // Attempt token refresh
        const refreshResponse = await axios.post(`${API_BASE_URL}/auth/refresh`, {
          token: authToken,
        });

        const newToken = refreshResponse.data.token;
        setAuthToken(newToken);

        if (originalRequest.headers) {
          originalRequest.headers.Authorization = `Bearer ${newToken}`;
        }
        return apiClient(originalRequest);
      } catch (refreshError) {
        // Refresh failed — logout
        if (logoutCallback) logoutCallback();
        return Promise.reject(refreshError);
      }
    }

    // Handle network errors
    if (!error.response) {
      useUIStore.getState().setOffline(true);
      useUIStore.getState().addNotification({
        title: 'Network Error',
        message: 'Unable to connect to server. Please check your connection.',
        type: 'error',
      });
    }

    // Handle server errors
    if (error.response?.status && error.response.status >= 500) {
      useUIStore.getState().addNotification({
        title: 'Server Error',
        message: 'Something went wrong. Please try again later.',
        type: 'error',
      });
    }

    return Promise.reject(error);
  }
);

// AI Service client (separate base URL)
const AI_BASE_URL = process.env.EXPO_PUBLIC_AI_URL || 'http://localhost:8000';

export const aiClient: AxiosInstance = axios.create({
  baseURL: AI_BASE_URL,
  timeout: 30000, // AI calls can be slow
  headers: {
    'Content-Type': 'application/json',
  },
});

// Attach same auth token to AI requests
aiClient.interceptors.request.use((config: InternalAxiosRequestConfig) => {
  if (authToken && config.headers) {
    config.headers.Authorization = `Bearer ${authToken}`;
  }
  return config;
});
