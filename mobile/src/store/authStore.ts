// CeylonTourMate — Auth Store (Zustand)
import { create } from 'zustand';
import { User, UserRole, LoginCredentials, RegisterData } from '../types';
import { apiClient, setAuthToken, setLogoutCallback } from '../services/api';

interface AuthStore {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  role: UserRole | null;

  // Actions
  login: (credentials: LoginCredentials) => Promise<void>;
  register: (data: RegisterData) => Promise<void>;
  socialLogin: (data: { email: string; displayName: string; photoURL?: string }) => Promise<void>;
  logout: () => void;
  setUser: (user: User) => void;
  setToken: (token: string) => void;
  setLoading: (loading: boolean) => void;
  restoreSession: () => Promise<void>;

  // Demo mode for development
  loginAsDemo: (role: UserRole) => void;
}

export const useAuthStore = create<AuthStore>((set, get) => ({
  user: null,
  token: null,
  isAuthenticated: false,
  isLoading: true,
  role: null,

  login: async (credentials: LoginCredentials) => {
    set({ isLoading: true });
    try {
      const response = await apiClient.post('/auth/login', credentials);
      const { user, token } = response.data;
      set({
        user,
        token,
        role: user.role,
        isAuthenticated: true,
        isLoading: false,
      });
    } catch (error) {
      set({ isLoading: false });
      throw error;
    }
  },

  register: async (data: RegisterData) => {
    set({ isLoading: true });
    try {
      const response = await apiClient.post('/auth/register', data);
      const { user, token } = response.data;
      set({
        user,
        token,
        role: user.role,
        isAuthenticated: true,
        isLoading: false,
      });
    } catch (error) {
      set({ isLoading: false });
      throw error;
    }
  },

  socialLogin: async (data) => {
    set({ isLoading: true });
    try {
      const response = await apiClient.post('/auth/google', data);
      const { user, token } = response.data;
      set({
        user,
        token,
        role: user.role,
        isAuthenticated: true,
        isLoading: false,
      });
    } catch (error) {
      set({ isLoading: false });
      throw error;
    }
  },

  logout: () => {
    set({
      user: null,
      token: null,
      role: null,
      isAuthenticated: false,
      isLoading: false,
    });
  },

  setUser: (user: User) => set({ user, role: user.role }),
  setToken: (token: string) => set({ token }),
  setLoading: (loading: boolean) => set({ isLoading: loading }),

  restoreSession: async () => {
    set({ isLoading: true });
    try {
      // In production, read token from SecureStore and validate
      // For now, just mark as done loading
      set({ isLoading: false });
    } catch {
      set({ isLoading: false });
    }
  },

  // Demo login for development without backend
  loginAsDemo: (role: UserRole) => {
    const demoUsers: Record<UserRole, User> = {
      [UserRole.TOURIST]: {
        id: 'demo-tourist-1',
        email: 'tourist@demo.com',
        displayName: 'Alex Tourist',
        role: UserRole.TOURIST,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
      [UserRole.GUIDE]: {
        id: 'demo-guide-1',
        email: 'guide@demo.com',
        displayName: 'Saman Guide',
        role: UserRole.GUIDE,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
      [UserRole.DRIVER]: {
        id: 'demo-driver-1',
        email: 'driver@demo.com',
        displayName: 'Kumara Driver',
        role: UserRole.DRIVER,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
      [UserRole.AGENCY_ADMIN]: {
        id: 'demo-admin-1',
        email: 'admin@demo.com',
        displayName: 'Agency Admin',
        role: UserRole.AGENCY_ADMIN,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
      [UserRole.SYSTEM_ADMIN]: {
        id: 'demo-sysadmin-1',
        email: 'sysadmin@demo.com',
        displayName: 'System Admin',
        role: UserRole.SYSTEM_ADMIN,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
    };

    const user = demoUsers[role];
    set({
      user,
      token: 'demo-token-' + role,
      role,
      isAuthenticated: true,
      isLoading: false,
    });
  },
}));

// Sync auth token with API service
useAuthStore.subscribe((state) => {
  setAuthToken(state.token);
});

// Provide a way for the API interceptor to trigger logout
setLogoutCallback(() => {
  useAuthStore.getState().logout();
});
