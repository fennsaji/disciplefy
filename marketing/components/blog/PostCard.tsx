// marketing/components/blog/PostCard.tsx
import { Link } from "@/lib/navigation";
import type { PostMeta } from "@/lib/blog";
import { formatDate } from "@/lib/format";

export function PostCard({ post }: { post: PostMeta }) {
  return (
    <Link
      href={`/blog/${post.slug}`}
      className="block p-6 rounded-2xl bg-[var(--surface)] border border-[var(--border)] hover:border-primary/30 transition-all group"
    >
      {post.tags[0] && (
        <span className="inline-block text-xs font-semibold text-primary bg-primary/10 px-3 py-1 rounded-full mb-3">
          {post.tags[0]}
        </span>
      )}
      <h3 className="font-display font-semibold text-lg mb-2 group-hover:text-primary transition-colors">
        {post.title}
      </h3>
      <p className="text-sm text-[var(--muted)] mb-4 line-clamp-2">{post.excerpt}</p>
      <div className="flex items-center justify-between text-xs text-[var(--muted)]">
        <span>{post.author}</span>
        <span>{formatDate(post.published_at)} · {post.read_time} min read</span>
      </div>
    </Link>
  );
}
