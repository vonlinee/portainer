import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { vi } from 'vitest';

import { Role, User } from '@/portainer/users/types';
import { useCurrentUser, useUser } from '@/react/hooks/useUser';
import { AuthenticationMethod } from '@/react/portainer/settings/types';
import {
  usePublicSettings,
  useSettings,
} from '@/react/portainer/settings/queries';
import { useUsers } from '@/portainer/users/queries';
import { withTestRouter } from '@/react/test-utils/withRouter';
import { withTestQueryProvider } from '@/react/test-utils/withTestQuery';
import { createMockQueryResult } from '@/react-tools/test-mocks';

import { useTeamMemberships } from '../teams/queries/useTeamMemberships';
import { useTeams } from '../teams/queries';

import { ListView } from './ListView';

const createUserMutate = vi.fn();

vi.mock('@/react/hooks/useUser', () => ({
  useCurrentUser: vi.fn(),
  useUser: vi.fn(),
}));

vi.mock('@/react/portainer/settings/queries', () => ({
  usePublicSettings: vi.fn(),
  useSettings: vi.fn(),
}));

vi.mock('@/portainer/users/queries', () => ({
  useUsers: vi.fn(),
}));

vi.mock('../teams/queries/useTeamMemberships', () => ({
  useTeamMemberships: vi.fn(),
}));

vi.mock('../teams/queries', () => ({
  useTeams: vi.fn(),
}));

vi.mock('../queries/useCreateUserMutation', () => ({
  useCreateUserMutation: vi.fn(() => ({
    isLoading: false,
    mutate: createUserMutate,
  })),
}));

describe('Users ListView', () => {
  beforeEach(() => {
    const user: User = {
      Id: 1,
      Username: 'admin',
      Role: Role.Admin,
      EndpointAuthorizations: {},
      ThemeSettings: { color: 'auto' },
      UseCache: false,
    };
    createUserMutate.mockImplementation((_, options) => {
      options?.onSuccess?.();
    });

    const currentUser = {
      user,
      isPureAdmin: true,
    };

    vi.mocked(useCurrentUser).mockReturnValue(currentUser);
    vi.mocked(useUser).mockReturnValue(currentUser);

    vi.mocked(useUsers).mockReturnValue(
      createMockQueryResult([]) as ReturnType<typeof useUsers>
    );

    vi.mocked(useTeamMemberships).mockReturnValue(
      createMockQueryResult([]) as ReturnType<typeof useTeamMemberships>
    );

    vi.mocked(useTeams).mockReturnValue(
      createMockQueryResult([]) as ReturnType<typeof useTeams>
    );

    vi.mocked(useSettings).mockReturnValue(
      createMockQueryResult({
        AuthenticationMethod: AuthenticationMethod.Internal,
      }) as ReturnType<typeof useSettings>
    );

    vi.mocked(usePublicSettings).mockReturnValue(
      createMockQueryResult({
        AuthenticationMethod: AuthenticationMethod.Internal,
        RequiredPasswordLength: 4,
      }) as ReturnType<typeof usePublicSettings>
    );
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it('shows user creation as a table action modal', async () => {
    const user = userEvent.setup();

    renderComponent();

    expect(screen.getAllByRole('heading', { name: 'Users' })).toHaveLength(2);
    expect(
      screen.queryByRole('heading', { name: 'Add a new user' })
    ).not.toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: /create user/i }));

    expect(
      screen.getByRole('heading', { name: 'Add a new user' })
    ).toBeVisible();
    expect(screen.getByRole('textbox', { name: /username/i })).toBeVisible();

    await user.type(screen.getByRole('textbox', { name: /username/i }), 'jdoe');
    const passwordInput = screen.getByTestId('user-passwordInput');
    const confirmPasswordInput = screen.getByTestId('user-passwordConfirmInput');

    expect(passwordInput).toHaveAttribute('type', 'password');
    expect(confirmPasswordInput).toHaveAttribute('type', 'password');

    await user.type(passwordInput, 'pass');
    await user.click(screen.getByRole('button', { name: /show password/i }));
    expect(passwordInput).toHaveAttribute('type', 'text');
    expect(passwordInput).toHaveValue('pass');
    await user.click(screen.getByRole('button', { name: /hide password/i }));
    expect(passwordInput).toHaveAttribute('type', 'password');

    await user.type(confirmPasswordInput, 'pass');
    await user.click(
      screen.getByRole('button', { name: /show confirm password/i })
    );
    expect(confirmPasswordInput).toHaveAttribute('type', 'text');
    expect(confirmPasswordInput).toHaveValue('pass');
    await user.click(screen.getByRole('button', { name: /create user/i }));

    expect(createUserMutate).toHaveBeenCalledWith(
      {
        password: 'pass',
        role: Role.Standard,
        teams: [],
        username: 'jdoe',
      },
      expect.any(Object)
    );
    expect(
      screen.queryByRole('heading', { name: 'Add a new user' })
    ).not.toBeInTheDocument();
  });
});

function renderComponent() {
  const Wrapped = withTestQueryProvider(withTestRouter(ListView));

  return render(<Wrapped />);
}
