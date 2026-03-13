import { createFileRoute } from "@tanstack/react-router";
import { useChat } from "@/hooks/useChats";
import Chat from "@/components/Chat";
import { getChat } from "@/api";
import { SidebarLayout } from "@/components/layout/layout";
import { ChatSidebar } from "@/components/ChatSidebar";
import { ErrorBoundary } from "@/components/ErrorBoundary";

export const Route = createFileRoute("/c/$chatId")({
  component: RouteComponent,
  loader: async ({ context, params }) => {
    // Skip loading for "new" chat
    if (params.chatId !== "new") {
      context.queryClient.ensureQueryData({
        queryKey: ["chat", params.chatId],
        queryFn: () => getChat(params.chatId),
        staleTime: 1500,
      });
    }
  },
});

function RouteComponent() {
  const { chatId } = Route.useParams();

  // Always call hooks at the top level - use a flag to skip data when chatId is "new"
  const {
    data: chatData,
    isLoading: chatLoading,
    error: chatError,
  } = useChat(chatId === "new" ? "" : chatId);

  // Handle "new" chat case - just use Chat component which handles everything
  if (chatId === "new") {
    return (
      <SidebarLayout sidebar={<ChatSidebar currentChatId={chatId} />}>
        <ErrorBoundary>
          <Chat chatId={chatId} />
        </ErrorBoundary>
      </SidebarLayout>
    );
  }

  // Handle existing chat case
  if (chatLoading) {
    return (
      <SidebarLayout sidebar={<ChatSidebar currentChatId={chatId} />}>
        <div className="p-4">Loading chat...</div>
      </SidebarLayout>
    );
  }

  if (chatError) {
    return (
      <SidebarLayout sidebar={<ChatSidebar currentChatId={chatId} />}>
        <div className="p-4">
          <div className="max-w-md bg-red-50 border border-red-200 rounded-lg p-4">
            <h3 className="font-semibold text-red-900 mb-2">Error loading chat</h3>
            <p className="text-red-700 text-sm mb-3">
              {chatError instanceof Error ? chatError.message : "Failed to load chat"}
            </p>
            <button
              onClick={() => window.location.reload()}
              className="px-3 py-1.5 bg-red-600 text-white text-sm rounded hover:bg-red-700 transition"
            >
              Retry
            </button>
          </div>
        </div>
      </SidebarLayout>
    );
  }

  if (!chatData) {
    return (
      <SidebarLayout sidebar={<ChatSidebar currentChatId={chatId} />}>
        <div className="p-4">Chat not found</div>
      </SidebarLayout>
    );
  }

  return (
    <SidebarLayout sidebar={<ChatSidebar currentChatId={chatId} />}>
      <ErrorBoundary>
        <Chat chatId={chatId} />
      </ErrorBoundary>
    </SidebarLayout>
  );
}
