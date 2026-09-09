import { BUBBLE_DESIGN, DARK_MODE, WIDGET_DESIGN } from './constants';

export const getBubbleView = type =>
  BUBBLE_DESIGN.includes(type) ? type : BUBBLE_DESIGN[0];

export const isExpandedView = type => getBubbleView(type) === BUBBLE_DESIGN[1];

export const isBoxView = type => getBubbleView(type) === BUBBLE_DESIGN[2];

// Both the pill and the box carry the launcher title beside the icon.
export const hasLauncherLabel = type => isExpandedView(type) || isBoxView(type);

export const getWidgetStyle = style =>
  WIDGET_DESIGN.includes(style) ? style : WIDGET_DESIGN[0];

export const isFlatWidgetStyle = style => style === 'flat';

// Sites embed this as a number or a string from their own config; anything unusable falls back
// to the design's own spacing rather than pushing the launcher off-screen.
export const getBubbleBottomOffset = offset => {
  const parsed = Number.parseInt(offset, 10);
  return Number.isFinite(parsed) ? Math.max(0, parsed) : 0;
};

export const getDarkMode = darkMode =>
  DARK_MODE.includes(darkMode) ? darkMode : DARK_MODE[0];
