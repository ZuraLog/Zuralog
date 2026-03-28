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
export {
  DSCommand,
  DSCommandDialog,
  DSCommandInput,
  DSCommandList,
  DSCommandEmpty,
  DSCommandGroup,
  DSCommandItem,
  DSCommandSeparator,
  DSCommandShortcut,
} from "./display/command";
export {
  DSBreadcrumb,
  DSBreadcrumbList,
  DSBreadcrumbItem,
  DSBreadcrumbLink,
  DSBreadcrumbPage,
  DSBreadcrumbSeparator,
  DSBreadcrumbEllipsis,
} from "./display/breadcrumb";
export {
  DSNavigationMenu,
  DSNavigationMenuList,
  DSNavigationMenuItem,
  DSNavigationMenuTrigger,
  DSNavigationMenuContent,
  DSNavigationMenuLink,
  DSNavigationMenuIndicator,
  navigationMenuTriggerStyle,
} from "./display/navigation-menu";
export {
  DSContextMenu,
  DSContextMenuTrigger,
  DSContextMenuContent,
  DSContextMenuItem,
  DSContextMenuCheckboxItem,
  DSContextMenuRadioGroup,
  DSContextMenuRadioItem,
  DSContextMenuLabel,
  DSContextMenuSeparator,
  DSContextMenuShortcut,
  DSContextMenuGroup,
  DSContextMenuSub,
  DSContextMenuSubTrigger,
  DSContextMenuSubContent,
} from "./display/context-menu";

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
export { DSToaster, dsToast } from "./feedback/sonner";

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
export { DSCalendar } from "./inputs/calendar";
export {
  DSInputOTP,
  DSInputOTPGroup,
  DSInputOTPSlot,
  DSInputOTPSeparator,
} from "./inputs/input-otp";

// Data components
export {
  CHART_COLORS,
  DS_CHART_THEME,
  DSChartContainer,
  DSChartTooltip,
} from "./data/chart";
export {
  DSTable,
  DSTableHeader,
  DSTableBody,
  DSTableFooter,
  DSTableHead,
  DSTableRow,
  DSTableCell,
  DSTableCaption,
} from "./data/table";

// Form components
export {
  DSFormField,
  DSFormLabel,
  DSFormDescription,
  DSFormMessage,
} from "./inputs/form";

// Hooks
export { useMagnetic } from "@/hooks/use-magnetic";
export { useTilt } from "@/hooks/use-tilt";
export { useScrollReveal } from "@/hooks/use-scroll-reveal";
export { useSplitReveal } from "@/hooks/use-split-reveal";
export { useScrambleNumber } from "@/hooks/use-scramble-number";

// Interaction components & utilities
export { SoundProvider, useSoundContext } from "./interactions/sound-provider";
export { SoundToggle } from "./interactions/sound-toggle";
export { BrandBibleThemeProvider, useBrandBibleTheme, useBrandBibleThemeOptional } from "./interactions/brand-bible-theme";
export { ThemeToggle } from "./interactions/theme-toggle";
export { AuroraBackground } from "./interactions/aurora-background";
export { SpotlightFollow } from "./interactions/spotlight-follow";
export { ScrollProgress } from "./interactions/scroll-progress";
export { ScrollDivider } from "./interactions/scroll-divider";
export { TypingText } from "./interactions/typing-text";
export { CustomCursor } from "./interactions/custom-cursor";
export { sageConfetti } from "./interactions/confetti";
export { MorphSvgDemo } from "./interactions/morph-svg-demo";
export { FooterBouncDemo } from "./interactions/footer-bounce-demo";
export { FlipFilterDemo } from "./interactions/flip-filter-demo";
export { ShapeOverlayDemo } from "./interactions/shape-overlay-demo";
export { MorphCurveDemo } from "./interactions/morph-curve-demo";
export { RollingTextDemo } from "./interactions/rolling-text-demo";
export { ContainerTextDemo } from "./interactions/container-text-demo";
