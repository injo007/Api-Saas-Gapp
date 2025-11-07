
import React, { createContext, useState, useContext, useCallback } from 'react';

interface DialogOptions {
  title?: string;
  message: string;
  onConfirm?: () => void;
  onCancel?: () => void;
  confirmText?: string;
  cancelText?: string;
}

interface DialogState extends DialogOptions {
  isOpen: boolean;
}

interface DialogContextType {
  dialogState: DialogState;
  openDialog: (options: DialogOptions) => void;
  closeDialog: () => void;
}

const DialogContext = createContext<DialogContextType | undefined>(undefined);

export const DialogProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [dialogState, setDialogState] = useState<DialogState>({
    isOpen: false,
    message: '',
  });

  const openDialog = useCallback((options: DialogOptions) => {
    setDialogState({
      isOpen: true,
      ...options,
    });
  }, []);

  const closeDialog = useCallback(() => {
    setDialogState((prevState) => ({ ...prevState, isOpen: false }));
  }, []);

  return (
    <DialogContext.Provider value={{ dialogState, openDialog, closeDialog }}>
      {children}
    </DialogContext.Provider>
  );
};

export const useDialog = () => {
  const context = useContext(DialogContext);
  if (context === undefined) {
    throw new Error('useDialog must be used within a DialogProvider');
  }
  return context;
};