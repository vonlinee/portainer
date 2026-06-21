import { useCurrentStateAndParams, useRouter } from '@uirouter/react';
import { useEffect, useState } from 'react';
import { X, Slash } from 'lucide-react';
import clsx from 'clsx';
import { useStore } from 'zustand';

import {
  PlatformType,
  EnvironmentId,
  Environment,
} from '@/react/portainer/environments/types';
import { getPlatformType } from '@/react/portainer/environments/utils';
import { useEnvironment } from '@/react/portainer/environments/queries/useEnvironment';
import { environmentStore } from '@/react/hooks/current-environment-store';

import { Icon } from '@@/Icon';
import { CollapseExpandButton } from '@@/CollapseExpandButton';

import { getPlatformIconByEnvironment } from '../portainer/environments/utils/get-platform-icon';

import styles from './EnvironmentSidebar.module.css';
import { AzureSidebar } from './AzureSidebar';
import { DockerSidebar } from './DockerSidebar';
import { KubernetesSidebar } from './KubernetesSidebar';
import { SidebarSection, SidebarSectionTitle } from './SidebarSection';
import { useSidebarState } from './useSidebarState';

export function EnvironmentSidebar() {
  const { query: currentEnvironmentQuery, clearEnvironment } =
    useCurrentEnvironment();
  const environment = currentEnvironmentQuery.data;

  const { isOpen } = useSidebarState();

  if (!isOpen && !environment) {
    return null;
  }

  return (
    <div className={clsx(styles.root, 'rounded py-2')}>
      {environment ? (
        <Content environment={environment} onClear={clearEnvironment} />
      ) : (
        <SidebarSectionTitle>
          <div className="flex items-center gap-1">
            <span>Environment:</span>
            <Icon icon={Slash} className="text-xl !text-gray-6" />
            <span className="text-sm text-gray-6">None selected</span>
          </div>
        </SidebarSectionTitle>
      )}
    </div>
  );
}

interface ContentProps {
  environment: Environment;
  onClear: () => void;
}

function Content({ environment, onClear }: ContentProps) {
  const platform = getPlatformType(environment.Type);
  const Sidebar = getSidebar(platform);
  const [isExpanded, setIsExpanded] = useState(true);
  const listId = `environment-sidebar-${environment.Id}`;

  useEffect(() => {
    setIsExpanded(true);
  }, [environment.Id]);

  return (
    <SidebarSection
      title={
        <Title
          environment={environment}
          isExpanded={isExpanded}
          listId={listId}
          onClear={onClear}
          onToggle={() => setIsExpanded((isExpanded) => !isExpanded)}
        />
      }
      hoverText={environment.Name}
      aria-label={environment.Name}
      showTitleWhenOpen
    >
      {isExpanded && (
        <div id={listId} className="mt-2">
          {Sidebar && (
            <Sidebar environmentId={environment.Id} environment={environment} />
          )}
        </div>
      )}
    </SidebarSection>
  );

  function getSidebar(platform: PlatformType) {
    const sidebar: {
      [key in PlatformType]: React.ComponentType<{
        environmentId: EnvironmentId;
        environment: Environment;
      }> | null;
    } = {
      [PlatformType.Azure]: AzureSidebar,
      [PlatformType.Docker]: DockerSidebar,
      [PlatformType.Podman]: DockerSidebar, // same as docker for now, until pod management is added
      [PlatformType.Kubernetes]: KubernetesSidebar,
    };

    return sidebar[platform];
  }
}

function useCurrentEnvironment() {
  const { params } = useCurrentStateAndParams();
  const router = useRouter();

  const envStore = useStore(environmentStore);
  const { setEnvironmentId } = envStore;
  useEffect(() => {
    const environmentId = parseInt(params.endpointId, 10);
    if (params.endpointId && !Number.isNaN(environmentId)) {
      setEnvironmentId(environmentId);
    }
  }, [setEnvironmentId, params.endpointId, params.environmentId]);

  return { query: useEnvironment(envStore.environmentId), clearEnvironment };

  function clearEnvironment() {
    if (params.endpointId || params.environmentId) {
      router.stateService.go('portainer.home');
    }

    envStore.clear();
  }
}

interface TitleProps {
  environment: Environment;
  isExpanded: boolean;
  listId: string;
  onClear(): void;
  onToggle(): void;
}

function Title({
  environment,
  isExpanded,
  listId,
  onClear,
  onToggle,
}: TitleProps) {
  const { isOpen } = useSidebarState();

  const EnvironmentIcon = getPlatformIconByEnvironment(
    environment.Type,
    environment.ContainerEngine
  );

  if (!isOpen) {
    return (
      <div className="-ml-3 flex w-8 justify-center" title={environment.Name}>
        <EnvironmentIcon className="text-2xl" />
      </div>
    );
  }

  return (
    <div className="flex items-center">
      <button
        type="button"
        onClick={onToggle}
        className="flex min-w-0 flex-1 items-center border-0 bg-transparent p-0 text-left text-white"
        aria-expanded={isExpanded}
        aria-controls={listId}
      >
        <EnvironmentIcon className="mr-3 flex-none text-2xl" />
        <span className="overflow-hidden text-ellipsis whitespace-nowrap">
          {environment.Name}
        </span>
      </button>

      <div className="ml-auto mr-2 flex flex-none items-center">
        <CollapseExpandButton
          isExpanded={isExpanded}
          onClick={onToggle}
          aria-controls={listId}
          className={clsx(
            styles.titleIconBtn,
            'group flex h-5 w-5 items-center justify-center border-0 p-0 text-white'
          )}
        />

        <button
          title="Clear environment"
          type="button"
          onClick={onClear}
          className={clsx(
            styles.titleIconBtn,
            'ml-1 flex h-5 w-5 items-center justify-center rounded border-0 p-1 text-sm text-white transition-colors duration-200'
          )}
        >
          <X />
        </button>
      </div>
    </div>
  );
}
