# Lighthouse Performance Improvement Tasks

Based on the Lighthouse report, here are the recommended tasks to improve the performance of the web application.

## 1. Image Optimization

Images are often a major source of performance bottlenecks.

- **Serve images in next-gen formats:** Convert images to formats like WebP or AVIF, which offer better compression than PNG or JPEG.
- **Properly size images:** Ensure that images are not larger than their rendered size on the user's screen. Use responsive images (`srcset` attribute) to serve different image sizes for different screen resolutions.
- **Efficiently encode images:** Compress images to reduce their file size without significant loss of quality.
- **Defer offscreen images:** Use lazy loading for images that are not in the initial viewport.

## 2. Reduce Unused Code

Remove or defer code that is not needed for the initial page load.

- **Reduce unused JavaScript:**
    - Use code splitting to break down large JavaScript bundles into smaller chunks that are loaded on demand.
    - Use tree shaking to remove unused code from your bundles.
- **Reduce unused CSS:**
    - Identify and remove unused CSS rules. Tools like PurgeCSS can help automate this process.

## 3. Eliminate Render-Blocking Resources

Resources that block the initial rendering of the page should be minimized.

- **Defer non-critical CSS:** Load non-critical CSS asynchronously.
- **Inline critical CSS:** Inline the CSS required for the above-the-fold content directly in the HTML to render it faster.
- **Defer or async JavaScript:** Load JavaScript asynchronously using `defer` or `async` attributes to avoid blocking the HTML parser.

## 4. Improve Loading Speed

Optimize the delivery of your application's assets.

- **Enable text compression:** Use Gzip or Brotli to compress text-based files (HTML, CSS, JavaScript).
- **Reduce server response times (Time to First Byte - TTFB):** Optimize backend logic, database queries, and server configuration to reduce the time it takes for the server to respond to a request.
- **Use a Content Delivery Network (CDN):** Serve assets from a CDN to reduce latency for users by distributing content closer to them.
- **Preconnect to required origins:** Use `<link rel="preconnect">` to establish early connections to important third-party origins.

## 5. Optimize Main-Thread Work

Reduce the amount of work the browser's main thread has to do to render the page.

- **Minimize main-thread work:** Break down long-running JavaScript tasks into smaller ones using `requestIdleCallback` or `setTimeout`.
- **Reduce JavaScript execution time:** Profile and optimize slow-running JavaScript functions.
- **Avoid large layout shifts:** Ensure that content does not shift unexpectedly during page load (Cumulative Layout Shift - CLS).

---

## Flutter-Specific Implementation Suggestions

### 1. Image Optimization

- **Use the `cached_network_image` package:** This package is already included in your `pubspec.yaml`. It provides caching and placeholder support for network images, which can significantly improve performance.
- **Use WebP for assets:** Flutter supports the WebP format. Convert your PNG and JPG assets in `assets/images/` to WebP to reduce their size. You can use tools like `cwebp` to convert images.
- **Implement responsive images:** Use the `LayoutBuilder` widget to load different image sizes based on the available screen space.
- **Lazy load images in lists:** For long lists of images, use the `ListView.builder` with `cached_network_image` to ensure that images are only loaded when they are about to be scrolled into view.

### 2. Reduce Unused Code

- **Run `flutter build appbundle --analyze-size`:** This command helps you visualize the size of your app's different components, making it easier to identify large dependencies or assets.
- **Use Dart's tree shaking:** Dart's compiler includes tree shaking, which automatically removes unused code. Ensure you are building in release mode (`flutter build apk --release` or `flutter build appbundle --release`) to take full advantage of this.
- **Analyze dependencies:** Use the `flutter pub deps` command to analyze your project's dependency tree and identify any unnecessary packages.

### 3. Eliminate Render-Blocking Resources

- **Use `defer` keyword for imports:** For libraries that are not needed at startup, you can use the `deferred as` keyword to load them lazily.
- **Optimize asset loading:** Use the `rootBundle` to load assets efficiently. For large assets, consider loading them in an isolate to avoid blocking the main thread.

### 4. Improve Loading Speed

- **Enable text compression on your server:** Ensure that your backend server (Supabase) is configured to compress responses using Gzip or Brotli.
- **Reduce server response times:** Optimize your Supabase queries and backend functions. Use the `explain` command in PostgreSQL to analyze query performance.
- **Use a CDN for assets:** If you are storing assets in Supabase Storage, they are already served via a CDN.
- **Preconnect to required origins:** While Flutter doesn't have a direct equivalent to the `<link rel="preconnect">` tag, you can warm up connections to your backend services at app startup.

### 5. Optimize Main-Thread Work

- **Use Isolates for heavy computation:** For any CPU-intensive tasks, use Dart's `Isolate` to run code on a separate thread, preventing UI jank.
- **Profile your app:** Use Flutter's DevTools to profile your app's performance and identify bottlenecks in CPU usage and rendering.
- **Optimize widget builds:**
    - Use `const` constructors for widgets that don't change.
    - Use `ListView.builder` for long lists.
    - Avoid unnecessary rebuilds by using `const` widgets and properly managing state with `flutter_bloc`.

---

## Actionable Implementation Steps

### 1. Image Optimization

1.  **Convert `google_logo.png` to WebP:**
    - Use an online converter or a command-line tool like `cwebp` to convert `/assets/images/google_logo.png` to WebP format.
    - `cwebp -q 80 /assets/images/google_logo.png -o /assets/images/google_logo.webp`
2.  **Update `login_screen.dart` to use the WebP image:**
    - Open `lib/features/auth/presentation/pages/login_screen.dart`.
    - Change `AssetImage('assets/images/google_logo.png')` to `AssetImage('assets/images/google_logo.webp')`.
3.  **Use `cached_network_image` for network images:**
    - Identify all `Image.network()` widgets in the project.
    - Replace them with `CachedNetworkImage`, providing a `placeholder` and `errorWidget`.

### 2. Reduce Unused Code

1.  **Analyze app size:**
    - Run `flutter build appbundle --analyze-size`.
    - Review the generated report to identify the largest packages and assets.
2.  **Review dependencies:**
    - Run `flutter pub deps`.
    - Examine the dependency tree for any packages that are not being used or could be replaced with a more lightweight alternative.

### 3. Eliminate Render-Blocking Resources

1.  **Identify deferrable libraries:**
    - Review your `pubspec.yaml` and identify any large libraries that are only used in specific parts of your app.
2.  **Implement deferred loading:**
    - For the identified libraries, use the `deferred as` keyword to load them on demand.
    - `import 'package:large_library/large_library.dart' deferred as large_library;`
    - `await large_library.loadLibrary();`

### 4. Improve Loading Speed

1.  **Verify text compression:**
    - Open your browser's developer tools and inspect the network requests to your Supabase backend.
    - Check the `content-encoding` header to ensure that responses are being compressed with `gzip` or `br`.
2.  **Optimize Supabase queries:**
    - Identify slow-running queries in your app.
    - Use the `EXPLAIN` command in the Supabase SQL editor to analyze the query plans and identify opportunities for optimization, such as adding indexes.

### 5. Optimize Main-Thread Work

1.  **Profile the app:**
    - Open your project in VS Code or Android Studio.
    - Launch Flutter DevTools and connect to your app.
    - Use the Performance and CPU profiler views to identify performance bottlenecks and long-running tasks.
2.  **Refactor heavy computations:**
    - For any identified long-running tasks, refactor them to run in a separate isolate using `compute()`.
3.  **Optimize widget builds:**
    - In DevTools, enable "Track Widget Rebuilds" to identify widgets that are rebuilding unnecessarily.
    - Refactor these widgets to use `const` constructors, `const` widgets, and proper state management to minimize rebuilds.
