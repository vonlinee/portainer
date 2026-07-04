import { ReactNode } from 'react';
import { render, screen } from '@testing-library/react';
import { vi } from 'vitest';

import { createMockEnvironment } from '@/react-tools/test-mocks';
import {
  EnvironmentType,
  type Environment,
} from '@/react/portainer/environments/types';
import { useEnvironmentList } from '@/react/portainer/environments/queries/useEnvironmentList';

import { WizardEndpointsList } from './WizardEndpointsList';

vi.mock('@/react/portainer/environments/queries/useEnvironmentList', () => ({
  ENVIRONMENTS_POLLING_INTERVAL: 30000,
  useEnvironmentList: vi.fn(),
}));

vi.mock('@@/Link', () => ({
  Link: ({
    children,
    to,
    params,
    ...props
  }: {
    children: ReactNode;
    to: string;
    params: Record<string, unknown>;
  }) => (
    <a href={`${to}:${JSON.stringify(params)}`} {...props}>
      {children}
    </a>
  ),
}));

describe('WizardEndpointsList', () => {
  beforeEach(() => {
    vi.mocked(useEnvironmentList).mockReturnValue({
      environments: [],
      isLoading: false,
      totalCount: 0,
      totalAvailable: 0,
      updateAvailable: false,
    });
  });

  it('links a new Docker environment to its dashboard', () => {
    const environment = createMockEnvironment({
      Id: 7,
      Name: 'OSH',
      Type: EnvironmentType.AgentOnDocker,
    });

    renderList([environment]);

    const link = screen.getByRole('link', { name: /OSH/i });
    expect(link).toHaveAttribute('href', 'docker.dashboard:{"endpointId":7}');
  });
});

function renderList(environments: Environment[]) {
  vi.mocked(useEnvironmentList).mockReturnValue({
    environments,
    isLoading: false,
    totalCount: environments.length,
    totalAvailable: environments.length,
    updateAvailable: false,
  });

  return render(
    <WizardEndpointsList environmentIds={environments.map((env) => env.Id)} />
  );
}
