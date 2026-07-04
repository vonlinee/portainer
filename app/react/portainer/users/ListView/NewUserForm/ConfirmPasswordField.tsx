import { useState } from 'react';
import { Check, XIcon } from 'lucide-react';
import { useField } from 'formik';

import { FormControl } from '@@/form-components/FormControl';
import { InputGroup } from '@@/form-components/InputGroup';
import { Icon } from '@@/Icon';

import { FormValues } from './FormValues';
import { PasswordVisibilityButton } from './PasswordVisibilityButton';

export function ConfirmPasswordField() {
  const [showPassword, setShowPassword] = useState(false);
  const [{ name, onBlur, onChange, value }, { error }] =
    useField<FormValues['confirmPassword']>('confirmPassword');

  return (
    <FormControl
      inputId="confirm_password"
      label="Confirm password"
      required
      errors={error}
    >
      <InputGroup>
        <InputGroup.Input
          id="confirm_password"
          name={name}
          data-cy="user-passwordConfirmInput"
          value={value}
          onChange={onChange}
          onBlur={onBlur}
          required
          type={showPassword ? 'text' : 'password'}
          autoComplete="one-time-code"
        />
        <InputGroup.Addon>
          <PasswordVisibilityButton
            isVisible={showPassword}
            label="confirm password"
            dataCy="user-toggleConfirmPasswordVisibilityButton"
            onClick={() => setShowPassword((showPassword) => !showPassword)}
          />
        </InputGroup.Addon>
        <InputGroup.Addon>
          {error ? (
            <Icon mode="danger" icon={XIcon} />
          ) : (
            <Icon mode="success" icon={Check} />
          )}
        </InputGroup.Addon>
      </InputGroup>
    </FormControl>
  );
}
