// Zuralog Design System — barrel export
export { PatternOverlay } from "./primitives/pattern-overlay";
export type { PatternOverlayProps } from "./primitives/pattern-overlay";

export { Text } from "./primitives/typography";
export type { TextProps } from "./primitives/typography";
export { Button as DSButton } from "./buttons/button";
export type { ButtonProps as DSButtonProps } from "./buttons/button";
export { Card } from "./cards/card";
export type { CardProps } from "./cards/card";
export { TextField } from "./inputs/text-field";
export type { TextFieldProps } from "./inputs/text-field";
export { Toggle } from "./inputs/toggle";
export type { ToggleProps } from "./inputs/toggle";
export { DSCheckbox } from "./inputs/checkbox";
export type { CheckboxProps as DSCheckboxProps } from "./inputs/checkbox";
export { DSSlider } from "./inputs/slider";
export type { SliderProps as DSSliderProps } from "./inputs/slider";
export { DSRadioGroup, RadioItem } from "./inputs/radio-group";
export type {
  RadioGroupProps as DSRadioGroupProps,
  RadioItemProps,
} from "./inputs/radio-group";

// Display components
export { Chip } from "./display/chip";
export type { ChipProps } from "./display/chip";
export { Divider } from "./display/divider";
export type { DividerProps } from "./display/divider";
export { Avatar } from "./display/avatar";
export type { AvatarProps } from "./display/avatar";
export {
  DSAccordion,
  DSAccordionItem,
  DSAccordionTrigger,
  DSAccordionContent,
} from "./display/accordion";
export {
  DSTabs,
  DSTabsList,
  DSTabsTrigger,
  DSTabsContent,
} from "./display/tabs";
export {
  DSDropdownMenu,
  DSDropdownMenuTrigger,
  DSDropdownMenuContent,
  DSDropdownMenuItem,
  DSDropdownMenuSeparator,
  DSDropdownMenuLabel,
  DSDropdownMenuCheckboxItem,
  DSDropdownMenuRadioGroup,
  DSDropdownMenuRadioItem,
  DSDropdownMenuSub,
  DSDropdownMenuSubTrigger,
  DSDropdownMenuSubContent,
} from "./display/dropdown-menu";
export { DSScrollArea, DSScrollBar } from "./display/scroll-area";
export {
  DSPagination,
  DSPaginationContent,
  DSPaginationItem,
  DSPaginationLink,
  DSPaginationPrevious,
  DSPaginationNext,
  DSPaginationEllipsis,
} from "./display/pagination";
export {
  DSCollapsible,
  DSCollapsibleTrigger,
  DSCollapsibleContent,
} from "./display/collapsible";

// Feedback components
export { Badge } from "./feedback/badge";
export type { BadgeProps } from "./feedback/badge";
export {
  DSTooltip,
  DSTooltipTrigger,
  DSTooltipContent,
} from "./feedback/tooltip";
export {
  DSDialog,
  DSDialogTrigger,
  DSDialogContent,
  DSDialogTitle,
  DSDialogDescription,
  DSDialogClose,
} from "./feedback/dialog";
export {
  DSPopover,
  DSPopoverTrigger,
  DSPopoverContent,
  DSPopoverHeader,
  DSPopoverTitle,
  DSPopoverDescription,
} from "./feedback/popover";
export {
  DSSheet,
  DSSheetTrigger,
  DSSheetClose,
  DSSheetContent,
  DSSheetHeader,
  DSSheetFooter,
  DSSheetTitle,
  DSSheetDescription,
} from "./feedback/sheet";
export { DSSkeleton } from "./feedback/skeleton";
export type { DSSkeletonProps } from "./feedback/skeleton";
export { DSProgress } from "./feedback/progress";
export type { DSProgressProps } from "./feedback/progress";
export { DSAlert } from "./feedback/alert";
export type { DSAlertProps } from "./feedback/alert";
export {
  DSHoverCard,
  DSHoverCardTrigger,
  DSHoverCardContent,
} from "./feedback/hover-card";

// Input components (new)
export { DSLabel } from "./inputs/label";
export type { DSLabelProps } from "./inputs/label";
export { DSTextarea } from "./inputs/textarea";
export type { DSTextareaProps } from "./inputs/textarea";
export {
  DSSelect,
  DSSelectTrigger,
  DSSelectContent,
  DSSelectItem,
  DSSelectLabel,
  DSSelectSeparator,
  DSSelectValue,
  DSSelectGroup,
} from "./inputs/select";
export { DSToggleGroup } from "./inputs/toggle-group";
export type { DSToggleGroupProps } from "./inputs/toggle-group";

// Hooks
export { useMagnetic } from "@/hooks/use-magnetic";
export { useTilt } from "@/hooks/use-tilt";
export { useScrollReveal } from "@/hooks/use-scroll-reveal";
export { useSplitReveal } from "@/hooks/use-split-reveal";
export { useScrambleNumber } from "@/hooks/use-scramble-number";

// Interaction components & utilities
export { SoundProvider, useSoundContext } from "./interactions/sound-provider";
export { SoundToggle } from "./interactions/sound-toggle";
export { AuroraBackground } from "./interactions/aurora-background";
export { SpotlightFollow } from "./interactions/spotlight-follow";
export { ScrollProgress } from "./interactions/scroll-progress";
export { ScrollDivider } from "./interactions/scroll-divider";
export { TypingText } from "./interactions/typing-text";
export { CustomCursor } from "./interactions/custom-cursor";
export { sageConfetti } from "./interactions/confetti";
