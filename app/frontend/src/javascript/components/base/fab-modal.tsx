import React, { ReactNode, BaseSyntheticEvent, useEffect, useState } from 'react';
import Modal from 'react-modal';
import { useTranslation } from 'react-i18next';
import { Loader } from './loader';
import CustomAssetAPI from '../../api/custom-asset';
import { CustomAsset, CustomAssetName } from '../../models/custom-asset';
import { FabButton } from './fab-button';

Modal.setAppElement('body');

export enum ModalSize {
  small = 'sm',
  medium = 'md',
  large = 'lg'
}

interface FabModalProps {
  title?: string,
  isOpen: boolean,
  toggleModal: () => void,
  confirmButton?: ReactNode,
  closeButton?: boolean,
  className?: string,
  width?: ModalSize,
  customHeader?: ReactNode,
  customFooter?: ReactNode,
  onConfirm?: (event: BaseSyntheticEvent) => void,
  preventConfirm?: boolean,
  onCreation?: () => void,
  onConfirmSendFormId?: string,
}

/**
 * This component is a template for a modal dialog that wraps the application style
 */
export const FabModal: React.FC<FabModalProps> = ({ title, isOpen, toggleModal, children, confirmButton, className, width = 'sm', closeButton, customHeader, customFooter, onConfirm, preventConfirm, onCreation, onConfirmSendFormId }) => {
  const { t } = useTranslation('shared');

  const [blackLogo, setBlackLogo] = useState<CustomAsset>(null);

  // initial request to the API to get the theme's logo, for back backgrounds
  useEffect(() => {
    CustomAssetAPI.get(CustomAssetName.LogoBlackFile).then(data => setBlackLogo(data));
  }, []);

  useEffect(() => {
    if (typeof onCreation === 'function' && isOpen) {
      onCreation();
    }
  }, [isOpen]);

  /**
   * Check if the confirm button should be present
   */
  const hasConfirmButton = (): boolean => {
    return confirmButton !== undefined;
  };

  /**
   * Check if the behavior of the confirm button is to send a form, using the provided ID
   */
  const confirmationSendForm = (): boolean => {
    return onConfirmSendFormId !== undefined;
  };

  /**
   * Should we display the close button?
   */
  const hasCloseButton = (): boolean => {
    return closeButton;
  };

  /**
   * Check if there's a custom footer
   */
  const hasCustomFooter = (): boolean => {
    return customFooter !== undefined;
  };

  /**
   * Check if there's a custom header
   */
  const hasCustomHeader = (): boolean => {
    return customHeader !== undefined;
  };

  return (
    <Modal isOpen={isOpen}
      className={`fab-modal fab-modal-${width} ${className}`}
      overlayClassName="fab-modal-overlay"
      onRequestClose={toggleModal}>
      <div className="fab-modal-header">
        <Loader>
          {blackLogo && <img src={blackLogo.custom_asset_file_attributes.attachment_url}
            alt={blackLogo.custom_asset_file_attributes.attachment}
            className="modal-logo" />}
        </Loader>
        {!hasCustomHeader() && <h1>{ title }</h1>}
        {hasCustomHeader() && customHeader}
      </div>
      <div className="fab-modal-content">
        {children}
      </div>
      <div className="fab-modal-footer">
        <Loader>
          {hasCloseButton() && <FabButton className="modal-btn--close" onClick={toggleModal}>{t('app.shared.buttons.close')}</FabButton>}
          {hasConfirmButton() && !confirmationSendForm() && <FabButton className="modal-btn--confirm" disabled={preventConfirm} onClick={onConfirm}>{confirmButton}</FabButton>}
          {hasConfirmButton() && confirmationSendForm() && <FabButton className="modal-btn--confirm" disabled={preventConfirm} type="submit" form={onConfirmSendFormId}>{confirmButton}</FabButton>}
          {hasCustomFooter() && customFooter}
        </Loader>
      </div>
    </Modal>
  );
};
