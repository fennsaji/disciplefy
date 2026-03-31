// marketing/components/ui/Button.tsx
import { cn } from "@/lib/utils";

type Variant = "primary" | "secondary" | "ghost";
type Size = "sm" | "md" | "lg";

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: Size;
  href?: string;
}

const variants: Record<Variant, string> = {
  primary: "bg-primary hover:bg-primary-hover text-white font-semibold",
  secondary: "border border-primary text-primary hover:bg-primary hover:text-white",
  ghost: "text-[var(--muted)] hover:text-[var(--text)]",
};

const sizes: Record<Size, string> = {
  sm: "px-4 py-2 text-sm rounded-lg",
  md: "px-6 py-3 text-sm rounded-xl",
  lg: "px-8 py-4 text-base rounded-xl",
};

export function Button({ variant = "primary", size = "md", className, children, href, ...props }: ButtonProps) {
  const classes = cn(
    "inline-flex items-center justify-center transition-colors duration-150 font-sans",
    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2",
    "disabled:opacity-50 disabled:cursor-not-allowed",
    variants[variant], sizes[size], className
  );
  if (href) return <a href={href} className={classes} target="_blank" rel="noopener noreferrer">{children}</a>;
  return <button className={classes} {...props}>{children}</button>;
}
