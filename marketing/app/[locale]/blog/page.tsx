// marketing/app/[locale]/blog/page.tsx
import { BlogList } from "@/components/blog/BlogList";
import { getAllPosts } from "@/lib/blog";
import { type Locale } from "@/i18n";

export default async function LocaleBlogPage({
  params,
  searchParams,
}: {
  params: { locale: Locale };
  searchParams: { page?: string; tag?: string };
}) {
  const page = Math.max(1, parseInt(searchParams.page || "1", 10) || 1);
  const { posts, pagination } = await getAllPosts(params.locale, page, 12, searchParams.tag);

  return (
    <BlogList
      posts={posts}
      pagination={pagination}
      basePath={`/${params.locale}/blog`}
      tag={searchParams.tag}
    />
  );
}
