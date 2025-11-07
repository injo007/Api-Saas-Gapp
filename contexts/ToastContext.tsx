
import React, { createContext, useState, useContext, useCallback } from 'react';
import { v4 as uuidv4 } from 'uuid'; // For unique IDs for toasts

// A type definition for the toast properties
interface ToastOptions {
  message: string;
  type: 'success' | 'error' | 'info';
}

// Internal interface for toasts managed by the context, includes an ID
interface ToastItem extends ToastOptions {
  id: string;
}

// The shape of the context value
interface ToastContextType {
  toasts: ToastItem[];
  addToast: (options: ToastOptions) => void;
  dismissToast: (id: string) => void;
}

const ToastContext = createContext<ToastContextType | undefined>(undefined);

export const ToastProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [toasts, setToasts] = useState<ToastItem[]>([]);

  const addToast = useCallback((options: ToastOptions) => {
    const id = uuidv4();
    setToasts((prevToasts) => [...prevToasts, { id, ...options }]);
  }, []);

  const dismissToast = useCallback((id: string) => {
    setToasts((prevToasts) => prevToasts.filter((toast) => toast.id !== id));
  }, []);

  return (
    <ToastContext.Provider value={{ toasts, addToast, dismissToast }}>
      {children}
    </ToastContext.Provider>
  );
};

export const useToast = () => {
  const context = useContext(ToastContext);
  if (context === undefined) {
    throw new Error('useToast must be used within a ToastProvider');
  }
  return context;
};

// Add uuid library to pyproject.toml if not already there,
// or use a simpler incremental ID generation for frontend if not using npm.
// For this environment, we'll assume uuid is available or polyfilled for browser use.
// If not, a simple counter could be used:
// let nextToastId = 0;
// const addToast = useCallback((options: ToastOptions) => {
//   const id = String(nextToastId++);
//   setToasts((prevToasts) => [...prevToasts, { id, ...options }]);
// }, []);