#pragma once

#include <qstring.h>

namespace peakshell::apps {

// Thin exprtk wrapper mirroring OpenSearch SearchFilters::calculate().
// Returns true and sets `result` when `query` compiles as a numeric expression.
[[nodiscard]] bool tryEvaluateExpression(const QString& query, double& result);

} // namespace peakshell::apps
