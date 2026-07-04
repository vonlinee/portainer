import { useState } from 'react';
import { useField } from 'formik';

import { FormControl } from '@@/form-components/FormControl';
import { InputGroup } from '@@/form-components/InputGroup';

import { FormValues } from './FormValues';
import { PasswordVisibilityButton } from './PasswordVisibilityButton';

export function PasswordField() {
  const [showPassword, setShowPassword] = useState(false);
  const [{ name, onBlur, onChange, value }, { error }] =
    useField<FormValues['password']>('password');

  return (
    <FormControl label="Password" required inputId="psw-input" errors={error}>
      <InputGroup>
        <InputGroup.Input
          type={showPassword ? 'text' : 'password'}
          name={name}
          value={value}
          onChange={onChange}
          onBlur={onBlur}
          id="psw-input"
          data-cy="user-passwordInput"
          required
          autoComplete="one-time-code"
        />
        <InputGroup.Addon>
          <PasswordVisibilityButton
            isVisible={showPassword}
            label="password"
            dataCy="user-togglePasswordVisibilityButton"
            onClick={() => setShowPassword((showPassword) => !showPassword)}
          />
        </InputGroup.Addon>
      </InputGroup>
    </FormControl>
  );
}
