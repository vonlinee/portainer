import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { vi } from 'vitest';

import { Role, User } from '@/portainer/users/types';
import { useUsers } from '@/portainer/users/queries';
import { useCurrentUser, useUser } from '@/react/hooks/useUser';
import { usePublicSettings } from '@/react/portainer/settings/queries';
import { createMockQueryResult } from '@/react-tools/test-mocks';
import { withTestQueryProvider } from '@/react/test-utils/withTestQuery';
import { withTestRouter } from '@/react/test-utils/withRouter';

import { useTeams } from '../queries';

import { ListView } from './ListView';

const addTeamMutate = vi.fn();

vi.mock('@/react/hooks/useUser', () => ({
  useCurrentUser: vi.fn(),
  useUser: vi.fn(),
}));

vi.mock('@/portainer/users/queries', () => ({
  useUsers: vi.fn(),
}));

vi.mock('@/react/portainer/settings/queries', () => ({
  usePublicSettings: vi.fn(),
}));

vi.mock('../queries', () => ({
  useTeams: vi.fn(),
}));

vi.mock('../queries/useAddTeamMutation', () => ({
  useAddTeamMutation: vi.fn(() => ({
    isLoading: false,
    mutate: addTeamMutate,
  })),
}));

describe('Teams ListView', () => {
  beforeEach(() => {
    const user: User = {
      Id: 1,
      Username: 'admin',
      Role: Role.Admin,
      EndpointAuthorizations: {},
      ThemeSettings: { color: 'auto' },
      UseCache: false,
    };

    const currentUser = {
      user,
      isPureAdmin: true,
    };

    vi.mocked(useCurrentUser).mockReturnValue(currentUser);
    vi.mocked(useUser).mockReturnValue(currentUser);

    vi.mocked(useUsers).mockReturnValue(
      createMockQueryResult([]) as ReturnType<typeof useUsers>
    );

    vi.mocked(useTeams).mockReturnValue(
      createMockQueryResult([]) as ReturnType<typeof useTeams>
    );

    vi.mocked(usePublicSettings).mockReturnValue(
      createMockQueryResult(false) as ReturnType<typeof usePublicSettings>
    );

    addTeamMutate.mockImplementation((_, options) => {
      options?.onSuccess?.();
    });
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it('shows team creation as a table action modal', async () => {
    const user = userEvent.setup();

    renderComponent();

    expect(screen.getAllByRole('heading', { name: 'Teams' })).toHaveLength(2);
    expect(
      screen.queryByRole('heading', { name: 'Add a new team' })
    ).not.toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: /create team/i }));

    expect(
      screen.getByRole('heading', { name: 'Add a new team' })
    ).toBeVisible();

    await user.type(screen.getByRole('textbox', { name: /name/i }), 'ops');
    await user.click(screen.getByRole('button', { name: /create team/i }));

    expect(addTeamMutate).toHaveBeenCalledWith(
      {
        leaders: [],
        name: 'ops',
      },
      expect.any(Object)
    );
    expect(
      screen.queryByRole('heading', { name: 'Add a new team' })
    ).not.toBeInTheDocument();
  });
});

function renderComponent() {
  const Wrapped = withTestQueryProvider(withTestRouter(ListView));

  return render(<Wrapped />);
}
