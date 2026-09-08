// go.disciplefy.in with no path. Nobody is handed this URL on its own — every
// real link carries a path — so someone here has typed the host, truncated a
// link, or followed one that lost its tail. Send them to the site rather than
// leaving them on a 404.
import { redirect } from "next/navigation";

export default function GoRootPage() {
  redirect("https://www.disciplefy.in");
}
