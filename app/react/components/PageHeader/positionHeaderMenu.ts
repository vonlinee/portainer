import type { Position } from '@reach/popover';

const MENU_TOP_OFFSET = 5;
const MENU_RIGHT_OFFSET = 16;

export const positionHeaderMenu: Position = (targetRect, popoverRect) => {
  if (!targetRect || !popoverRect) {
    return {};
  }

  const headerRect = document
    .querySelector('[data-page-header]')
    ?.getBoundingClientRect();
  const minTop = window.pageYOffset + (headerRect?.bottom ?? targetRect.bottom);
  const buttonBottom = window.pageYOffset + targetRect.bottom;
  const top = Math.max(buttonBottom, minTop) + MENU_TOP_OFFSET;
  const left = Math.max(
    MENU_RIGHT_OFFSET,
    window.pageXOffset + targetRect.right - popoverRect.width
  );

  return {
    left: `${left}px`,
    top: `${top}px`,
  };
};
