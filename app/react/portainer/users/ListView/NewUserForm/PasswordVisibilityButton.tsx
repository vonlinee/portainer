import { EyeIcon, EyeOffIcon } from 'lucide-react';

import { Icon } from '@@/Icon';

interface Props {
  isVisible: boolean;
  label: string;
  dataCy: string;
  onClick: () => void;
}

export function PasswordVisibilityButton({
  isVisible,
  label,
  dataCy,
  onClick,
}: Props) {
  const action = isVisible ? 'Hide' : 'Show';

  return (
    <button
      type="button"
      className="border-0 bg-transparent p-0 text-gray-7 hover:text-gray-9 th-dark:text-gray-5 th-dark:hover:text-gray-3"
      aria-label={`${action} ${label}`}
      title={`${action} ${label}`}
      data-cy={dataCy}
      onClick={onClick}
    >
      <Icon icon={isVisible ? EyeOffIcon : EyeIcon} />
    </button>
  );
}
