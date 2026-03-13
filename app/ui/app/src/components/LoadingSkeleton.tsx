import React from "react";

interface LoadingSkeletonProps {
  variant?: "text" | "circle" | "rectangular";
  width?: string;
  height?: string;
  className?: string;
}

export const LoadingSkeleton: React.FC<LoadingSkeletonProps> = ({
  variant = "rectangular",
  width = "100%",
  height = "1rem",
  className = "",
}) => {
  const baseClass = "animate-pulse bg-neutral-200 dark:bg-neutral-700";
  
  const variantClass = {
    text: "rounded",
    circle: "rounded-full",
    rectangular: "rounded-lg",
  }[variant];

  return (
    <div
      className={`${baseClass} ${variantClass} ${className}`}
      style={{ width, height }}
      aria-label="Loading..."
      role="status"
    />
  );
};

export const ChatListSkeleton: React.FC = () => {
  return (
    <div className="p-4 space-y-3">
      {[...Array(5)].map((_, i) => (
        <div key={i} className="space-y-2">
          <LoadingSkeleton height="1.5rem" width="80%" />
          <LoadingSkeleton height="1rem" width="60%" />
        </div>
      ))}
    </div>
  );
};

export const ChatMessageSkeleton: React.FC = () => {
  return (
    <div className="space-y-4 p-4">
      <div className="flex items-start space-x-3">
        <LoadingSkeleton variant="circle" width="2.5rem" height="2.5rem" />
        <div className="flex-1 space-y-2">
          <LoadingSkeleton height="1rem" width="90%" />
          <LoadingSkeleton height="1rem" width="75%" />
          <LoadingSkeleton height="1rem" width="85%" />
        </div>
      </div>
    </div>
  );
};

export const ModelPickerSkeleton: React.FC = () => {
  return (
    <div className="space-y-2 p-2">
      {[...Array(3)].map((_, i) => (
        <LoadingSkeleton key={i} height="2.5rem" />
      ))}
    </div>
  );
};
