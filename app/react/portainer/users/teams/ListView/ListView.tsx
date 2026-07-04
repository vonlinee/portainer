import { useUsers } from '@/portainer/users/queries';
import { useCurrentUser } from '@/react/hooks/useUser';

import { PageHeader } from '@@/PageHeader';

import { useTeams } from '../queries';

import { TeamsDatatable } from './TeamsDatatable';

export function ListView() {
  const { isPureAdmin } = useCurrentUser();

  const usersQuery = useUsers(false);
  const teamsQuery = useTeams(!isPureAdmin, 0);

  return (
    <>
      <PageHeader
        title="Teams"
        breadcrumbs={[{ label: 'Teams management' }]}
        reload
      />

      {teamsQuery.data && (
        <TeamsDatatable
          teams={teamsQuery.data}
          users={usersQuery.data || []}
          isLoadingUsers={!usersQuery.data}
          isAdmin={isPureAdmin}
        />
      )}
    </>
  );
}
