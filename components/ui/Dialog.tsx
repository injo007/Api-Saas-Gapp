
import React from 'react';
import Button from './Button';
import { useDialog } from '../../contexts/DialogContext';

const Dialog: React.FC = () => {
  const { dialogState, closeDialog } = useDialog();

  if (!dialogState.isOpen) return null;

  const handleConfirm = () => {
    dialogState.onConfirm?.();
    closeDialog();
  };

  const handleCancel = () => {
    dialogState.onCancel?.();
    closeDialog();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50 px-4">
      <div className="bg-white dark:bg-gray-800 rounded-lg shadow-xl max-w-sm w-full p-6 space-y-4">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white">{dialogState.title || 'Confirmation'}</h3>
        <p className="text-gray-700 dark:text-gray-300">{dialogState.message}</p>
        <div className="flex justify-end space-x-3">
          <Button variant="secondary" onClick={handleCancel}>
            {dialogState.cancelText || 'Cancel'}
          </Button>
          <Button variant="primary" onClick={handleConfirm}>
            {dialogState.confirmText || 'Confirm'}
          </Button>
        </div>
      </div>
    </div>
  );
};

export default Dialog;