import { PageHeader } from '@@/PageHeader';

import { UsersDatatable } from './UsersDatatable/UsersDatatable';

export function ListView() {
  return (
    <>
      <PageHeader title="Users" breadcrumbs="User management" reload />

      <UsersDatatable />
    </>
  );
}
