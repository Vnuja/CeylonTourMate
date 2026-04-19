// CeylonTourMate — UI Store (Zustand)
import { create } from 'zustand';

interface Notification {
  id: string;
  title: string;
  message: string;
  type: 'info' | 'success' | 'warning' | 'error';
  timestamp: string;
  read: boolean;
}

interface UIStore {
  isLoading: boolean;
  loadingMessage: string | null;
  notifications: Notification[];
  unreadCount: number;
  isOffline: boolean;

  setLoading: (loading: boolean, message?: string) => void;
  addNotification: (notification: Omit<Notification, 'id' | 'timestamp' | 'read'>) => void;
  markNotificationRead: (id: string) => void;
  clearNotifications: () => void;
  setOffline: (offline: boolean) => void;
}

export const useUIStore = create<UIStore>((set) => ({
  isLoading: false,
  loadingMessage: null,
  notifications: [],
  unreadCount: 0,
  isOffline: false,

  setLoading: (loading, message) =>
    set({ isLoading: loading, loadingMessage: message || null }),

  addNotification: (notification) =>
    set((state) => {
      const newNotification: Notification = {
        ...notification,
        id: `notif-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`,
        timestamp: new Date().toISOString(),
        read: false,
      };
      return {
        notifications: [newNotification, ...state.notifications].slice(0, 100),
        unreadCount: state.unreadCount + 1,
      };
    }),

  markNotificationRead: (id) =>
    set((state) => ({
      notifications: state.notifications.map((n) =>
        n.id === id ? { ...n, read: true } : n
      ),
      unreadCount: Math.max(0, state.unreadCount - 1),
    })),

  clearNotifications: () => set({ notifications: [], unreadCount: 0 }),
  setOffline: (offline) => set({ isOffline: offline }),
}));
