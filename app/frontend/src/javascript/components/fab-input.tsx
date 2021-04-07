import React, { BaseSyntheticEvent, ReactNode, useCallback, useEffect, useState } from 'react';
import { debounce as _debounce } from 'lodash';

interface FabInputProps {
  id: string,
  onChange?: (value: any, validity?: ValidityState) => void,
  defaultValue: any,
  icon?: ReactNode,
  addOn?: ReactNode,
  addOnClassName?: string,
  className?: string,
  disabled?: boolean,
  required?: boolean,
  debounce?: number,
  readOnly?: boolean,
  maxLength?: number,
  pattern?: string,
  placeholder?: string,
  type?: 'text' | 'date' | 'password' | 'url' | 'time' | 'tel' | 'search' | 'number' | 'month' | 'email' | 'datetime-local' | 'week',
}

/**
 * This component is a template for an input component that wraps the application style
 */
export const FabInput: React.FC<FabInputProps> = ({ id, onChange, defaultValue, icon, className, disabled, type, required, debounce, addOn, addOnClassName, readOnly, maxLength, pattern, placeholder }) => {
  const [inputValue, setInputValue] = useState<any>(defaultValue);

  /**
   * When the component is mounted, initialize the default value for the input.
   * If the default value changes, update the value of the input until there's no content in it.
   */
  useEffect(() => {
    if (!inputValue) {
      setInputValue(defaultValue);
      if (typeof onChange === 'function') {
        onChange(defaultValue);
      }
    }
  }, [defaultValue]);

  /**
   * Check if the current component was provided an icon to display
   */
  const hasIcon = (): boolean => {
    return !!icon;
  }

  /**
   * Check if the current component was provided an add-on element to display, at the end of the input
   */
  const hasAddOn = (): boolean => {
    return !!addOn;
  }

  /**
   * Debounced (ie. temporised) version of the 'on change' callback.
   */
  const debouncedOnChange = debounce ? useCallback(_debounce(onChange, debounce), [onChange, debounce]) : null;

  /**
   * Handle the change of content in the input field, and trigger the parent callback, if any
   */
  const handleChange = (e: BaseSyntheticEvent): void => {
    const { value, validity } = e.target;
    setInputValue(value);
    if (typeof onChange === 'function') {
      if (debounce) {
        debouncedOnChange(value, validity);
      } else {
        onChange(value, validity);
      }
    }
  }

  return (
    <div className={`fab-input ${className ? className : ''}`}>
      {hasIcon() && <span className="fab-input--icon">{icon}</span>}
      <input id={id}
             type={type}
             className="fab-input--input"
             value={inputValue}
             onChange={handleChange}
             disabled={disabled}
             required={required}
             readOnly={readOnly}
             maxLength={maxLength}
             pattern={pattern}
             placeholder={placeholder} />
      {hasAddOn() && <span className={`fab-input--addon ${addOnClassName ?  addOnClassName : ''}`}>{addOn}</span>}
    </div>
  );
}

FabInput.defaultProps = { type: 'text', debounce: 0 };
