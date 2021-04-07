/**
 * Form to set the PayZen's username, password and public key
 */

import React, { ReactNode, useEffect, useState } from 'react';
import { Loader } from './loader';
import { useTranslation } from 'react-i18next';
import SettingAPI from '../api/setting';
import { SettingName } from '../models/setting';
import { FabInput } from './fab-input';
import { enableMapSet } from 'immer';
import { useImmer } from 'use-immer';
import PayzenAPI from '../api/payzen';
import { HtmlTranslate } from './html-translate';

enableMapSet();

interface PayZenKeysFormProps {
  onValidKeys: (payZenSettings: Map<SettingName, string>) => void
}

// all settings related to PayZen that are requested by this form
const payZenSettings: Array<SettingName> = [SettingName.PayZenUsername, SettingName.PayZenPassword, SettingName.PayZenEndpoint, SettingName.PayZenHmacKey, SettingName.PayZenPublicKey];
// settings related the to PayZen REST API (server side)
const restApiSettings: Array<SettingName> = [SettingName.PayZenUsername, SettingName.PayZenPassword, SettingName.PayZenEndpoint, SettingName.PayZenHmacKey];

// initial request to the API
const payZenKeys = SettingAPI.query(payZenSettings);

// Prevent multiples call to the payzen keys validation endpoint.
// this cannot be handled by a React state because of their asynchronous nature
let pendingKeysValidation = false;

const PayZenKeysFormComponent: React.FC<PayZenKeysFormProps> = ({ onValidKeys }) => {
  const { t } = useTranslation('admin');

  const [settings, updateSettings] = useImmer<Map<SettingName, string>>(new Map(payZenSettings.map(name => [name, ''])));
  const [restApiAddOn, setRestApiAddOn] = useState<ReactNode>(null);
  const [restApiAddOnClassName, setRestApiAddOnClassName] = useState<string>('');
  const [publicKeyAddOn, setPublicKeyAddOn] = useState<ReactNode>(null);
  const [publicKeyAddOnClassName, setPublicKeyAddOnClassName] = useState<string>('');

  useEffect(() => {
    updateSettings(payZenKeys.read());
  }, []);

  useEffect(() => {
    const validClassName = 'key-valid';
    if (publicKeyAddOnClassName === validClassName && restApiAddOnClassName === validClassName) {
      onValidKeys(settings);
    }
  }, [publicKeyAddOnClassName, restApiAddOnClassName, settings]);

  useEffect(() => {
    testRestApi();
  }, [settings])

  /**
   * Assign the inputted key to the settings and check if it is valid.
   * Depending on the test result, assign an add-on icon and a style to notify the user.
   */
  const testPublicKey = (key: string) => {
    if (!key.match(/^[0-9]+:/)) {
      setPublicKeyAddOn(<i className="fa fa-times" />);
      setPublicKeyAddOnClassName('key-invalid');
      return;
    }
    updateSettings(draft => draft.set(SettingName.PayZenPublicKey, key));
    setPublicKeyAddOn(<i className="fa fa-check" />);
    setPublicKeyAddOnClassName('key-valid');
  }

  /**
   * Send a test call to the payZen REST API to check if the inputted settings key are valid.
   * Depending on the test result, assign an add-on icon and a style to notify the user.
   */
  const testRestApi = () => {
    let valid: boolean = restApiSettings.map(s => !!settings.get(s))
      .reduce((acc, val) => acc && val, true);

    if (valid && !pendingKeysValidation) {
      pendingKeysValidation = true;
      PayzenAPI.chargeSDKTest(
        settings.get(SettingName.PayZenEndpoint),
        settings.get(SettingName.PayZenUsername),
        settings.get(SettingName.PayZenPassword)
      ).then(result => {
        pendingKeysValidation = false;

        if (result.success) {
          setRestApiAddOn(<i className="fa fa-check" />);
          setRestApiAddOnClassName('key-valid');
        } else {
          setRestApiAddOn(<i className="fa fa-times" />);
          setRestApiAddOnClassName('key-invalid');
        }
      }, () => {
        pendingKeysValidation = false;

        setRestApiAddOn(<i className="fa fa-times" />);
        setRestApiAddOnClassName('key-invalid');
      });
    }
    if (!valid) {
      setRestApiAddOn(<i className="fa fa-times" />);
      setRestApiAddOnClassName('key-invalid');
    }
  }

  /**
   * Assign the inputted key to the given settings
   */
  const setApiKey = (setting: SettingName.PayZenUsername | SettingName.PayZenPassword | SettingName.PayZenEndpoint | SettingName.PayZenHmacKey) => {
    return (key: string) => {
      updateSettings(draft => draft.set(setting, key));
    }
  }

  /**
   * Check if an add-on icon must be shown for the API settings
   */
  const hasApiAddOn = () => {
    return restApiAddOn !== null;
  }

  return (
    <div className="payzen-keys-form">
      <div className="payzen-keys-info">
        <HtmlTranslate trKey="app.admin.invoices.payment.payzen_keys_info_html" />
      </div>
      <form name="payzenKeysForm">
        <fieldset>
          <legend>{t('app.admin.invoices.payment.client_keys')}</legend>
          <div className="payzen-public-input">
            <label htmlFor="payzen_public_key">{ t('app.admin.invoices.payment.payzen.payzen_public_key') } *</label>
            <FabInput id="payzen_public_key"
                      icon={<i className="fas fa-info" />}
                      defaultValue={settings.get(SettingName.PayZenPublicKey)}
                      onChange={testPublicKey}
                      addOn={publicKeyAddOn}
                      addOnClassName={publicKeyAddOnClassName}
                      debounce={200}
                      required />
          </div>
        </fieldset>
        <fieldset>
          <legend className={hasApiAddOn() ? 'with-addon' : ''}>
            <span>{t('app.admin.invoices.payment.api_keys')}</span>
            {hasApiAddOn() && <span className={`fieldset-legend--addon ${restApiAddOnClassName ?  restApiAddOnClassName : ''}`}>{restApiAddOn}</span>}
          </legend>
          <div className="payzen-api-user-input">
            <label htmlFor="payzen_username">{ t('app.admin.invoices.payment.payzen.payzen_username') } *</label>
            <FabInput id="payzen_username"
                      type="number"
                      icon={<i className="fas fa-user-alt" />}
                      defaultValue={settings.get(SettingName.PayZenUsername)}
                      onChange={setApiKey(SettingName.PayZenUsername)}
                      debounce={200}
                      required />
          </div>
          <div className="payzen-api-password-input">
            <label htmlFor="payzen_password">{ t('app.admin.invoices.payment.payzen.payzen_password') } *</label>
            <FabInput id="payzen_password"
                      icon={<i className="fas fa-key" />}
                      defaultValue={settings.get(SettingName.PayZenPassword)}
                      onChange={setApiKey(SettingName.PayZenPassword)}
                      debounce={200}
                      required />
          </div>
          <div className="payzen-api-endpoint-input">
            <label htmlFor="payzen_endpoint">{ t('app.admin.invoices.payment.payzen.payzen_endpoint') } *</label>
            <FabInput id="payzen_endpoint"
                      type="url"
                      icon={<i className="fas fa-link" />}
                      defaultValue={settings.get(SettingName.PayZenEndpoint)}
                      onChange={setApiKey(SettingName.PayZenEndpoint)}
                      debounce={200}
                      required />
          </div>
          <div className="payzen-api-hmac-input">
            <label htmlFor="payzen_hmac">{ t('app.admin.invoices.payment.payzen.payzen_hmac') } *</label>
            <FabInput id="payzen_hmac"
                      icon={<i className="fas fa-subscript" />}
                      defaultValue={settings.get(SettingName.PayZenHmacKey)}
                      onChange={setApiKey(SettingName.PayZenHmacKey)}
                      debounce={200}
                      required />
          </div>
        </fieldset>
      </form>
    </div>
  );
}

export const PayZenKeysForm: React.FC<PayZenKeysFormProps> = ({ onValidKeys }) => {
  return (
    <Loader>
      <PayZenKeysFormComponent onValidKeys={onValidKeys} />
    </Loader>
  );
}
