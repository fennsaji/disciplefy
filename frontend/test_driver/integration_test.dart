// Host side of `flutter drive` for integration_test/ performance tests.
//
// Writes every timeline the test recorded with `binding.traceAction` to
// build/<reportKey>.timeline_summary.json (and the full timeline next to it),
// and prints the FrameTiming stats recorded with `binding.watchPerformance`.
// See integration_test/study_guide_scroll_perf_test.dart for how to run.

import 'dart:convert';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  return integrationDriver(
    responseDataCallback: (data) async {
      if (data == null) return;
      // Everything, per-frame lists included, to
      // build/integration_response_data.json.
      await writeResponseData(data);
      for (final entry in data.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic> && value['traceEvents'] is List) {
          final summary =
              driver.TimelineSummary.summarize(driver.Timeline.fromJson(value));
          if (summary.countFrames() == 0) {
            // ignore: avoid_print
            print('TIMELINE ${entry.key}: no frame events recorded');
            continue;
          }
          await summary.writeTimelineToFile(entry.key);
          // ignore: avoid_print
          print('TIMELINE ${entry.key}: ${jsonEncode({
                'average_frame_build_time_millis':
                    summary.computeAverageFrameBuildTimeMillis(),
                '90th_percentile_frame_build_time_millis':
                    summary.computePercentileFrameBuildTimeMillis(90),
                '99th_percentile_frame_build_time_millis':
                    summary.computePercentileFrameBuildTimeMillis(99),
                'worst_frame_build_time_millis':
                    summary.computeWorstFrameBuildTimeMillis(),
                'missed_frame_build_budget_count':
                    summary.computeMissedFrameBuildBudgetCount(),
                'average_frame_rasterizer_time_millis':
                    summary.computeAverageFrameRasterizerTimeMillis(),
                '90th_percentile_frame_rasterizer_time_millis':
                    summary.computePercentileFrameRasterizerTimeMillis(90),
                '99th_percentile_frame_rasterizer_time_millis':
                    summary.computePercentileFrameRasterizerTimeMillis(99),
                'worst_frame_rasterizer_time_millis':
                    summary.computeWorstFrameRasterizerTimeMillis(),
                'missed_frame_rasterizer_budget_count':
                    summary.computeMissedFrameRasterizerBudgetCount(),
                'frame_count': summary.countFrames(),
              })}');
        } else {
          // FrameTiming stats from watchPerformance: print the scalars
          // (averages, percentiles, missed budget counts), not the per-frame
          // lists.
          final shown = value is Map<String, dynamic>
              ? {
                  for (final e in value.entries)
                    if (e.value is! List && !e.key.contains('cache'))
                      e.key: e.value,
                }
              : value;
          // ignore: avoid_print
          print('REPORT ${entry.key}: ${jsonEncode(shown)}');
        }
      }
    },
  );
}
