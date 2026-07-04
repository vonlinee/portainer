import { PlusIcon } from 'lucide-react';
import { Form, Formik, FormikConfig } from 'formik';

import { useCurrentUser } from '@/react/hooks/useUser';
import { usePublicSettings } from '@/react/portainer/settings/queries';
import { AuthenticationMethod } from '@/react/portainer/settings/types';
import { Role } from '@/portainer/users/types';
import { notifySuccess } from '@/portainer/services/notifications';

import { Widget } from '@@/Widget';
import { FormActions } from '@@/form-components/FormActions';

import { useTeams } from '../../teams/queries';
import { useCreateUserMutation } from '../../queries/useCreateUserMutation';

import { UsernameField } from './UsernameField';
import { PasswordField } from './PasswordField';
import { ConfirmPasswordField } from './ConfirmPasswordField';
import { FormValues } from './FormValues';
import { TeamsFieldset } from './TeamsFieldset';
import { useValidation } from './useValidation';

interface Props {
  onSuccess?(): void;
  showWidget?: boolean;
}

export function NewUserForm({ onSuccess, showWidget = true }: Props) {
  const { isPureAdmin } = useCurrentUser();
  const teamsQuery = useTeams(!isPureAdmin);
  const settingsQuery = usePublicSettings();
  const createUserMutation = useCreateUserMutation();

  if (!teamsQuery.data || !settingsQuery.data) {
    return null;
  }

  const { AuthenticationMethod: authMethod } = settingsQuery.data;

  const form = (
    <NewUserFormInner
      authMethod={authMethod}
      isCreating={createUserMutation.isLoading}
      onSubmit={(values, { resetForm }) => {
        createUserMutation.mutate(
          {
            password: values.password,
            username: values.username,
            role: values.isAdmin ? Role.Admin : Role.Standard,
            teams: values.teams,
          },
          {
            onSuccess() {
              notifySuccess('User successfully created', values.username);
              resetForm();
              onSuccess?.();
            },
          }
        );
      }}
    />
  );

  if (!showWidget) {
    return form;
  }

  return (
    <div className="row">
      <div className="col-sm-12">
        <Widget>
          <Widget.Title icon={PlusIcon} title="Add a new user" />
          <Widget.Body>{form}</Widget.Body>
        </Widget>
      </div>
    </div>
  );
}

interface InnerProps {
  authMethod: AuthenticationMethod;
  isCreating: boolean;
  onSubmit: FormikConfig<FormValues>['onSubmit'];
}

function NewUserFormInner({ authMethod, isCreating, onSubmit }: InnerProps) {
  const validation = useValidation();

  return (
    <Formik<FormValues>
      initialValues={{
        username: '',
        password: '',
        confirmPassword: '',
        isAdmin: false,
        teams: [],
      }}
      validationSchema={validation}
      validateOnMount
      onSubmit={onSubmit}
    >
      {({ errors, isValid }) => (
        <Form className="form-horizontal">
          <UsernameField authMethod={authMethod} />

          {authMethod === AuthenticationMethod.Internal && (
            <>
              <PasswordField />

              <ConfirmPasswordField />
            </>
          )}

          <TeamsFieldset />

          <FormActions
            data-cy="user-createUserButton"
            submitLabel="Create user"
            isLoading={isCreating}
            isValid={isValid}
            loadingText="Creating user..."
            errors={errors}
            submitIcon={PlusIcon}
          />
        </Form>
      )}
    </Formik>
  );
}
