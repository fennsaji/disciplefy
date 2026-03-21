// marketing/components/blog/PostCard.tsx
import { Link } from "@/lib/navigation";
import type { PostMeta } from "@/lib/blog";
import { formatDate } from "@/lib/format";

const TAG_GRADIENT: Record<string, string> = {
  foundations:   "from-indigo-500 to-violet-500",
  seeker:        "from-violet-500 to-purple-500",
  prayer:        "from-blue-500 to-indigo-500",
  "bible-study": "from-indigo-500 to-violet-500",
  discipleship:  "from-teal-500 to-indigo-500",
  growth:        "from-emerald-500 to-teal-500",
  theology:      "from-violet-600 to-purple-600",
  devotional:    "from-rose-500 to-pink-500",
};
const DEFAULT_GRADIENT = "from-indigo-500 to-violet-600";

function getGradient(tags: string[]) {
  for (const tag of tags) {
    if (TAG_GRADIENT[tag]) return TAG_GRADIENT[tag];
  }
  return DEFAULT_GRADIENT;
}

export function PostCard({ post }: { post: PostMeta }) {
  const gradient = getGradient(post.tags);
  return (
    <Link
      href={`/blog/${post.slug}`}
      prefetch={false}
      className="group flex flex-col rounded-2xl bg-[var(--surface)] border border-[var(--border)] hover:border-primary/40 hover:shadow-lg hover:-translate-y-0.5 transition-all duration-200 overflow-hidden"
    >
      {/* Gradient accent stripe */}
      <div className={`h-1 w-full bg-gradient-to-r ${gradient} opacity-80 group-hover:opacity-100 transition-opacity`} />

      <div className="flex flex-col flex-1 p-6">
        {/* Tags */}
        {post.tags.length > 0 && (
          <div className="flex flex-wrap gap-1.5 mb-3">
            {post.tags.slice(0, 3).map((tag) => (
              <span
                key={tag}
                className="inline-block text-xs font-semibold text-primary dark:text-indigo-300 bg-primary/10 dark:bg-indigo-500/15 px-2.5 py-0.5 rounded-full"
              >
                {tag}
              </span>
            ))}
          </div>
        )}

        {/* Title */}
        <h3 className="font-display font-semibold text-lg leading-snug mb-2 group-hover:text-primary transition-colors flex-1">
          {post.title}
        </h3>

        {/* Excerpt */}
        <p className="text-sm text-[var(--muted)] mb-4 line-clamp-2 leading-relaxed">
          {post.excerpt}
        </p>

        {/* Footer */}
        <div className="flex items-center justify-between text-xs text-[var(--muted)] mt-auto pt-3 border-t border-[var(--border)]">
          <span className="font-medium">{post.author}</span>
          <span className="flex items-center gap-1.5">
            <span>{formatDate(post.published_at)}</span>
            <span>·</span>
            <span>{post.read_time} min read</span>
          </span>
        </div>
      </div>
    </Link>
  );
}
