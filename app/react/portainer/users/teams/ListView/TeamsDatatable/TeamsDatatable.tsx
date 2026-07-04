import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Plus, Users } from 'lucide-react';
import { ColumnDef } from '@tanstack/react-table';

import { notifySuccess } from '@/portainer/services/notifications';
import { promiseSequence } from '@/portainer/helpers/promise-utils';
import { Team, TeamId } from '@/react/portainer/users/teams/types';
import { User } from '@/portainer/users/types';

import { Datatable } from '@@/datatables';
import { buildNameColumn } from '@@/datatables/buildNameColumn';
import { createPersistedStore } from '@@/datatables/types';
import { useTableState } from '@@/datatables/useTableState';
import { DeleteButton } from '@@/buttons/DeleteButton';
import { Button } from '@@/buttons';
import { Modal } from '@@/modals/Modal';

import { deleteTeam } from '../../queries/useDeleteTeamMutation';
import { CreateTeamForm } from '../CreateTeamForm';

const storageKey = 'teams';

const columns: ColumnDef<Team>[] = [
  buildNameColumn<Team>('Name', 'portainer.teams.team', 'teams-name'),
];

interface Props {
  teams: Team[];
  users: User[];
  isLoadingUsers: boolean;
  isAdmin: boolean;
}

const settingsStore = createPersistedStore(storageKey, 'name');

export function TeamsDatatable({
  teams,
  users,
  isLoadingUsers,
  isAdmin,
}: Props) {
  const { handleRemove } = useRemoveMutation();
  const [isCreateTeamModalOpen, setIsCreateTeamModalOpen] = useState(false);
  const tableState = useTableState(settingsStore, storageKey);

  return (
    <>
      <Datatable<Team>
        dataset={teams}
        columns={columns}
        settingsManager={tableState}
        title="Teams"
        titleIcon={Users}
        renderTableActions={(selectedRows) =>
          isAdmin && (
            <>
              <Button
                icon={Plus}
                data-cy="create-team-button"
                disabled={isLoadingUsers}
                onClick={() => setIsCreateTeamModalOpen(true)}
              >
                Create team
              </Button>

              <DeleteButton
                onConfirmed={() => handleRemoveClick(selectedRows)}
                disabled={selectedRows.length === 0}
                confirmMessage="Are you sure you want to remove the selected teams?"
                data-cy="remove-teams-button"
              />
            </>
          )
        }
        data-cy="teams-datatable"
      />
      {isCreateTeamModalOpen && (
        <Modal
          onDismiss={() => setIsCreateTeamModalOpen(false)}
          aria-label="Create team"
          size="lg"
        >
          <Modal.Header title="Add a new team" />
          <Modal.Body>
            <CreateTeamForm
              users={users}
              teams={teams}
              showWidget={false}
              onSuccess={() => setIsCreateTeamModalOpen(false)}
            />
          </Modal.Body>
        </Modal>
      )}
    </>
  );

  function handleRemoveClick(selectedRows: Team[]) {
    const ids = selectedRows.map((row) => row.Id);
    handleRemove(ids);
  }
}

function useRemoveMutation() {
  const queryClient = useQueryClient();

  const deleteMutation = useMutation(
    async (ids: TeamId[]) =>
      promiseSequence(ids.map((id) => () => deleteTeam(id))),
    {
      meta: {
        error: { title: 'Failure', message: 'Unable to remove team' },
      },
      onSuccess() {
        return queryClient.invalidateQueries(['teams']);
      },
    }
  );

  return { handleRemove };

  async function handleRemove(teams: TeamId[]) {
    deleteMutation.mutate(teams, {
      onSuccess: () => {
        notifySuccess('Teams successfully removed', '');
      },
    });
  }
}
